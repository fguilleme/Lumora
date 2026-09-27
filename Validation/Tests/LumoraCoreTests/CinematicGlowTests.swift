import Testing
import Foundation
import CoreImage
@testable import LumoraCore

@Test func cinematicGlowPersistenceAndZero() throws {
    let legacy=Data(#"{"texture":0,"clarity":0,"dehaze":0,"vignette":0,"grain":0}"#.utf8)
    var s=try JSONDecoder().decode(EffectsSettings.self,from:legacy)
    #expect(s.cinematicGlowIntensity==0);#expect(s.isIdentity)
    s[.cinematicGlow]=70
    #expect(try JSONDecoder().decode(EffectsSettings.self,from:JSONEncoder().encode(s))==s)
    s[.cinematicGlow]=Double.nan;#expect(s.isIdentity)
    s[.cinematicGlow]=150;#expect(s.cinematicGlowIntensity==100)
    s[.cinematicGlow]=0;#expect(s.isIdentity)
    let r=try CinematicGlowGPU()
    let hdrSpace=try #require(CGColorSpace(name:CGColorSpace.extendedLinearSRGB))
    let pixel:[Float]=[2,1.5,0.4,1]
    let values:[Float]=Array(repeating:pixel,count:32*24).flatMap{$0}
    let data=values.withUnsafeBytes{Data($0)}
    let source=CIImage(bitmapData:data,bytesPerRow:32*16,size:CGSize(width:32,height:24),format:.RGBAf,colorSpace:hdrSpace).transformed(by:CGAffineTransform(translationX:4,y:6))
    let identity=try r.apply(source,intensity:0)
    #expect(identity === source);#expect(r.allocatedTextureBytes==0)
    let frame=try r.prepare(source)
    let hdrInput=r.pixels(frame.source); #expect(hdrInput[0]>1.9); #expect(abs(hdrInput[1]-1.5)<0.00001)
    for i:Float in [70,85,100] {
        try r.render(frame,settings:.init(intensity:i))
        let p=r.pixels(frame.output)
        #expect(abs(p[0]-2)<0.00001);#expect(abs(p[1]-1.5)<0.00001)
    }
}

@Test(.enabled(if:ProcessInfo.processInfo.environment["LUMORA_GLOW_CORPUS"] != nil))
func cinematicGlowProductionCorpus() throws {
    let repo=URL(fileURLWithPath:try #require(ProcessInfo.processInfo.environment["LUMORA_GLOW_CORPUS"]))
    let base=repo.appendingPathComponent("Validation/OpticalDiffusionV2Validation")
    let root=repo.appendingPathComponent("Validation/CinematicGlowProductionValidation/Corpus")
    try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
    let corpus=try #require(JSONSerialization.jsonObject(with:Data(contentsOf:base.appendingPathComponent("corpus.json"))) as? [String:Any])
    let cases=try #require(corpus["cases"] as? [[String:Any]])
    let r=try CinematicGlowGPU();var audit=[[String:Any]]()
    for c in cases {try autoreleasepool {
        let id=c["id"] as! String,dir=root.appendingPathComponent(id)
        try FileManager.default.createDirectory(at:dir,withIntermediateDirectories:true)
        let input=try CinematicGlowGPU.load(base.appendingPathComponent(c["input"] as! String))
        let f=try r.prepare(input)
        try r.export(f.source,to:dir.appendingPathComponent("original.png"))
        let src=r.pixels(f.source)
        for level:Float in [0,25,40,55,70,85,100] {
            // Zero is verified at the integration API; copy here for the corpus artifact.
            let t=level==0 ? f.source:f.output
            if level>0 {try r.render(f,settings:.init(intensity:level))}
            let pixels=r.pixels(t)
            try r.export(t,to:dir.appendingPathComponent("\(Int(level)).png"))
            try pixels.withUnsafeBytes{try Data($0).write(to:dir.appendingPathComponent("\(Int(level)).rgba32f"))}
            var maxReference=0.0
            if let ref=[40:"v2",70:"safe",100:"strong_safe"][Int(level)] {
                let data=try Data(contentsOf:repo.appendingPathComponent("Validation/CinematicGlowSafeValidation/\(id)/\(ref).rgba32f"))
                let values=data.withUnsafeBytes{Array($0.bindMemory(to:Float.self))}
                #expect(values.count==pixels.count)
                maxReference=Double(zip(values,pixels).map{abs($0-$1)}.max() ?? 0)
                #expect(maxReference<0.000003)
            }
            let finite=pixels.allSatisfy { $0.isFinite }; #expect(finite)
            if level>=70 {
                let valid=stride(from:0,to:pixels.count,by:4).allSatisfy { k in (0..<3).allSatisfy { ch in pixels[k+ch]>=src[k+ch]-0.000001 && pixels[k+ch]<=max(1,src[k+ch])+0.000001 } }
                #expect(valid)
            }
            audit.append(["case":id,"intensity":level,"maxReferenceError":maxReference,"textureBytes":f.textureBytes,"textures":f.textureCount])
        }
        // Check continuity on both sides of each knot in float, not just integer UI steps.
        for knot:Float in [40,70] {
            try r.render(f,settings:.init(intensity:knot-0.001));let a=r.pixels(f.output)
            try r.render(f,settings:.init(intensity:knot+0.001));let b=r.pixels(f.output)
            let delta=zip(a,b).map{abs($0-$1)}.max() ?? 0
            #expect(delta<0.00001)
            audit.append(["case":id,"knot":knot,"maxContinuityDelta":delta])
        }
    }}
    try JSONSerialization.data(withJSONObject:audit,options:[.prettyPrinted,.sortedKeys]).write(to:root.appendingPathComponent("audit.json"))
}

@Test func cinematicGlowPreviewHQExportAgreement() async throws {
    let folder=URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
    defer{try? FileManager.default.removeItem(at:folder)}
    let space=try #require(CGColorSpace(name:CGColorSpace.displayP3))
    let context=CIContext(options:[.workingColorSpace:CGColorSpace(name:CGColorSpace.extendedLinearSRGB)!])
    let extent=CGRect(x:0,y:0,width:400,height:512)
    let backdrop=CIImage(color:CIColor(red:0.02,green:0.025,blue:0.03)).cropped(to:extent)
    let light=CIImage(color:CIColor(red:0.97,green:0.85,blue:0.65)).cropped(to:CGRect(x:160,y:120,width:40,height:200)).composited(over:backdrop)
    let url=folder.appendingPathComponent("fixture.png")
    try context.writePNGRepresentation(of:light,to:url,format:.RGBA8,colorSpace:space,options:[:])
    func bytes(_ image:CGImage)->[UInt8] {
        var b=[UInt8](repeating:0,count:image.width*image.height*4)
        context.render(CIImage(cgImage:image),toBitmap:&b,rowBytes:image.width*4,bounds:CGRect(x:0,y:0,width:image.width,height:image.height),format:.RGBA8,colorSpace:space)
        return b
    }
    let engine=RenderEngine()
    let original=try await engine.render(url:url,state:EditState(),quality:.high)
    let baseline=bytes(original.image)
    for level in [0.0,40,70,100,0] {
        var state=EditState();state.effects[.cinematicGlow]=level
        let preview=try await engine.render(url:url,state:state,quality:.interactive)
        let high=try await engine.render(url:url,state:state,quality:.high)
        var settings=ExportSettings();settings.format = .png;settings.colorSpace = .displayP3
        let exported=try await engine.export(request:.init(sourceURL:url,state:state,name:"test"),settings:settings,directory:folder){_ in}
        let loaded=try #require(CIImage(contentsOf:exported.url))
        let bitmap=try #require(context.createCGImage(loaded,from:extent,format:.RGBA8,colorSpace:space))
        let a=bytes(preview.image),b=bytes(high.image),c=bytes(bitmap)
        #expect(a==b)
        let maxDifference=zip(b,c).map{abs(Int($0)-Int($1))}.max() ?? 0
        #expect(maxDifference<=2)
        if level==0 {#expect(b==baseline)}else{#expect(b != baseline)}
    }
}
