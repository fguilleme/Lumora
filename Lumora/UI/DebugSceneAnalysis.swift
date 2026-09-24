#if DEBUG
import Foundation
import CoreGraphics
import CoreImage
import Vision
import CoreVideo

/// Diagnostic observations only. This type is deliberately absent from EditState.
struct DebugSceneAnalysis: Codable, Sendable {
    struct Face: Codable, Sendable {
        let x: Double, y: Double, width: Double, height: Double, confidence: Double
        let luminance: Double
        let backgroundLuminance: Double
    }
    struct Candidate: Codable, Sendable {
        let source: String
        let x: Double, y: Double, width: Double, height: Double
        let score: Double
        let semantic: Double, size: Double, saliency: Double, contrast: Double, composition: Double
        let luminance: Double
    }
    struct Region: Codable, Sendable {
        let kind: String
        let area: Double
        let x: Double, y: Double, width: Double, height: Double
        let luminance: Double
    }
    struct Interpretation: Codable, Sendable {
        let name: String
        let score: Double
        let evidence: [String]
    }
    struct Cell: Codable, Sendable {
        let luminance: Float, logLuminance: Float, chroma: Float
        let localContrast: Float, gradient: Float, highlight: Float, shadow: Float, texture: Float
    }
    let modelVersion: Int
    let width: Int, height: Int, gridWidth: Int, gridHeight: Int
    let global: ImageAnalysis
    let cells: [Cell]
    let faces: [Face]
    let candidates: [Candidate]
    let regions: [Region]
    let interpretations: [Interpretation]
    let backlightScore: Double
    let shadowNoiseRisk: Double
    let visionConfidence: Double
    let personAvailable: Bool, saliencyAvailable: Bool
    let visionErrors: [String: String]
    let timingsMS: [String: Double]
}

struct DebugSceneResult: Sendable {
    let analysis: DebugSceneAnalysis
    let overlays: [String: CGImage]
    let fields: [String: [Float]]
}

actor DebugSceneAnalyzer {
    static let shared = DebugSceneAnalyzer()
    private var cachedSource: CGImage?
    private var cached: DebugSceneResult?

    func analyze(_ image: CGImage) throws -> DebugSceneResult {
        if let cachedSource, cachedSource === image, let cached { return cached }
        let start = ProcessInfo.processInfo.systemUptime
        let bitmap = try DebugLabBitmap.linear(image,maximum:128)
        let w = bitmap.width, h = bitmap.height, pixels = bitmap.pixels
        let global = ImageAnalysis.measure(pixels)
        let globalMS = (ProcessInfo.processInfo.systemUptime-start)*1000
        try Task.checkCancellation()

        let spatialStart = ProcessInfo.processInfo.systemUptime
        let count = w*h
        var y = [Float](repeating: 0, count: count)
        var chroma = y, logY = y, local = y, gradient = y, texture = y
        var highlights = y, shadows = y
        for i in 0..<count {
            let r=pixels[4*i], g=pixels[4*i+1], b=pixels[4*i+2]
            y[i]=max(0,0.2126*r+0.7152*g+0.0722*b)
            chroma[i]=max(r,g,b)-min(r,g,b)
            logY[i]=log2(y[i]+0.005)
            highlights[i]=min(1,max(0,(y[i]-0.7)/0.3))
            shadows[i]=min(1,max(0,(0.12-y[i])/0.12))
        }
        func at(_ x: Int,_ row: Int) -> Int { min(h-1,max(0,row))*w+min(w-1,max(0,x)) }
        for row in 0..<h { for x in 0..<w {
            let i=row*w+x
            let center=logY[i]
            let neighbor=(logY[at(x-1,row)]+logY[at(x+1,row)]+logY[at(x,row-1)]+logY[at(x,row+1)])/4
            local[i]=min(1,abs(center-neighbor)/1.5)
            gradient[i]=min(1,hypot(logY[at(x+1,row)]-logY[at(x-1,row)],logY[at(x,row+1)]-logY[at(x,row-1)])/2)
            texture[i]=abs(center-neighbor)
        }}
        let noiseSamples=(0..<count).filter { y[$0] < 0.1 && gradient[$0] < 0.18 }.map { Double(texture[$0]) }
        let noiseRisk=min(1,(noiseSamples.isEmpty ? 0 : noiseSamples.reduce(0,+)/Double(noiseSamples.count))/0.13)
        let cells=(0..<count).map { i in DebugSceneAnalysis.Cell(luminance:y[i],logLuminance:logY[i],chroma:chroma[i],localContrast:local[i],gradient:gradient[i],highlight:highlights[i],shadow:shadows[i],texture:texture[i]) }
        let regions=Self.regions(y:y,w:w,h:h)
        let spatialMS=(ProcessInfo.processInfo.systemUptime-spatialStart)*1000
        try Task.checkCancellation()

        let visionStart=ProcessInfo.processInfo.systemUptime
        let faceRequest=VNDetectFaceRectanglesRequest()
        // Vision can be unavailable in some Simulator/macOS configurations.
        // Keep spatial diagnostics usable and report missing semantic evidence.
        var visionErrors:[String:String]=[:]
        do {try VNImageRequestHandler(cgImage:image,orientation:.up).perform([faceRequest])}
        catch {visionErrors["faces"]=error.localizedDescription}
        let faceMS=(ProcessInfo.processInfo.systemUptime-visionStart)*1000
        try Task.checkCancellation()
        let personStart=ProcessInfo.processInfo.systemUptime
        let personRequest=VNGeneratePersonSegmentationRequest()
        personRequest.qualityLevel = .balanced
        personRequest.outputPixelFormat = kCVPixelFormatType_OneComponent8
        var personMap: [Float]? = nil
        do {
            try VNImageRequestHandler(cgImage:image,orientation:.up).perform([personRequest])
            if let buffer=personRequest.results?.first?.pixelBuffer {personMap=Self.read(buffer,w:w,h:h)}
        } catch {visionErrors["person"]=error.localizedDescription}
        let personMS=(ProcessInfo.processInfo.systemUptime-personStart)*1000
        try Task.checkCancellation()
        let saliencyStart=ProcessInfo.processInfo.systemUptime
        let saliencyRequest=VNGenerateAttentionBasedSaliencyImageRequest()
        var saliencyMap: [Float]? = nil
        do {
            try VNImageRequestHandler(cgImage:image,orientation:.up).perform([saliencyRequest])
            if saliencyRequest.results?.first?.pixelBuffer == nil {
                try VNImageRequestHandler(cgImage:image,orientation:.up).perform([saliencyRequest])
            }
            if let buffer=saliencyRequest.results?.first?.pixelBuffer {saliencyMap=Self.read(buffer,w:w,h:h)}
        } catch {visionErrors["saliency"]=error.localizedDescription}
        let saliencyMS=(ProcessInfo.processInfo.systemUptime-saliencyStart)*1000
        try Task.checkCancellation()

        let scoreStart=ProcessInfo.processInfo.systemUptime
        let faces=(faceRequest.results ?? []).map { face -> DebugSceneAnalysis.Face in
            let box=face.boundingBox
            let rect=CGRect(x:box.minX,y:1-box.maxY,width:box.width,height:box.height)
            let lum=Self.mean(y,w:w,h:h,in:rect)
            let surround=Self.mean(y,w:w,h:h,in:rect.insetBy(dx:-rect.width*0.7,dy:-rect.height*0.7))
            return .init(x:rect.minX,y:rect.minY,width:rect.width,height:rect.height,
                         confidence:Double(face.confidence),luminance:lum,backgroundLuminance:surround)
        }
        let candidates=Self.candidates(faces:faces,person:personMap,saliency:saliencyMap,y:y,w:w,h:h)
        let largestBright=regions.filter{$0.kind=="near-white"}.map(\.area).max() ?? 0
        let primary=candidates.first
        let subjectY=primary?.luminance ?? 0
        let outsideY=primary.map { candidate in
            Self.mean(y,w:w,h:h,in:CGRect(x:candidate.x,y:candidate.y,width:candidate.width,height:candidate.height).insetBy(dx:-0.15,dy:-0.15))
        } ?? 0
        let backlight=min(1,max(0,(outsideY-subjectY)/0.55)) * min(1,largestBright/0.12)
        let dark=global.luminance.median < 0.07 ? 1.0 : 0.0
        let smallLights=regions.filter{$0.kind=="highlight" || $0.kind=="near-white"}.allSatisfy{$0.area<0.06}
        var interpretations:[DebugSceneAnalysis.Interpretation]=[]
        if backlight>0.1 { interpretations.append(.init(name:"Possible backlit subject",score:backlight,evidence:["subject/background luminance","large bright region"])) }
        if dark>0 { interpretations.append(.init(name:smallLights ? "Dark scene with isolated lights" : "Low-key or dark scene",score:smallLights ? 0.8 : 0.55,evidence:["median luminance","highlight region area"])) }
        if largestBright>0.2 { interpretations.append(.init(name:"Large bright region; white subject or high-key ambiguity",score:min(1,largestBright*2),evidence:["near-white connected area","texture not conclusive"])) }
        if primary != nil && backlight>0.2 && subjectY<0.05 { interpretations.append(.init(name:"Silhouette plausible; exposure intent unknown",score:0.5,evidence:["dark candidate","bright surroundings"])) }
        if interpretations.isEmpty { interpretations.append(.init(name:"No strong scene interpretation",score:0.3,evidence:["global and spatial observations"])) }
        let visionConfidence=min(1,(personMap == nil ? 0 : 0.45)+(saliencyMap == nil ? 0 : 0.25)+(faces.isEmpty ? 0 : 0.3))
        let scoringMS=(ProcessInfo.processInfo.systemUptime-scoreStart)*1000
        let analysis=DebugSceneAnalysis(modelVersion:1,width:image.width,height:image.height,gridWidth:w,gridHeight:h,
                                        global:global,cells:cells,faces:faces,candidates:candidates,regions:regions,
                                        interpretations:interpretations,backlightScore:backlight,shadowNoiseRisk:noiseRisk,
                                        visionConfidence:visionConfidence,personAvailable:personMap != nil,saliencyAvailable:saliencyMap != nil,
                                        visionErrors:visionErrors,
                                        timingsMS:["global":globalMS,"spatial":spatialMS,"faces":faceMS,"person":personMS,
                                                   "saliency":saliencyMS,"scoring":scoringMS])
        let subject=Self.candidateMap(candidates,w:w,h:h)
        let fields:[String:[Float]]=["Faces":Self.faceMap(faces,w:w,h:h),"Persons":personMap ?? Array(repeating:0,count:count),
                                     "Saliency":saliencyMap ?? Array(repeating:0,count:count),"Subject candidates":subject,
                                     "Foreground/background":personMap ?? subject,"Highlights":highlights,"Shadows":shadows,
                                     "Noise-risk":zip(shadows,texture).map{$0*$1},"Final analysis map":subject]
        let overlays=fields.compactMapValues { Self.overlay($0,w:w,h:h) }
        let result=DebugSceneResult(analysis:analysis,overlays:overlays,fields:fields)
        cachedSource=image;cached=result
        return result
    }

    private static func mean(_ values:[Float],w:Int,h:Int,in rect:CGRect)->Double {
        let x0=max(0,min(w-1,Int(rect.minX*Double(w)))),x1=max(x0+1,min(w,Int(rect.maxX*Double(w))))
        let y0=max(0,min(h-1,Int(rect.minY*Double(h)))),y1=max(y0+1,min(h,Int(rect.maxY*Double(h))))
        var sum=0.0
        for row in y0..<y1 { for x in x0..<x1 {sum+=Double(values[row*w+x])} }
        return sum/Double((x1-x0)*(y1-y0))
    }
    private static func read(_ buffer:CVPixelBuffer,w:Int,h:Int)->[Float]? {
        CVPixelBufferLockBaseAddress(buffer,.readOnly)
        defer {CVPixelBufferUnlockBaseAddress(buffer,.readOnly)}
        guard let base=CVPixelBufferGetBaseAddress(buffer) else{return nil}
        let bw=CVPixelBufferGetWidth(buffer),bh=CVPixelBufferGetHeight(buffer),stride=CVPixelBufferGetBytesPerRow(buffer)
        let format=CVPixelBufferGetPixelFormatType(buffer)
        var out=[Float](repeating:0,count:w*h)
        for row in 0..<h {for x in 0..<w {
            let sx=min(bw-1,x*bw/w),sy=min(bh-1,row*bh/h)
            let pixel=base.advanced(by:sy*stride)
            switch format {
            case kCVPixelFormatType_OneComponent8:
                out[row*w+x]=Float(pixel.assumingMemoryBound(to:UInt8.self)[sx])/255
            case kCVPixelFormatType_OneComponent32Float:
                out[row*w+x]=pixel.assumingMemoryBound(to:Float.self)[sx]
            case kCVPixelFormatType_OneComponent16Half:
                out[row*w+x]=Float(Float16(bitPattern:pixel.assumingMemoryBound(to:UInt16.self)[sx]))
            default:return nil
            }
        }}
        return out
    }
    private static func regions(y:[Float],w:Int,h:Int)->[DebugSceneAnalysis.Region] {
        var result:[DebugSceneAnalysis.Region]=[]
        for (kind,threshold,above) in [("deep shadows",Float(0.035),false),("shadows",0.12,false),("midtones",0.12,true),("highlights",0.7,true),("near-white",0.92,true)] {
            var seen=[Bool](repeating:false,count:w*h)
            for start in 0..<y.count where !seen[start] {
                let match=above ? y[start]>=threshold : y[start]<threshold
                if !match {seen[start]=true;continue}
                var queue=[start],head=0,x0=w,y0=h,x1=0,y1=0,sum=0.0
                seen[start]=true
                while head<queue.count {
                    let i=queue[head];head+=1;let x=i%w,row=i/w
                    x0=min(x0,x);x1=max(x1,x);y0=min(y0,row);y1=max(y1,row);sum+=Double(y[i])
                    for n in [x>0 ? i-1 : i,x+1<w ? i+1 : i,row>0 ? i-w : i,row+1<h ? i+w : i] where !seen[n] {
                        seen[n]=true
                        if above ? y[n]>=threshold : y[n]<threshold {queue.append(n)}
                    }
                }
                if queue.count >= max(4,w*h/500) {
                    result.append(.init(kind:kind,area:Double(queue.count)/Double(w*h),x:Double(x0)/Double(w),y:Double(y0)/Double(h),
                                        width:Double(x1-x0+1)/Double(w),height:Double(y1-y0+1)/Double(h),luminance:sum/Double(queue.count)))
                }
            }
        }
        return result.sorted{$0.area>$1.area}
    }
    private static func candidates(faces:[DebugSceneAnalysis.Face],person:[Float]?,saliency:[Float]?,y:[Float],w:Int,h:Int)->[DebugSceneAnalysis.Candidate] {
        var output:[DebugSceneAnalysis.Candidate]=[]
        func append(source:String,rect:CGRect,semantic:Double) {
            let area=max(0,rect.width*rect.height)
            let size=min(1,sqrt(area)/0.5)
            let center=1-min(1,hypot(rect.midX-0.5,rect.midY-0.5)/0.7)
            let lum=mean(y,w:w,h:h,in:rect)
            let around=mean(y,w:w,h:h,in:rect.insetBy(dx:-0.12,dy:-0.12))
            let separation=min(1,abs(lum-around)/0.35)
            let sal=saliency.map {mean($0,w:w,h:h,in:rect)} ?? 0
            let score=0.35*semantic+0.18*size+0.18*sal+0.17*separation+0.12*center
            output.append(.init(source:source,x:rect.minX,y:rect.minY,width:rect.width,height:rect.height,score:score,
                                semantic:semantic,size:size,saliency:sal,contrast:separation,composition:center,luminance:lum))
        }
        for f in faces {append(source:"face",rect:CGRect(x:f.x,y:f.y,width:f.width,height:f.height),semantic:f.confidence)}
        if let person {
            let points=(0..<person.count).filter{person[$0]>0.55}
            if points.count>max(8,w*h/100) {
                let xs=points.map{$0%w},ys=points.map{$0/w}
                append(source:"person",rect:CGRect(x:Double(xs.min()!)/Double(w),y:Double(ys.min()!)/Double(h),
                                                    width:Double(xs.max()!-xs.min()!+1)/Double(w),height:Double(ys.max()!-ys.min()!+1)/Double(h)),
                       semantic:Double(points.count)/Double(w*h))
            }
        }
        if let saliency {
            let points=(0..<saliency.count).filter{saliency[$0]>0.65}
            if points.count>max(8,w*h/100) {
                let xs=points.map{$0%w},ys=points.map{$0/w}
                append(source:"saliency",rect:CGRect(x:Double(xs.min()!)/Double(w),y:Double(ys.min()!)/Double(h),
                                                      width:Double(xs.max()!-xs.min()!+1)/Double(w),height:Double(ys.max()!-ys.min()!+1)/Double(h)),
                       semantic:0.3)
            }
        }
        return output.sorted{$0.score>$1.score}
    }
    private static func candidateMap(_ candidates:[DebugSceneAnalysis.Candidate],w:Int,h:Int)->[Float] {
        var out=[Float](repeating:0,count:w*h)
        for c in candidates {
            let x0=max(0,Int(c.x*Double(w))),x1=min(w,Int((c.x+c.width)*Double(w)))
            let y0=max(0,Int(c.y*Double(h))),y1=min(h,Int((c.y+c.height)*Double(h)))
            if x0<x1 && y0<y1 {for row in y0..<y1 {for x in x0..<x1 {out[row*w+x]=max(out[row*w+x],Float(c.score))}}}
        }
        return out
    }
    private static func faceMap(_ faces:[DebugSceneAnalysis.Face],w:Int,h:Int)->[Float] {
        candidateMap(faces.map{.init(source:"face",x:$0.x,y:$0.y,width:$0.width,height:$0.height,score:$0.confidence,
                                     semantic:$0.confidence,size:0,saliency:0,contrast:0,composition:0,luminance:$0.luminance)},w:w,h:h)
    }
    private static func overlay(_ values:[Float],w:Int,h:Int)->CGImage? {
        var bytes=[UInt8](repeating:0,count:w*h*4)
        for i in 0..<w*h {
            let value=min(1,max(0,values[i]))
            bytes[4*i]=255;bytes[4*i+1]=UInt8((1-value)*180);bytes[4*i+2]=30
            bytes[4*i+3]=UInt8(value*155)
        }
        let data=Data(bytes),provider=CGDataProvider(data:data as CFData)!
        return CGImage(width:w,height:h,bitsPerComponent:8,bitsPerPixel:32,bytesPerRow:w*4,
                       space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGBitmapInfo(rawValue:CGImageAlphaInfo.last.rawValue),
                       provider:provider,decode:nil,shouldInterpolate:true,intent:.defaultIntent)
    }
}
#endif
