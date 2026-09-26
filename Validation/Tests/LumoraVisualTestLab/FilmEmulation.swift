import Foundation
import CoreImage
@testable import LumoraCore

struct FilmEmulationTestChart {
    let image:CIImage
    let regions:[ChartRegion]
    static let names=["gray-ramp","log-exposure-ramp","near-black-ramp","midtone-ramp",
                      "highlight-ramp","hdr-ramp","red-ramp","green-ramp",
                      "blue-ramp","color-patches","light-skin","dark-skin",
                      "pastels","saturated-colors","frequency","sky-gradient"]
    static func generate(size:Int)->Self {
        let image=SyntheticCharts.make(size:size){x,y in
            let col=min(3,Int(x*4)),row=min(3,Int(y*4)),i=row*4+col
            let u=x*4-Double(col),v=y*4-Double(row),t=Float(u)
            switch i {
            case 0:return SIMD3(repeating:t)
            case 1:return SIMD3(repeating:Float(pow(2,-8+14*u)*0.18))
            case 2:return SIMD3(repeating:Float(u*0.12))
            case 3:return SIMD3(repeating:Float(0.18+0.55*u))
            case 4:return SIMD3(repeating:Float(0.62+0.38*u))
            case 5:return SIMD3(repeating:Float(4*u))
            case 6:return SIMD3(t,0,0)
            case 7:return SIMD3(0,t,0)
            case 8:return SIMD3(0,0,t)
            case 9:
                let colors:[SIMD3<Float>]=[.init(0.8,0.08,0.06),.init(0.06,0.75,0.06),
                    .init(0.08,0.10,0.85),.init(0.07,0.75,0.80),.init(0.75,0.07,0.75),
                    .init(0.80,0.74,0.06)]
                return colors[min(5,Int(u*3)+3*Int(v*2))]
            case 10:return .init(0.59,0.35,0.24)
            case 11:return .init(0.28,0.15,0.10)
            case 12:return .init(0.56+0.27*t,0.51+0.31*t,0.48+0.36*t)
            case 13:return .init(0.20+0.70*t,0.07+0.20*t,0.67-0.53*t)
            case 14:
                let wave=sin(2*Double.pi*8*u)+sin(2*Double.pi*32*u)
                    + sin(2*Double.pi*96*u)+sin(2*Double.pi*192*u)
                let signal=Float(0.45+0.012*wave)
                return SIMD3(repeating:signal)
            default:return .init(0.22+0.32*t,0.38+0.35*t,0.62+0.34*t)
            }
        }
        let cell=size/4
        let regions=names.enumerated().map{i,name in
            ChartRegion(name:name,x:(i%4)*cell,y:size-(i/4+1)*cell,width:cell,height:cell,
                        ramp:name.contains("ramp") || name.contains("gradient"))
        }
        return Self(image:image,regions:regions)
    }
    func rect(_ name:String)->CGRect{regions.first{$0.name==name}!.rect}
}

extension LumoraVisualTestLab {
    private func filmPreset(_ title:String)->CreativeEffect {
        CreativeFXPreset.all(for:.filmEmulation).first{$0.title==title}!.makeEffect()
    }
    private func filmKey(_ title:String)->String {
        title.lowercased().replacingOccurrences(of:" ",with:"_")
    }
    private func filmRamp(width:Int=8192,_ make:(Double)->SIMD3<Float>)->CIImage {
        var data=Data(count:width*16)
        data.withUnsafeMutableBytes{raw in
            let p=raw.bindMemory(to:Float.self)
            for x in 0..<width {
                let c=make((Double(x)+0.5)/Double(width)),i=x*4
                p[i]=c.x;p[i+1]=c.y;p[i+2]=c.z;p[i+3]=1
            }
        }
        return CIImage(bitmapData:data,bytesPerRow:width*16,size:CGSize(width:width,height:1),
                       format:.RGBAf,colorSpace:SyntheticCharts.linearSpace)
    }
    private func filmSample(_ image:CIImage,_ rect:CGRect)->SIMD3<Double> {
        let bounds=CGRect(x:floor(rect.midX-4),y:floor(rect.midY-4),width:8,height:8)
        let p=gpu.read(image,bounds)
        var sum=SIMD3<Double>(repeating:0)
        for i in stride(from:0,to:p.count,by:4) {sum+=SIMD3(Double(p[i]),Double(p[i+1]),Double(p[i+2]))}
        return sum/Double(max(1,p.count/4))
    }
    private func filmY(_ rgb:SIMD3<Double>)->Double{rgb.x*0.2126+rgb.y*0.7152+rgb.z*0.0722}
    private func filmChroma(_ rgb:SIMD3<Double>)->Double{max(rgb.x,rgb.y,rgb.z)-min(rgb.x,rgb.y,rgb.z)}
    private func filmHue(_ rgb:SIMD3<Double>)->Double{atan2(sqrt(3)*(rgb.y-rgb.z),2*rgb.x-rgb.y-rgb.z)}
    private func filmHueShift(_ a:SIMD3<Double>,_ b:SIMD3<Double>)->Double {
        let d=abs(filmHue(a)-filmHue(b));return min(d,2*Double.pi-d)
    }
    private func filmMetric(_ before:SIMD3<Double>,_ after:SIMD3<Double>,_ key:String,_ c:inout LabCase) {
        c.metrics[key+"-inputY"]=filmY(before);c.metrics[key+"-outputY"]=filmY(after)
        c.metrics[key+"-inputChroma"]=filmChroma(before);c.metrics[key+"-outputChroma"]=filmChroma(after)
        c.metrics[key+"-chromaRatio"]=filmChroma(after)/max(1e-6,filmChroma(before))
        c.metrics[key+"-hueShift"]=filmHueShift(before,after)
    }
    func runFilmEmulation() async throws {
        progress("Film Emulation test chart and 8192-point curves")
        let chart=FilmEmulationTestChart.generate(size:2048)
        try artifacts.png(chart.image,"FilmEmulation/FilmEmulationTestChart.png")
        try artifacts.json(chart.regions,"FilmEmulation/chart_regions.json")
        do {
            try filmIdentityHistory(chart)
            try filmCurves(chart)
            try filmLatitudeExposure(chart)
            try filmColorAndSkin(chart)
            try filmBandingFrequency(chart)
            try filmDecompositionAndDiversity(chart)
            try filmComparisons(chart)
            try filmMasksAndStack(chart)
            try filmPerformance()
            try await filmPipeline(chart)
            try filmPhotos()
        } catch {
            var c=LabCase(name:"FE_harness")
            c.check("Completed",false,hard:true,String(describing:error));cases.append(c)
            try filmReport();throw error
        }
        try filmReport()
    }
    private func filmIdentityHistory(_ chart:FilmEmulationTestChart) throws {
        for (name,settings) in [("amount_zero",["amount":0.0]),
                                ("strength_zero",["filmStrength":0.0])] {
            let output=try render(chart.image,[effect(.filmEmulation,settings)])
            let m=gpu.compare(chart.image,output)
            var c=LabCase(name:"FE_identity_"+name)
            c.metrics=["maxRGBError":m.maxError,"meanRGBError":m.mae,"nonFinitePixels":Double(m.nonFinite)]
            c.check("Strict identity",m.maxError==0,hard:true,"Zero-value bypass of the production kernel.")
            c.check("Finite",m.nonFinite==0,hard:true,"No NaN/Inf.")
            cases.append(c)
        }
        let warm=CreativeFXPreset.all(for:.filmEmulation).first{$0.title=="Warm Portrait"}!
        var selected=CreativeEffect(.filmEmulation,maskID:UUID())
        let id=selected.id,mask=selected.maskID
        selected=warm.applying(to:selected)
        let matched=CreativeFXPreset.matching(selected)?.title=="Warm Portrait"
        var custom=selected;custom["highlightRollOff"]+=1
        let customState=CreativeFXPreset.matching(custom)==nil
        custom["highlightRollOff"]-=1
        let rematched=CreativeFXPreset.matching(custom)?.title=="Warm Portrait"
        var initial=EditState();initial.creative.effects=[selected]
        var exposed=initial;exposed.creative.effects[0]["exposure"]=1
        var strengthened=exposed;strengthened.creative.effects[0]["filmStrength"]=95
        var changed=strengthened;changed.creative.effects[0]=CreativeFXPreset.all(for:.filmEmulation)
            .first{$0.title=="Dense Slide"}!.applying(to:changed.creative.effects[0])
        var history=HistoryManager()
        history.begin("Exposure",state:initial);history.commit(exposed)
        history.begin("Film Strength",state:exposed);history.commit(strengthened)
        history.begin("Film Type",state:strengthened);history.commit(changed)
        let undo1=history.undo(),undo2=history.undo(),redo=history.redo()
        let persisted=try JSONDecoder().decode(EditState.self,from:JSONEncoder().encode(changed))
        var c=LabCase(name:"FE_preset_history")
        c.check("Preset/Custom/rematch",matched && customState && rematched,hard:true,
                "Shared parameter-snapshot matcher; exact return restores the preset label.")
        c.check("Identity and mask",selected.id==id && selected.maskID==mask,hard:true,
                "Switching Film Type keeps the effect and target.")
        c.check("Undo/Undo/Redo",undo1==strengthened && undo2==exposed && redo==strengthened,
                hard:true,"Exposure, strength and type use existing EditState history.")
        c.check("Persistence",persisted==changed,hard:true,"Codable document round trip.")
        cases.append(c)
    }
}

extension LumoraVisualTestLab {
    private func filmReport() throws {
        let selected=cases.filter{$0.name.hasPrefix("FE_")}
        try artifacts.json(selected,"FilmEmulation/metrics.json")
        let counts=Dictionary(grouping:selected,by:\.status).mapValues(\.count)
        let rows=selected.map{c in
            "| \(c.name) | \(c.status) | \(c.checks.filter{$0.hard && $0.status == "FAIL"}.count) | \(c.checks.filter{$0.status == "WARN"}.count) | \(c.metrics.keys.sorted().map{"\($0)=\(String(format:"%.5g",c.metrics[$0]!))"}.joined(separator:"; ")) | \(c.images.map{"[image](\($0))"}.joined(separator:" ")) |"
        }.joined(separator:"\n")
        let report="""
        # Film Emulation — validation

        `CreativeEffectKind.filmEmulation` uses the production ordered Creative stack, existing masks and opacity compositor, and RenderEngine preview/HQ/export. The algorithms of High/Low Key, Grain, Tonal Contrast, Detail Extractor, Glamour Glow, Bleach Bypass, Pro Contrast and Cross Processing are unchanged. The response is a parametric pointwise Metal kernel; it does not add grain, halation, blur, vignette, face processing, sharpening or geometry changes. No commercial film profile or external LUT is used, and no Golden Master was created.

        ## Response model

        Exposure is multiplied into linear RGB as `x·2^EV` before film response. For each channel, the nonnegative exposure coordinate is `z=log2(1+x/q)`, `q=0.03`. It is finite at zero and keeps small signals resolvable. The characteristic response is

        `g(z)=m·z + t·wt·[softplus((zt−z)/wt)−softplus(zt/wt)] − h·wh·[softplus((z−zh)/wh)−softplus(−zh/wh)]`,

        `F(x)=q·[2^g(z)−1]·[0.18/Fraw(0.18)]`, where `m` is midtone slope, `t` toe compression, `h` shoulder compression, and the last factor anchors middle gray. All terms are smooth. The derivative in log exposure is `m−t·sigmoid((zt−z)/wt)−h·sigmoid((z−zh)/wh)`; preset coefficients keep it positive through the tested range. Film Strength interpolates toe, shoulder and slope from the identity response; user Contrast changes `m`, Shadow Density changes `t`, and Highlight Roll-Off changes `h`. Faded Negative permits a small negative toe term to soften the lower response while retaining positive slope.

        Output above linear 1 is evaluated by the same analytic formula, so there is no SDR splice or premature clamp. Negative extended RGB is extrapolated with the analytic tangent at zero, avoiding logarithms of negative values. Per-channel slope/zone coefficients create small R/G/B differences. A diagonally dominant, row-sum-one matrix applies bounded layer crosstalk. Color Response scales channel asymmetry, crosstalk and luminance-dependent saturation together. Saturation is radial around Rec.709 linear luminance, with smooth shadow/midtone/highlight weights; the processed hue direction and luminance are preserved by this step. Lumora retains extended linear values in the renderer. The PNG contact sheets are display conversions; clipping/gamut measurements use RGBAf before display conversion, and the renderer does not silently clamp to SDR. Any modest negative excursions remain available to the existing downstream gamut/output path.

        Seven original types: Neutral Negative, Warm Portrait, Vivid Chrome, Muted Cinema, Faded Negative, Vintage Color, Dense Slide. Presets are complete parameter snapshots; editing them shows Custom while preserving effect ID, mask and stack position. The seven `FilmResponseParameters` values are immutable and fixed-size. There is no derived LUT, persistent texture allocation, unbounded cache or face/texture analysis. The 28-switch stale-state test is not a substitute for an on-device resident-memory and thermal trace.

        **Hard invariants:** strict Amount/Film Strength identity (at neutral controls), 8192-point monotonicity and continuity, finite negative/HDR response, deterministic uniform patches, no artificial spatial-frequency preference, mask isolation, stack ordering, preset/Custom/Undo/Redo/persistence and preview cache invalidation. **Quality heuristics:** film diversity, latitude tendency, skin plausibility, banding, clipping, resolution agreement, photographic appearance and preview/export similarity. `PASS` is not aesthetic approval. `WARN` requests manual review; `FAIL` marks a broken hard invariant. Counts: PASS \(counts["PASS"] ?? 0), WARN \(counts["WARN"] ?? 0), FAIL \(counts["FAIL"] ?? 0).

        [Synthetic chart](FilmEmulation/FilmEmulationTestChart.png), [all characteristic curves](FilmEmulation/all_characteristic_curves.png), [HDR](FilmEmulation/hdr_response.png), [latitude](FilmEmulation/latitude_comparison.png), [saturation by luminance](FilmEmulation/saturation_vs_luminance.png), [banding](FilmEmulation/banding_stress_test.png), [frequency response](FilmEmulation/frequency_response.png), [masks](FilmEmulation/mask_comparison.png), [preview/HQ/export](FilmEmulation/Pipeline/comparison.png).

        [Synthetic film diversity](FilmEmulationFilmDiversity.md), [photographic film diversity](FilmEmulationPhotoDiversity.md), [simple-grade analysis](FilmEmulation_vs_simple_grade.md). The [Film vs Cross comparison](FilmEmulation/film_vs_cross_processing.png) includes the same synthetic chart and portrait. Look decomposition sheets call stages of the production kernel. Eight source photographs remain unchanged; each has all seven films, a contact sheet, 100% crops, difference maps and exact JSON settings. A [global photo sheet](FilmEmulation/global_photo_contact_sheet.png) is an overview, not a substitute for native crops.

        | Case | Status | Hard failures | Warnings | Metrics | Artifacts |
        |---|---|---:|---:|---|---|
        \(rows)

        ## Priority manual inspection

        1. [Backlight latitude](FilmEmulation/RealPhotos/04_backlight/backlight_film_comparison.png)
        2. [White subject highlights](FilmEmulation/RealPhotos/07_white_subject/white_subject_film_comparison.png)
        3. [Light skin portrait](FilmEmulation/RealPhotos/01_portrait_light_skin/portrait_light_film_comparison.png)
        4. [Dark skin portrait](FilmEmulation/RealPhotos/02_portrait_dark_skin/portrait_dark_film_comparison.png)
        5. [All characteristic curves](FilmEmulation/all_characteristic_curves.png)
        6. [Saturation by luminance](FilmEmulation/saturation_vs_luminance.png)
        7. [Synthetic film distance matrix](FilmEmulation/film_distance_matrix.png)
        """
        try report.write(to:artifacts.url("FilmEmulationValidationReport.md"),atomically:true,encoding:.utf8)
    }
}

extension LumoraVisualTestLab {
    private func filmCrop(_ image:CIImage,x:Double,y:Double,side:Int=512)->CIImage {
        let s=min(CGFloat(side),image.extent.width,image.extent.height)
        let px=min(image.extent.maxX-s,max(image.extent.minX,image.extent.minX+image.extent.width*x-s/2))
        let py=min(image.extent.maxY-s,max(image.extent.minY,image.extent.minY+image.extent.height*y-s/2))
        return image.cropped(to:CGRect(x:floor(px),y:floor(py),width:s,height:s))
    }
    private func filmPhotoRegions(_ index:Int)->[(String,Double,Double)] {
        switch index {
        case 0:return [("skin",0.50,0.50),("eye",0.48,0.58),("hair",0.65,0.75),("bright background",0.77,0.72)]
        case 1:return [("skin",0.50,0.50),("skin highlight",0.56,0.58),("dark curls",0.48,0.78),("dark clothing",0.50,0.20)]
        case 2:return [("clouds",0.50,0.28),("sun",0.50,0.42),("blue sky",0.25,0.75),("green landscape",0.65,0.52),("ridge",0.50,0.57)]
        case 3:return [("sun",0.50,0.28),("hair",0.50,0.70),("face",0.45,0.54),("shoulder",0.61,0.43),("sea reflection",0.50,0.15)]
        case 4:return [("lamp",0.50,0.25),("dark sky",0.30,0.80),("stone",0.50,0.68),("wet pavement",0.50,0.17)]
        case 5:return [("dark interior",0.30,0.50),("sunlit wall",0.70,0.60),("wood table",0.55,0.26),("window",0.50,0.75)]
        case 6:return [("white dress",0.50,0.68),("white wall",0.25,0.63),("skin",0.50,0.52),("blue sky",0.75,0.80)]
        default:return [("skin",0.50,0.50),("hair",0.48,0.75),("fabric",0.50,0.35),("water",0.50,0.18)]
        }
    }
    private func filmPhotos() throws {
        let repo=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let folder=URL(fileURLWithPath:ProcessInfo.processInfo.environment["LUMORA_VISUAL_ASSETS"]
            ?? repo.appendingPathComponent("Validation/VisualTestAssets").path)
        let files=try FileManager.default.contentsOfDirectory(at:folder,includingPropertiesForKeys:nil)
            .filter{["png","jpg","jpeg","tif","tiff","heic"].contains($0.pathExtension.lowercased())}
            .sorted{$0.lastPathComponent<$1.lastPathComponent}
        guard files.count==8 else{throw NSError(domain:"FilmEmulationLab",code:1,
            userInfo:[NSLocalizedDescriptionKey:"Expected eight photos; found \(files.count) in \(folder.path)"])}
        let titles=CreativeFXPreset.all(for:.filmEmulation).map(\.title)
        let comparisonNames=["portrait_light_film_comparison.png","portrait_dark_film_comparison.png",
                             "landscape_film_comparison.png","backlight_film_comparison.png",
                             "night_film_comparison.png","indoor_film_comparison.png",
                             "white_subject_film_comparison.png","fine_texture_film_comparison.png"]
        var global:[(String,CIImage)]=[]
        var distances=Array(repeating:Array(repeating:0.0,count:titles.count),count:titles.count)
        var dense:[(String,CIImage)]=[],warmScenes:[(String,CIImage)]=[]
        for (index,file) in files.enumerated() {
            progress("Film Emulation photo \(index+1)/8: \(file.lastPathComponent)")
            try autoreleasepool {
                guard var input=CIImage(contentsOf:file,options:[.applyOrientationProperty:true]) else{throw LabError.render}
                input=input.transformed(by:CGAffineTransform(translationX:-input.extent.minX,y:-input.extent.minY))
                let root="FilmEmulation/RealPhotos/"+file.deletingPathExtension().lastPathComponent
                try artifacts.png(input,root+"/Original.png")
                let centers=filmPhotoRegions(index)
                var sheet:[(String,CIImage)]=[("Original",input)]
                var crops:[(String,CIImage)]=centers.map{("Original · \($0.0)",filmCrop(input,x:$0.1,y:$0.2))}
                var selected:[String:CIImage]=[:]
                var samples:[CIImage]=[]
                var c=LabCase(name:"FE_photo_"+file.deletingPathExtension().lastPathComponent)
                c.notes=["Manual photographic review only; no Golden Master.",
                         "Native 512 px crop centers: \(centers.map{"\($0.0)=(\($0.1),\($0.2))"}.joined(separator:", "))."]
                global.append((file.deletingPathExtension().lastPathComponent+" Original",normalized(input,to:256)))
                for title in titles {
                    let fx=filmPreset(title).validated,key=filmKey(title)
                    let output=try render(input,[fx])
                    let path=root+"/"+key
                    try artifacts.png(output,path+".png")
                    try artifacts.png(artifacts.difference(input,output,gain:6),path+"_difference_x6.png")
                    try artifacts.json(fx,path+"_settings.json")
                    let a=normalized(input,to:512),b=normalized(output,to:512)
                    let m=gpu.compare(a,b),gamut=filmGamutMetrics(a,b)
                    c.metrics[key+"-meanLuminanceChange"]=m.residual.mean
                    c.metrics[key+"-MAE"]=m.mae
                    c.metrics[key+"-chromaticityDrift"]=m.chromaticityMAE
                    for (metric,value) in gamut {c.metrics[key+"-"+metric]=value}
                    c.check("Finite \(title)",m.nonFinite==0,hard:true,"512 px RGBAf photographic sample.")
                    if title=="Neutral Negative" {
                        c.check("Neutral Negative visible",m.mae>0.002,
                                "A near-identity natural film deserves manual review if its change is tiny.")
                    }
                    sheet.append((title,output));selected[title]=output;samples.append(b)
                    global.append((file.deletingPathExtension().lastPathComponent+" "+title,normalized(output,to:256)))
                    for (label,x,y) in centers {crops.append(("\(title) · \(label)",filmCrop(output,x:x,y:y)))}
                }
                for i in titles.indices {for j in 0..<i {
                    let d=gpu.compare(samples[i],samples[j]).mae
                    distances[i][j]+=d;distances[j][i]+=d
                }}
                let contact=root+"/FilmEmulation_contact_sheet.png"
                let native=root+"/FilmEmulation_crops_100percent.png"
                let special=root+"/"+comparisonNames[index]
                try artifacts.sheet(sheet,contact,cell:960,maxColumns:3)
                try artifacts.sheet(crops,native,nativeCrop:true,cell:512,maxColumns:4)
                try artifacts.sheet(crops,special,nativeCrop:true,cell:512,maxColumns:4)
                c.images=[contact,native,special];cases.append(c)
                if [2,3,4,6].contains(index),let slide=selected["Dense Slide"] {
                    let point=centers[0]
                    dense.append((file.deletingPathExtension().lastPathComponent+" Dense Slide",
                                  filmCrop(slide,x:point.1,y:point.2)))
                }
                if [0,1,3,6].contains(index),let warm=selected["Warm Portrait"] {
                    warmScenes.append((file.deletingPathExtension().lastPathComponent+" Warm Portrait",
                                       filmCrop(warm,x:centers[0].1,y:centers[0].2)))
                }
                if index==5 {
                    let photo=normalized(input,to:768)
                    let muted=try render(photo,[filmPreset("Muted Cinema")])
                    let bleach=try render(photo,[CreativeFXPreset.all(for:.bleachBypass).first{$0.title=="Cinematic"}!.makeEffect()])
                    let cross=try render(photo,[CreativeFXPreset.all(for:.crossProcessing).first{$0.title=="Vintage Process"}!.makeEffect()])
                    try artifacts.sheet([("Original",photo),("Muted Cinema",muted),
                                         ("Bleach Cinematic",bleach),("Cross Vintage",cross)],
                                        "FilmEmulation/muted_cinema_comparison.png",cell:512,maxColumns:2)
                }
                if index==3 {
                    let photo=normalized(input,to:768)
                    let vintage=try render(photo,[filmPreset("Vintage Color")])
                    let cross=try render(photo,[CreativeFXPreset.all(for:.crossProcessing).first{$0.title=="Vintage Process"}!.makeEffect()])
                    try artifacts.sheet([("Original",photo),("Vintage Color film",vintage),
                                         ("Vintage Cross",cross),("Difference ×8",artifacts.difference(vintage,cross,gain:8))],
                                        "FilmEmulation/vintage_film_vs_vintage_cross.png",cell:512,maxColumns:2)
                }
            }
        }
        try artifacts.sheet(global,"FilmEmulation/global_photo_contact_sheet.png",cell:256,maxColumns:8)
        try artifacts.sheet(dense,"FilmEmulation/dense_slide_stress_test.png",nativeCrop:true,cell:512,maxColumns:4)
        try artifacts.sheet(warmScenes,"FilmEmulation/WarmPortrait_cross_scene_comparison.png",nativeCrop:true,cell:512,maxColumns:4)
        let mean=distances.map{$0.map{$0/Double(files.count)}}
        var md="# Film Emulation — photographic diversity\n\nMean pairwise linear RGB MAE across the same eight photographs at 512 px. Non-neutral pairs below 0.004 trigger WARN. No Film Type is changed from these values.\n\n| Film | "+titles.joined(separator:" | ")+" |\n|---|"+Array(repeating:"---:",count:titles.count).joined(separator:"|")+"|\n"
        for i in titles.indices {
            md+="| \(titles[i]) | "+mean[i].map{String(format:"%.5f",$0)}.joined(separator:" | ")+" |\n"
            var c=LabCase(name:"FE_photo_diversity_"+filmKey(titles[i]))
            for j in 0..<i where i>0 && j>0 {
                c.metrics["distanceTo_"+filmKey(titles[j])]=mean[i][j]
                c.check("Distinct from \(titles[j])",mean[i][j]>=0.004,
                        "Photo diversity heuristic; no automatic preset adjustment.")
            }
            cases.append(c)
        }
        try md.write(to:artifacts.url("FilmEmulationPhotoDiversity.md"),atomically:true,encoding:.utf8)
        try artifacts.plot(mean.enumerated().map{(titles[$0.offset],$0.element)},
                           "FilmEmulation/photo_preset_distance_matrix.png",title:"Eight-photo Film Type distances",
                           xMaximum:Double(titles.count-1))
    }
}

extension LumoraVisualTestLab {
    private func filmPerformance() throws {
        progress("Film Emulation 1024/2048/4096 rendering and resolution")
        var c=LabCase(name:"FE_resolution_performance")
        var reference:CIImage?
        for dimension in [1024,2048,4096] {
            try autoreleasepool {
                let input=SyntheticCharts.make(size:dimension){x,y in
                    let t=Float(0.04+0.88*(x+0.35*y)/1.35)
                    return SIMD3(t*0.92,t*0.77,t*0.63)
                }
                let prepare=ProcessInfo.processInfo.systemUptime
                let fx=filmPreset("Neutral Negative")
                c.metrics["\(dimension)-parameterPreparationMilliseconds"]=(ProcessInfo.processInfo.systemUptime-prepare)*1000
                let start=ProcessInfo.processInfo.systemUptime
                let output=try render(input,[fx])
                let sample=normalized(output,to:512)
                let m=gpu.compare(normalized(input,to:512),sample)
                c.metrics["\(dimension)-renderMaterializationMilliseconds"]=(ProcessInfo.processInfo.systemUptime-start)*1000
                c.metrics["\(dimension)-nonFinitePixels"]=Double(m.nonFinite)
                c.metrics["\(dimension)-meanOutputY"]=m.output.mean
                c.check("Finite \(dimension)",m.nonFinite==0,hard:true,"GPU render materialized at native resolution.")
                if let reference {
                    let agreement=gpu.compare(reference,sample)
                    c.metrics["\(dimension)-normalizedRMSE"]=agreement.rmse
                    c.check("Resolution agreement \(dimension)",agreement.rmse<0.015,
                            "Quality heuristic after normalizing outputs to 512 px.")
                } else {reference=sample}
                try artifacts.png(sample,"FilmEmulation/resolution_\(dimension).png")
            }
        }
        c.notes=["No LUT is generated or cached; seven immutable FilmResponseParameters values are static. Timings include CI materialization and readback, not isolated GPU kernel time."]
        cases.append(c)
    }
    private func filmPipeline(_ chart:FilmEmulationTestChart) async throws {
        progress("Film Emulation interactive, HQ and export")
        let source=normalized(chart.image,to:2048)
        let path=try artifacts.url("FilmEmulation/Pipeline/source.png")
        try artifacts.png(source,"FilmEmulation/Pipeline/source.png")
        let engine=RenderEngine()
        var state=EditState();state.creative.effects=[filmPreset("Warm Portrait")]
        var c=LabCase(name:"FE_preview_HQ_export")
        var images:[(String,CIImage)]=[]
        for quality in [PreviewQuality.interactive,.high] {
            let result=try await engine.render(url:path,state:state,quality:quality)
            let name=quality == .interactive ? "interactive":"HQ"
            c.metrics[name+"-milliseconds"]=result.milliseconds
            c.metrics[name+"-width"]=Double(result.image.width)
            images.append((name,CIImage(cgImage:result.image)))
        }
        let repeated=try await engine.render(url:path,state:state,quality:.interactive)
        c.check("Preview cache hit",repeated.cacheHit,hard:true,"Production RenderEngine source/preview cache.")
        state.creative.effects[0]["filmStrength"]=100
        let changed=try await engine.render(url:path,state:state,quality:.interactive)
        let changedImage=CIImage(cgImage:changed.image)
        c.metrics["parameterChangeMAE"]=gpu.compare(images[0].1,changedImage).mae
        c.check("Slider updates preview",c.metrics["parameterChangeMAE"]!>1e-6,hard:true,
                "Changing Film Strength invalidates the preview.")
        var settings=ExportSettings();settings.format = .png
        settings.colorSpace = .displayP3;settings.includeMetadata = false
        let exported=try await engine.export(request:ExportRequest(sourceURL:path,state:state,name:"film-emulation-lab"),
                                             settings:settings,directory:artifacts.url("FilmEmulation/Pipeline/Export"))
        guard let exportImage=CIImage(contentsOf:exported.url) else{throw LabError.render}
        let commonPreview=normalized(changedImage,to:512),commonExport=normalized(exportImage,to:512)
        let m=gpu.compare(commonPreview,commonExport)
        c.metrics["exportWidth"]=Double(exported.width)
        c.metrics["previewExportMAE"]=m.mae
        c.metrics["previewExportRMSE"]=m.rmse
        c.metrics["previewExportMaxError"]=m.maxError
        c.metrics["previewExportSSIM"]=m.ssim
        c.check("Preview/export agreement",m.ssim>0.90,
                "Quality heuristic after display-space conversion and resizing.")
        images += [("Changed preview",changedImage),("Export",exportImage)]
        c.images=["FilmEmulation/Pipeline/comparison.png"]
        try artifacts.sheet(images,c.images[0],cell:512)
        cases.append(c)
    }
}

extension LumoraVisualTestLab {
    private func filmMasksAndStack(_ chart:FilmEmulationTestChart) throws {
        progress("Film Emulation masks and Creative stack ordering")
        let source=normalized(chart.image,to:1024),fx=filmPreset("Vivid Chrome")
        var radial=RadialGradientMask();radial.center=MaskPoint(x:0.35,y:0.5)
        radial.radiusX=0.19;radial.radiusY=0.19;radial.feather=4
        let mask=LocalMask(name:"Film region",components:[MaskComponent(shape:.radial(radial))])
        var targeted=fx;targeted.maskID=mask.id
        let simple=try render(source,[targeted],masks:[mask])
        var inverse=mask;inverse.inverted=true
        let inverted=try render(source,[targeted],masks:[inverse])
        var radial2=radial;radial2.center=MaskPoint(x:0.75,y:0.5)
        let secondMask=LocalMask(name:"Second",components:[MaskComponent(shape:.radial(radial2))])
        var second=fx;second.maskID=secondMask.id
        let stacked=try render(source,[targeted,second],masks:[mask,secondMask])
        var hole=radial;hole.radiusX=0.055;hole.radiusY=0.055;hole.feather=0
        let subtraction=LocalMask(name:"Film minus center",components:[
            MaskComponent(operation:.add,shape:.radial(radial)),
            MaskComponent(operation:.subtract,shape:.radial(hole))])
        var cutFX=fx;cutFX.maskID=subtraction.id
        let cut=try render(source,[cutFX],masks:[subtraction])
        let outside=CGRect(x:10,y:10,width:64,height:64)
        let center=CGRect(x:344,y:496,width:24,height:24)
        let secondCenter=CGRect(x:756,y:496,width:24,height:24)
        var c=LabCase(name:"FE_masks")
        for (key,image,rect) in [("simple",simple,outside),("inverted",inverted,center),
                                  ("stacked",stacked,outside),("subtractive",cut,center)] {
            let m=gpu.compare(source,image,region:rect)
            c.metrics[key+"-outsideMaskMaxError"]=m.maxError
            c.metrics[key+"-outsideMaskMeanError"]=m.mae
            c.check("Outside mask \(key)",m.maxError<2e-6,hard:true,
                    "Existing mask/opacity compositor must isolate unchanged regions.")
        }
        c.metrics["simpleCenterMAE"]=gpu.compare(source,simple,region:center).mae
        c.metrics["stackedSecondMAE"]=gpu.compare(source,stacked,region:secondCenter).mae
        c.check("Masked regions respond",c.metrics["simpleCenterMAE"]!>1e-6 &&
                c.metrics["stackedSecondMAE"]!>1e-6,hard:true,"Both target regions change.")
        c.images=["FilmEmulation/mask_comparison.png"]
        try artifacts.sheet([("Original",source),("Simple",simple),("Inverted",inverted),
                             ("Stacked",stacked),("Subtractive",cut)],c.images[0],cell:512,maxColumns:3)
        cases.append(c)
        let others:[(String,String,CreativeEffect)]=[
            ("grain","FilmEmulation/stack_film_grain.png",effect(.grain,["amount":60,"size":40,"chromaAmount":0])),
            ("glow","FilmEmulation/stack_film_glow.png",CreativeFXPreset.all(for:.glamourGlow).first{$0.title=="Portrait Glow"}!.makeEffect()),
            ("bleach","FilmEmulation/stack_film_bleach.png",CreativeFXPreset.all(for:.bleachBypass).first{$0.title=="Classic Bypass"}!.makeEffect()),
            ("cross","FilmEmulation/stack_film_cross.png",CreativeFXPreset.all(for:.crossProcessing).first{$0.title=="Warm Process"}!.makeEffect()),
            ("pro_contrast","FilmEmulation/stack_film_pro_contrast.png",CreativeFXPreset.all(for:.proContrast).first{$0.title=="Natural Contrast"}!.makeEffect())]
        for (name,path,other) in others {
            let forward=try render(source,[fx,other]),reverse=try render(source,[other,fx])
            let m=gpu.compare(forward,reverse)
            var order=LabCase(name:"FE_stack_"+name)
            order.metrics=["forwardReverseMAE":m.mae,"nonFinitePixels":Double(m.nonFinite)]
            order.check("Order differs",m.mae>1e-7,hard:true,
                        "Film and the other production Creative renderer are noncommutative.")
            order.check("Finite",m.nonFinite==0,hard:true,"No invalid pixels.")
            try artifacts.sheet([("Film → \(name)",forward),("\(name) → Film",reverse),
                                 ("Difference ×8",artifacts.difference(forward,reverse,gain:8))],
                                path,cell:512,maxColumns:3)
            order.images=[path];cases.append(order)
        }
        let analyzer=ProContrastAnalyzer.shared
        let unique=SyntheticCharts.make(size:256){x,y in
            let v=Float(0.21731+0.58249*x+0.01387*y)
            return SIMD3(v*0.97,v,v*0.89)
        }
        let beforeCounters=analyzer.counters()
        let upstream=analyzer.analyze(unique)
        let after=try render(unique,[fx])
        let filmInput=analyzer.analyze(after)
        let afterCounters=analyzer.counters()
        var cache=LabCase(name:"FE_pro_contrast_cache_invalidation")
        cache.metrics=["sourceP50":upstream.0.p50,"filmP50":filmInput.0.p50,
                       "newMisses":Double(afterCounters.misses-beforeCounters.misses)]
        cache.check("Film changes Pro Contrast input",!filmInput.1 &&
                    abs(upstream.0.p50-filmInput.0.p50)>1e-5,hard:true,
                    "Pro Contrast must analyze the pixels after Film Emulation when Film is earlier in the stack.")
        cases.append(cache)
    }
}

extension LumoraVisualTestLab {
    private func filmSimpleGrade(_ image:CIImage,warm:Bool)->CIImage {
        let r=warm ? 1.035:1.012,g=warm ? 1.005:1.010,b=warm ? 0.968:0.997
        return image.applyingFilter("CIColorMatrix",parameters:[
            "inputRVector":CIVector(x:r,y:0,z:0,w:0),
            "inputGVector":CIVector(x:0,y:g,z:0,w:0),
            "inputBVector":CIVector(x:0,y:0,z:b,w:0)])
            .applyingFilter("CIColorControls",parameters:[
                kCIInputSaturationKey:warm ? 1.01:1.14,
                kCIInputContrastKey:warm ? 1.025:1.15])
            .cropped(to:image.extent)
    }
    private func filmComparisons(_ chart:FilmEmulationTestChart) throws {
        progress("Film Emulation versus simple grading and Cross Processing")
        let source=normalized(chart.image,to:1024)
        var gradeNotes="# Film Emulation vs simple color grading\n\nThe diagnostic baselines use constant linear RGB gains (temperature/tint), Core Image global contrast and saturation. They are adjusted to resemble each film broadly, not optimized to maximize or minimize distance. Film Emulation applies exposure before a logarithmic toe/mid/shoulder response, small layer coupling and luminance-dependent saturation.\n\n"
        for (title,warm,path) in [("Warm Portrait",true,"FilmEmulation/film_vs_simple_grade_warm_portrait.png"),
                                  ("Vivid Chrome",false,"FilmEmulation/film_vs_simple_grade_vivid_chrome.png")] {
            let film=try render(source,[filmPreset(title)])
            let grade=filmSimpleGrade(source,warm:warm)
            let m=gpu.compare(film,grade)
            var c=LabCase(name:"FE_simple_grade_"+filmKey(title))
            c.metrics=["MAE":m.mae,"RMSE":m.rmse,"SSIM":m.ssim,
                       "nonFinitePixels":Double(m.nonFinite)]
            for zone in ["near-black-ramp","midtone-ramp","highlight-ramp","hdr-ramp",
                         "light-skin","dark-skin"] {
                let r=chart.rect(zone)
                let rect=CGRect(x:r.minX/2,y:r.minY/2,width:r.width/2,height:r.height/2)
                let f=filmSample(film,rect),g=filmSample(grade,rect)
                c.metrics[zone+"-filmY"]=filmY(f);c.metrics[zone+"-gradeY"]=filmY(g)
                c.metrics[zone+"-chromaDifference"]=filmChroma(f)-filmChroma(g)
            }
            c.check("Parametric response differs",m.mae>0.002,
                    "A single exposure/contrast/saturation/temperature/tint grade does not model toe and shoulder.")
            c.images=[path]
            try artifacts.sheet([("Original",source),(title,film),("Simple grade",grade),
                                 ("Difference ×6",artifacts.difference(film,grade,gain:6))],
                                path,cell:512,maxColumns:2)
            cases.append(c)
            gradeNotes+="## \(title)\n\nMAE \(String(format:"%.6f",m.mae)), RMSE \(String(format:"%.6f",m.rmse)), SSIM \(String(format:"%.5f",m.ssim)). Toe, midtones, shoulder, skin and HDR regional values are in the validation report. [Comparison](\(path)).\n\n"
        }
        try gradeNotes.write(to:artifacts.url("FilmEmulation_vs_simple_grade.md"),atomically:true,encoding:.utf8)
        let styles:[(String,CreativeEffect)]=[
            ("Original",CreativeEffect(.filmEmulation)),
            ("Neutral Negative",filmPreset("Neutral Negative")),
            ("Warm Portrait",filmPreset("Warm Portrait")),
            ("Cross Warm Process",CreativeFXPreset.all(for:.crossProcessing).first{$0.title=="Warm Process"}!.makeEffect()),
            ("Cross Vintage Process",CreativeFXPreset.all(for:.crossProcessing).first{$0.title=="Vintage Process"}!.makeEffect())]
        var items:[(String,CIImage)]=[("Original",source)]
        var output:[String:CIImage]=[:]
        for (name,fx) in styles.dropFirst() {
            let image=try render(source,[fx]);items.append((name,image));output[name]=image
        }
        let repo=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let photo=repo.appendingPathComponent("Validation/VisualTestAssets/01_portrait_light_skin.png")
        guard let real=CIImage(contentsOf:photo,options:[.applyOrientationProperty:true]) else{throw LabError.render}
        let realSource=normalized(real,to:768)
        items.append(("Portrait Original",realSource))
        for (name,fx) in styles.dropFirst() {
            items.append(("Portrait "+name,try render(realSource,[fx])))
        }
        var c=LabCase(name:"FE_vs_cross_processing")
        let negative=output["Neutral Negative"]!,warm=output["Warm Portrait"]!
        let crossWarm=output["Cross Warm Process"]!,crossVintage=output["Cross Vintage Process"]!
        c.metrics=["neutralVsCrossWarmMAE":gpu.compare(negative,crossWarm).mae,
                   "warmVsCrossWarmMAE":gpu.compare(warm,crossWarm).mae,
                   "warmVsCrossVintageMAE":gpu.compare(warm,crossVintage).mae]
        for zone in ["near-black-ramp","midtone-ramp","highlight-ramp","hdr-ramp","light-skin"] {
            let r=chart.rect(zone),rect=CGRect(x:r.minX/2,y:r.minY/2,width:r.width/2,height:r.height/2)
            for (name,image) in [("negative",negative),("warm",warm),
                                 ("crossWarm",crossWarm),("crossVintage",crossVintage)] {
                let rgb=filmSample(image,rect)
                c.metrics[zone+"-"+name+"-Y"]=filmY(rgb)
                c.metrics[zone+"-"+name+"-chroma"]=filmChroma(rgb)
                c.metrics[zone+"-"+name+"-hue"]=filmHue(rgb)
            }
        }
        c.check("Distinct engines",c.metrics["warmVsCrossWarmMAE"]!>0.004,
                "Film characteristic response and expressive independent RGB curves should remain measurably different; WARN only.")
        c.images=["FilmEmulation/film_vs_cross_processing.png"]
        try artifacts.sheet(items,c.images[0],cell:512,maxColumns:5)
        cases.append(c)
    }
}

extension LumoraVisualTestLab {
    private func filmDecompositionAndDiversity(_ chart:FilmEmulationTestChart) throws {
        progress("Film Emulation look decomposition and synthetic film diversity")
        let source=normalized(chart.image,to:1024)
        let renderer=FilmEmulationRenderer()
        for title in ["Neutral Negative","Warm Portrait","Vivid Chrome","Vintage Color","Dense Slide"] {
            let fx=filmPreset(title),key=filmKey(title)
            var items:[(String,CIImage)]=[("Original",source)]
            for (stage,label) in [(0,"Tone Response Only"),(1,"+ Channel Response"),
                                  (2,"+ Color Coupling"),(3,"+ Luminance Saturation")] {
                let output=try renderer.applyStages(source,effect:fx,stage:stage)
                items.append((label,output))
            }
            let final=try render(source,[fx])
            items.append(("Final Film Response",final))
            let path="FilmEmulation/look_decomposition_"+key+".png"
            try artifacts.sheet(items,path,cell:512,maxColumns:3)
            var c=LabCase(name:"FE_decomposition_"+key)
            c.metrics["stage3ProductionMAE"]=gpu.compare(items[4].1,final).mae
            c.check("Same renderer",c.metrics["stage3ProductionMAE"]!<1e-7,hard:true,
                    "Final stage is the exact production kernel through CreativeStackRenderer.")
            c.images=[path];cases.append(c)
        }
        let titles=CreativeFXPreset.all(for:.filmEmulation).map(\.title)
        let cube=normalized(chart.image,to:512)
        let outputs=try titles.map{try render(cube,[filmPreset($0)])}
        var rows:[[Double]]=[]
        var md="# Film Emulation — diversity\n\nMAE in extended-linear RGB on the full synthetic chart (exposure, channel ramps, color, skin, pastel, saturated and HDR regions). Near-identical non-neutral pairs below 0.004 trigger WARN; presets are never changed from these measurements.\n\n| Film | "+titles.joined(separator:" | ")+" |\n|---|"+Array(repeating:"---:",count:titles.count).joined(separator:"|")+"|\n"
        for i in titles.indices {
            let distances=titles.indices.map{gpu.compare(outputs[i],outputs[$0]).mae}
            rows.append(distances)
            md+="| \(titles[i]) | "+distances.map{String(format:"%.5f",$0)}.joined(separator:" | ")+" |\n"
            var c=LabCase(name:"FE_diversity_"+filmKey(titles[i]))
            for j in 0..<i where i>0 && j>0 {
                c.metrics["distanceTo_"+filmKey(titles[j])]=distances[j]
                c.check("Distinct from \(titles[j])",distances[j]>=0.004,
                        "Photographic diversity heuristic; no automatic preset adjustment.")
            }
            cases.append(c)
        }
        try md.write(to:artifacts.url("FilmEmulationFilmDiversity.md"),atomically:true,encoding:.utf8)
        try artifacts.plot(rows.enumerated().map{(titles[$0.offset],$0.element)},
                           "FilmEmulation/film_distance_matrix.png",title:"Film Type distance matrix",
                           xMaximum:Double(titles.count-1))
        var switching=LabCase(name:"FE_style_switching_memory")
        let start=ProcessInfo.processInfo.systemUptime
        var last:CIImage=source
        for i in 0..<28 {last=try render(source,[filmPreset(titles[i%titles.count])])}
        let known=try render(source,[filmPreset(titles[27%titles.count])])
        let m=gpu.compare(last,known)
        switching.metrics=["switches":28,"elapsedMilliseconds":(ProcessInfo.processInfo.systemUptime-start)*1000,
                           "repeatMaxRGBError":m.maxError,"nonFinitePixels":Double(m.nonFinite)]
        switching.check("No stale style state",m.maxError==0,hard:true,
                        "Style switching has no mutable LUT or profile cache; parameters are fixed-size values.")
        switching.notes=["The renderer allocates no persistent CIImage/MTLTexture cache. This test checks stale state, not iPhone thermal behavior or a continuous resident-memory trace."]
        cases.append(switching)
    }
}

extension LumoraVisualTestLab {
    private func filmBandingFrequency(_ chart:FilmEmulationTestChart) throws {
        progress("Film Emulation gradients, spatial frequency and absence of grain")
        let gradients:[(String,(Double)->SIMD3<Float>)]=[
            ("gray",{SIMD3(repeating:Float($0))}),
            ("blue",{let t=Float($0);return .init(0.18+0.45*t,0.35+0.43*t,0.58+0.40*t)}),
            ("skin",{let t=Float($0);return .init(0.25+0.46*t,0.15+0.31*t,0.09+0.23*t)}),
            ("sunset",{let t=Float($0);return .init(0.28+0.67*t,0.08+0.57*t,0.26+0.35*t)})]
        var images:[(String,CIImage)]=[]
        for (name,make) in gradients {
            let source=SyntheticCharts.make(size:2048){x,_ in make(x)}
            images.append((name+" original",source))
            for title in ["Neutral Negative","Vivid Chrome","Vintage Color","Dense Slide"] {
                let output=try render(source,[filmPreset(title)])
                let pixels=gpu.read(output,CGRect(x:0,y:1024,width:2048,height:1))
                var c=LabCase(name:"FE_banding_"+name+"_"+filmKey(title))
                for channel in 0..<3 {
                    let values=(0..<2048).map{Double(pixels[$0*4+channel])}
                    let steps=zip(values.dropFirst(),values).map{$0-$1}
                    c.metrics["channel\(channel)-distinct16bitLevels"]=Double(Set(values.map{Int(($0*65535).rounded())}).count)
                    c.metrics["channel\(channel)-maximumStep"]=steps.map(abs).max() ?? 0
                    c.metrics["channel\(channel)-reversals"]=Double(steps.filter{$0 < -1e-6}.count)
                    c.check("Smooth channel \(channel)",(steps.map(abs).max() ?? 0)<0.015,
                            "Quality heuristic on a 2048-column linear gradient.")
                }
                c.check("Finite",gpu.compare(source,output,region:CGRect(x:0,y:1024,width:2048,height:1)).nonFinite==0,
                        hard:true,"No invalid gradient values.")
                cases.append(c);images.append((name+" "+title,output))
            }
        }
        try artifacts.sheet(images,"FilmEmulation/banding_stress_test.png",cell:512,maxColumns:5)
        let width=4096,frequencies=[8.0,32.0,96.0,192.0]
        let frequencySource=filmRamp(width:width){x in
            let v=0.45+frequencies.map{0.012*sin(2*Double.pi*$0*x)}.reduce(0,+)
            return SIMD3(repeating:Float(v))
        }
        let frequencyOutput=try render(frequencySource,[filmPreset("Dense Slide")])
        let a=gpu.read(frequencySource,CGRect(x:0,y:0,width:width,height:1))
        let b=gpu.read(frequencyOutput,CGRect(x:0,y:0,width:width,height:1))
        func amplitude(_ pixels:[Float],_ frequency:Double)->Double {
            let mean=(0..<width).map{LabGPU.luma(pixels,$0*4)}.reduce(0,+)/Double(width)
            var sinPart=0.0,cosPart=0.0
            for x in 0..<width {
                let phase=2*Double.pi*frequency*(Double(x)+0.5)/Double(width)
                let v=LabGPU.luma(pixels,x*4)-mean
                sinPart+=v*sin(phase);cosPart+=v*cos(phase)
            }
            return 2*hypot(sinPart,cosPart)/Double(width)
        }
        let gains=frequencies.map{amplitude(b,$0)/max(1e-9,amplitude(a,$0))}
        var frequency=LabCase(name:"FE_frequency_response")
        for (i,hz) in frequencies.enumerated(){frequency.metrics["frequency\(Int(hz))-gain"]=gains[i]}
        frequency.metrics["gainSpread"]=(gains.max() ?? 0)-(gains.min() ?? 0)
        frequency.check("No spatial preference",frequency.metrics["gainSpread"]!<0.10,hard:true,
                        "Pointwise film should not favor 8, 32, 96 or 192 cycles at equal amplitude.")
        frequency.check("Finite",gpu.compare(frequencySource,frequencyOutput).nonFinite==0,hard:true,
                        "Frequency fixture output.")
        frequency.images=["FilmEmulation/frequency_response.png"]
        try artifacts.plot([("Input",frequencies.map{amplitude(a,$0)}),
                            ("Film",frequencies.map{amplitude(b,$0)}),
                            ("Gain",gains)],frequency.images[0],
                           title:"Spatial frequency amplitude and gain",xMaximum:192)
        cases.append(frequency)
        for value in [0.08,0.48,0.87] {
            let source=SyntheticCharts.gray(value,size:256)
            let fx=filmPreset("Vintage Color")
            let first=try render(source,[fx]),second=try render(source,[fx])
            let p=gpu.read(first,source.extent)
            var moments=Moments()
            for i in stride(from:0,to:p.count,by:4){moments.add(LabGPU.luma(p,i))}
            let determinism=gpu.compare(first,second)
            var c=LabCase(name:"FE_no_grain_"+String(format:"%.2f",value))
            c.metrics=["inputVariance":0,"outputVariance":moments.variance,
                       "repeatMaxRGBError":determinism.maxError]
            c.check("Uniform stays uniform",moments.variance<1e-12,hard:true,
                    "The film kernel contains no noise, texture or spatial operation.")
            c.check("Deterministic",determinism.maxError==0,hard:true,
                    "Same source and settings produce identical output.")
            cases.append(c)
        }
    }
}

extension LumoraVisualTestLab {
    private func filmGamutMetrics(_ before:CIImage,_ after:CIImage)->[String:Double] {
        let a=gpu.read(before,before.extent.integral),b=gpu.read(after,before.extent.integral)
        var source=0,output=0,new=0,negative=0,nonfinite=0
        for i in stride(from:0,to:a.count,by:4) {
            if !(0..<4).allSatisfy({a[i+$0].isFinite && b[i+$0].isFinite}) {nonfinite+=1;continue}
            let old=(0..<3).contains{a[i+$0]>=1},out=(0..<3).contains{b[i+$0]>=1}
            source+=old ? 1:0;output+=out ? 1:0
            new+=((0..<3).contains{b[i+$0]>=1 && a[i+$0]<1}) ? 1:0
            negative+=((0..<3).contains{b[i+$0]<(-0.25)}) ? 1:0
        }
        let pixels=Double(max(1,a.count/4))
        return ["inputClippedFraction":Double(source)/pixels,"outputClippedFraction":Double(output)/pixels,
                "newClippedFraction":Double(new)/pixels,"excessiveNegativeFraction":Double(negative)/pixels,
                "nonFinitePixels":Double(nonfinite)]
    }
    private func filmColorAndSkin(_ chart:FilmEmulationTestChart) throws {
        progress("Film Emulation chroma, channel coupling and skin by exposure")
        let titles=CreativeFXPreset.all(for:.filmEmulation).map(\.title)
        var saturationSeries:[(String,[Double])]=[]
        var skinItems:[(String,CIImage)]=[]
        for title in titles {
            let fx=filmPreset(title),key=filmKey(title)
            var c=LabCase(name:"FE_color_skin_"+key)
            var chromaRatios:[Double]=[]
            for (name,level) in [("shadow",0.12),("midtone",0.50),("highlight",0.85)] {
                let base=SIMD3<Double>(0.88,0.48,0.24),scale=level/filmY(base)
                let rgb=base*scale
                let swatch=CIImage(color:CIColor(red:rgb.x,green:rgb.y,blue:rgb.z,
                                                  colorSpace:SyntheticCharts.linearSpace)!).cropped(to:CGRect(x:0,y:0,width:64,height:64))
                let output=try render(swatch,[fx])
                let after=filmSample(output,output.extent)
                filmMetric(rgb,after,name,&c)
                chromaRatios.append(c.metrics[name+"-chromaRatio"]!)
            }
            saturationSeries.append((title,chromaRatios))
            for (name,base) in [("light",SIMD3<Double>(0.59,0.35,0.24)),
                                ("dark",SIMD3<Double>(0.28,0.15,0.10))] {
                for ev in -2...2 {
                    let rgb=base*pow(2,Double(ev))
                    let source=CIImage(color:CIColor(red:rgb.x,green:rgb.y,blue:rgb.z,
                                                      colorSpace:SyntheticCharts.linearSpace)!).cropped(to:CGRect(x:0,y:0,width:64,height:64))
                    let output=try render(source,[fx])
                    filmMetric(rgb,filmSample(output,output.extent),"\(name)_EV\(ev)",&c)
                    if ev==0 {skinItems.append((title+" "+name,output))}
                }
            }
            let reference=normalized(chart.image,to:512)
            let output=try render(reference,[fx])
            for (key,value) in filmGamutMetrics(reference,output) {c.metrics[key]=value}
            c.check("Finite photographic chart",c.metrics["nonFinitePixels"]==0,hard:true,
                    "RGBAf output, including HDR and saturated patches.")
            if title=="Warm Portrait" {
                let light=c.metrics["light_EV0-hueShift"] ?? 0
                let dark=c.metrics["dark_EV0-hueShift"] ?? 0
                c.check("Plausible warm skin",light<0.25 && dark<0.25,
                        "Moderate hue rotation (<0.25 rad) on both synthetic carnations.")
                c.check("Skin chroma restrained",(c.metrics["light_EV0-chromaRatio"] ?? 0)<1.25,
                        "Quality heuristic; photographic review is authoritative.")
            }
            if title=="Vivid Chrome" {
                for name in ["color-patches","saturated-colors","sky-gradient"] {
                    let rect=chart.rect(name)
                    let scaled=CGRect(x:rect.minX/4,y:rect.minY/4,width:rect.width/4,height:rect.height/4)
                    filmMetric(filmSample(reference,scaled),filmSample(output,scaled),name,&c)
                }
            }
            cases.append(c)
            // Inject single-channel signals and measure layer interaction after
            // subtracting the same film's tone-only response.
            var matrix=LabCase(name:"FE_color_coupling_"+key)
            var toneOnly=fx;toneOnly["colorResponse"]=0
            for (name,rgb) in [("R",SIMD3<Double>(0.45,0,0)),
                               ("G",SIMD3<Double>(0,0.45,0)),
                               ("B",SIMD3<Double>(0,0,0.45))] {
                let source=CIImage(color:CIColor(red:rgb.x,green:rgb.y,blue:rgb.z,
                                                  colorSpace:SyntheticCharts.linearSpace)!).cropped(to:CGRect(x:0,y:0,width:64,height:64))
                let full=filmSample(try render(source,[fx]),source.extent)
                let neutral=filmSample(try render(source,[toneOnly]),source.extent)
                matrix.metrics[name+"-R"]=full.x;matrix.metrics[name+"-G"]=full.y
                matrix.metrics[name+"-B"]=full.z
                matrix.metrics[name+"-deltaR"]=full.x-neutral.x
                matrix.metrics[name+"-deltaG"]=full.y-neutral.y
                matrix.metrics[name+"-deltaB"]=full.z-neutral.z
            }
            matrix.notes=["Measured RGB response rows include the nonlinear characteristic curve; deltas subtract a colorResponse=0 render. The analytic matrix is diagonally dominant with off-diagonal coefficient \(FilmResponseParameters.styles[Int(fx["style"])].coupling*fx["filmStrength"]/100*fx["colorResponse"]/100)."]
            cases.append(matrix)
        }
        try artifacts.plot(saturationSeries,"FilmEmulation/saturation_vs_luminance.png",
                           title:"Chroma ratio · shadows, midtones, highlights",xMaximum:2)
        try artifacts.sheet(skinItems,"FilmEmulation/skin_exposure_response.png",cell:256,maxColumns:4)
        let reference=normalized(chart.image,to:1024)
        let important=["Neutral Negative","Warm Portrait","Vivid Chrome","Dense Slide"]
        try artifacts.sheet(try important.map{($0,try render(reference,[filmPreset($0)]))},
                            "FilmEmulation/color_chart_comparison.png",cell:512,maxColumns:2)
    }
}

extension LumoraVisualTestLab {
    private func filmScale(_ image:CIImage,_ gain:Double)->CIImage {
        image.applyingFilter("CIColorMatrix",parameters:[
            "inputRVector":CIVector(x:gain,y:0,z:0,w:0),
            "inputGVector":CIVector(x:0,y:gain,z:0,w:0),
            "inputBVector":CIVector(x:0,y:0,z:gain,w:0)])
            .cropped(to:image.extent)
    }
    private func filmLatitudeExposure(_ chart:FilmEmulationTestChart) throws {
        progress("Film Emulation exposure latitude, push/pull and pre/post exposure")
        let titles=["Neutral Negative","Warm Portrait","Vivid Chrome","Dense Slide"]
        var levels:[String:[Double]]=[:]
        for title in titles {
            let fx=filmPreset(title),key=filmKey(title)
            var outputLevels:[Double]=[]
            for ev in -6...5 {
                let source=SyntheticCharts.gray(0.18*pow(2,Double(ev)),size:64)
                let output=try render(source,[fx])
                outputLevels.append(filmY(filmSample(output,output.extent)))
            }
            let gaps=zip(outputLevels.dropFirst(),outputLevels).map{$0-$1}
            var c=LabCase(name:"FE_latitude_"+key)
            c.metrics=["lowEVSeparation":gaps.first ?? 0,"highEVSeparation":gaps.last ?? 0,
                       "minimumSeparation":gaps.min() ?? 0,"distinguishableSteps":Double(gaps.filter{$0>0.0001}.count)]
            c.check("Exposure levels ordered",gaps.allSatisfy{$0>0},hard:true,
                    "Patches −6 to +5 EV retain a positive residual slope.")
            cases.append(c);levels[title]=outputLevels
        }
        var comparison=LabCase(name:"FE_latitude_comparison")
        let negative=levels["Neutral Negative"]!,slide=levels["Dense Slide"]!
        comparison.metrics=["negativeLowGap":negative[1]-negative[0],
                            "slideLowGap":slide[1]-slide[0],
                            "negativeHighGap":negative[11]-negative[10],
                            "slideHighGap":slide[11]-slide[10]]
        comparison.check("Negative latitude tendency",
                         comparison.metrics["negativeLowGap"]!>comparison.metrics["slideLowGap"]! ||
                         comparison.metrics["negativeHighGap"]!>comparison.metrics["slideHighGap"]!,
                         "At least one exposure extreme should separate better in the high-latitude negative.")
        cases.append(comparison)
        try artifacts.plot(titles.map{($0,levels[$0]!)},"FilmEmulation/latitude_comparison.png",
                           title:"Exposure levels −6 to +5 EV",xMaximum:11)
        let source=normalized(chart.image,to:1024)
        for (title,path) in [("Neutral Negative","FilmEmulation/exposure_response_negative.png"),
                             ("Dense Slide","FilmEmulation/exposure_response_slide.png")] {
            var items:[(String,CIImage)]=[("Original",source)]
            var c=LabCase(name:"FE_exposure_sweep_"+filmKey(title))
            for ev in -2...2 {
                var fx=filmPreset(title);fx["exposure"]=Double(ev)
                let output=try render(source,[fx])
                let m=gpu.compare(source,output)
                c.metrics["EV\(ev)-meanY"]=m.output.mean
                c.metrics["EV\(ev)-nonFinitePixels"]=Double(m.nonFinite)
                c.check("Finite EV \(ev)",m.nonFinite==0,hard:true,"Pre-response exposure.")
                items.append(("\(ev) EV",output))
            }
            try artifacts.sheet(items,path,cell:512,maxColumns:3)
            c.images=[path];cases.append(c)
        }
        var warm=filmPreset("Warm Portrait");warm["exposure"]=1
        let pre=try render(source,[warm])
        warm["exposure"]=0
        let post=filmScale(try render(source,[warm]),2)
        let m=gpu.compare(pre,post)
        var prepost=LabCase(name:"FE_exposure_pre_vs_post")
        prepost.metrics=["MAE":m.mae,"RMSE":m.rmse,"SSIM":m.ssim,"nonFinitePixels":Double(m.nonFinite)]
        for name in ["near-black-ramp","midtone-ramp","highlight-ramp","hdr-ramp"] {
            let rect=chart.rect(name)
            // Compare the same chart coordinates after normalization to 1024.
            let scaled=CGRect(x:rect.minX/2,y:rect.minY/2,width:rect.width/2,height:rect.height/2)
            prepost.metrics[name+"-preY"]=gpu.compare(source,pre,region:scaled).output.mean
            prepost.metrics[name+"-postY"]=gpu.compare(source,post,region:scaled).output.mean
        }
        prepost.check("Pre/post differ",m.mae>0.001,hard:true,
                      "The film shoulder/toe act after pre-exposure; multiplying output by 2 is distinct.")
        prepost.check("Finite",m.nonFinite==0,hard:true,"Both extended-linear outputs.")
        prepost.images=["FilmEmulation/exposure_pre_vs_post.png"]
        try artifacts.sheet([("Original",source),("+1 EV before film",pre),
                             ("Film then ×2",post),("Difference ×4",artifacts.difference(pre,post))],
                            prepost.images[0],cell:512,maxColumns:2)
        cases.append(prepost)
        var high:[(String,CIImage)]=[("Original",source)],low:[(String,CIImage)]=[("Original",source)]
        for title in titles {
            let output=try render(source,[filmPreset(title)])
            high.append((title,output.cropped(to:CGRect(x:0,y:0,width:1024,height:512))))
            low.append((title,output.cropped(to:CGRect(x:0,y:512,width:1024,height:512))))
        }
        try artifacts.sheet(high,"FilmEmulation/highlight_rolloff_comparison.png",cell:512,maxColumns:3)
        try artifacts.sheet(low,"FilmEmulation/shadow_density_comparison.png",cell:512,maxColumns:3)
        for title in ["Neutral Negative","Warm Portrait","Dense Slide"] {
            let fx=filmPreset(title)
            let under=try render(filmScale(source,0.25),[fx])
            let over=try render(filmScale(source,4),[fx])
            let more=try render(filmScale(source,8),[fx])
            var c=LabCase(name:"FE_exposure_stress_"+filmKey(title))
            for (name,image) in [("under2",under),("over2",over),("over3",more)] {
                let metrics=gpu.compare(source,image)
                c.metrics[name+"-meanY"]=metrics.output.mean
                c.metrics[name+"-nonFinitePixels"]=Double(metrics.nonFinite)
                c.check("Finite \(name)",metrics.nonFinite==0,hard:true,
                        "Under/overexposure up to +3 EV keeps the film response stable.")
            }
            let path="FilmEmulation/exposure_stress_"+filmKey(title)+".png"
            try artifacts.sheet([("−2 EV",under),("Original exposure",source),
                                 ("+2 EV",over),("+3 EV",more)],path,cell:512,maxColumns:2)
            c.images=[path];cases.append(c)
        }
    }
}

extension LumoraVisualTestLab {
    private func filmCurves(_ chart:FilmEmulationTestChart) throws {
        let width=8192
        let scene=filmRamp(width:width){x in SIMD3(repeating:Float(4*x))}
        let exposure=filmRamp(width:width){x in SIMD3(repeating:Float(0.18*pow(2,-8+14*x)))}
        let hdr=filmRamp(width:width){x in SIMD3(repeating:Float(8*x))}
        let line=CGRect(x:0,y:0,width:width,height:1)
        var all:[(String,[Double])]=[]
        var hdrSeries:[(String,[Double])]=[("Identity",(0..<width).map{8*Double($0)/Double(width-1)})]
        for preset in CreativeFXPreset.all(for:.filmEmulation) {
            let title=preset.title,key=filmKey(title),fx=preset.makeEffect()
            let output=try render(scene,[fx])
            let pixels=gpu.read(output,line)
            let y=(0..<width).map{LabGPU.luma(pixels,$0*4)}
            let p=try render(exposure,[fx])
            let logPixels=gpu.read(p,line)
            let logY=(0..<width).map{LabGPU.luma(logPixels,$0*4)}
            var c=LabCase(name:"FE_curves_"+key)
            let values:[(String,[Double])]=[("Luminance",y),
                ("Red",(0..<width).map{Double(pixels[$0*4])}),
                ("Green",(0..<width).map{Double(pixels[$0*4+1])}),
                ("Blue",(0..<width).map{Double(pixels[$0*4+2])})]
            for (name,series) in values {
                let steps=zip(series.dropFirst(),series).map{$0-$1}
                let reversals=steps.filter{$0 < -1e-6}.count
                let maxChange=zip(steps.dropFirst(),steps).map{abs($0-$1)}.max() ?? 0
                c.metrics[name+"Reversals"]=Double(reversals)
                c.metrics[name+"MaxAdjacentDerivativeChange"]=maxChange
                c.check("Monotonic \(name)",reversals==0,hard:true,"8192 samples over linear input 0–4.")
                c.check("Continuous \(name)",maxChange<0.02,hard:true,
                        "No toe/shoulder/SDR-to-HDR splice; derivatives vary smoothly.")
            }
            c.metrics["toeOutputAt0.02"]=y[41]
            c.metrics["midtoneOutputAt0.18"]=y[369]
            c.metrics["shoulderOutputAt1"]=y[2048]
            c.metrics["HDRInput4Output"]=y.last ?? 0
            c.metrics["nonFinitePixels"]=Double(gpu.compare(scene,output,region:line).nonFinite)
            c.check("HDR retained",(y.last ?? 0)>1,hard:true,"4.0 remains above SDR white.")
            c.check("Finite",c.metrics["nonFinitePixels"]==0,hard:true,"RGBAf curve.")
            let characteristic="FilmEmulation/characteristic_curves_"+key+".png"
            let channel="FilmEmulation/channel_response_"+key+".png"
            try artifacts.plot([("Identity",(0..<width).map{0.18*pow(2,-8+14*Double($0)/Double(width-1))}),
                                (title,logY)],characteristic,title:title+" · exposure −8 to +6 EV",xMaximum:14)
            try artifacts.plot([( "Identity",(0..<width).map{4*Double($0)/Double(width-1)}),
                                ("Red",values[1].1),("Green",values[2].1),("Blue",values[3].1)],
                               channel,title:title+" · channel response",xMaximum:4)
            c.images=[characteristic,channel];cases.append(c)
            all.append((title,logY))
            let h=try render(hdr,[fx]),hPixels=gpu.read(h,line)
            let hY=(0..<width).map{LabGPU.luma(hPixels,$0*4)}
            let hSteps=zip(hY.dropFirst(),hY).map{$0-$1}
            var hc=LabCase(name:"FE_HDR_"+key)
            hc.metrics=["outputAt8":hY.last ?? 0,
                        "reversals":Double(hSteps.filter{$0 < -1e-6}.count),
                        "nonFinitePixels":Double(gpu.compare(hdr,h,region:line).nonFinite)]
            hc.check("Monotonic HDR",hc.metrics["reversals"]==0,hard:true,"0–8 linear luminance.")
            hc.check("No premature clamp",(hY.last ?? 0)>1.2,hard:true,"HDR output stays extended.")
            hc.check("Finite HDR",hc.metrics["nonFinitePixels"]==0,hard:true,"No NaN/Inf.")
            cases.append(hc)
            hdrSeries.append((title,hY))
        }
        try artifacts.plot(all,"FilmEmulation/all_characteristic_curves.png",
                           title:"Seven film responses · exposure −8 to +6 EV",xMaximum:14)
        try artifacts.plot(hdrSeries,"FilmEmulation/hdr_response.png",
                           title:"HDR response · linear input 0–8",xMaximum:8)
        let negative=filmRamp(width:2048){x in
            let v=Float(-0.03+0.18*x);return SIMD3(v,v*0.7,v*1.2)
        }
        let n=try render(negative,[filmPreset("Dense Slide")])
        let m=gpu.compare(negative,n)
        var c=LabCase(name:"FE_negative_extended_RGB")
        c.metrics=["nonFinitePixels":Double(m.nonFinite),"maxRGBError":m.maxError]
        c.check("Finite negative continuation",m.nonFinite==0,hard:true,
                "Below zero the curve uses the analytic tangent at the origin.")
        cases.append(c)
    }
}
