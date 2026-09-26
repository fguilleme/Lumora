import Foundation
import CoreImage
import Darwin
@testable import LumoraCore

extension GradingPresetValidation {
    func integration() async throws {
        guard let file=files.first else {throw LabError.configuration}
        var c=LabCase(name:"Integration lifecycle / masks / export")
        let engine=RenderEngine()
        var export=ExportSettings();export.format = .png;export.maximumDimension=1024;export.colorSpace = .displayP3
        for preset in [ColorGradingPreset.softPortrait,.tealWarm,.goldenHour,.blueHour,.moody,.splitWarmCool] {
            let state=preset.applying(to:EditState()),p=try await engine.render(url:file,state:state,quality:.interactive),h=try await engine.render(url:file,state:state,quality:.high)
            let exported=try await engine.export(request:.init(sourceURL:file,state:state,name:preset.id),settings:export,directory:lab.artifacts.url(root+"Export"))
            let output=CIImage(contentsOf:exported.url)!,pi=helper.reduced(CIImage(cgImage:p.image),side:256),hi=helper.reduced(CIImage(cgImage:h.image),side:256)
            let pm=lab.gpu.compare(pi,hi).mae,em=lab.gpu.compare(hi,helper.reduced(output,side:256)).mae
            c.metrics[preset.id+" previewHQ"]=pm;c.metrics[preset.id+" HQexport"]=em
            c.check(preset.id+" preview/HQ/export",pm<0.015 && em<0.015,"Standard 256px common linear representation; .015 MAE quality threshold")
        }
        let source=AutoCorrectionTestChart.generate("already_good",size:256)
        var stacks:[(String,CIImage)]=[]
        for (preset,kind) in [(ColorGradingPreset.cinematic,CreativeEffectKind.filmEmulation),(.moody,.glamourGlow),(.splitWarmCool,.silverBW),(.goldenHour,.darkenLightenCenter)] {
            let graded=try await render(source,preset.settings)
            let out=try CreativeStackRenderer.apply(graded,stack:.init(effects:[CreativeEffect(kind)]),masks:[])
            c.check(preset.id+" stack finite",samples(out).allSatisfy(\.isFinite),hard:true,"Existing grading then Creative order")
            if kind == .silverBW {
                let p=samples(out);var diff:Float=0
                for i in stride(from:0,to:p.count,by:4) {diff=max(diff,abs(p[i]-p[i+1]),abs(p[i+1]-p[i+2]))}
                c.check("Silver B&W neutral",diff<1e-5,hard:true,"Downstream monochrome conversion removes chroma")
            }
            stacks.append((preset.title+" + "+kind.rawValue,out))
        }
        try sheet(stacks,"creative_interactions.png")
        for mode in 0..<4 {
            var mask=LocalMask(name:"Grading",components:[MaskComponent(shape:.radial(.init()))])
            if mode==1 {mask.inverted=true}
            if mode>=2 {mask.components.append(MaskComponent(shape:.linear(.init())))}
            if mode==3 {mask.components[1].operation = .subtract}
            mask.adjustments.colorGrading=ColorGradingPreset.tealWarm.settings
            var state=EditState();state.masks=[mask]
            let a=try await engine.render(url:file,state:state,quality:.interactive)
            state.masks[0].adjustments.colorGrading=manual(mask.adjustments.colorGrading)
            let b=try await engine.render(url:file,state:state,quality:.interactive)
            c.check("Mask mode \(mode) manual reproduction",lab.gpu.compare(CIImage(cgImage:a.image),CIImage(cgImage:b.image)).maxError==0,hard:true,"Same existing simple/inverted/stacked/subtractive compositor")
        }
        // Documents own values; duplication and alternating documents cannot share mutable settings.
        var a=ColorGradingPreset.tealWarm.applying(to:EditState()),b=ColorGradingPreset.pastel.applying(to:EditState())
        let savedA=try JSONEncoder().encode(a),savedB=try JSONEncoder().encode(b)
        for _ in 0..<8 {a=try JSONDecoder().decode(EditState.self,from:savedA);b=try JSONDecoder().decode(EditState.self,from:savedB)}
        c.check("A/B documents isolated",a.colorGrading==ColorGradingPreset.tealWarm.settings && b.colorGrading==ColorGradingPreset.pastel.settings,hard:true,"Persisted settings, no preset ID dependency")
        func rss()->Double {
            var info=mach_task_basic_info(),count=mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size/MemoryLayout<natural_t>.size)
            let status=withUnsafeMutablePointer(to:&info){p in p.withMemoryRebound(to:integer_t.self,capacity:Int(count)){task_info(mach_task_self_,task_flavor_t(MACH_TASK_BASIC_INFO),$0,&count)}}
            return status==KERN_SUCCESS ? Double(info.resident_size):0
        }
        for cycle in 0..<64 {
            let preset=presets[cycle%16],state=preset.applying(to:EditState()),start=ContinuousClock.now
            _=try await engine.render(url:files[(cycle/16)%8],state:state,quality:.interactive)
            performance["Preset selection production render ms",default:[]].append(helper.elapsed(start))
            if cycle%16==15 {memory.append(rss())}
        }
        c.metrics["RSS first"]=memory.first!;c.metrics["RSS last"]=memory.last!
        c.check("Memory after warmup",memory.last!<memory.first!+64*1024*1024,"64 selections across four photos; >64 MiB retained growth warrants investigation")
        c.images=[root+"creative_interactions.png"];lab.cases.append(c)
    }
}
