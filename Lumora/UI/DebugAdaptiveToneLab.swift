#if DEBUG
import Foundation
import CoreGraphics
import CoreImage

enum DebugToneVariant: String, CaseIterable, Identifiable, Sendable {
    case off = "Off / Original pipeline"
    case gaussian = "Phase 1 · Gaussian"
    case bilateral = "Phase 1 · Bilateral"
    case guided = "Phase 1 · Guided"
    case phase2A = "Phase 2 · A"
    case phase2B = "Phase 2 · B"
    case phase2C = "Phase 2 · C"
    case spatial = "Phase 4 · Spatial"
    case semantic = "Phase 4 · Semantic"
    case combined = "Phase 4 · Combined"
    case budgetA = "Phase 5 · Shadow Budget A"
    case budgetB = "Phase 5 · Shadow Budget B"
    case budgetC = "Phase 5 · Shadow Budget C"
    var id: String { rawValue }
}

struct DebugToneOutput: Sendable {
    let image: CGImage
    let milliseconds: Double
    let preparationMilliseconds: Double
    let backend: String
    let allocatedBytes: Int
    let p95: Float
    let over2: Double, over3: Double, over4: Double, maxGain: Double
    let cacheHit: Bool
}

actor DebugAdaptiveToneLab {
    static let shared = DebugAdaptiveToneLab()
    private struct Key: Hashable { let source: ObjectIdentifier; let variant: DebugToneVariant; let amount: Int }
    private var outputs: [Key: DebugToneOutput] = [:]
    private var maps: [DebugToneVariant: FloatMap] = [:]
    private var lastSource: CGImage?

    func mapOverlay(_ image:CGImage,scene:DebugSceneResult,variant:DebugToneVariant)throws->CGImage {
        if lastSource == nil || lastSource !== image {outputs.removeAll();maps.removeAll();lastSource=image}
        let map:FloatMap
        if let cached=maps[variant] {map=cached}
        else {map=try DebugPhase4Importance.make(image:image,scene:scene,variant:variant);maps[variant]=map}
        var rgba=[Float](repeating:0,count:map.width*map.height*4)
        for i in map.pixels.indices {
            let value=min(1,max(0,map.pixels[i]))
            rgba[4*i]=value;rgba[4*i+1]=0.18*value;rgba[4*i+2]=0.04*value;rgba[4*i+3]=0.65*value
        }
        return try DebugLabBitmap.display(rgba,width:map.width,height:map.height)
    }

    func gainOverlay(_ input:CGImage,_ output:CGImage)throws->CGImage {
        let src=try DebugLabBitmap.linear(input),dst=try DebugLabBitmap.linear(output)
        guard src.width==dst.width,src.height==dst.height else {throw NSError(domain:"Gain map size mismatch",code:4)}
        var rgba=[Float](repeating:0,count:src.pixels.count)
        for i in 0..<src.width*src.height {
            let y=max(0.003,0.2126*src.pixels[4*i]+0.7152*src.pixels[4*i+1]+0.0722*src.pixels[4*i+2])
            let mapped=0.2126*dst.pixels[4*i]+0.7152*dst.pixels[4*i+1]+0.0722*dst.pixels[4*i+2]
            let gain=mapped/y
            let color:(Float,Float,Float)=gain>4 ? (0.85,0.12,0.08) : gain>3 ? (0.95,0.65,0.12) :
                gain>2 ? (0.25,0.7,0.25) : gain>1.5 ? (0.1,0.5,0.75) : (0.08,0.16,0.28)
            rgba[4*i]=color.0;rgba[4*i+1]=color.1;rgba[4*i+2]=color.2;rgba[4*i+3]=0.55
        }
        return try DebugLabBitmap.display(rgba,width:src.width,height:src.height)
    }

    func render(_ image: CGImage, variant: DebugToneVariant, amount: Int,
                scene: DebugSceneResult?) throws -> DebugToneOutput {
        let sourceID=ObjectIdentifier(image)
        if lastSource == nil || lastSource !== image {outputs.removeAll();maps.removeAll();lastSource=image}
        let key=Key(source:sourceID,variant:variant,amount:amount)
        if let cached=outputs[key] {
            return .init(image:cached.image,milliseconds:cached.milliseconds,
                         preparationMilliseconds:cached.preparationMilliseconds,backend:cached.backend,allocatedBytes:cached.allocatedBytes,
                         p95:cached.p95,over2:cached.over2,over3:cached.over3,over4:cached.over4,maxGain:cached.maxGain,cacheHit:true)
        }
        if variant == .off || amount == 0 {
            let result=DebugToneOutput(image:image,milliseconds:0,preparationMilliseconds:0,backend:"Off",allocatedBytes:0,p95:0,over2:0,over3:0,over4:0,maxGain:1,cacheHit:false)
            outputs[key]=result;return result
        }
        try Task.checkCancellation()
        let start=ProcessInfo.processInfo.systemUptime
        let decoded=try DebugLabBitmap.linear(image)
        let width=decoded.width,height=decoded.height,rgba=decoded.pixels
        try Task.checkCancellation()
        let map:FloatMap?
        if [.spatial,.semantic,.combined].contains(variant),let scene {
            if let cached=maps[variant] {map=cached}
            else {
                let generated=try DebugPhase4Importance.make(image:image,scene:scene,variant:variant)
                maps[variant]=generated;map=generated
            }
        } else if [.spatial,.semantic,.combined].contains(variant) {
            throw NSError(domain:"Debug Lab: scene analysis is pending",code:3)
        } else {map=nil}
        let budget:String?
        switch variant {case .budgetA:budget="A";case .budgetB:budget="B";case .budgetC:budget="C";default:budget=nil}
        let kernel:String
        switch variant {
        case .guided:kernel="finalToneGuided"
        case .phase2A:kernel="finalTonePhase2A"
        case .phase2B:kernel="finalTonePhase2B"
        default:kernel="finalTone"
        }
        // Phase 1 Gaussian/Bilateral are not equivalent to the guided decomposition.
        // Their dedicated CPU reference is evaluated below, never relabelled as Guided.
        if variant == .gaussian || variant == .bilateral {
            let output=try DebugPhase1Reference.render(rgba,width:width,height:height,variant:variant,amount:Float(amount)/100)
            let bitmap=try DebugLabBitmap.display(output,width:width,height:height)
            let result=Self.summarize(input:rgba,output:output,image:bitmap,ms:(ProcessInfo.processInfo.systemUptime-start)*1000,
                                      prep:0,backend:"CPU",bytes:rgba.count*MemoryLayout<Float>.size*3,p95:0)
            outputs[key]=result;return result
        }
        let runner=try Runner(image:FloatImage(width:width,height:height,pixels:rgba),formatMode:"optimized",
                              importanceMap:map,budgetVariant:budget,toneKernel:kernel)
        let (gpuMS,rendered,_)=try runner.run(amount:Float(amount)/100,readback:true,globalSide:nil,p95Override:-1,profile:false)
        try Task.checkCancellation()
        guard let rendered else {throw NSError(domain:"DebugLab",code:1)}
        let bitmap=try DebugLabBitmap.display(rendered,width:width,height:height)
        let p95=runner.p95.contents().assumingMemoryBound(to:Float.self).pointee
        let result=Self.summarize(input:rgba,output:rendered,image:bitmap,ms:gpuMS,
                                  prep:max(0,(ProcessInfo.processInfo.systemUptime-start)*1000-gpuMS),
                                  backend:"Metal",bytes:runner.allocatedBytes,p95:p95)
        outputs[key]=result
        if outputs.count>6 {outputs.removeValue(forKey:outputs.keys.first!)}
        return result
    }

    private static func summarize(input:[Float],output:[Float],image:CGImage,ms:Double,prep:Double,backend:String,bytes:Int,p95:Float)->DebugToneOutput {
        var over2=0,over3=0,over4=0,total=0,maxGain=1.0
        for i in stride(from:0,to:min(input.count,output.count),by:4) {
            let before=max(0.003,Double(0.2126*input[i]+0.7152*input[i+1]+0.0722*input[i+2]))
            let after=Double(0.2126*output[i]+0.7152*output[i+1]+0.0722*output[i+2])
            let gain=after/before
            if gain>2 {over2+=1};if gain>3 {over3+=1};if gain>4 {over4+=1}
            maxGain=max(maxGain,gain);total+=1
        }
        let n=Double(max(1,total))
        return .init(image:image,milliseconds:ms,preparationMilliseconds:prep,backend:backend,allocatedBytes:bytes,p95:p95,
                     over2:Double(over2)/n,over3:Double(over3)/n,over4:Double(over4)/n,maxGain:maxGain,cacheHit:false)
    }
}
#endif
