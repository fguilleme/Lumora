import Foundation
import CoreImage
import Darwin
import Metal
import ImageIO
import UniformTypeIdentifiers
@testable import LumoraCore

extension LumoraVisualTestLab {
    func dlcIntegration() async throws {
        let fx=dlcPreset("Portrait Focus"),source=DarkenLightenCenterTestChart.image(width:1024,height:1024)
        var radial=RadialGradientMask();radial.center=MaskPoint(x:0.35,y:0.5)
        radial.radiusX=0.19;radial.radiusY=0.19;radial.feather=4
        let mask=LocalMask(name:"DLC region",components:[MaskComponent(shape:.radial(radial))])
        var targeted=fx;targeted.maskID=mask.id
        let simple=try render(source,[targeted],masks:[mask])
        var inverse=mask;inverse.inverted=true
        let inverted=try render(source,[targeted],masks:[inverse])
        var radial2=radial;radial2.center=MaskPoint(x:0.75,y:0.5)
        let secondMask=LocalMask(name:"Second",components:[MaskComponent(shape:.radial(radial2))])
        var second=fx;second.maskID=secondMask.id
        let stacked=try render(source,[targeted,second],masks:[mask,secondMask])
        var hole=radial;hole.radiusX=0.055;hole.radiusY=0.055;hole.feather=0
        let subtraction=LocalMask(name:"DLC minus center",components:[MaskComponent(operation:.add,shape:.radial(radial)),
            MaskComponent(operation:.subtract,shape:.radial(hole))])
        var cutFX=fx;cutFX.maskID=subtraction.id
        let cut=try render(source,[cutFX],masks:[subtraction])
        let outside=CGRect(x:10,y:10,width:64,height:64),center=CGRect(x:344,y:496,width:24,height:24)
        var masks=LabCase(name:"DLC_standard_masks")
        for (name,image,rect) in [("simple",simple,outside),("inverted",inverted,center),("stacked",stacked,outside),("subtractive",cut,center)] {
            let m=gpu.compare(source,image,region:rect)
            masks.metrics[name+"-outsideMaskMaxError"]=m.maxError;masks.metrics[name+"-outsideMaskMeanError"]=m.mae
            masks.check(name,m.maxError<2e-6,hard:true,"Standard Lumora ROI isolation protocol, existing compositor")
        }
        masks.check("Inside responds",gpu.compare(source,simple,region:center).mae>1e-6,hard:true,"Target ROI changes")
        masks.check("Second responds",gpu.compare(source,stacked,region:CGRect(x:756,y:496,width:24,height:24)).mae>1e-6,hard:true,"Second mask changes")
        cases.append(masks)
        try artifacts.sheet([("Original",source),("Simple",simple),("Inverted",inverted),("Stacked",stacked),("Subtractive",cut)],
                            "DarkenLightenCenter/mask_comparison.png",cell:384,maxColumns:3)
        let preset=CreativeFXPreset.all(for:.darkenLightenCenter).first{$0.title=="Portrait Focus"}!
        var initial=EditState();initial.creative.effects=[preset.applying(to:targeted)]
        var changed=initial;changed.creative.effects[0]["size"]+=1
        var history=HistoryManager();history.begin("Center size",state:initial);history.commit(changed)
        let undone=history.undo(),redone=history.redo()
        var rematch=changed.creative.effects[0];rematch["size"]-=1
        var states=LabCase(name:"DLC_standard_preset_history_persistence")
        states.check("Preset / Custom",CreativeFXPreset.matching(initial.creative.effects[0])?.title==preset.title && CreativeFXPreset.matching(changed.creative.effects[0])==nil,hard:true,"Shared matcher")
        states.check("Rematch",CreativeFXPreset.matching(rematch)?.title==preset.title,hard:true,"Exact return to snapshot")
        states.check("Undo / Redo",undone==initial && redone==changed,hard:true,"Existing HistoryManager restores full state")
        states.check("Mask and identity",initial.creative.effects[0].id==targeted.id && initial.creative.effects[0].maskID==mask.id,hard:true,"Existing applying(to:) semantics")
        states.check("Document persistence",try JSONDecoder().decode(EditState.self,from:JSONEncoder().encode(changed))==changed,hard:true,"Codable round trip")
        let settings=DarkenLightenCenterSettings(effect:initial.creative.effects[0])
        states.check("Settings persistence",try JSONDecoder().decode(DarkenLightenCenterSettings.self,from:JSONEncoder().encode(settings))==settings,hard:true,"DarkenLightenCenterSettings Codable")
        var invalid=DarkenLightenCenterSettings();invalid.centerX = .nan;invalid.rotation = .infinity;invalid.size=500
        states.check("Validation",invalid.validated.centerX.isFinite && invalid.validated.rotation.isFinite && invalid.validated.size==150,hard:true,"Existing parameter range sanitizer")
        cases.append(states)
        let others:[CreativeEffectKind]=[.silverBW,.silverToning,.filmEmulation,.highKey,.lowKey,.glamourGlow,.tonalContrast,.detailExtractor,.grain]
        for kind in others {
            let other=CreativeFXPreset.all(for:kind).dropFirst().first!.makeEffect()
            let base=kind == .silverToning ? try render(source,[effect(.silverBW)]):source
            let a=try render(base,[fx,other]),b=try render(base,[other,fx]),m=gpu.compare(a,b)
            var c=LabCase(name:"DLC_stack_"+kind.rawValue)
            c.metrics["orderMAE"]=m.mae
            c.check("Finite both orders",m.nonFinite==0,hard:true,"Ordered production compositor")
            let direct=try CreativeStackRenderer.renderers[kind]!.apply(DarkenLightenCenterRenderer().apply(base,effect:fx),effect:other)
            c.check("Order matches explicit composition",gpu.compare(a,direct).maxError<2e-6,hard:true,"No arbitrary noncommutativity threshold imposed")
            if kind == .filmEmulation {c.check("Nonlinear film differs",m.mae>1e-5,hard:true,"Exposure before and after film response differ")}
            try artifacts.sheet([("DLC → "+kind.rawValue,a),(kind.rawValue+" → DLC",b),("Difference ×8",artifacts.difference(a,b,gain:8))],"DarkenLightenCenter/stack_"+kind.rawValue+".png",cell:384,maxColumns:3)
            cases.append(c)
        }
        var copies=CreativeEffectStack(effects:[fx]);copies.duplicate(fx.id)
        var multi=LabCase(name:"DLC_history_multi_instance")
        multi.check("Duplicate independent identity",copies.effects[0].id != copies.effects[1].id && copies.effects[0].parameters==copies.effects[1].parameters && copies.effects[0].maskID==copies.effects[1].maskID,hard:true,"Shared duplicate implementation")
        copies.effects[1]["centerX"]=0.73;copies.effects[1]["shape"]=65;copies.effects[1]["rotation"]=37
        multi.check("Original unchanged",copies.effects[0]==fx,hard:true,"Value settings, no shared geometry cache")
        let stackedResult=try render(source,copies.effects),sequential=try render(render(source,[copies.effects[0]]),[copies.effects[1]])
        multi.check("Instances compose",gpu.compare(stackedResult,sequential).maxError<2e-6,hard:true,"Pointwise gains may commute; order still evaluated literally")
        var dragInitial=EditState();dragInitial.creative=copies
        var dragChanged=dragInitial,h=HistoryManager();h.begin("Center drag",state:dragInitial)
        for i in 0..<80 {dragChanged.creative.effects[0]["centerX"]=0.2+Double(i)/200;dragChanged.creative.effects[0]["centerY"]=0.4273}
        h.commit(dragChanged)
        multi.check("Coalesced drag Undo/Redo",h.undo()==dragInitial && h.redo()==dragChanged,hard:true,"One begin/commit for a continuous gesture, as used in EditorSession")
        let restored=try JSONDecoder().decode(EditState.self,from:JSONEncoder().encode(dragChanged))
        multi.check("Restored pixels",gpu.compare(try render(source,dragChanged.creative.effects),try render(source,restored.creative.effects)).maxError==0,hard:true,"Persistence includes all geometry and external mask settings")
        cases.append(multi)
        try await dlcPipelineAndOrientation()
    }
    /// Clamp only the validation source at its boundary before reduction, preventing
    /// Lanczos from mixing transparent outside pixels into the measurement.
    func dlcFullFrame(_ image:CIImage,side:Int)->CIImage {
        let e=image.extent,scale=Double(side)/max(e.width,e.height)
        return image.transformed(by:CGAffineTransform(translationX:-e.minX,y:-e.minY)).clampedToExtent()
            .applyingFilter("CILanczosScaleTransform",parameters:[kCIInputScaleKey:scale,kCIInputAspectRatioKey:1])
            .cropped(to:CGRect(x:0,y:0,width:floor(e.width*scale),height:floor(e.height*scale)))
    }
    /// Centroid/covariance of the linear gain field. Signed background residuals
    /// cancel codec quantization instead of biasing the moment by rectified noise.

    func dlcMoments(_ image:CIImage)->[String:Double] {
        let p=silverPixels(image),w=Int(image.extent.width),h=Int(image.extent.height)
        var background=0.0,count=0.0
        for y in 0..<h {for x in 0..<w where x<16 || x>=w-16 || y<16 || y>=h-16 {
            background+=LabGPU.luma(p,(y*w+x)*4);count+=1
        }}
        background/=count
        var sum=0.0,x1=0.0,y1=0.0,xx=0.0,yy=0.0,xy=0.0
        for y in 0..<h {for x in 0..<w {
            let weight=LabGPU.luma(p,(y*w+x)*4)-background,px=(Double(x)+0.5)/Double(w),py=(Double(y)+0.5)/Double(h)
            sum+=weight;x1+=weight*px;y1+=weight*py;xx+=weight*px*px;yy+=weight*py*py;xy+=weight*px*py
        }}
        let cx=x1/sum,cy=y1/sum,vx=xx/sum-cx*cx,vy=yy/sum-cy*cy,cov=xy/sum-cx*cy
        let disc=sqrt(pow(vx-vy,2)+4*cov*cov)
        return ["x":cx,"y":cy,"radius":sqrt(max(0,(vx+vy+disc)/2)),"angle":atan2(2*cov,vx-vy)*90/Double.pi]
    }
    func dlcPipelineAndOrientation() async throws {
        var c=LabCase(name:"DLC_preview_HQ_export_alignment")
        let input=try artifacts.url("DarkenLightenCenter/Pipeline/source.tiff")
        try gpu.context.writeTIFFRepresentation(of:dlcFlat(2048,2048),to:input,format:.RGBAf,colorSpace:gpu.linear,options:[:])
        let engine=RenderEngine();var state=EditState()
        state.creative.effects=[dlc(["centerEV":0.5,"borderEV":-0.5,"centerX":0.3731,"centerY":0.4273,"size":23,"shape":45,"rotation":37,"feather":70])]
        var images:[(String,CIImage)]=[]
        for quality in [PreviewQuality.interactive,.high] {
            let output=try await engine.render(url:input,state:state,quality:quality),name=quality == .interactive ? "interactive":"HQ"
            images.append((name,CIImage(cgImage:output.image)));c.metrics[name+"-milliseconds"]=output.milliseconds
        }
        var settings=ExportSettings();settings.format = .png;settings.colorSpace = .displayP3;settings.includeMetadata=false
        let exported=try await engine.export(request:ExportRequest(sourceURL:input,state:state,name:"DLC"),settings:settings,directory:artifacts.url("DarkenLightenCenter/Pipeline/Export"))
        let output=CIImage(contentsOf:exported.url)!,reference=dlcFullFrame(output,side:512),expected=dlcMoments(reference)
        c.metrics["export-centerError"]=hypot(expected["x"]!-0.3731,expected["y"]!-0.4273)
        c.check("Export center",c.metrics["export-centerError"]!<0.003,hard:true,"Recovered field centroid, normalized displacement <.003 including output quantization")
        for (name,image) in images {
            let normalized=dlcFullFrame(image,side:512),moments=dlcMoments(normalized),m=gpu.compare(normalized,reference)
            let displacement=hypot(moments["x"]!-expected["x"]!,moments["y"]!-expected["y"]!)
            let radius=abs(moments["radius"]!-expected["radius"]!),angle=abs(moments["angle"]!-expected["angle"]!)
            c.metrics[name+"-centerDisplacement"]=displacement;c.metrics[name+"-radiusError"]=radius;c.metrics[name+"-rotationErrorDegrees"]=angle
            c.metrics[name+"-profileMAE"]=m.mae
            c.check(name+" alignment",displacement<0.003 && radius<0.003 && angle<1 && m.mae<0.002,hard:true,"Moment geometry and complete common-size profile; 8-bit output tolerance")
        }
        images.append(("Export",output));try artifacts.sheet(images,"DarkenLightenCenter/preview_export_alignment.png",cell:512,maxColumns:3)
        let repeatPreview=try await engine.render(url:input,state:state,quality:.interactive)
        c.check("Cache hit",repeatPreview.cacheHit,hard:true,"Existing RenderEngine cache")
        var last=CIImage(cgImage:repeatPreview.image)
        for (key,value) in [("centerX",0.65),("centerY",0.55),("size",35.0),("shape",-35.0),("rotation",-27.0),("feather",30.0)] {
            state.creative.effects[0][key]=value
            let rendered=try await engine.render(url:input,state:state,quality:.interactive),current=CIImage(cgImage:rendered.image)
            c.check("No stale "+key,gpu.compare(last,current).mae>1e-6,hard:true,"Each geometry parameter invalidates output")
            last=current
        }
        state.creative.effects.append(dlc(["centerEV":0.3,"centerX":0.2]))
        let multiple=try await engine.render(url:input,state:state,quality:.interactive)
        c.check("Multi-instance cache",gpu.compare(last,CIImage(cgImage:multiple.image)).mae>1e-6,hard:true,"Full stack contributes to cache key")
        cases.append(c)
        var orientation=LabCase(name:"DLC_EXIF_orientation"),items:[(String,CIImage)]=[]
        let asymmetric=DarkenLightenCenterTestChart.image(width:360,height:240)
        guard let cg=gpu.context.createCGImage(asymmetric,from:asymmetric.extent,format:.RGBA8,colorSpace:CGColorSpace(name:CGColorSpace.sRGB)!) else {throw LabError.render}
        for exif in 1...8 {
            let file=try artifacts.url("DarkenLightenCenter/Orientation/exif_\(exif).tiff")
            guard let destination=CGImageDestinationCreateWithURL(file as CFURL,UTType.tiff.identifier as CFString,1,nil) else {throw LabError.render}
            CGImageDestinationAddImage(destination,cg,[kCGImagePropertyOrientation:exif] as CFDictionary)
            guard CGImageDestinationFinalize(destination) else {throw LabError.render}
            let oriented=CIImage(cgImage:cg).oriented(forExifOrientation:Int32(exif))
            var edit=EditState();edit.creative.effects=[dlc(["centerX":0.25,"centerY":0.25,"centerEV":1,"borderEV":-0.5,"size":30])]
            let result=try await engine.render(url:file,state:edit,quality:.high)
            let actual=CIImage(cgImage:result.image),direct=try render(oriented,edit.creative.effects)
            let metric=gpu.compare(silverFullFrame(actual,side:240),silverFullFrame(direct,side:240))
            orientation.metrics["EXIF\(exif)-profileMAE"]=metric.mae
            orientation.check("EXIF \(exif)",metric.mae<0.003,hard:true,"ImageIO orientation vs independently oriented CI image; asymmetric corner landmarks and top-left center")
            items.append(("EXIF \(exif)",actual))
            let exported=try await engine.export(request:ExportRequest(sourceURL:file,state:edit,name:"orientation-\(exif)"),settings:settings,directory:artifacts.url("DarkenLightenCenter/Orientation/Export"))
            let export=CIImage(contentsOf:exported.url)!
            orientation.check("EXIF export \(exif)",gpu.compare(silverFullFrame(export,side:240),silverFullFrame(actual,side:240)).mae<0.003,hard:true,"Same normalized visual center after export")
        }
        try artifacts.sheet(items,"DarkenLightenCenter/orientation_chart.png",cell:384,maxColumns:4);cases.append(orientation)
    }
}
