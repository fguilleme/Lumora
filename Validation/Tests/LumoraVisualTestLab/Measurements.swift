import Foundation
import CoreImage
import Metal
import Accelerate

struct Moments: Encodable {
    var count=0
    var mean=0.0, m2=0.0
    var min=Double.greatestFiniteMagnitude, max = -Double.greatestFiniteMagnitude
    var variance:Double { count > 1 ? m2/Double(count-1) : 0 }
    var standardDeviation:Double { sqrt(variance) }
    private enum CodingKeys:String,CodingKey { case count,mean,variance,standardDeviation,min,max }
    func encode(to encoder:Encoder) throws {
        var c=encoder.container(keyedBy:CodingKeys.self)
        try c.encode(count,forKey:.count);try c.encode(mean,forKey:.mean)
        try c.encode(variance,forKey:.variance);try c.encode(standardDeviation,forKey:.standardDeviation)
        try c.encode(count>0 ? min:0,forKey:.min);try c.encode(count>0 ? max:0,forKey:.max)
    }
    mutating func add(_ value:Double) {
        guard value.isFinite else { return }
        count += 1; let delta=value-mean; mean += delta/Double(count); m2 += delta*(value-mean)
        min=Swift.min(min,value); max=Swift.max(max,value)
    }
}
struct Comparison: Encodable {
    var input=Moments(), output=Moments(), residual=Moments(), chromaResidual=Moments()
    var mae=0.0, rmse=0.0, maxError=0.0, ssim=1.0
    var chromaticityMAE=0.0, maxChromaticityError=0.0
    var nonFinite=0, blackInput=0, blackOutput=0, whiteInput=0, whiteOutput=0, outsideSDR=0
    var histogramInput=[Int](repeating:0,count:128)
    var histogramOutput=[Int](repeating:0,count:128)
    var histogramResidual=[Int](repeating:0,count:128)
    var monotonicityViolations=0, flatSteps=0, maxAdjacentStep=0.0
    var transferInput:[Double]=[], transferOutput:[Double]=[]
    var residualStd:Double { residual.standardDeviation }
}
struct Structure: Codable {
    let autocorrelation:[String:Double]
    let spectrum:[Double]
    let spectralCentroid:Double
    let peakFrequency:Double
    let highFrequencyEnergy:Double
    let edgeRMS:Double
    let edgeP95:Double
    let rgbCorrelation:[String:Double]
}
struct LabGPU {
    let context:CIContext
    let deviceName:String
    let linear=CGColorSpace(name:CGColorSpace.extendedLinearSRGB)!
    init() throws {
        guard let device=MTLCreateSystemDefaultDevice(), device.supportsDynamicLibraries else {
            throw NSError(domain:"LumoraVisualTestLab",code:1,userInfo:[NSLocalizedDescriptionKey:"A Metal device supporting dynamic libraries is required; no silent CPU fallback."])
        }
        deviceName=device.name
        context=CIContext(mtlDevice:device,options:[.workingColorSpace:CGColorSpace(name:CGColorSpace.extendedLinearSRGB)!, .workingFormat:CIFormat.RGBAf, .cacheIntermediates:false])
    }
    func read(_ image:CIImage,_ bounds:CGRect) -> [Float] {
        var values=[Float](repeating:0,count:Int(bounds.width*bounds.height)*4)
        values.withUnsafeMutableBytes { context.render(image,toBitmap:$0.baseAddress!,rowBytes:Int(bounds.width)*16,bounds:bounds,format:.RGBAf,colorSpace:linear) }
        return values
    }
    static func luma(_ p:[Float],_ i:Int)->Double { Double(p[i])*0.2126+Double(p[i+1])*0.7152+Double(p[i+2])*0.0722 }
    func compare(_ before:CIImage,_ after:CIImage,region:CGRect?=nil,ramp:Bool=false)->Comparison {
        let bounds=(region ?? before.extent).integral
        var result=Comparison(), squared=0.0, ssimSum=0.0, windows=0
        // Bounded working memory: at most 128 rows of both RGBA float images.
        for row in stride(from:Int(bounds.minY),to:Int(bounds.maxY),by:128) {
            let rect=CGRect(x:bounds.minX,y:CGFloat(row),width:bounds.width,height:CGFloat(min(128,Int(bounds.maxY)-row)))
            let a=read(before,rect), b=read(after,rect)
            for i in stride(from:0,to:a.count,by:4) {
                guard (0..<4).allSatisfy({ a[i+$0].isFinite && b[i+$0].isFinite }) else { result.nonFinite += 1; continue }
                let x=Self.luma(a,i),y=Self.luma(b,i),d=y-x
                result.input.add(x); result.output.add(y); result.residual.add(d)
                result.chromaResidual.add((Double(b[i]-a[i])-Double(b[i+1]-a[i+1])))
                result.blackInput += x <= 1e-6 ? 1:0; result.blackOutput += y <= 1e-6 ? 1:0
                result.whiteInput += (0..<3).contains(where:{a[i+$0] >= 1-1e-6}) ? 1:0
                result.whiteOutput += (0..<3).contains(where:{b[i+$0] >= 1-1e-6}) ? 1:0
                let outOfRange:Bool = (0..<3).contains { channel in b[i+channel] < Float(0) || b[i+channel] > Float(1) }
                if outOfRange { result.outsideSDR += 1 }
                result.histogramInput[min(127,max(0,Int(min(1,max(0,x))*127)))] += 1
                result.histogramOutput[min(127,max(0,Int(min(1,max(0,y))*127)))] += 1
                // Residual histogram range [-0.25,0.25], overflow accumulates in endpoints.
                result.histogramResidual[min(127,max(0,Int(min(0.5,max(0,d+0.25))*254)))] += 1
                let sumA=Double(a[i])+Double(a[i+1])+Double(a[i+2])
                let sumB=Double(b[i])+Double(b[i+1])+Double(b[i+2])
                if sumA>1e-8 && sumB>1e-8 {
                    for channel in 0..<3 {
                        let drift=abs(Double(a[i+channel])/sumA-Double(b[i+channel])/sumB)
                        result.chromaticityMAE += drift
                        result.maxChromaticityError=max(result.maxChromaticityError,drift)
                    }
                }
                for c in 0..<3 { let delta=abs(Double(b[i+c])-Double(a[i+c])); result.mae += delta; squared += delta*delta; result.maxError=max(result.maxError,delta) }
            }
            // Mean of non-overlapping 8×8 luminance SSIM windows; linear data, L=1.
            let width=Int(rect.width),height=Int(rect.height)
            for y in stride(from:0,to:height-7,by:8) { for x in stride(from:0,to:width-7,by:8) {
                var aa=Moments(),bb=Moments(),cross=0.0
                for j in 0..<8 { for k in 0..<8 {
                    let i=((y+j)*width+x+k)*4,u=Self.luma(a,i),v=Self.luma(b,i)
                    aa.add(u);bb.add(v);cross += u*v
                } }
                let covariance=(cross-64*aa.mean*bb.mean)/63
                let score=((2*aa.mean*bb.mean+0.0001)*(2*covariance+0.0009))/((aa.mean*aa.mean+bb.mean*bb.mean+0.0001)*(aa.variance+bb.variance+0.0009))
                if score.isFinite { ssimSum += score;windows += 1 }
            } }
        }
        let count=Double(max(1,result.input.count*3));result.chromaticityMAE /= count;result.mae /= count;result.rmse=sqrt(squared/count)
        result.ssim=windows > 0 ? ssimSum/Double(windows):1
        if ramp {
            let rect=CGRect(x:bounds.minX,y:floor(bounds.midY),width:bounds.width,height:1)
            let a=read(before,rect),b=read(after,rect)
            for i in stride(from:0,to:a.count,by:4) {
                result.transferInput.append(Self.luma(a,i)); result.transferOutput.append(Self.luma(b,i))
                if i>0 { let d=Self.luma(b,i)-Self.luma(b,i-4)
                    if d < -1e-6 { result.monotonicityViolations += 1 }
                    if abs(d)<1e-7 { result.flatSteps += 1 }
                    result.maxAdjacentStep=max(result.maxAdjacentStep,abs(d))
                }
            }
        }
        return result
    }
    func structure(_ input:CIImage,_ output:CIImage,region:CGRect)->Structure {
        let side=Int(pow(2.0,floor(log2(Double(min(256,min(region.width,region.height)))))))
        let rect=CGRect(x:floor(region.midX-CGFloat(side)/2),y:floor(region.midY-CGFloat(side)/2),width:CGFloat(side),height:CGFloat(side))
        let a=read(input,rect),b=read(output,rect)
        let residual=(0..<side*side).map { Self.luma(b,$0*4)-Self.luma(a,$0*4) }
        func correlation(_ x:[Double],_ y:[Double])->Double {
            let n=Double(x.count),mx=x.reduce(0,+)/n,my=y.reduce(0,+)/n
            var xy=0.0,xx=0.0,yy=0.0
            for i in x.indices { let u=x[i]-mx,v=y[i]-my;xy+=u*v;xx+=u*u;yy+=v*v }
            return xx*yy>1e-30 ? xy/sqrt(xx*yy):0
        }
        var correlations:[String:Double]=[:],edges:[Double]=[]
        for (dx,dy) in [(1,0),(0,1),(1,1),(2,0),(0,2),(4,0)] {
            var x:[Double]=[],y:[Double]=[]
            for row in 0..<side-dy { for col in 0..<side-dx {
                x.append(residual[row*side+col]);y.append(residual[(row+dy)*side+col+dx])
                if dx==1 && dy==0 { edges.append(abs(x.last!-y.last!)) }
            } }
            correlations["\(dx),\(dy)"]=correlation(x,y)
        }
        var channels=[[Double]](repeating:[],count:3)
        for channel in 0..<3 { for pixel in 0..<(side*side) {
            let index=pixel*4+channel
            channels[channel].append(Double(b[index])-Double(a[index]))
        } }
        let spectrum=Self.radialSpectrum(residual,side:side)
        let total=spectrum.reduce(0,+)
        var weightedFrequency=0.0
        for (index,energy) in spectrum.enumerated() { weightedFrequency += Double(index)/Double(side)*energy }
        let centroid=weightedFrequency/max(total,1e-30)
        let peak=spectrum.indices.dropFirst().max(by:{spectrum[$0]<spectrum[$1]}) ?? 0
        edges.sort()
        let highEnergy=spectrum.dropFirst(side/4).reduce(0.0,+)/Swift.max(total,1e-30)
        let edgeSquareSum=edges.reduce(0.0) { sum,value in sum+value*value }
        let edgeRMS=sqrt(edgeSquareSum/Double(Swift.max(1,edges.count)))
        let percentile=edges.isEmpty ? 0:edges[Swift.min(edges.count-1,Int(Double(edges.count)*0.95))]
        let rgb=["RG":correlation(channels[0],channels[1]),"RB":correlation(channels[0],channels[2]),"GB":correlation(channels[1],channels[2])]
        return Structure(autocorrelation:correlations,spectrum:spectrum,spectralCentroid:centroid,
                         peakFrequency:Double(peak)/Double(side),highFrequencyEnergy:highEnergy,
                         edgeRMS:edgeRMS,edgeP95:percentile,rgbCorrelation:rgb)
    }
    private static func radialSpectrum(_ values:[Double],side:Int)->[Double] {
        let mean=values.reduce(0,+)/Double(values.count)
        var real=[Float](repeating:0,count:values.count),imag=real
        for y in 0..<side { for x in 0..<side {
            let wx=0.5-0.5*cos(2*Double.pi*Double(x)/Double(side-1)),wy=0.5-0.5*cos(2*Double.pi*Double(y)/Double(side-1))
            real[y*side+x]=Float((values[y*side+x]-mean)*wx*wy)
        } }
        let logn=vDSP_Length(log2(Double(side)))
        guard let setup=vDSP_create_fftsetup(logn,FFTRadix(kFFTRadix2)) else { return [] }
        defer { vDSP_destroy_fftsetup(setup) }
        real.withUnsafeMutableBufferPointer { r in imag.withUnsafeMutableBufferPointer { i in
            var complex=DSPSplitComplex(realp:r.baseAddress!,imagp:i.baseAddress!)
            vDSP_fft2d_zip(setup,&complex,1,0,logn,logn,FFTDirection(FFT_FORWARD))
        } }
        var bins=[Double](repeating:0,count:side/2),counts=[Double](repeating:0,count:side/2)
        for y in 0..<side { for x in 0..<side {
            let dx=min(x,side-x),dy=min(y,side-y),radius=Int(sqrt(Double(dx*dx+dy*dy)))
            if radius>0 && radius<bins.count { let i=y*side+x;bins[radius]+=Double(real[i]*real[i]+imag[i]*imag[i]);counts[radius]+=1 }
        } }
        // Per-annulus total energy normalized to unit sum (not mean energy per coefficient).
        let total=bins.reduce(0,+)
        return bins.map{$0/max(total,1e-30)}
    }
}
