import Foundation
import CoreImage
import Metal
import ImageIO

private struct GPUParams {
    var lens: SIMD4<Float>; var depth: SIMD4<Float>; var options: SIMD4<Float>; var flags: SIMD4<UInt32>
}
public final class LensFrame {
    public let original: MTLTexture
    public let rawDepth: MTLTexture
    public let confidence: MTLTexture
    public let depth: MTLTexture
    public let output: MTLTexture
    var normalizationKey: SIMD4<Float>?
    var normalizedStrokes: [SIMD4<Float>] = []
    public let hasConfidence: Bool
    public let foreground: MTLTexture
    public let coverage: MTLTexture
    public let background: MTLTexture
    public let rawBackgroundDepth: MTLTexture
    public let geometry: MTLTexture
    public let backgroundGeometry: MTLTexture
    public let layerCount: UInt32
    public var width: Int { original.width }
    public var height: Int { original.height }
    init(original: MTLTexture, rawDepth: MTLTexture, confidence: MTLTexture, depth: MTLTexture, output: MTLTexture, hasConfidence: Bool,
         foreground: MTLTexture,coverage: MTLTexture,background: MTLTexture,rawBackgroundDepth: MTLTexture,geometry: MTLTexture,backgroundGeometry: MTLTexture,layerCount: UInt32) {
        self.original=original;self.rawDepth=rawDepth;self.confidence=confidence;self.depth=depth;self.output=output;self.hasConfidence=hasConfidence
        self.foreground=foreground;self.coverage=coverage;self.background=background;self.rawBackgroundDepth=rawBackgroundDepth
        self.geometry=geometry;self.backgroundGeometry=backgroundGeometry;self.layerCount=layerCount
    }
}
/// All image operations use GPU textures. CPU readback exists only in explicit export/validation
/// and a single Float for focus picking, never a full frame in the interactive path.
public final class DepthLensRenderer {
    public let device: MTLDevice
    public let queue: MTLCommandQueue
    public let context: CIContext
    public let shaderURL: URL
    public let workingSpace = CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!
    private let normalize: MTLComputePipelineState
    private let lens: MTLComputePipelineState?
    private let library: MTLLibrary
    private let optimized: Bool
    private var specialized: [String:MTLComputePipelineState] = [:]
    private let pick: MTLComputePipelineState
    private let prepareGeometry: MTLComputePipelineState
    private var sampleBuffers: [String:MTLBuffer] = [:]
    public init(optimized: Bool = true) throws {
        self.optimized=optimized
        guard let device=MTLCreateSystemDefaultDevice(), let queue=device.makeCommandQueue() else { throw LensError.message("Metal indisponible") }
        self.device=device;self.queue=queue
        context=CIContext(mtlDevice:device,options:[.workingColorSpace:workingSpace,.workingFormat:CIFormat.RGBAh,.cacheIntermediates:false])
        shaderURL=URL(fileURLWithPath:"DepthLensShader.swift")
        let source=DepthLensShader.source
        let options=MTLCompileOptions();options.fastMathEnabled=false
        let library=try device.makeLibrary(source:source,options:options)
        self.library=library
        normalize=try device.makeComputePipelineState(function:library.makeFunction(name:"normalizeDepth")!)
        lens = optimized ? nil:try device.makeComputePipelineState(function:library.makeFunction(name:"depthLens")!)
        pick=try device.makeComputePipelineState(function:library.makeFunction(name:"sampleFocus")!)
        prepareGeometry=try device.makeComputePipelineState(function:library.makeFunction(name:"prepareGeometry")!)
    }
    public func updateColor(_ image:CIImage, frame:LensFrame) throws {
        let zero=image.transformed(by:CGAffineTransform(translationX:-image.extent.minX,y:-image.extent.minY))
        let im=zero.transformed(by:CGAffineTransform(scaleX:Double(frame.width)/image.extent.width,y:Double(frame.height)/image.extent.height))
            .transformed(by:CGAffineTransform(scaleX:1,y:-1)).transformed(by:CGAffineTransform(translationX:0,y:Double(frame.height)))
        let cb=queue.makeCommandBuffer()!
        context.render(im,to:frame.original,commandBuffer:cb,bounds:CGRect(x:0,y:0,width:frame.width,height:frame.height),colorSpace:workingSpace)
        cb.commit();cb.waitUntilCompleted();try check(cb)
    }
    public func texture(width: Int,height: Int,format: MTLPixelFormat = .rgba16Float) throws -> MTLTexture {
        let d=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:format,width:width,height:height,mipmapped:false)
        d.usage=[.shaderRead,.shaderWrite,.renderTarget];d.storageMode = .private
        guard let t=device.makeTexture(descriptor:d) else { throw LensError.message("Allocation GPU impossible") };return t
    }
    public static func loadImage(_ url: URL) throws -> CIImage {
        guard let image=CIImage(contentsOf:url,options:[.applyOrientationProperty:true,.expandToHDR:true]) else { throw LensError.message("Photo illisible") }
        return image.transformed(by:CGAffineTransform(translationX:-image.extent.minX,y:-image.extent.minY))
    }
    public func prepare(image: CIImage, depth input: DepthInput, longEdge: Int? = nil) throws -> LensFrame {
        let ratio: CGFloat
        if let edge = longEdge { ratio = min(CGFloat(1), CGFloat(edge) / max(image.extent.width, image.extent.height)) } else { ratio = 1 }
        let w=max(1,Int((image.extent.width*ratio).rounded())),h=max(1,Int((image.extent.height*ratio).rounded()))
        let color=try texture(width:w,height:h),raw=try texture(width:w,height:h,format:.rgba32Float)
        let conf=try texture(width:w,height:h,format:.rgba32Float)
        let normalized=try texture(width:w,height:h,format:.r32Float),output=try texture(width:w,height:h)
        let geometry=try texture(width:w,height:h,format:.rg32Float),backGeometry=try texture(width:w,height:h,format:.rg32Float)
        let coverage=try texture(width:w,height:h,format:.rgba32Float)
        let front=try input.layers == nil ? color:texture(width:w,height:h)
        let back=try input.layers == nil ? color:texture(width:w,height:h)
        let backDepth=try input.layers == nil ? raw:texture(width:w,height:h,format:.rgba32Float)
        let cb=queue.makeCommandBuffer()!
        func upload(_ im: CIImage,_ to: MTLTexture,_ colorSpace: CGColorSpace?,nearestScalar: Bool = true) {
            let zero=im.transformed(by:CGAffineTransform(translationX:-im.extent.minX,y:-im.extent.minY))
            // Depth is scalar data: nearest registration avoids inventing intermediate surfaces
            // across discontinuities. Photos keep Core Image's normal image resampling.
            let sampled=colorSpace == nil && nearestScalar ? zero.samplingNearest() : zero
            let resized=sampled.transformed(by:CGAffineTransform(scaleX:Double(w)/im.extent.width,y:Double(h)/im.extent.height))
            // Explicit top-left texture storage, shared by image, raw depth, focus and brush coordinates.
            let flipped=resized.transformed(by:CGAffineTransform(scaleX:1,y:-1)).transformed(by:CGAffineTransform(translationX:0,y:Double(h)))
            context.render(flipped,to:to,commandBuffer:cb,bounds:CGRect(x:0,y:0,width:w,height:h),colorSpace:colorSpace ?? workingSpace)
        }
        upload(image,color,workingSpace);upload(input.raw,raw,nil)
        upload(input.confidence ?? CIImage(color:CIColor(red:0,green:0,blue:0)).cropped(to:input.raw.extent),conf,nil)
        if let layers=input.layers {
            for map in [layers.foregroundColor,layers.coverage,layers.backgroundColor,layers.backgroundDepth] {
                guard abs(map.extent.width/map.extent.height-image.extent.width/image.extent.height)<0.001 else {throw LensError.message("Layer/depth ratio mismatch")}
            }
            upload(layers.foregroundColor,front,workingSpace);upload(layers.coverage,coverage,nil,nearestScalar:false)
            upload(layers.backgroundColor,back,workingSpace);upload(layers.backgroundDepth,backDepth,nil)
        }else{upload(CIImage(color:CIColor(red:1,green:1,blue:1)).cropped(to:input.raw.extent),coverage,nil)}
        cb.commit();cb.waitUntilCompleted();try check(cb)
        return LensFrame(original:color,rawDepth:raw,confidence:conf,depth:normalized,output:output,hasConfidence:input.confidence != nil,
                         foreground:front,coverage:coverage,background:back,rawBackgroundDepth:backDepth,geometry:geometry,backgroundGeometry:backGeometry,layerCount:input.layers == nil ? 1:2)
    }
    public func encode(frame: LensFrame,settings: LensSettings,strokes: [DepthStroke] = [],commandBuffer cb: MTLCommandBuffer) {
        var p=GPUParams(lens:SIMD4(settings.focal,settings.aperture,settings.focus,settings.maxRadius*Float(max(frame.width,frame.height))/960),
                        depth:SIMD4(settings.nearMeters,settings.farMeters,settings.transition,settings.edgeTolerance),
                        options:SIMD4(settings.rawMin,settings.rawMax,settings.inverted ? 1:0,settings.bloom),
                        flags:SIMD4(settings.blades,max(32,settings.samples),settings.debug,UInt32(strokes.count)))
        let strokeData=strokes.isEmpty ? [SIMD4<Float>(repeating:0)] : strokes.map(\.value)
        let buffer=strokeData.withUnsafeBytes{device.makeBuffer(bytes:$0.baseAddress!,length:$0.count,options:.storageModeShared)!}
        let key=SIMD4(settings.rawMin,settings.rawMax,settings.inverted ? Float(1):0,0)
        if !optimized || frame.normalizationKey != key || frame.normalizedStrokes != strokes.map(\.value) {
        let n=cb.makeComputeCommandEncoder()!;n.setComputePipelineState(normalize)
        n.setTexture(frame.rawDepth,index:0);n.setTexture(frame.depth,index:1)
        n.setBytes(&p,length:MemoryLayout<GPUParams>.stride,index:0);n.setBuffer(buffer,offset:0,index:1)
        dispatch(n,frame);n.endEncoding()
        }
        let g=cb.makeComputeCommandEncoder()!;g.setComputePipelineState(prepareGeometry)
        for (i,t) in [frame.depth,frame.rawBackgroundDepth,frame.geometry,frame.backgroundGeometry].enumerated(){g.setTexture(t,index:i)}
        g.setBytes(&p,length:MemoryLayout<GPUParams>.stride,index:0);dispatch(g,frame);g.endEncoding()
        let e=cb.makeComputeCommandEncoder()!;e.setComputePipelineState(pipeline(frame:frame,settings:settings))
        for (i,t) in [frame.original,frame.rawDepth,frame.depth,frame.confidence,frame.output,frame.geometry,frame.backgroundGeometry,frame.coverage,frame.foreground,frame.background].enumerated(){e.setTexture(t,index:i)}
        let count=max(32,settings.samples)
        let sampleKey="\(count)-\(optimized ? settings.blades:0)"
        if sampleBuffers[sampleKey] == nil {
            let offsets=(0..<count).map{ i -> SIMD2<Float> in
                let n=i<count/2 ? count/2:count-count/2, k=i<count/2 ? i:i-count/2
                let phase:Float=i<count/2 ? 0:1
                let angle=(Float(k)*2+phase)*2.399963229728653, radius=sqrt((Float(k)+0.25+phase*0.5)/Float(n))
                return SIMD2(cos(angle)*radius,sin(angle)*radius)
            }
            if optimized {
                let packed=offsets.map{v -> SIMD4<Float> in
                    var distance=sqrt(v.x*v.x+v.y*v.y)
                    if settings.blades>=3 {
                        let n=Float(settings.blades),pi=Float.pi,sector=2*pi/n
                        let angle=atan2(v.y,v.x)
                        let boundary=cos(pi/n)/cos((angle+4*pi+sector*0.5).truncatingRemainder(dividingBy:sector)-sector*0.5)
                        distance /= boundary
                    }
                    return SIMD4(v.x,v.y,distance,0)
                }
                sampleBuffers[sampleKey]=packed.withUnsafeBytes{device.makeBuffer(bytes:$0.baseAddress!,length:$0.count,options:.storageModeShared)!}
            } else {sampleBuffers[sampleKey]=offsets.withUnsafeBytes{device.makeBuffer(bytes:$0.baseAddress!,length:$0.count,options:.storageModeShared)!}}
        }
        e.setBuffer(sampleBuffers[sampleKey],offset:0,index:1)
        var layerCount=frame.layerCount;e.setBytes(&layerCount,length:4,index:2)
        e.setBytes(&p,length:MemoryLayout<GPUParams>.stride,index:0);dispatch(e,frame);e.endEncoding()
    }
    private func pipeline(frame:LensFrame,settings:LensSettings)->MTLComputePipelineState {
        if let lens {return lens}
        let key="\(frame.layerCount)-\(settings.blades)-\(settings.debug)"
        if let p=specialized[key]{return p}
        let constants=MTLFunctionConstantValues();var scalar=frame.layerCount==1;var blades=settings.blades;var debug=settings.debug
        constants.setConstantValue(&scalar,type:.bool,index:0);constants.setConstantValue(&blades,type:.uint,index:1);constants.setConstantValue(&debug,type:.uint,index:2)
        let f=try! library.makeFunction(name:"depthLens",constantValues:constants)
        let p=try! device.makeComputePipelineState(function:f);specialized[key]=p;return p
    }
    private func dispatch(_ encoder: MTLComputeCommandEncoder,_ frame: LensFrame) {
        encoder.dispatchThreads(MTLSize(width:frame.width,height:frame.height,depth:1),threadsPerThreadgroup:MTLSize(width:16,height:8,depth:1))
    }
    @discardableResult public func render(frame: LensFrame,settings: LensSettings,strokes: [DepthStroke] = []) throws -> (gpuMS: Double,wallMS: Double) {
        let start=CFAbsoluteTimeGetCurrent(),cb=queue.makeCommandBuffer()!
        encode(frame:frame,settings:settings,strokes:strokes,commandBuffer:cb);cb.commit();cb.waitUntilCompleted();try check(cb)
        frame.normalizationKey=SIMD4(settings.rawMin,settings.rawMax,settings.inverted ? Float(1):0,0);frame.normalizedStrokes=strokes.map(\.value)
        return ((cb.gpuEndTime-cb.gpuStartTime)*1000,(CFAbsoluteTimeGetCurrent()-start)*1000)
    }
    public func focus(frame: LensFrame,point: CGPoint) throws -> Float {
        let buffer=device.makeBuffer(length:4,options:.storageModeShared)!,cb=queue.makeCommandBuffer()!,e=cb.makeComputeCommandEncoder()!
        var q=SIMD2<UInt32>(UInt32(min(frame.width-1,max(0,Int(point.x*Double(frame.width))))),UInt32(min(frame.height-1,max(0,Int(point.y*Double(frame.height))))))
        e.setComputePipelineState(pick);e.setTexture(frame.depth,index:0);e.setBuffer(buffer,offset:0,index:0)
        e.setBytes(&q,length:MemoryLayout.size(ofValue:q),index:1)
        e.dispatchThreads(MTLSize(width:1,height:1,depth:1),threadsPerThreadgroup:MTLSize(width:1,height:1,depth:1));e.endEncoding()
        cb.commit();cb.waitUntilCompleted();try check(cb)
        return buffer.contents().load(as:Float.self)
    }
    public func image(_ texture: MTLTexture) -> CIImage {
        CIImage(mtlTexture:texture,options:[.colorSpace:workingSpace])!
            .transformed(by:CGAffineTransform(scaleX:1,y:-1))
            .transformed(by:CGAffineTransform(translationX:0,y:Double(texture.height)))
    }
    public func export(_ texture: MTLTexture,to url: URL,hdr: Bool = false) throws {
        let im=image(texture)
        if hdr { try context.writeTIFFRepresentation(of:im,to:url,format:.RGBAh,colorSpace:workingSpace,options:[:]) }
        else { try context.writePNGRepresentation(of:im,to:url,format:.RGBA8,colorSpace:CGColorSpace(name:CGColorSpace.sRGB)!,options:[:]) }
    }
    /// Validation only. Explicit full-frame readback never used by the UI.
    public func pixels(_ texture: MTLTexture) -> [Float] {
        var values=[Float](repeating:0,count:texture.width*texture.height*4)
        values.withUnsafeMutableBytes{context.render(image(texture),toBitmap:$0.baseAddress!,rowBytes:texture.width*16,bounds:CGRect(x:0,y:0,width:texture.width,height:texture.height),format:.RGBAf,colorSpace:workingSpace)}
        return values
    }
    private func check(_ cb: MTLCommandBuffer) throws { if let error=cb.error{throw error} }
}
