import Foundation
import CoreImage
import Darwin
import Metal
@testable import LumoraCore

extension LumoraVisualTestLab {
    func toningIntegration() async throws {
        let fx=toningPreset("Classic Sepia"),source=SilverToningTestChart.generate()
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
        var masks=LabCase(name:"ST_standard_masks")
        for (name,image,rect) in [("simple",simple,outside),("inverted",inverted,center),("stacked",stacked,outside),("subtractive",cut,center)] {
            let m=gpu.compare(source,image,region:rect)
            masks.metrics[name+"-outsideMaskMaxError"]=m.maxError;masks.metrics[name+"-outsideMaskMeanError"]=m.mae
            masks.check(name,m.maxError<2e-6,hard:true,"Standard Lumora ROI isolation protocol, existing compositor")
        }
        masks.check("Inside responds",gpu.compare(source,simple,region:center).mae>1e-6,hard:true,"Target ROI changes")
        masks.check("Second responds",gpu.compare(source,stacked,region:CGRect(x:756,y:496,width:24,height:24)).mae>1e-6,hard:true,"Second mask changes")
        cases.append(masks)
        try artifacts.sheet([("Original",source),("Simple",simple),("Inverted",inverted),("Stacked",stacked),("Subtractive",cut)],
                            "SilverToning/mask_comparison.png",cell:384,maxColumns:3)
        let preset=CreativeFXPreset.all(for:.silverToning).first{$0.title=="Subtle Selenium"}!
        var initial=EditState();initial.creative.effects=[preset.applying(to:targeted)]
        var changed=initial;changed.creative.effects[0]["strength"]+=1
        var history=HistoryManager();history.begin("Silver filter",state:initial);history.commit(changed)
        let undone=history.undo(),redone=history.redo()
        var rematch=changed.creative.effects[0];rematch["strength"]-=1
        var states=LabCase(name:"ST_standard_preset_history_persistence")
        states.check("Preset / Custom",CreativeFXPreset.matching(initial.creative.effects[0])?.title==preset.title && CreativeFXPreset.matching(changed.creative.effects[0])==nil,hard:true,"Shared matcher")
        states.check("Rematch",CreativeFXPreset.matching(rematch)?.title==preset.title,hard:true,"Exact return to snapshot")
        states.check("Undo / Redo",undone==initial && redone==changed,hard:true,"Existing HistoryManager restores full state")
        states.check("Mask and identity",initial.creative.effects[0].id==targeted.id && initial.creative.effects[0].maskID==mask.id,hard:true,"Existing applying(to:) semantics")
        states.check("Document persistence",try JSONDecoder().decode(EditState.self,from:JSONEncoder().encode(changed))==changed,hard:true,"Codable round trip")
        let settings=SilverToningSettings(effect:initial.creative.effects[0])
        states.check("Settings persistence",try JSONDecoder().decode(SilverToningSettings.self,from:JSONEncoder().encode(settings))==settings,hard:true,"SilverToningSettings Codable")
        var invalid=SilverToningSettings();invalid.balance = .nan;invalid.shadowHue = .infinity;invalid.strength=500
        states.check("Validation",invalid.validated.balance.isFinite && invalid.validated.shadowHue.isFinite && invalid.validated.strength==100,hard:true,"Existing parameter range sanitizer")
        cases.append(states)
        let others:[(String,CreativeEffect)]=[
            ("silver_bw",effect(.silverBW)),
            ("film_grain",effect(.grain,["amount":60,"size":40,"chromaAmount":0])),
            ("glamour_glow",CreativeFXPreset.all(for:.glamourGlow).first{$0.title=="Portrait Glow"}!.makeEffect()),
            ("film_emulation",CreativeFXPreset.all(for:.filmEmulation).first{$0.title=="Vivid Chrome"}!.makeEffect()),
            ("cross_processing",CreativeFXPreset.all(for:.crossProcessing).first{$0.title=="Warm Process"}!.makeEffect())]
        let textured=try render(SilverBWTestChart.generate(size:512).image,[effect(.silverBW)])
        for (name,other) in others {
            let a=try render(textured,[fx,other]),b=try render(textured,[other,fx]),m=gpu.compare(a,b)
            var c=LabCase(name:"ST_stack_"+name)
            c.metrics=["orderMAE":m.mae,"nonFinite":Double(m.nonFinite),"toningLastChannelError":silverNeutralError(silverPixels(b))]
            c.check("Order respected",m.mae>1e-7,hard:true,"Production ordered stack, neutral BW base; no commutativity imposed")
            c.check("Finite",m.nonFinite==0,hard:true,"Both orders")
            if name=="silver_bw" {
                c.check("BW last removes toning",silverNeutralError(silverPixels(a))<2e-6 && silverNeutralError(silverPixels(b))>0.001,hard:true,"Full monochrome conversion last")
            }
            try artifacts.sheet([("Toning → "+name,a),(name+" → Toning",b),("Difference ×8",artifacts.difference(a,b,gain:8))],
                                "SilverToning/stack_with_"+name+".png",cell:384,maxColumns:3)
            cases.append(c)
        }
        // Multi-step history with toner, strength, balance and paper changes.
        var edit=EditState();edit.creative.effects=[toningPreset("Subtle Selenium")]
        var h=HistoryManager(),snapshots=[edit]
        for (key,value) in [("strength",70.0),("balance",25.0),("paperTone",40.0),("toner",2.0)] {
            h.begin(key,state:edit);edit.creative.effects[0][key]=value;h.commit(edit);snapshots.append(edit)
        }
        var historyCheck=LabCase(name:"ST_multi_step_history")
        let u1=h.undo(),u2=h.undo(),r1=h.redo()
        historyCheck.check("Undo Undo Redo",u1==snapshots[3] && u2==snapshots[2] && r1==snapshots[3],hard:true,"Every setting is in shared EditState")
        cases.append(historyCheck)
        // Soft mask edge: pointwise coloration must retain ramp luminance.
        var soft=radial;soft.feather=80
        let softMask=LocalMask(name:"Soft",components:[MaskComponent(shape:.radial(soft))])
        var softFX=fx;softFX.maskID=softMask.id
        let softOutput=try render(source,[softFX],masks:[softMask]),softMetric=gpu.compare(source,softOutput)
        var edge=LabCase(name:"ST_soft_mask_edge")
        edge.metrics["luminanceResidualRMS"]=softMetric.residualStd
        edge.check("No luminance fringe",softMetric.residualStd<2e-6,hard:true,"Shared soft mask blend interpolates constant-Y colors")
        try artifacts.sheet([("Input",source),("Soft mask",softOutput)],"SilverToning/mask_edge.png",cell:512,maxColumns:2)
        cases.append(edge)
        let inputPath=try artifacts.url("SilverToning/Pipeline/source.png")
        try artifacts.png(SilverToningTestChart.generate(size:2048),"SilverToning/Pipeline/source.png")
        for presetTitle in ["Subtle Selenium","Classic Sepia","Split Warm/Cool"] {
        let engine=RenderEngine();var state=EditState();state.creative.effects=[toningPreset(presetTitle)]
        var pipeline=LabCase(name:"ST_pipeline_"+presetTitle),images:[(String,CIImage)]=[]
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
                                             directory:artifacts.url("SilverToning/Pipeline/Export"))
        guard let output=CIImage(contentsOf:exported.url) else {throw LabError.render}
        for (name,image) in images {
            let m=gpu.compare(silverFullFrame(image,side:512),silverFullFrame(output,side:512))
            pipeline.metrics[name+"-exportMAE"]=m.mae;pipeline.metrics[name+"-exportRMSE"]=m.rmse
            pipeline.metrics[name+"-exportMaxError"]=m.maxError
            pipeline.check(name+" / export",m.rmse<0.003,hard:true,"Pointwise common-size RGB RMSE < .003 including resampling and 8-bit codec")
        }
        state.creative.effects[0]["strength"]=80
        let changedPreview=try await engine.render(url:inputPath,state:state,quality:.interactive)
        pipeline.check("Strength invalidates preview",gpu.compare(images[0].1,CIImage(cgImage:changedPreview.image)).mae>1e-6,hard:true,"Changed Silver settings cannot reuse stale pixels")
        state.creative.effects[0]["toner"]=3
        let switched=try await engine.render(url:inputPath,state:state,quality:.interactive)
        pipeline.check("Toner invalidates preview",gpu.compare(CIImage(cgImage:changedPreview.image),CIImage(cgImage:switched.image)).mae>1e-6,hard:true,"Toner selector uses same cache key")
        images.append(("Export",output))
        try artifacts.sheet(images,"SilverToning/Pipeline/"+presetTitle+".png",cell:512,maxColumns:3)
        cases.append(pipeline)
    }
        }
}

extension LumoraVisualTestLab {
    func toningPerformance() throws {
        progress("Silver Toning: isolated GPU command timing, CPU graph preparation, resolution and memory")
        guard let device=MTLCreateSystemDefaultDevice(),let queue=device.makeCommandQueue() else {throw LabError.render}
        let context=CIContext(mtlDevice:device,options:[.workingColorSpace:gpu.linear,.workingFormat:CIFormat.RGBAf,.cacheIntermediates:false])
        var c=LabCase(name:"ST_performance_resolution_memory")
        let fx=toningPreset("Classic Sepia")
        var references:[Float] = []
        for side in [1024,2048,4096] {
            try autoreleasepool {
                let input=silverSample(SIMD3(repeating:0.18)).clampedToExtent().cropped(to:CGRect(x:0,y:0,width:side,height:side))
                let desc=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.rgba32Float,width:side,height:side,mipmapped:false)
                desc.usage=[.shaderRead,.shaderWrite,.renderTarget];desc.storageMode = .private
                guard let texture=device.makeTexture(descriptor:desc) else {throw LabError.render}
                var gpuMS:[Double]=[],cpuMS:[Double]=[],wallMS:[Double]=[]
                for iteration in 0..<6 {
                    let start=ProcessInfo.processInfo.systemUptime
                    let output=try toningOutput(input,fx)
                    let prepared=ProcessInfo.processInfo.systemUptime
                    guard let command=queue.makeCommandBuffer() else {throw LabError.render}
                    context.render(output,to:texture,commandBuffer:command,bounds:input.extent,colorSpace:gpu.linear)
                    command.commit();command.waitUntilCompleted()
                    guard command.status == .completed else {throw LabError.render}
                    if iteration>0 {
                        gpuMS.append((command.gpuEndTime-command.gpuStartTime)*1000)
                        cpuMS.append((prepared-start)*1000)
                        wallMS.append((ProcessInfo.processInfo.systemUptime-start)*1000)
                    }
                }
                c.metrics["\(side)-GPU-medianMS"]=gpuMS.sorted()[2]
                c.metrics["\(side)-CPU-graph-medianMS"]=cpuMS.sorted()[2]
                c.metrics["\(side)-wall-medianMS"]=wallMS.sorted()[2]
                let sample=gpu.read(try toningOutput(input,fx),CGRect(x:0,y:0,width:16,height:16))
                if references.isEmpty {references=sample}
                let error=zip(sample,references).map{abs($0-$1)}.max() ?? 0
                c.check("Resolution \(side)",error<2e-6,hard:true,"Same luminance/color at native resolution, pointwise response")
            }
        }
        func rss()->Double {
            var info=mach_task_basic_info(),count=mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size/MemoryLayout<natural_t>.size)
            let result=withUnsafeMutablePointer(to:&info){p in p.withMemoryRebound(to:integer_t.self,capacity:Int(count)){task_info(mach_task_self_,task_flavor_t(MACH_TASK_BASIC_INFO),$0,&count)}}
            return result==KERN_SUCCESS ? Double(info.resident_size):0
        }
        let source=SilverToningTestChart.generate(size:256)
        var memory:[Double]=[]
        for batch in 0..<4 {
            for i in 0..<36 {
                try autoreleasepool {
                    let f=toningFX(["toner":Double(1+i%8),"strength":Double(i*17%101),"balance":Double(i*13%201-100),"paperTone":Double(i*19%201-100),"shadowHue":Double(i*41%360),"highlightHue":Double(i*71%360)])
                    c.check("Switch \(batch)/\(i)",silverPixels(try toningOutput(source,f)).allSatisfy(\.isFinite),hard:true,"All chromatic settings varied, no retained per-effect textures")
                }
            }
            memory.append(rss());c.metrics["RSS-batch\(batch)"]=memory.last!
        }
        c.check("Bounded post-warmup memory",memory.last!-memory[0]<64*1024*1024,"144 changes; RSS diagnostic, not a device leak instrument")
        c.notes=["GPU command timestamps include CI encoding execution and output writes, without CPU readback. CPU timing is settings validation/graph preparation; compile is warmed. No isolated kernel-only claim. Mac GPU, not iPhone thermal performance."]
        cases.append(c)
    }
}
