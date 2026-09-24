#if DEBUG
// Standalone experimental Metal runner. No Lumora production target imports it.
import Foundation
import Metal

struct Parameters {
    var width: UInt32, height: UInt32, radius: UInt32, gaussianRadius: UInt32, pairedDetail: UInt32
    var sigma: Float, amount: Float, p95Override: Float
}
struct FloatImage {
    let width: Int, height: Int, pixels: [Float]
    init(width: Int, height: Int, pixels: [Float]) { self.width=width; self.height=height; self.pixels=pixels }
    init(_ url: URL) throws {
        let data = try Data(contentsOf: url)
        guard data.count >= 8 else { throw NSError(domain:"image",code:1) }
        let w = Int(data.withUnsafeBytes { $0.load(fromByteOffset:0,as:UInt32.self) })
        let h = Int(data.withUnsafeBytes { $0.load(fromByteOffset:4,as:UInt32.self) })
        guard data.count == 8 + w*h*16 else { throw NSError(domain:"image",code:2) }
        width=w; height=h
        pixels = data.withUnsafeBytes { raw in
            Array(UnsafeBufferPointer(start:raw.baseAddress!.advanced(by:8).assumingMemoryBound(to:Float.self),count:w*h*4))
        }
    }
}
struct FloatMap {
    let width: Int, height: Int, pixels: [Float]
    init(width: Int, height: Int, pixels: [Float]) { self.width=width; self.height=height; self.pixels=pixels }
    init(_ url: URL) throws {
        let data=try Data(contentsOf:url)
        guard data.count>=8 else {throw NSError(domain:"map",code:1)}
        let w=Int(data.withUnsafeBytes{$0.load(fromByteOffset:0,as:UInt32.self)})
        let h=Int(data.withUnsafeBytes{$0.load(fromByteOffset:4,as:UInt32.self)})
        guard data.count==8+w*h*4 else {throw NSError(domain:"map",code:2)}
        width=w;height=h
        pixels=data.withUnsafeBytes { raw in
            Array(UnsafeBufferPointer(start:raw.baseAddress!.advanced(by:8).assumingMemoryBound(to:Float.self),count:w*h))
        }
    }
}
func writeImage(_ url: URL,_ pixels:[Float],_ width:Int,_ height:Int) throws {
    var w=UInt32(width),h=UInt32(height)
    var data=Data(bytes:&w,count:4); data.append(Data(bytes:&h,count:4))
    pixels.withUnsafeBytes { data.append(contentsOf:$0) }
    try data.write(to:url)
}
final class Runner {
    let device: MTLDevice, queue: MTLCommandQueue
    let functions: [String: MTLComputePipelineState]
    let image: FloatImage
    let source, output, yl, scratch, stats, coeff, bd, blur, fine, coarse: MTLTexture
    let importance: MTLTexture?
    let hist, p95: MTLBuffer
    let deviceAllocationBytes: Int
    let formatMode: String
    let budgetVariant: String?
    let toneKernel: String
    var paired: Bool { formatMode == "optimized" }
    init(image:FloatImage,formatMode:String,importanceMap:FloatMap?,budgetVariant:String?,toneKernel:String="finalTone") throws {
        guard let d=MTLCreateSystemDefaultDevice(),let q=d.makeCommandQueue() else {throw NSError(domain:"Metal unavailable",code:1)}
        guard budgetVariant == nil || ["A","B","C"].contains(budgetVariant!) else {throw NSError(domain:"invalid budget variant",code:1)}
        guard importanceMap == nil || budgetVariant == nil else {throw NSError(domain:"Phase4/Phase5 combination not tested",code:1)}
        device=d; queue=q; self.image=image; self.formatMode=formatMode; self.budgetVariant=budgetVariant; self.toneKernel=toneKernel
        let allocationBefore=d.currentAllocatedSize
        let options=MTLCompileOptions(); options.mathMode = .safe
        let metalSource=DebugToneShaders.source
        let lib=try d.makeLibrary(source:metalSource,options:options)
        var states:[String:MTLComputePipelineState]=[:]
        for name in ["luminanceLog","percentile","momentsH","boxV","boxH","coefficients","residual","gaussianH","gaussianV","gaussianVCoarsePair","finalTone"] {
            states[name]=try d.makeComputePipelineState(function:lib.makeFunction(name:name)!)
        }
        if importanceMap != nil {states["finalToneSpatial"]=try d.makeComputePipelineState(function:lib.makeFunction(name:"finalToneSpatial")!)}
        if let budgetVariant {
            let name="finalToneBudget"+budgetVariant
            states[name]=try d.makeComputePipelineState(function:lib.makeFunction(name:name)!)
        }
        if toneKernel != "finalTone" {
            states[toneKernel]=try d.makeComputePipelineState(function:lib.makeFunction(name:toneKernel)!)
        }
        functions=states
        func texture(_ format:MTLPixelFormat)->MTLTexture {
            let desc=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:format,width:image.width,height:image.height,mipmapped:false)
            desc.storageMode = .shared; desc.usage=[.shaderRead,.shaderWrite]
            return d.makeTexture(descriptor:desc)!
        }
        let rgL:MTLPixelFormat = (["fp32","optimized","rgba16"].contains(formatMode) || formatMode.hasPrefix("hybrid")) ? .rg32Float:.rg16Float
        let rgMom:MTLPixelFormat = ["fp32","optimized","rgba16","hybridC","hybridD"].contains(formatMode) ? .rg32Float:.rg16Float
        let rgBase:MTLPixelFormat = (["fp32","optimized","rgba16"].contains(formatMode) || formatMode.hasPrefix("hybrid")) ? .rg32Float:.rg16Float
        let rBlur:MTLPixelFormat = ["fp32","hybridB"].contains(formatMode) ? .r32Float:.r16Float
        source=texture(formatMode == "rgba16" ? .rgba16Float:.rgba32Float)
        output=texture(formatMode == "rgba16" ? .rgba16Float:.rgba32Float)
        yl=texture(rgL); scratch=texture(rgMom); stats=texture(rgMom); coeff=texture(rgMom); bd=texture(rgBase)
        if formatMode == "optimized" {
            blur=stats;fine=coeff;coarse=coeff
        } else {
            blur=texture(rBlur);fine=texture(rBlur);coarse=texture(rBlur)
        }
        if let map=importanceMap {
            let desc=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.r32Float,width:map.width,height:map.height,mipmapped:false)
            desc.storageMode = .shared;desc.usage=[.shaderRead]
            let tex=d.makeTexture(descriptor:desc)!
            map.pixels.withUnsafeBytes { raw in
                tex.replace(region:MTLRegionMake2D(0,0,map.width,map.height),mipmapLevel:0,
                            withBytes:raw.baseAddress!,bytesPerRow:map.width*4)
            }
            importance=tex
        } else {importance=nil}
        hist=d.makeBuffer(length:4096*4,options:.storageModeShared)!
        p95=d.makeBuffer(length:4,options:.storageModeShared)!
        deviceAllocationBytes=d.currentAllocatedSize-allocationBefore
        if formatMode == "rgba16" {
            let half=image.pixels.map(Float16.init)
            half.withUnsafeBytes { raw in
                source.replace(region:MTLRegionMake2D(0,0,image.width,image.height),mipmapLevel:0,
                               withBytes:raw.baseAddress!,bytesPerRow:image.width*8)
            }
        } else {
            image.pixels.withUnsafeBytes { raw in
                source.replace(region:MTLRegionMake2D(0,0,image.width,image.height),mipmapLevel:0,
                               withBytes:raw.baseAddress!,bytesPerRow:image.width*16)
            }
        }
    }
    func run(amount:Float, readback:Bool, globalSide:Int?, p95Override:Float, profile:Bool) throws -> (Double,[Float]?,[(String,Double)]) {
        memset(hist.contents(),0,4096*4)
        var cmd=queue.makeCommandBuffer()!
        var steps:[(String,Double)]=[]
        let w=image.width,h=image.height
        func encode(_ name:String,_ textures:[MTLTexture],_ buffers:[MTLBuffer],_ p:Parameters) {
            let enc=cmd.makeComputeCommandEncoder()!
            enc.label=name; enc.setComputePipelineState(functions[name]!)
            for (i,t) in textures.enumerated(){enc.setTexture(t,index:i)}
            for (i,b) in buffers.enumerated(){enc.setBuffer(b,offset:0,index:i)}
            var param=p
            enc.setBytes(&param,length:MemoryLayout<Parameters>.stride,index:buffers.count)
            let grid=MTLSize(width:name == "percentile" ? 1:w,height:name == "percentile" ? 1:h,depth:1)
            // percentile has a scalar thread_position_in_grid argument. Dispatching
            // a 16×16 group makes its implicit Y component invalid on device.
            let group=MTLSize(width:name == "percentile" ? 1:16,
                              height:name == "percentile" ? 1:16,depth:1)
            enc.dispatchThreads(grid,threadsPerThreadgroup:group); enc.endEncoding()
            if profile {
                cmd.commit();cmd.waitUntilCompleted()
                steps.append((name,(cmd.gpuEndTime-cmd.gpuStartTime)*1000))
                cmd=queue.makeCommandBuffer()!
            }
        }
        let side=globalSide ?? min(w,h)
        var p=Parameters(width:UInt32(w),height:UInt32(h),radius:UInt32(max(2,Int((Double(side) * 0.045).rounded(.toNearestOrEven)))),gaussianRadius:0,pairedDetail:paired ? 1:0,sigma:1,amount:amount,p95Override:p95Override)
        encode("luminanceLog",[source,yl],[hist],p)
        encode("percentile",[],[hist,p95],p)
        encode("momentsH",[yl,scratch],[],p)
        encode("boxV",[scratch,stats],[],p)
        encode("coefficients",[stats,coeff],[],p)
        encode("boxH",[coeff,scratch],[],p)
        encode("boxV",[scratch,stats],[],p)
        encode("residual",[yl,stats,bd],[],p)
        p.sigma=max(0.8,Float(side) * 0.004)
        p.gaussianRadius=UInt32(Int(4*p.sigma+0.5))
        encode("gaussianH",[bd,blur],[],p)
        encode("gaussianV",[blur,fine],[],p)
        p.sigma=max(2.0,Float(side) * 0.016)
        p.gaussianRadius=UInt32(Int(4*p.sigma+0.5))
        encode("gaussianH",[bd,blur],[],p)
        encode(paired ? "gaussianVCoarsePair" : "gaussianV",[blur,coarse],[],p)
        if let budgetVariant {
            encode("finalToneBudget"+budgetVariant,[source,yl,bd,fine,coarse,output],[p95],p)
        } else if let importance {
            encode("finalToneSpatial",[source,yl,bd,fine,coarse,output,importance],[p95],p)
        } else {
            encode(toneKernel,[source,yl,bd,fine,coarse,output],[p95],p)
        }
        var gpu=0.0
        if profile {
            gpu=steps.reduce(0) { $0+$1.1 }
        } else {
            cmd.commit(); cmd.waitUntilCompleted()
            if let error=cmd.error {throw error}
            gpu=(cmd.gpuEndTime-cmd.gpuStartTime)*1000
        }
        if !readback{return (gpu,nil,steps)}
        var pixels=[Float](repeating:0,count:w*h*4)
        if formatMode == "rgba16" {
            var half=[Float16](repeating:0,count:w*h*4)
            half.withUnsafeMutableBytes { raw in
                output.getBytes(raw.baseAddress!,bytesPerRow:w*8,from:MTLRegionMake2D(0,0,w,h),mipmapLevel:0)
            }
            pixels=half.map(Float.init)
        } else {
            pixels.withUnsafeMutableBytes { raw in
                output.getBytes(raw.baseAddress!,bytesPerRow:w*16,from:MTLRegionMake2D(0,0,w,h),mipmapLevel:0)
            }
        }
        return (gpu,pixels,steps)
    }
    var allocatedBytes:Int {
        var seen=Set<ObjectIdentifier>()
        let allTextures=[source,output,yl,scratch,stats,coeff,bd,blur,fine,coarse]+(importance.map{[$0]} ?? [])
        let pixelBytes=allTextures.reduce(0) { total,t in
            if !seen.insert(ObjectIdentifier(t)).inserted { return total }
            let bpp:Int
            switch t.pixelFormat {
            case .rgba32Float: bpp=16
            case .rgba16Float: bpp=8
            case .rg32Float: bpp=8
            case .rg16Float: bpp=4
            case .r32Float: bpp=4
            case .r16Float: bpp=2
            default: bpp=0
            }
            return total + bpp*t.width*t.height
        }
        return pixelBytes+hist.length+p95.length
    }
}

private enum DebugToneShaders {
    static let source = #"""
#include <metal_stdlib>
using namespace metal;

struct Parameters { uint width, height, radius, gaussianRadius, pairedDetail; float sigma, amount, p95Override; };
constant float eps = 0.005f;

int reflect101(int x, int n) {
    if (n <= 1) return 0;
    while (x < 0 || x >= n) x = x < 0 ? -x : 2 * n - x - 2;
    return x;
}
int reflect(int x, int n) {
    if (n <= 1) return 0;
    while (x < 0 || x >= n) x = x < 0 ? -x - 1 : 2 * n - x - 1;
    return x;
}
float sstep(float a, float b, float x) {
    float t = clamp((x-a)/(b-a), 0.0f, 1.0f);
    return t*t*(3.0f-2.0f*t);
}

kernel void luminanceLog(texture2d<float, access::read> src [[texture(0)]],
                         texture2d<float, access::write> dst [[texture(1)]],
                         device atomic_uint *hist [[buffer(0)]],
                         constant Parameters &p [[buffer(1)]], uint2 id [[thread_position_in_grid]]) {
    if (id.x >= p.width || id.y >= p.height) return;
    float3 rgb=src.read(id).rgb;
    float y=dot(rgb,float3(.2126f,.7152f,.0722f));
    float l=log2(max(y,0.0f)+eps);
    dst.write(float4(y,l,0,0),id);
    uint bin=min(4095u,uint(clamp(max(y,0.0f)*512.0f,0.0f,4095.0f)));
    atomic_fetch_add_explicit(&hist[bin],1u,memory_order_relaxed);
}

kernel void percentile(device atomic_uint *hist [[buffer(0)]],device float *value [[buffer(1)]],
                       constant Parameters &p [[buffer(2)]],uint id [[thread_position_in_grid]]) {
    if (id != 0) return;
    if (p.p95Override >= 0.0f) { value[0]=p.p95Override; return; }
    uint target=uint(ceil(0.95f*float(p.width*p.height)));
    uint count=0;
    for(uint i=0;i<4096;i++) {
        count+=atomic_load_explicit(&hist[i],memory_order_relaxed);
        if(count>=target) { value[0]=(float(i)+0.5f)/512.0f; return; }
    }
    value[0]=8.0f;
}

kernel void momentsH(texture2d<float,access::read> src [[texture(0)]],texture2d<float,access::write> dst [[texture(1)]],
                     constant Parameters &p [[buffer(0)]],uint2 id [[thread_position_in_grid]]) {
    if(id.x>=p.width||id.y>=p.height)return;
    float2 sum=0;
    for(int k=-int(p.radius);k<=int(p.radius);k++) {
        float l=src.read(uint2(reflect101(int(id.x)+k,int(p.width)),id.y)).g;
        sum+=float2(l,l*l);
    }
    dst.write(float4(sum/float(2*p.radius+1),0,0),id);
}
kernel void boxV(texture2d<float,access::read> src [[texture(0)]],texture2d<float,access::write> dst [[texture(1)]],
                 constant Parameters &p [[buffer(0)]],uint2 id [[thread_position_in_grid]]) {
    if(id.x>=p.width||id.y>=p.height)return;
    float2 sum=0;
    for(int k=-int(p.radius);k<=int(p.radius);k++)
        sum+=src.read(uint2(id.x,reflect101(int(id.y)+k,int(p.height)))).rg;
    dst.write(float4(sum/float(2*p.radius+1),0,0),id);
}
kernel void boxH(texture2d<float,access::read> src [[texture(0)]],texture2d<float,access::write> dst [[texture(1)]],
                 constant Parameters &p [[buffer(0)]],uint2 id [[thread_position_in_grid]]) {
    if(id.x>=p.width||id.y>=p.height)return;
    float2 sum=0;
    for(int k=-int(p.radius);k<=int(p.radius);k++)
        sum+=src.read(uint2(reflect101(int(id.x)+k,int(p.width)),id.y)).rg;
    dst.write(float4(sum/float(2*p.radius+1),0,0),id);
}
kernel void coefficients(texture2d<float,access::read> src [[texture(0)]],texture2d<float,access::write> dst [[texture(1)]],
                         constant Parameters &p [[buffer(0)]],uint2 id [[thread_position_in_grid]]) {
    if(id.x>=p.width||id.y>=p.height)return;
    float2 m=src.read(id).rg;
    float v=max(0.0f,m.y-m.x*m.x);
    float a=v/(v+.06f);
    dst.write(float4(a,m.x*(1-a),0,0),id);
}
kernel void residual(texture2d<float,access::read> logY [[texture(0)]],texture2d<float,access::read> meanAB [[texture(1)]],
                     texture2d<float,access::write> dst [[texture(2)]],constant Parameters &p [[buffer(0)]],
                     uint2 id [[thread_position_in_grid]]) {
    if(id.x>=p.width||id.y>=p.height)return;
    float l=logY.read(id).g;
    float2 ab=meanAB.read(id).rg;
    float b=ab.x*l+ab.y;
    dst.write(float4(b,l-b,0,0),id);
}
kernel void gaussianH(texture2d<float,access::read> src [[texture(0)]],texture2d<float,access::write> dst [[texture(1)]],
                      constant Parameters &p [[buffer(0)]],uint2 id [[thread_position_in_grid]]) {
    if(id.x>=p.width||id.y>=p.height)return;
    float sum=0,norm=0;
    for(int k=-int(p.gaussianRadius);k<=int(p.gaussianRadius);k++) {
        float w=exp(-.5f*float(k*k)/(p.sigma*p.sigma));
        sum+=w*src.read(uint2(reflect(int(id.x)+k,int(p.width)),id.y)).g;
        norm+=w;
    }
    dst.write(float4(sum/norm,0,0,0),id);
}
kernel void gaussianV(texture2d<float,access::read> src [[texture(0)]],texture2d<float,access::write> dst [[texture(1)]],
                      constant Parameters &p [[buffer(0)]],uint2 id [[thread_position_in_grid]]) {
    if(id.x>=p.width||id.y>=p.height)return;
    float sum=0,norm=0;
    for(int k=-int(p.gaussianRadius);k<=int(p.gaussianRadius);k++) {
        float w=exp(-.5f*float(k*k)/(p.sigma*p.sigma));
        sum+=w*src.read(uint2(id.x,reflect(int(id.y)+k,int(p.height)))).r;
        norm+=w;
    }
    dst.write(float4(sum/norm,0,0,0),id);
}
kernel void gaussianVCoarsePair(texture2d<float,access::read> src [[texture(0)]],
                                texture2d<float,access::read_write> dst [[texture(1)]],
                                constant Parameters &p [[buffer(0)]],uint2 id [[thread_position_in_grid]]) {
    if(id.x>=p.width||id.y>=p.height)return;
    float sum=0,norm=0;
    for(int k=-int(p.gaussianRadius);k<=int(p.gaussianRadius);k++) {
        float w=exp(-.5f*float(k*k)/(p.sigma*p.sigma));
        sum+=w*src.read(uint2(id.x,reflect(int(id.y)+k,int(p.height)))).r;
        norm+=w;
    }
    dst.write(float4(dst.read(id).r,sum/norm,0,0),id);
}
kernel void finalTone(texture2d<float,access::read> src [[texture(0)]],texture2d<float,access::read> yl [[texture(1)]],
                      texture2d<float,access::read> bd [[texture(2)]],texture2d<float,access::read> fine [[texture(3)]],
                      texture2d<float,access::read> coarse [[texture(4)]],texture2d<float,access::write> out [[texture(5)]],
                      device float *p95 [[buffer(0)]],constant Parameters &p [[buffer(1)]],uint2 id [[thread_position_in_grid]]) {
    if(id.x>=p.width||id.y>=p.height)return;
    float y=yl.read(id).r;
    float2 v=bd.read(id).rg;
    float b=v.x,d=v.y,f=fine.read(id).r,c=p.pairedDetail != 0 ? coarse.read(id).g : coarse.read(id).r;
    float context=sstep(.48f,.88f,p95[0]);
    float shadow=1-sstep(log2(.012f+eps),log2(.22f+eps),b);
    float h=sstep(log2(.50f+eps),log2(1.8f+eps),b);
    float white=sstep(log2(.55f+eps),log2(.95f+eps),b);
    float toe=sstep(log2(.001f+eps),log2(.015f+eps),b);
    float mapped=b+1.5f*context*shadow+.9f*context*shadow*toe-h*(1-.75f*white)
                 +.95f*c+1.08f*(f-c)+1.12f*(d-f);
    float target=max(0.0f,exp2(mapped)-eps);
    float q=target/max(y,.003f);
    float gain=q<=1.0f?q:1.0f+4.0f*tanh((q-1.0f)/4.0f);
    float4 input=src.read(id);
    out.write(float4(input.rgb+p.amount*(input.rgb*gain-input.rgb),input.a),id);
}

// Appended to Phase3 Shaders.metal at runtime. Phase2 C kernels stay untouched.
kernel void finalToneSpatial(texture2d<float,access::read> src [[texture(0)]],
                             texture2d<float,access::read> yl [[texture(1)]],
                             texture2d<float,access::read> bd [[texture(2)]],
                             texture2d<float,access::read> fine [[texture(3)]],
                             texture2d<float,access::read> coarse [[texture(4)]],
                             texture2d<float,access::write> out [[texture(5)]],
                             texture2d<float,access::sample> importance [[texture(6)]],
                             device float *p95 [[buffer(0)]],constant Parameters &p [[buffer(1)]],
                             uint2 id [[thread_position_in_grid]]) {
    if(id.x>=p.width||id.y>=p.height)return;
    float2 uv=(float2(id)+.5f)/float2(p.width,p.height);
    constexpr sampler linearSampler(coord::normalized,filter::linear,address::clamp_to_edge);
    float imp=clamp(importance.sample(linearSampler,uv).r,0.0f,1.0f);
    // Only the additional 0.9-stop C recovery is spatially modulated.
    // The 1.5-stop base recovery and all C tone/detail/gain math are unchanged.
    float extraWeight=.15f+.85f*imp;
    float y=yl.read(id).r;
    float2 v=bd.read(id).rg;
    float b=v.x,d=v.y,f=fine.read(id).r,c=p.pairedDetail != 0 ? coarse.read(id).g : coarse.read(id).r;
    float context=sstep(.48f,.88f,p95[0]);
    float shadow=1-sstep(log2(.012f+eps),log2(.22f+eps),b);
    float h=sstep(log2(.50f+eps),log2(1.8f+eps),b);
    float white=sstep(log2(.55f+eps),log2(.95f+eps),b);
    float toe=sstep(log2(.001f+eps),log2(.015f+eps),b);
    float mapped=b+1.5f*context*shadow+.9f*context*shadow*toe*extraWeight-h*(1-.75f*white)
                 +.95f*c+1.08f*(f-c)+1.12f*(d-f);
    float target=max(0.0f,exp2(mapped)-eps);
    float q=target/max(y,.003f);
    float gain=q<=1.0f?q:1.0f+4.0f*tanh((q-1.0f)/4.0f);
    float4 input=src.read(id);
    out.write(float4(input.rgb+p.amount*(input.rgb*gain-input.rgb),input.a),id);
}

// Appended to the standalone Phase 3 shader source. Existing C remains intact.
float budgetRecovery(float b) {
    // Base guided log luminance: near-black gets a small share of C's extra
    // 0.9 stop; useful shadows transition smoothly to the full extra recovery.
    return .25f + .75f*sstep(log2(.0005f+eps),log2(.012f+eps),b);
}

float budgetKneeWidth(float b) {
    // The original C knee width is 4. Near-black narrows continuously to 2.
    // The slope at raw gain=1 is still exactly one for every width.
    return 2.0f + 2.0f*sstep(log2(.0005f+eps),log2(.004f+eps),b);
}

void toneWithBudget(texture2d<float,access::read> src,
                    texture2d<float,access::read> yl,
                    texture2d<float,access::read> bd,
                    texture2d<float,access::read> fine,
                    texture2d<float,access::read> coarse,
                    texture2d<float,access::write> out,
                    device float *p95,constant Parameters &p,uint2 id,uint variant) {
    if(id.x>=p.width||id.y>=p.height)return;
    float y=yl.read(id).r;
    float2 v=bd.read(id).rg;
    float b=v.x,d=v.y,f=fine.read(id).r,c=p.pairedDetail != 0 ? coarse.read(id).g : coarse.read(id).r;
    float context=sstep(.48f,.88f,p95[0]);
    float shadow=1-sstep(log2(.012f+eps),log2(.22f+eps),b);
    float h=sstep(log2(.50f+eps),log2(1.8f+eps),b);
    float white=sstep(log2(.55f+eps),log2(.95f+eps),b);
    float toe=sstep(log2(.001f+eps),log2(.015f+eps),b);
    float extraWeight=(variant==1u||variant==3u) ? budgetRecovery(b) : 1.0f;
    float mapped=b+1.5f*context*shadow+.9f*context*shadow*toe*extraWeight-h*(1-.75f*white)
                 +.95f*c+1.08f*(f-c)+1.12f*(d-f);
    float target=max(0.0f,exp2(mapped)-eps);
    float q=target/max(y,.003f);
    float knee=(variant==2u||variant==3u) ? budgetKneeWidth(b) : 4.0f;
    float gain=q<=1.0f?q:1.0f+knee*tanh((q-1.0f)/knee);
    float4 input=src.read(id);
    out.write(float4(input.rgb+p.amount*(input.rgb*gain-input.rgb),input.a),id);
}

#define BUDGET_KERNEL(SUFFIX, NUMBER) \
kernel void finalToneBudget##SUFFIX(texture2d<float,access::read> src [[texture(0)]], \
    texture2d<float,access::read> yl [[texture(1)]],texture2d<float,access::read> bd [[texture(2)]], \
    texture2d<float,access::read> fine [[texture(3)]],texture2d<float,access::read> coarse [[texture(4)]], \
    texture2d<float,access::write> out [[texture(5)]],device float *p95 [[buffer(0)]], \
    constant Parameters &p [[buffer(1)]],uint2 id [[thread_position_in_grid]]) { \
    toneWithBudget(src,yl,bd,fine,coarse,out,p95,p,id,NUMBER); \
}

BUDGET_KERNEL(A,1u)
BUDGET_KERNEL(B,2u)
BUDGET_KERNEL(C,3u)

// Fixed Phase 1 guided and Phase 2 A/B response equations, ported from the
// archived prototypes. The shared guided decomposition is the Phase 3 runner.
void debugFixedTone(texture2d<float,access::read> src,
                    texture2d<float,access::read> yl,
                    texture2d<float,access::read> bd,
                    texture2d<float,access::read> fine,
                    texture2d<float,access::read> coarse,
                    texture2d<float,access::write> out,
                    device float *p95,constant Parameters &p,uint2 id,uint variant) {
    if(id.x>=p.width||id.y>=p.height)return;
    float y=yl.read(id).r;
    float2 v=bd.read(id).rg;
    float b=v.x,d=v.y;
    float context=sstep(.48f,.88f,p95[0]);
    float shadow=1-sstep(log2(.012f+eps),log2(.22f+eps),b);
    float h=sstep(log2(.50f+eps),log2(1.8f+eps),b);
    float mapped;
    if(variant==0u) {
        mapped=b+1.5f*context*shadow-h+d;
    } else {
        float f=fine.read(id).r;
        float c=p.pairedDetail != 0 ? coarse.read(id).g : coarse.read(id).r;
        float white=sstep(log2(.55f+eps),log2(.95f+eps),b);
        float compression=h*(variant==2u ? 1-.75f*white : 1);
        mapped=b+1.5f*context*shadow-compression+.95f*c+1.08f*(f-c)+1.12f*(d-f);
    }
    float target=max(0.0f,exp2(mapped)-eps);
    float q=target/max(y,.003f);
    float gain=min(4.0f,q);
    float4 input=src.read(id);
    out.write(float4(input.rgb+p.amount*(input.rgb*gain-input.rgb),input.a),id);
}
#define DEBUG_FIXED_KERNEL(SUFFIX, NUMBER) \
kernel void finalTone##SUFFIX(texture2d<float,access::read> src [[texture(0)]], \
    texture2d<float,access::read> yl [[texture(1)]],texture2d<float,access::read> bd [[texture(2)]], \
    texture2d<float,access::read> fine [[texture(3)]],texture2d<float,access::read> coarse [[texture(4)]], \
    texture2d<float,access::write> out [[texture(5)]],device float *p95 [[buffer(0)]], \
    constant Parameters &p [[buffer(1)]],uint2 id [[thread_position_in_grid]]) { \
    debugFixedTone(src,yl,bd,fine,coarse,out,p95,p,id,NUMBER); \
}
DEBUG_FIXED_KERNEL(Guided,0u)
DEBUG_FIXED_KERNEL(Phase2A,1u)
DEBUG_FIXED_KERNEL(Phase2B,2u)

"""#
}
#endif
