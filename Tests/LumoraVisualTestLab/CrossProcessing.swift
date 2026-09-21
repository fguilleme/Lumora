import Foundation
import CoreImage
@testable import LumoraCore

struct CrossProcessingTestChart {
    let image: CIImage
    let regions: [ChartRegion]
    static let names = ["gray-ramp", "red-ramp", "green-ramp", "blue-ramp",
                        "dark-gray", "mid-gray", "bright-gray", "color-patches",
                        "light-skin", "dark-skin", "sky-gradient", "hdr-ramp",
                        "warm-skin", "cool-skin", "near-black", "highlight"]
    static func generate(size: Int) -> Self {
        let image = SyntheticCharts.make(size: size) { x,y in
            let col=min(3,Int(x*4)),row=min(3,Int(y*4)),i=row*4+col
            let u=x*4-Double(col),v=y*4-Double(row)
            let t=Float(u), texture=Float(0.008*sin(u*73)*sin(v*47))
            switch i {
            case 0: return SIMD3(repeating:t)
            case 1: return SIMD3(t,0,0)
            case 2: return SIMD3(0,t,0)
            case 3: return SIMD3(0,0,t)
            case 4: return SIMD3(repeating:0.07+texture)
            case 5: return SIMD3(repeating:0.44+texture)
            case 6: return SIMD3(repeating:0.85+texture)
            case 7:
                let colors:[SIMD3<Float>]=[.init(0.8,0.08,0.06),.init(0.06,0.75,0.06),
                    .init(0.08,0.10,0.85),.init(0.07,0.75,0.80),.init(0.75,0.07,0.75),
                    .init(0.80,0.74,0.06)]
                return colors[min(5,Int(u*3)+3*Int(v*2))]
            case 8: return .init(0.59,0.35,0.24)
            case 9: return .init(0.28,0.15,0.10)
            case 10: return .init(0.28+0.22*t,0.45+0.21*t,0.72+0.23*t)
            case 11: return SIMD3(repeating:4*t)
            case 12: return .init(0.62,0.32,0.20)
            case 13: return .init(0.40,0.30,0.28)
            case 14: return SIMD3(repeating:0.012+0.09*t)
            default: return SIMD3(repeating:0.75+0.24*t)
            }
        }
        let cell=size/4
        return Self(image:image,regions:names.enumerated().map { i,name in
            ChartRegion(name:name,x:(i%4)*cell,y:size-(i/4+1)*cell,
                        width:cell,height:cell,ramp:name.contains("ramp") || name.contains("gradient"))
        })
    }
    func rect(_ name:String)->CGRect {regions.first{$0.name == name}!.rect}
}

extension LumoraVisualTestLab {
    private func cpPreset(_ title:String)->CreativeEffect {
        CreativeFXPreset.all(for:.crossProcessing).first{$0.title == title}!.makeEffect()
    }
    private func cpKey(_ title:String)->String {
        title.lowercased().replacingOccurrences(of:" ",with:"_").replacingOccurrences(of:"-",with:"_")
    }
    private func cpHue(_ rgb:SIMD3<Double>)->Double {
        atan2(sqrt(3)*(rgb.y-rgb.z),2*rgb.x-rgb.y-rgb.z)
    }
    private func cpChroma(_ rgb:SIMD3<Double>)->Double {
        max(rgb.x,rgb.y,rgb.z)-min(rgb.x,rgb.y,rgb.z)
    }
    private func cpSample(_ image:CIImage,_ rect:CGRect)->SIMD3<Double> {
        let bounds=CGRect(x:floor(rect.midX-4),y:floor(rect.midY-4),width:8,height:8)
        let p=gpu.read(image,bounds)
        var sum=SIMD3<Double>(repeating:0)
        for i in stride(from:0,to:p.count,by:4) {
            sum += SIMD3(Double(p[i]),Double(p[i+1]),Double(p[i+2]))
        }
        return sum/Double(p.count/4)
    }
    private func cpColorMetrics(_ input:SIMD3<Double>,_ output:SIMD3<Double>,_ prefix:String,_ c:inout LabCase) {
        let yi=input.x*0.2126+input.y*0.7152+input.z*0.0722
        let yo=output.x*0.2126+output.y*0.7152+output.z*0.0722
        let delta=abs(cpHue(output)-cpHue(input))
        c.metrics[prefix+"-inputHue"]=cpHue(input)
        c.metrics[prefix+"-outputHue"]=cpHue(output)
        c.metrics[prefix+"-hueShift"]=min(delta,2*Double.pi-delta)
        c.metrics[prefix+"-inputChroma"]=cpChroma(input)
        c.metrics[prefix+"-outputChroma"]=cpChroma(output)
        c.metrics[prefix+"-chromaRatio"]=cpChroma(output)/max(1e-6,cpChroma(input))
        c.metrics[prefix+"-inputY"]=yi;c.metrics[prefix+"-outputY"]=yo
        c.metrics[prefix+"-luminanceRatio"]=yo/max(1e-6,yi)
    }
    func runCrossProcessing() async throws {
        progress("Cross Processing chart and independent RGB curves")
        let chart=CrossProcessingTestChart.generate(size:2048)
        try artifacts.png(chart.image,"CrossProcessing/CrossProcessingTestChart.png")
        try artifacts.json(chart.regions,"CrossProcessing/chart_regions.json")
        do {
            try cpIdentityAndPresets(chart)
            try cpCurvesAndPatches(chart)
            try cpBandingHDRAndLift(chart)
            try cpDiversityAndGrade(chart)
            try cpMasksAndStack(chart)
            try cpPerformance()
            try await cpPipeline(chart)
            try cpPhotos()
        } catch {
            var c=LabCase(name:"CP_harness")
            c.check("Completed",false,hard:true,String(describing:error));cases.append(c)
            try cpReport();throw error
        }
        try cpReport()
    }
    private func cpIdentityAndPresets(_ chart:CrossProcessingTestChart) throws {
        for (label,parameters) in [("amount_zero",["amount":0.0]),
                                   ("style_zero",["styleStrength":0.0])] {
            let output=try render(chart.image,[effect(.crossProcessing,parameters)])
            let m=gpu.compare(chart.image,output)
            var c=LabCase(name:"CP_identity_"+label)
            c.metrics=["maxRGBError":m.maxError,"meanRGBError":m.mae,"nonFinitePixels":Double(m.nonFinite)]
            c.check("Strict identity",m.maxError == 0,hard:true,"Zero bypasses the pointwise GPU kernel.")
            c.check("Finite",m.nonFinite == 0,hard:true,"RGBAf output.")
            cases.append(c)
        }
        let preset=CreativeFXPreset.all(for:.crossProcessing).first{$0.title=="Warm Process"}!
        var existing=CreativeEffect(.crossProcessing,maskID:UUID())
        let id=existing.id,mask=existing.maskID
        existing=preset.applying(to:existing)
        let matched=CreativeFXPreset.matching(existing)?.title=="Warm Process"
        existing["styleStrength"]+=1
        var before=EditState(),after=EditState()
        before.creative.effects=[preset.makeEffect()];after.creative.effects=[existing]
        var history=HistoryManager();history.begin("Cross slider",state:before);history.commit(after)
        let undone=history.undo(),redone=history.redo()
        let persisted=try JSONDecoder().decode(EditState.self,from:JSONEncoder().encode(after))
        var c=LabCase(name:"CP_preset_history")
        c.check("Preset then Custom",matched && CreativeFXPreset.matching(existing)==nil,hard:true,
                "Complete parameter snapshot with a hidden style index.")
        c.check("ID and mask retained",existing.id==id && existing.maskID==mask,hard:true,
                "Applying style preserves placement and target.")
        c.check("Undo/Redo",undone==before && redone==after,hard:true,"Existing state history.")
        c.check("Persistence",persisted==after,hard:true,"Codable round trip.")
        cases.append(c)
    }
    private func cpCurvesAndPatches(_ chart:CrossProcessingTestChart) throws {
        let ramp=SyntheticCharts.make(size:4096) { x,_ in SIMD3(repeating:Float(x)) }
        let line=CGRect(x:0,y:2048,width:4096,height:1)
        var gray:[(String,CIImage)]=[("Original",chart.image.cropped(to:chart.rect("gray-ramp")))]
        for preset in CreativeFXPreset.all(for:.crossProcessing) {
            let key=cpKey(preset.title),fx=preset.makeEffect()
            let output=try render(ramp,[fx])
            let input=gpu.read(ramp,line),pixels=gpu.read(output,line)
            var c=LabCase(name:"CP_curves_"+key)
            var series:[(String,[Double])]=[("Identity",(0..<4096).map{Double($0)/4095})]
            for (channel,name) in [(0,"red"),(1,"green"),(2,"blue")] {
                let values=(0..<4096).map{Double(pixels[$0*4+channel])}
                let steps=zip(values.dropFirst(),values).map(-)
                let reversal=steps.filter{$0 < -1e-6}.count
                let derivative=zip(steps.dropFirst(),steps).map{abs($0-$1)}.max() ?? 0
                c.metrics[name+"Reversals"]=Double(reversal)
                c.metrics[name+"MaxAdjacentDerivativeChange"]=derivative
                c.metrics[name+"HDRInput1"]=Double(input[4095*4+channel])
                c.check("Monotone \(name)",reversal==0,hard:true,"4096 RGBf samples.")
                c.check("Continuous \(name)",derivative<0.002,hard:true,
                        "No visible step or uncontrolled spline overshoot.")
                series.append((name.capitalized,values))
            }
            let m=gpu.compare(ramp,output,region:line)
            c.metrics["nonFinitePixels"]=Double(m.nonFinite)
            c.check("Finite",m.nonFinite==0,hard:true,"Full channel curves.")
            let path="CrossProcessing/curves_"+key+".png"
            try artifacts.plot(series,path,title:preset.title+" · linear RGB")
            c.images=[path];cases.append(c)
            let strip=try render(chart.image.cropped(to:chart.rect("gray-ramp")),[fx])
            gray.append((preset.title,strip))
            var patches=LabCase(name:"CP_patches_"+key)
            let source=chart.image
            let processed=try render(source,[fx])
            for name in ["dark-gray","mid-gray","bright-gray","light-skin","dark-skin",
                         "warm-skin","cool-skin","sky-gradient"] {
                cpColorMetrics(cpSample(source,chart.rect(name)),cpSample(processed,chart.rect(name)),name,&patches)
            }
            let colors=chart.rect("color-patches")
            for row in 0..<2 {for col in 0..<3 {
                let rect=CGRect(x:colors.minX+CGFloat(col)*colors.width/3,
                                y:colors.minY+CGFloat(row)*colors.height/2,
                                width:colors.width/3,height:colors.height/2)
                cpColorMetrics(cpSample(source,rect),cpSample(processed,rect),"color_\(row)_\(col)",&patches)
            }}
            let comparison=gpu.compare(source,processed)
            patches.metrics["newChannelClippingFraction"]=Double(max(0,comparison.whiteOutput-comparison.whiteInput))/Double(max(1,comparison.input.count))
            patches.metrics["nonFinitePixels"]=Double(comparison.nonFinite)
            patches.check("Finite patches",comparison.nonFinite==0,hard:true,"No NaN or Inf.")
            if ["Subtle Cross","Warm Process","Cool Process","Vintage Process"].contains(preset.title) {
                for skin in ["light-skin","dark-skin"] {
                    let shift=patches.metrics[skin+"-hueShift"]!
                    patches.check("Plausible \(skin)",shift<0.38,
                                  "Moderate-style skin heuristic: hue rotation <0.38 rad; manual review remains primary.")
                }
            }
            cases.append(patches)
        }
        try artifacts.sheet(gray,"CrossProcessing/gray_ramp_styles.png",cell:512,maxColumns:4)
    }
}

extension LumoraVisualTestLab {
    private func cpCrop(_ image:CIImage,x:Double,y:Double,side:Int=512)->CIImage {
        let s=min(CGFloat(side),image.extent.width,image.extent.height)
        let px=min(image.extent.maxX-s,max(image.extent.minX,image.extent.minX+image.extent.width*x-s/2))
        let py=min(image.extent.maxY-s,max(image.extent.minY,image.extent.minY+image.extent.height*y-s/2))
        return image.cropped(to:CGRect(x:floor(px),y:floor(py),width:s,height:s))
    }
    private func cpPriority(_ index:Int)->[(String,Double,Double)] {
        switch index {
        case 0:return [("skin",0.5,0.5),("hair and eyes",0.5,0.77)]
        case 1:return [("skin",0.5,0.5),("hair and eyes",0.5,0.77)]
        case 2:return [("clouds",0.5,0.28),("ridge",0.5,0.57)]
        case 3:return [("subject",0.48,0.57),("sun",0.5,0.28)]
        case 4:return [("lamps",0.5,0.25),("stone",0.5,0.68)]
        case 5:return [("window",0.5,0.3),("interior",0.5,0.7)]
        case 6:return [("dress",0.5,0.68),("skin",0.5,0.52)]
        default:return [("skin",0.5,0.5),("knit",0.5,0.58),("water",0.5,0.25)]
        }
    }
    private func cpPhotos() throws {
        let repo=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let folder=URL(fileURLWithPath:ProcessInfo.processInfo.environment["LUMORA_VISUAL_ASSETS"]
            ?? repo.appendingPathComponent("VisualTestAssets").path)
        let files=try FileManager.default.contentsOfDirectory(at:folder,includingPropertiesForKeys:nil)
            .filter{["png","jpg","jpeg","tif","tiff","heic"].contains($0.pathExtension.lowercased())}
            .sorted{$0.lastPathComponent<$1.lastPathComponent}
        guard files.count == 8 else {throw NSError(domain:"CrossProcessingLab",code:1,
            userInfo:[NSLocalizedDescriptionKey:"Expected eight photos; found \(files.count) in \(folder.path)"])}
        let titles=CreativeFXPreset.all(for:.crossProcessing).map(\.title)
        for (index,file) in files.enumerated() {
            progress("Cross Processing photo \(index+1)/8: \(file.lastPathComponent)")
            try autoreleasepool {
                guard var input=CIImage(contentsOf:file,options:[.applyOrientationProperty:true]) else {throw LabError.render}
                input=input.transformed(by:CGAffineTransform(translationX:-input.extent.minX,y:-input.extent.minY))
                let root="CrossProcessing/RealPhotos/"+file.deletingPathExtension().lastPathComponent
                try artifacts.png(input,root+"/Original.png")
                let centers=cpPriority(index)
                var sheet:[(String,CIImage)]=[("Original",input)]
                var crops:[(String,CIImage)]=centers.map{("Original · \($0.0)",cpCrop(input,x:$0.1,y:$0.2))}
                var selected:[String:CIImage]=[:]
                var c=LabCase(name:"CP_photo_"+file.deletingPathExtension().lastPathComponent)
                c.notes=["Manual aesthetic review only; no Golden Master.",
                         "Native 512 px crop centers: \(centers.map{"\($0.0)=(\($0.1),\($0.2))"}.joined(separator:", "))."]
                for title in titles {
                    let fx=cpPreset(title).validated
                    let output=try render(input,[fx])
                    let key=cpKey(title),path=root+"/"+key
                    try artifacts.png(output,path+".png")
                    try artifacts.png(artifacts.difference(input,output,gain:6),path+"_difference_x6.png")
                    try artifacts.json(fx,path+"_settings.json")
                    let a=normalized(input,to:512),b=normalized(output,to:512),m=gpu.compare(a,b)
                    c.metrics[key+"-meanLuminanceChange"]=m.residual.mean
                    c.metrics[key+"-chromaticityDrift"]=m.chromaticityMAE
                    c.metrics[key+"-newChannelClippingFraction"]=Double(max(0,m.whiteOutput-m.whiteInput))/Double(max(1,m.input.count))
                    c.metrics[key+"-nonFinitePixels"]=Double(m.nonFinite)
                    c.check("Finite \(title)",m.nonFinite==0,hard:true,"512 px RGBAf photographic sample.")
                    sheet.append((title,output));selected[title]=output
                    for (label,x,y) in centers {crops.append(("\(title) · \(label)",cpCrop(output,x:x,y:y)))}
                }
                let contact=root+"/CrossProcessing_contact_sheet.png"
                let native=root+"/CrossProcessing_crops_100percent.png"
                try artifacts.sheet(sheet,contact,cell:960,maxColumns:3)
                try artifacts.sheet(crops,native,nativeCrop:true,cell:512,maxColumns:4)
                c.images=[contact,native]
                if index < 2 {
                    let point=centers[0]
                    let subset=["Subtle Cross","Warm Process","Cool Process","Cyan Shadows","Vintage Process","Strong Cross"]
                    let items:[(String,CIImage)]=[("Original",input)]+subset.compactMap{title in
                        selected[title].map{(title,$0)}
                    }
                    let portrait=root+"/portrait_cross_processing.png"
                    try artifacts.sheet(items.map{($0.0,cpCrop($0.1,x:point.1,y:point.2))},
                                        portrait,nativeCrop:true,cell:512,maxColumns:4)
                    c.images.append(portrait)
                }
                cases.append(c)
            }
        }
    }
    private func cpReport() throws {
        let selected=cases.filter{$0.name.hasPrefix("CP_")}
        try artifacts.json(selected,"CrossProcessing/metrics.json")
        let counts=Dictionary(grouping:selected,by:\.status).mapValues(\.count)
        let lines=selected.map{c in
            "| \(c.name) | \(c.status) | \(c.checks.filter{$0.hard && $0.status == "FAIL"}.count) | \(c.checks.filter{$0.status == "WARN"}.count) | \(c.metrics.keys.sorted().map{"\($0)=\(String(format:"%.5g",c.metrics[$0]!))"}.joined(separator:"; ")) | \(c.images.map{"[image](\($0))"}.joined(separator:" ")) |"
        }.joined(separator:"\n")
        let report="""
        # Cross Processing — validation

        `CreativeEffectKind.crossProcessing` uses the production ordered Creative stack, existing mask/opacity compositor and RenderEngine preview/HQ/export. No existing Creative effect algorithm was changed. The effect uses one pointwise Metal kernel in extended-linear sRGB; no 3D LUT or external film curve is used. No Golden Master was created.

        Seven original styles select distinct analytic R/G/B curve coefficients. For `0≤x≤1` each channel uses `x + a·x(1−x) + (b+0.20·Contrast)·x(1−x)(2x−1)` plus smooth luminance-weighted shadow/highlight opponent-color shaping and optional Black Lift. Style Strength scales all deviations from identity; Amount blends final output with input. For negative RGB and HDR above 1, a tangent-matched linear continuation avoids early clamp and a derivative break. Saturation is radial around Rec.709 linear luminance `Y=0.2126R+0.7152G+0.0722B`, preserving the processed hue direction and luminance. Black Lift is zero unless selected; no grain is generated.

        **Hard checks**: exact Amount/Style-Strength identity, 4096-sample channel monotonicity and continuity, HDR finiteness/headroom, black floor at lift zero, preset/Custom/Undo/Redo/persistence, masks, stack order, preview invalidation. **Heuristics**: skin plausibility for moderate styles, banding, style diversity, resolution and preview/export agreement. `PASS` does not approve photographic quality; `WARN` requests manual review. Counts: PASS \(counts["PASS"] ?? 0), WARN \(counts["WARN"] ?? 0), FAIL \(counts["FAIL"] ?? 0).

        [Test chart](CrossProcessing/CrossProcessingTestChart.png), [gray ramp styles](CrossProcessing/gray_ramp_styles.png), [banding stress](CrossProcessing/banding_stress_test.png), [HDR curves](CrossProcessing/hdr_curves.png), [black lift](CrossProcessing/black_lift_comparison.png), [style distances](CrossProcessing/preset_distance_matrix.png), [simple grade comparison](CrossProcessing/cross_vs_simple_grade.png), [masks](CrossProcessing/mask_comparison.png).

        See [preset diversity](CrossProcessingPresetDiversity.md) and [simple grade analysis](CrossProcessing_vs_simple_grade.md). Eight real photographs have Original and all seven styles, full contact sheets, native 100% crops, difference maps and exact settings JSON. Two portrait sheets support skin/lips/eyes inspection. Their metrics are descriptive and never automatically judge the look.

        | Case | Status | Hard failures | Warnings | Metrics | Artifacts |
        |---|---|---:|---:|---|---|
        \(lines)
        """
        try report.write(to:artifacts.url("CrossProcessingValidationReport.md"),atomically:true,encoding:.utf8)
    }
}

extension LumoraVisualTestLab {
    private func cpMasksAndStack(_ chart:CrossProcessingTestChart) throws {
        progress("Cross Processing existing masks and effect order")
        let source=normalized(chart.image,to:1024),fx=cpPreset("Strong Cross")
        var radial=RadialGradientMask();radial.center=MaskPoint(x:0.35,y:0.5)
        radial.radiusX=0.19;radial.radiusY=0.19;radial.feather=4
        let mask=LocalMask(name:"Cross region",components:[MaskComponent(shape:.radial(radial))])
        var targeted=fx;targeted.maskID=mask.id
        let simple=try render(source,[targeted],masks:[mask])
        var inverse=mask;inverse.inverted=true
        let inverted=try render(source,[targeted],masks:[inverse])
        var radial2=radial;radial2.center=MaskPoint(x:0.75,y:0.5)
        let secondMask=LocalMask(name:"Second",components:[MaskComponent(shape:.radial(radial2))])
        var second=fx;second.maskID=secondMask.id
        let stacked=try render(source,[targeted,second],masks:[mask,secondMask])
        var hole=radial;hole.radiusX=0.055;hole.radiusY=0.055;hole.feather=0
        let subtraction=LocalMask(name:"Cross minus center",components:[
            MaskComponent(operation:.add,shape:.radial(radial)),
            MaskComponent(operation:.subtract,shape:.radial(hole))])
        var cutFX=fx;cutFX.maskID=subtraction.id
        let cut=try render(source,[cutFX],masks:[subtraction])
        let outside=CGRect(x:10,y:10,width:64,height:64)
        let center=CGRect(x:344,y:496,width:24,height:24)
        let secondCenter=CGRect(x:756,y:496,width:24,height:24)
        var c=LabCase(name:"CP_masks")
        c.metrics=["simpleOutsideMaxError":gpu.compare(source,simple,region:outside).maxError,
                   "invertedCenterMaxError":gpu.compare(source,inverted,region:center).maxError,
                   "stackedOutsideMaxError":gpu.compare(source,stacked,region:outside).maxError,
                   "subtractiveCenterMaxError":gpu.compare(source,cut,region:center).maxError,
                   "simpleCenterMAE":gpu.compare(source,simple,region:center).mae,
                   "stackedSecondMAE":gpu.compare(source,stacked,region:secondCenter).mae]
        for key in ["simpleOutsideMaxError","invertedCenterMaxError",
                    "stackedOutsideMaxError","subtractiveCenterMaxError"] {
            c.check("Mask isolation \(key)",c.metrics[key]!<2e-6,hard:true,
                    "No changes outside the composed existing mask.")
        }
        c.check("Masked regions respond",c.metrics["simpleCenterMAE"]!>1e-6 &&
                c.metrics["stackedSecondMAE"]!>1e-6,hard:true,"Both selected regions change.")
        c.images=["CrossProcessing/mask_comparison.png"]
        try artifacts.sheet([("Original",source),("Simple",simple),("Inverted",inverted),
                             ("Stacked",stacked),("Subtractive",cut)],c.images[0],cell:512,maxColumns:3)
        cases.append(c)
        let others:[(String,CreativeEffect)]=[
            ("Film Grain",effect(.grain,["amount":60,"size":40,"chromaAmount":0])),
            ("Bleach Bypass",CreativeFXPreset.all(for:.bleachBypass).first{$0.title=="Classic Bypass"}!.makeEffect()),
            ("Glamour Glow",CreativeFXPreset.all(for:.glamourGlow).first{$0.title=="Portrait Glow"}!.makeEffect()),
            ("Pro Contrast",CreativeFXPreset.all(for:.proContrast).first{$0.title=="Natural Contrast"}!.makeEffect()),
            ("Tonal Contrast",CreativeFXPreset.all(for:.tonalContrast).first{$0.title=="Natural Texture"}!.makeEffect())]
        for (name,other) in others {
            let forward=try render(source,[fx,other]),reverse=try render(source,[other,fx])
            let m=gpu.compare(forward,reverse)
            var order=LabCase(name:"CP_stack_"+cpKey(name))
            order.metrics=["forwardReverseMAE":m.mae,"nonFinitePixels":Double(m.nonFinite)]
            order.check("Order differs",m.mae>1e-7,hard:true,"The production ordered Creative stack is noncommutative.")
            order.check("Finite",m.nonFinite==0,hard:true,"RGBAf output.")
            let path="CrossProcessing/stack_"+cpKey(name)+".png"
            try artifacts.sheet([("Cross → \(name)",forward),("\(name) → Cross",reverse),
                                 ("Difference ×8",artifacts.difference(forward,reverse,gain:8))],
                                path,cell:512,maxColumns:3)
            order.images=[path];cases.append(order)
        }
    }
    private func cpPerformance() throws {
        progress("Cross Processing 1024/2048/4096 render timing")
        var c=LabCase(name:"CP_resolution_performance")
        var reference:CIImage?
        for dimension in [1024,2048,4096] {
            try autoreleasepool {
                let input=SyntheticCharts.make(size:dimension){x,y in
                    let t=Float(0.12+0.78*(x+0.35*y)/1.35)
                    return SIMD3(t*0.92,t*0.76,t*0.66)
                }
                let start=ProcessInfo.processInfo.systemUptime
                let output=try render(input,[cpPreset("Warm Process")])
                let sample=normalized(output,to:512)
                let m=gpu.compare(normalized(input,to:512),sample)
                c.metrics["\(dimension)-milliseconds"]=(ProcessInfo.processInfo.systemUptime-start)*1000
                c.metrics["\(dimension)-nonFinitePixels"]=Double(m.nonFinite)
                c.check("Finite \(dimension)",m.nonFinite==0,hard:true,"Render and materialize at requested resolution.")
                if let reference {
                    let agreement=gpu.compare(reference,sample)
                    c.metrics["\(dimension)-normalizedRMSE"]=agreement.rmse
                    c.check("Resolution agreement \(dimension)",agreement.rmse<0.015,
                            "Quality heuristic after resizing outputs to 512 pixels.")
                } else {reference=sample}
                try artifacts.png(sample,"CrossProcessing/resolution_\(dimension).png")
            }
        }
        cases.append(c)
    }
    private func cpPipeline(_ chart:CrossProcessingTestChart) async throws {
        progress("Cross Processing interactive, HQ and export")
        let source=normalized(chart.image,to:2048)
        let path=try artifacts.url("CrossProcessing/Pipeline/source.png")
        try artifacts.png(source,"CrossProcessing/Pipeline/source.png")
        let engine=RenderEngine()
        var state=EditState();state.creative.effects=[cpPreset("Warm Process")]
        var c=LabCase(name:"CP_preview_HQ_export")
        var images:[(String,CIImage)]=[]
        for quality in [PreviewQuality.interactive,.high] {
            let result=try await engine.render(url:path,state:state,quality:quality)
            let name=quality == .interactive ? "interactive":"HQ"
            c.metrics[name+"-milliseconds"]=result.milliseconds
            c.metrics[name+"-width"]=Double(result.image.width)
            images.append((name,CIImage(cgImage:result.image)))
        }
        let repeated=try await engine.render(url:path,state:state,quality:.interactive)
        c.check("Preview cache hit",repeated.cacheHit,hard:true,"Production RenderEngine cache.")
        state.creative.effects[0]["styleStrength"]=100
        let changed=try await engine.render(url:path,state:state,quality:.interactive)
        let changedImage=CIImage(cgImage:changed.image)
        c.metrics["parameterChangeMAE"]=gpu.compare(images[0].1,changedImage).mae
        c.check("Slider updates preview",c.metrics["parameterChangeMAE"]!>1e-6,hard:true,
                "A changed style strength invalidates the preview.")
        var settings=ExportSettings();settings.format = .png
        settings.colorSpace = .displayP3;settings.includeMetadata = false
        let exported=try await engine.export(request:ExportRequest(sourceURL:path,state:state,name:"cross-processing-lab"),
                                             settings:settings,directory:artifacts.url("CrossProcessing/Pipeline/Export"))
        guard let exportImage=CIImage(contentsOf:exported.url) else {throw LabError.render}
        c.metrics["exportWidth"]=Double(exported.width)
        c.metrics["previewExportSSIM"]=gpu.compare(normalized(changedImage,to:512),
                                                     normalized(exportImage,to:512)).ssim
        c.check("Preview/export agreement",c.metrics["previewExportSSIM"]!>0.90,
                "Quality heuristic after display conversion and resizing.")
        images += [("Changed preview",changedImage),("Export",exportImage)]
        c.images=["CrossProcessing/Pipeline/comparison.png"]
        try artifacts.sheet(images,c.images[0],cell:512)
        cases.append(c)
    }
}

extension LumoraVisualTestLab {
    private func cpBandingHDRAndLift(_ chart:CrossProcessingTestChart) throws {
        progress("Cross Processing banding, HDR, black lift and tonal separation")
        let gradients:[(String,(Double)->SIMD3<Float>)]=[
            ("gray",{SIMD3(repeating:Float($0))}),
            ("blue_sky",{let x=Float($0);return SIMD3(0.22+0.35*x,0.38+0.35*x,0.64+0.35*x)}),
            ("warm_skin",{let x=Float($0);return SIMD3(0.28+0.40*x,0.16+0.28*x,0.11+0.21*x)})]
        var bandImages:[(String,CIImage)]=[]
        for (name,make) in gradients {
            let source=SyntheticCharts.make(size:4096){x,_ in make(x)}
            bandImages.append((name+" original",source))
            for title in ["Subtle Cross","Vintage Process","Strong Cross"] {
                let output=try render(source,[cpPreset(title)])
                let pixels=gpu.read(output,CGRect(x:0,y:2048,width:4096,height:1))
                var result=LabCase(name:"CP_banding_"+name+"_"+cpKey(title))
                for channel in 0..<3 {
                    let values=(0..<4096).map{Double(pixels[$0*4+channel])}
                    let steps=zip(values.dropFirst(),values).map{$0-$1}
                    let unique=Set(values.map{Int(($0*65535).rounded())}).count
                    result.metrics["channel\(channel)-distinct16bitLevels"]=Double(unique)
                    result.metrics["channel\(channel)-maxStep"]=steps.map(abs).max() ?? 0
                    result.metrics["channel\(channel)-reversals"]=Double(steps.filter{$0 < -1e-6}.count)
                    result.check("No false contour \(channel)",unique>1000 && (steps.map(abs).max() ?? 0)<0.004,
                                 "Quality heuristic on a 4096-column linear RGBAf ramp.")
                }
                result.check("Finite",gpu.compare(source,output,region:CGRect(x:0,y:2048,width:4096,height:1)).nonFinite==0,
                             hard:true,"No invalid gradient values.")
                cases.append(result)
                bandImages.append((name+" "+title,output))
            }
        }
        try artifacts.sheet(bandImages,"CrossProcessing/banding_stress_test.png",cell:512,maxColumns:4)
        let hdr=SyntheticCharts.make(size:4096){x,_ in SIMD3(repeating:Float(4*x))}
        var curves:[(String,[Double])]=[("Identity",(0..<4096).map{4*Double($0)/4095})]
        for title in ["Subtle Cross","Vintage Process","Strong Cross"] {
            let output=try render(hdr,[cpPreset(title)])
            let pixels=gpu.read(output,CGRect(x:0,y:2048,width:4096,height:1))
            var c=LabCase(name:"CP_HDR_"+cpKey(title))
            for ch in 0..<3 {
                let values=(0..<4096).map{Double(pixels[$0*4+ch])}
                let reversals=zip(values.dropFirst(),values).filter{$0-$1 < -1e-6}.count
                c.metrics["channel\(ch)-reversals"]=Double(reversals)
                c.metrics["channel\(ch)-maximum"]=values.last ?? 0
                c.check("HDR monotone \(ch)",reversals==0,hard:true,"0–4 extended linear channel ramp.")
                c.check("HDR retained \(ch)",(values.last ?? 0)>2,hard:true,"No clamp to SDR white.")
                if ch==0 {curves.append((title,values))}
            }
            c.check("Finite",gpu.compare(hdr,output,region:CGRect(x:0,y:2048,width:4096,height:1)).nonFinite==0,
                    hard:true,"HDR output remains finite.")
            cases.append(c)
        }
        try artifacts.plot(curves,"CrossProcessing/hdr_curves.png",title:"Extended-linear HDR response",xMaximum:4)
        let negative=SyntheticCharts.make(size:256){x,_ in
            let v=Float(-0.03+0.15*x);return SIMD3(v,v*0.7,v*1.2)
        }
        let negativeOutput=try render(negative,[cpPreset("Strong Cross")])
        let neg=gpu.compare(negative,negativeOutput)
        var nc=LabCase(name:"CP_negative_RGB")
        nc.metrics=["nonFinitePixels":Double(neg.nonFinite),"maxRGBError":neg.maxError]
        nc.check("Finite negative continuation",neg.nonFinite==0,hard:true,
                 "Per-channel tangent continuation below zero, without sign division.")
        cases.append(nc)
        let black=SyntheticCharts.make(size:1024){x,y in
            if y<0.25 {return SIMD3(repeating:0)}
            if y<0.50 {return SIMD3(repeating:Float(x*0.09))}
            if y<0.75 {return SIMD3(Float(x*0.13),Float(x*0.07),Float(x*0.04))}
            return SIMD3(Float(x*0.04),Float(x*0.08),Float(x*0.12))
        }
        var liftImages:[(String,CIImage)]=[("Original",black)]
        for value in [0.0,12.0,28.0,55.0] {
            var fx=cpPreset("Vintage Process");fx["blackLift"]=value
            let output=try render(black,[fx])
            let before=cpSample(black,CGRect(x:0,y:800,width:1024,height:220))
            let after=cpSample(output,CGRect(x:0,y:800,width:1024,height:220))
            var c=LabCase(name:"CP_black_lift_\(Int(value))")
            c.metrics=["inputBlack":before.x,"outputBlackR":after.x,
                       "outputBlackG":after.y,"outputBlackB":after.z]
            c.check("Black floor",value>0 || abs(after.x)<2e-6,hard:true,
                    "With Black Lift zero, the curve and chromatic shaping keep black at zero.")
            c.check("Lift direction",value==0 || after.x>0,hard:true,"Raised black floor.")
            cases.append(c);liftImages.append(("Lift \(Int(value))",output))
        }
        try artifacts.sheet(liftImages,"CrossProcessing/black_lift_comparison.png",cell:512,maxColumns:3)
        let cyan=try render(chart.image,[cpPreset("Cyan Shadows")])
        var separation=LabCase(name:"CP_shadow_highlight_separation")
        for (key,y) in [("shadow",0.12),("midtone",0.50),("highlight",0.85)] {
            let swatch=SyntheticCharts.gray(y,size:64)
            let output=try render(swatch,[cpPreset("Cyan Shadows")])
            let rgb=cpSample(output,output.extent)
            separation.metrics[key+"-chroma"]=cpChroma(rgb)
            separation.metrics[key+"-redBlueDifference"]=rgb.x-rgb.z
        }
        separation.check("Cyan shadows distinct",separation.metrics["shadow-redBlueDifference"]! <
                         separation.metrics["highlight-redBlueDifference"]!,hard:true,
                         "Dark and bright neutral swatches receive different chromatic responses.")
        separation.check("Cyan shadow bias",separation.metrics["shadow-chroma"]! >
                         separation.metrics["midtone-chroma"]!,hard:true,
                         "The cyan cast is stronger in shadows than in neutral midtones.")
        cases.append(separation)
        try artifacts.sheet([("Original",chart.image),("Cyan Shadows",cyan)],
                            "CrossProcessing/shadow_highlight_separation.png",cell:768,maxColumns:2)
    }
    private func cpDiversityAndGrade(_ chart:CrossProcessingTestChart) throws {
        progress("Cross Processing style distances and simple grading baseline")
        let presets=CreativeFXPreset.all(for:.crossProcessing)
        let source=SyntheticCharts.make(size:256){x,y in
            let band=min(3,Int(y*4))
            let t=Float(x)
            switch band {
            case 0:return SIMD3(repeating:t)
            case 1:return SIMD3(t*0.9,t*0.55,t*0.33)
            case 2:return SIMD3(t*0.24,t*0.60,t*0.85)
            default:return SIMD3(t*0.78,t*0.80,t*0.18)
            }
        }
        let outputs=try presets.map{try render(source,[$0.makeEffect()])}
        var rows:[[Double]]=[]
        var md="# Cross Processing — preset diversity\n\nMean absolute linear RGB distance on a synthetic four-band color cube. Non-subtle pairs below 0.006 are WARN; no style is auto-adjusted.\n\n| Style | "+presets.map{$0.title}.joined(separator:" | ")+" |\n|---|"+Array(repeating:"---:",count:presets.count).joined(separator:"|")+"|\n"
        for i in presets.indices {
            let distances=presets.indices.map{gpu.compare(outputs[i],outputs[$0]).mae}
            rows.append(distances)
            md+="| \(presets[i].title) | "+distances.map{String(format:"%.5f",$0)}.joined(separator:" | ")+" |\n"
            var c=LabCase(name:"CP_diversity_"+cpKey(presets[i].title))
            for j in 0..<i where i>0 && j>0 {
                c.metrics["distanceTo_"+cpKey(presets[j].title)]=distances[j]
                c.check("Distinct from \(presets[j].title)",distances[j]>=0.006,
                        "Near-identical non-subtle styles require manual review; preset values are unchanged.")
            }
            cases.append(c)
        }
        try md.write(to:artifacts.url("CrossProcessingPresetDiversity.md"),atomically:true,encoding:.utf8)
        try artifacts.plot(rows.enumerated().map{(presets[$0.offset].title,$0.element)},
                           "CrossProcessing/preset_distance_matrix.png",title:"Style distance matrix",xMaximum:Double(presets.count-1))
        let warm=try render(chart.image,[cpPreset("Warm Process")])
        // Deliberately simple constant temperature/tint gains, linear saturation
        // and fixed contrast. It is a diagnostic baseline, not a Creative FX.
        let baseline=chart.image.applyingFilter("CIColorMatrix",parameters:[
            "inputRVector":CIVector(x:1.055,y:0,z:0,w:0),
            "inputGVector":CIVector(x:0,y:1.005,z:0,w:0),
            "inputBVector":CIVector(x:0,y:0,z:0.95,w:0)])
            .applyingFilter("CIColorControls",parameters:[kCIInputSaturationKey:1.025,
                                                          kCIInputContrastKey:1.045])
            .cropped(to:chart.image.extent)
        let comparison=gpu.compare(warm,baseline)
        var c=LabCase(name:"CP_vs_simple_grade")
        c.metrics=["MAE":comparison.mae,"RMSE":comparison.rmse,"SSIM":comparison.ssim,
                   "nonFinitePixels":Double(comparison.nonFinite)]
        c.check("Curves differ from constant grade",comparison.mae>0.001,hard:true,
                "A temperature/tint/saturation/contrast grade cannot reproduce channel-specific tone response.")
        c.images=["CrossProcessing/cross_vs_simple_grade.png"]
        try artifacts.sheet([("Original",chart.image),("Warm Process",warm),("Simple grade",baseline),
                             ("Difference ×6",artifacts.difference(warm,baseline,gain:6))],
                            c.images[0],cell:768,maxColumns:2)
        cases.append(c)
        let note="""
        # Cross Processing vs simple color grading

        Baseline: constant linear RGB gains (R 1.055, G 1.005, B 0.950), followed by Core Image saturation 1.025 and contrast 1.045. These settings approximately warm the chart. Cross Processing instead uses three different analytic tone curves and luminance-dependent shadow/highlight chromatic shaping. The measured MAE is \(String(format:"%.6f",comparison.mae)) in the linear chart; this diagnostic does not imply either result is aesthetically superior.

        [Visual comparison](CrossProcessing/cross_vs_simple_grade.png)
        """
        try note.write(to:artifacts.url("CrossProcessing_vs_simple_grade.md"),atomically:true,encoding:.utf8)
    }
}
