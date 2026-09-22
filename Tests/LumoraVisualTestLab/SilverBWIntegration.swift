import Foundation
import CoreImage
import Darwin
@testable import LumoraCore

extension LumoraVisualTestLab {
    func silverIntegration(_ chart:SilverBWTestChart) async throws {
        let fx=silverPreset("Classic Film"),source=silverFullFrame(chart.image,side:1024)
        var radial=RadialGradientMask();radial.center=MaskPoint(x:0.35,y:0.5)
        radial.radiusX=0.19;radial.radiusY=0.19;radial.feather=4
        let mask=LocalMask(name:"Silver region",components:[MaskComponent(shape:.radial(radial))])
        var targeted=fx;targeted.maskID=mask.id
        let simple=try render(source,[targeted],masks:[mask])
        var inverse=mask;inverse.inverted=true
        let inverted=try render(source,[targeted],masks:[inverse])
        var radial2=radial;radial2.center=MaskPoint(x:0.75,y:0.5)
        let secondMask=LocalMask(name:"Second",components:[MaskComponent(shape:.radial(radial2))])
        var second=fx;second.maskID=secondMask.id
        let stacked=try render(source,[targeted,second],masks:[mask,secondMask])
        var hole=radial;hole.radiusX=0.055;hole.radiusY=0.055;hole.feather=0
        let subtraction=LocalMask(name:"Silver minus center",components:[MaskComponent(operation:.add,shape:.radial(radial)),
            MaskComponent(operation:.subtract,shape:.radial(hole))])
        var cutFX=fx;cutFX.maskID=subtraction.id
        let cut=try render(source,[cutFX],masks:[subtraction])
        let outside=CGRect(x:10,y:10,width:64,height:64),center=CGRect(x:344,y:496,width:24,height:24)
        var masks=LabCase(name:"SBW_standard_masks")
        for (name,image,rect) in [("simple",simple,outside),("inverted",inverted,center),("stacked",stacked,outside),("subtractive",cut,center)] {
            let m=gpu.compare(source,image,region:rect)
            masks.metrics[name+"-outsideMaskMaxError"]=m.maxError;masks.metrics[name+"-outsideMaskMeanError"]=m.mae
            masks.check(name,m.maxError<2e-6,hard:true,"Standard Lumora ROI isolation protocol, existing compositor")
        }
        masks.check("Inside responds",gpu.compare(source,simple,region:center).mae>1e-6,hard:true,"Target ROI changes")
        masks.check("Second responds",gpu.compare(source,stacked,region:CGRect(x:756,y:496,width:24,height:24)).mae>1e-6,hard:true,"Second mask changes")
        cases.append(masks)
        try artifacts.sheet([("Original",source),("Simple",simple),("Inverted",inverted),("Stacked",stacked),("Subtractive",cut)],
                            "SilverBW/mask_comparison.png",cell:384,maxColumns:3)
        let preset=CreativeFXPreset.all(for:.silverBW).first{$0.title=="Soft Portrait"}!
        var initial=EditState();initial.creative.effects=[preset.applying(to:targeted)]
        var changed=initial;changed.creative.effects[0]["filterStrength"]+=1
        var history=HistoryManager();history.begin("Silver filter",state:initial);history.commit(changed)
        let undone=history.undo(),redone=history.redo()
        var rematch=changed.creative.effects[0];rematch["filterStrength"]-=1
        var states=LabCase(name:"SBW_standard_preset_history_persistence")
        states.check("Preset / Custom",CreativeFXPreset.matching(initial.creative.effects[0])?.title==preset.title && CreativeFXPreset.matching(changed.creative.effects[0])==nil,hard:true,"Shared matcher")
        states.check("Rematch",CreativeFXPreset.matching(rematch)?.title==preset.title,hard:true,"Exact return to snapshot")
        states.check("Undo / Redo",undone==initial && redone==changed,hard:true,"Existing HistoryManager restores full state")
        states.check("Mask and identity",initial.creative.effects[0].id==targeted.id && initial.creative.effects[0].maskID==mask.id,hard:true,"Existing applying(to:) semantics")
        states.check("Document persistence",try JSONDecoder().decode(EditState.self,from:JSONEncoder().encode(changed))==changed,hard:true,"Codable round trip")
        let settings=SilverBWSettings(effect:initial.creative.effects[0])
        states.check("Settings persistence",try JSONDecoder().decode(SilverBWSettings.self,from:JSONEncoder().encode(settings))==settings,hard:true,"SilverBWSettings Codable")
        var invalid=SilverBWSettings();invalid.brightness = .nan;invalid.filterHue = .infinity;invalid.structure=500
        states.check("Validation",invalid.validated.brightness.isFinite && invalid.validated.filterHue.isFinite && invalid.validated.structure==100,hard:true,"Existing parameter range sanitizer")
        cases.append(states)
        let others:[(String,CreativeEffect)]=[
            ("grain",effect(.grain,["amount":60,"size":40,"chromaAmount":0])),
            ("tonal_contrast",effect(.tonalContrast,["globalAmount":75])),
            ("detail_extractor",effect(.detailExtractor,["amount":65])),
            ("glamour_glow",CreativeFXPreset.all(for:.glamourGlow).first{$0.title=="Portrait Glow"}!.makeEffect()),
            ("film_emulation",CreativeFXPreset.all(for:.filmEmulation).first{$0.title=="Vivid Chrome"}!.makeEffect()),
            ("cross_processing",CreativeFXPreset.all(for:.crossProcessing).first{$0.title=="Warm Process"}!.makeEffect())]
        for (name,other) in others {
            let a=try render(source,[fx,other]),b=try render(source,[other,fx]),m=gpu.compare(a,b)
            var c=LabCase(name:"SBW_stack_"+name)
            c.metrics=["orderMAE":m.mae,"nonFinite":Double(m.nonFinite),"otherThenSilverChannelError":silverNeutralError(silverPixels(b)),
                       "silverThenOtherChannelError":silverNeutralError(silverPixels(a))]
            c.check("Order respected",m.mae>1e-7,hard:true,"Production ordered Creative stack; never force commutativity")
            c.check("Finite",m.nonFinite==0,hard:true,"Both orders")
            c.check("Silver last is neutral",c.metrics["otherThenSilverChannelError"]!<2e-6,hard:true,"Source color affects density then is removed")
            try artifacts.sheet([("Silver → "+name,a),(name+" → Silver",b),("Difference ×8",artifacts.difference(a,b,gain:8))],
                                "SilverBW/stack_"+name+".png",cell:384,maxColumns:3)
            cases.append(c)
        }
        let inputPath=try artifacts.url("SilverBW/Pipeline/source.png")
        try artifacts.png(SilverBWTestChart.generate(size:2048).image,"SilverBW/Pipeline/source.png")
        let engine=RenderEngine();var state=EditState();state.creative.effects=[silverPreset("Soft Portrait")]
        var pipeline=LabCase(name:"SBW_standard_preview_HQ_export_cache"),images:[(String,CIImage)]=[]
        for quality in [PreviewQuality.interactive,.high] {
            let r=try await engine.render(url:inputPath,state:state,quality:quality)
            let name=quality == .interactive ? "interactive":"HQ"
            pipeline.metrics[name+"-milliseconds"]=r.milliseconds
            pipeline.metrics[name+"-width"]=Double(r.image.width)
            images.append((name,CIImage(cgImage:r.image)))
        }
        let repeated=try await engine.render(url:inputPath,state:state,quality:.interactive)
        pipeline.check("Cache hit",repeated.cacheHit,hard:true,"Shared RenderEngine cache")
        var exportSettings=ExportSettings();exportSettings.format = .png;exportSettings.colorSpace = .displayP3;exportSettings.includeMetadata=false
        let exported=try await engine.export(request:ExportRequest(sourceURL:inputPath,state:state,name:"silver-lab"),settings:exportSettings,
                                             directory:artifacts.url("SilverBW/Pipeline/Export"))
        guard let output=CIImage(contentsOf:exported.url) else {throw LabError.render}
        for (name,image) in images {
            let m=gpu.compare(silverFullFrame(image,side:512),silverFullFrame(output,side:512))
            pipeline.metrics[name+"-exportMAE"]=m.mae;pipeline.metrics[name+"-exportRMSE"]=m.rmse
            pipeline.metrics[name+"-exportMaxError"]=m.maxError
            pipeline.check(name+" / export",m.ssim>0.90,"Shared display conversion / common-size SSIM protocol")
        }
        let exportError=silverNeutralError(silverPixels(silverFullFrame(output,side:512)))
        pipeline.metrics["export-neutralError"]=exportError
        pipeline.check("Export neutral",exportError<0.001,hard:true,"Output codec/color-management tolerance")
        state.creative.effects[0]["filterStrength"]=80
        let changedPreview=try await engine.render(url:inputPath,state:state,quality:.interactive)
        pipeline.check("Filter invalidates preview",gpu.compare(images[0].1,CIImage(cgImage:changedPreview.image)).mae>1e-6,hard:true,"Changed Silver settings cannot reuse stale pixels")
        state.creative.effects[0]["filmResponse"]=5
        let switched=try await engine.render(url:inputPath,state:state,quality:.interactive)
        pipeline.check("Film response invalidates preview",gpu.compare(CIImage(cgImage:changedPreview.image),CIImage(cgImage:switched.image)).mae>1e-6,hard:true,"Film selector uses same cache key")
        images.append(("Export",output))
        try artifacts.sheet(images,"SilverBW/Pipeline/comparison.png",cell:512,maxColumns:3)
        cases.append(pipeline)
    }
    private func silverResidentBytes()->Double {
        var info=mach_task_basic_info(),count=mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size/MemoryLayout<natural_t>.size)
        let result=withUnsafeMutablePointer(to:&info){pointer in
            pointer.withMemoryRebound(to:integer_t.self,capacity:Int(count)){task_info(mach_task_self_,task_flavor_t(MACH_TASK_BASIC_INFO),$0,&count)}
        }
        return result==KERN_SUCCESS ? Double(info.resident_size):0
    }
    func silverPerformance() throws {
        progress("Silver B&W: materialized GPU render 1024 / 2048 / 4096")
        var c=LabCase(name:"SBW_standard_resolution_performance_memory")
        var references:[Int:CIImage]=[:]
        for dimension in [1024,2048,4096] { for structure in [0,50] {
            try autoreleasepool {
                let source=SyntheticCharts.make(size:dimension){x,y in
                    let v=Float(0.04+0.88*(x+0.35*y)/1.35)
                    return .init(v*0.92,v*0.77,v*0.63)
                }
                let fx=silverFX(["structure":Double(structure)])
                let output=try render(source,[fx])
                // Warm the pipelines first; measurements include full RGBAf
                // materialization/readback, not isolated GPU command duration.
                _=silverPixels(output)
                var timings:[Double]=[]
                for _ in 0..<3 {
                    let start=ProcessInfo.processInfo.systemUptime
                    _=silverPixels(try render(source,[fx]))
                    timings.append((ProcessInfo.processInfo.systemUptime-start)*1000)
                }
                timings.sort()
                c.metrics["\(dimension)-structure\(structure)-materializationMedianMS"]=timings[1]
                let sample=silverFullFrame(output,side:256),p=silverPixels(sample)
                c.check("Finite \(dimension)/\(structure)",p.allSatisfy(\.isFinite),hard:true,"Full native materialization, float sample")
                if let reference=references[structure] {
                    let m=gpu.compare(reference,sample)
                    c.metrics["\(dimension)-structure\(structure)-resolutionRMSE"]=m.rmse
                    c.check("Resolution \(dimension)/\(structure)",m.rmse<0.015,"Existing common-size resolution tolerance")
                } else {
                    references[structure]=CIImage(bitmapData:p.withUnsafeBytes{Data($0)},bytesPerRow:256*16,size:CGSize(width:256,height:256),format:.RGBAf,colorSpace:gpu.linear)
                }
            }
        }}
        let source=SilverBWTestChart.generate(size:512).image
        _=silverPixels(try render(source,[silverPreset("High Structure")]))
        let memoryBefore=silverResidentBytes()
        for i in 0..<28 {
            try autoreleasepool {
                let fx=silverFX(["filmResponse":Double(i%7),"filterHue":Double((i*47)%360),"structure":50])
                let p=silverPixels(try render(source,[fx]))
                c.check("Switch finite \(i)",p.allSatisfy(\.isFinite),hard:true,"No stale-state or invalid intermediate")
            }
        }
        let memoryAfter=silverResidentBytes()
        c.metrics["residentBeforeBytes"]=memoryBefore;c.metrics["residentAfterBytes"]=memoryAfter
        c.check("Bounded observed growth",memoryAfter-memoryBefore<128*1024*1024,"28 switches; process RSS includes Core Image/driver caches, not an iOS thermal trace")
        let expected=try render(source,[silverFX()]),repeatImage=try render(source,[silverFX()])
        c.check("No stale response",gpu.compare(expected,repeatImage).maxError==0,hard:true,"Deterministic after repeated profile changes")
        c.notes=["Static kernels/immutable profiles only. No per-frame CPU image readback in production, no image cache owned by Silver. Native timings apply equally to interactive/HQ effect code; actual RenderEngine interactive/HQ is measured separately."]
        cases.append(c)
    }
}
