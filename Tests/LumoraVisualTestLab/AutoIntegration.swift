import Foundation
import CoreImage
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import Darwin
@testable import LumoraCore

extension AutoValidation {
    func integration() async throws {
        lab.progress("Auto: cache lifecycle, rotation/EXIF, masked inputs, preview/export and bounded memory")
        guard let file=files.first else {throw LabError.configuration}
        var c=LabCase(name:"Auto integration")
        await engine.clearCaches()
        let base=try await engine.autoAnalysis(url:file,state:EditState())
        c.check("Cold cache miss",!base.cacheHit,hard:true,"Single-entry actor cache")
        var state=base.proposal.applying(.light,to:EditState())
        state.creative.effects=[CreativeEffect(.silverToning)]
        let reuse=try await engine.autoAnalysis(url:file,state:state)
        c.check("Shared/UI/Creative-independent cache",reuse.cacheHit && reuse.proposal.analysis==base.proposal.analysis,hard:true,"Develop parameters, module selection and downstream Creative do not enter base key")
        state.geometry.cropZoom=35
        let cropped=try await engine.autoAnalysis(url:file,state:state)
        let croppedAgain=try await engine.autoAnalysis(url:file,state:state)
        c.check("Crop invalidates",!cropped.cacheHit && croppedAgain.cacheHit && croppedAgain.proposal.analysis==cropped.proposal.analysis,hard:true,"Same crop is bit-identical")
        state.optics.distortion=15
        let upstream=try await engine.autoAnalysis(url:file,state:state)
        c.check("Upstream optics invalidates",!upstream.cacheHit,hard:true,"Pixels changed")
        let other=try await engine.autoAnalysis(url:files[1],state:EditState())
        let returned=try await engine.autoAnalysis(url:file,state:EditState())
        c.check("A→B→A bounded cache",!other.cacheHit && !returned.cacheHit && returned.proposal.analysis==base.proposal.analysis,hard:true,"One proposal retained, no source/preview/buffer retained")
        for turn in 1...3 {
            var rotated=EditState();rotated.geometry.quarterTurns=turn
            let r=try await engine.autoAnalysis(url:file,state:rotated)
            let delta=zip(r.proposal.analysis.luminance.percentiles,base.proposal.analysis.luminance.percentiles).map{abs($0-$1)}.max()!
            c.metrics["rotation\(turn)-percentileMax"]=delta
            c.check("Rotation \(turn)",delta<0.002 && abs(r.proposal.intent.exposureShiftEV-base.proposal.intent.exposureShiftEV)<0.02,hard:true,"Quarter turns preserve visible pixels; allow .002 linear for sampling")
        }
        var masked=EditState()
        let component=MaskComponent(shape:.radial(.init()))
        masked.masks=[LocalMask(name:"Auto target",components:[component])]
        let local=try await engine.autoAnalysis(url:file,state:masked,maskID:masked.masks[0].id)
        c.check("Mask target samples",local.proposal.analysis.count>0 && local.proposal.analysis.count<base.proposal.analysis.count,hard:true,"Only selected matte >=5% contributes; analyze before its development")
        masked.masks[0].adjustments.exposure=2
        let localAgain=try await engine.autoAnalysis(url:file,state:masked,maskID:masked.masks[0].id)
        c.check("Local Auto does not analyze itself",localAgain.cacheHit,hard:true,"Target settings excluded from key")
        masked.exposure=1
        let changedBase=try await engine.autoAnalysis(url:file,state:masked,maskID:masked.masks[0].id)
        c.check("Local upstream base invalidation",!changedBase.cacheHit,hard:true,"Previous development changes actual local input")
        let chart=AutoCorrectionTestChart.generate("already_good",size:256)
        guard let cg=lab.gpu.context.createCGImage(chart,from:chart.extent,format:.RGBA8,colorSpace:CGColorSpace(name:CGColorSpace.sRGB)!) else {throw LabError.render}
        var exifReference:ImageAnalysis?
        for orientation in 1...8 {
            let url=try lab.artifacts.url("Auto/Orientation/exif_\(orientation).tiff")
            guard let dest=CGImageDestinationCreateWithURL(url as CFURL,UTType.tiff.identifier as CFString,1,nil) else {throw LabError.render}
            CGImageDestinationAddImage(dest,cg,[kCGImagePropertyOrientation:orientation] as CFDictionary)
            guard CGImageDestinationFinalize(dest) else {throw LabError.render}
            let result=try await engine.autoAnalysis(url:url,state:EditState())
            if exifReference==nil {exifReference=result.proposal.analysis}
            let delta=zip(exifReference!.luminance.percentiles,result.proposal.analysis.luminance.percentiles).map{abs($0-$1)}.max()!
            c.check("EXIF \(orientation)",delta<1e-5,hard:true,"Orientation/mirroring does not change statistics of identical pixels")
        }
        // Production paths: same persisted parameters, no Auto renderer in preview/export.
        var settings=ExportSettings();settings.format = .png;settings.maximumDimension=1024;settings.colorSpace = .displayP3
        for module in [AutoModule.light,.color,.curves,.global] {
            let s=base.proposal.applying(module,to:EditState())
            let preview=try await engine.render(url:file,state:s,quality:.interactive)
            let hq=try await engine.render(url:file,state:s,quality:.high)
            let exported=try await engine.export(request:.init(sourceURL:file,state:s,name:"Auto-"+module.rawValue),settings:settings,directory:lab.artifacts.url("Auto/Export"))
            guard let export=CIImage(contentsOf:exported.url) else {throw LabError.render}
            let p=lab.gpu.compare(reduced(CIImage(cgImage:preview.image),side:256),reduced(CIImage(cgImage:hq.image),side:256))
            let e=lab.gpu.compare(reduced(CIImage(cgImage:hq.image),side:256),reduced(export,side:256))
            c.metrics[module.rawValue+"-previewHQ-MAE"]=p.mae;c.metrics[module.rawValue+"-HQexport-MAE"]=e.mae
            c.check(module.rawValue+" preview/HQ/export",p.mae<0.015 && e.mae<0.015,"SDR output re-normalized to 256px linear; resampling/encoding allowed")
            let restored=try JSONDecoder().decode(EditState.self,from:JSONEncoder().encode(s))
            let rerender=try await engine.render(url:file,state:restored,quality:.high)
            c.check(module.rawValue+" persisted render",lab.gpu.compare(CIImage(cgImage:hq.image),CIImage(cgImage:rerender.image)).maxError==0,hard:true,"Rendered solely from saved settings")
        }
        lab.cases.append(c)
        func rss()->Double {
            var info=mach_task_basic_info(),count=mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size/MemoryLayout<natural_t>.size)
            let result=withUnsafeMutablePointer(to:&info) { p in p.withMemoryRebound(to:integer_t.self,capacity:Int(count)) {task_info(mach_task_self_,task_flavor_t(MACH_TASK_BASIC_INFO),$0,&count)} }
            return result==KERN_SUCCESS ? Double(info.resident_size) : 0
        }
        var memory=LabCase(name:"Auto memory/cache cycles"),readings:[Double]=[]
        let memoryEngine=RenderEngine()
        for batch in 0..<4 {
            for cycle in 0..<12 {
                let source=files[(batch*12+cycle)%8]
                let r=try await memoryEngine.autoAnalysis(url:source,state:EditState())
                for module in [AutoModule.light,.color,.curves] {
                    let state=r.proposal.applying(module,to:EditState())
                    let reused=try await memoryEngine.autoAnalysis(url:source,state:state)
                    memory.check("Cycle \(batch*12+cycle) \(module.rawValue)",reused.cacheHit,hard:true,"Cross-module analysis reuse")
                }
            }
            readings.append(rss());memory.metrics["RSS-batch\(batch)"]=readings.last!
        }
        memory.check("Post-warmup RSS",readings.last!-readings.first!<64*1024*1024,"48 image cycles × three Auto requests; <64 MiB drift, diagnostic not Instruments")
        lab.cases.append(memory)
    }
}
