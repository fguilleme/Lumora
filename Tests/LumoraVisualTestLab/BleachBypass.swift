import Foundation
import CoreImage
@testable import LumoraCore

struct BleachBypassTestChart {
    let image: CIImage
    let regions: [ChartRegion]
    static let names = ["gray-ramp", "dark-texture", "mid-texture", "bright-texture",
                        "light-skin", "dark-skin", "red", "green",
                        "blue", "cyan", "magenta", "yellow",
                        "white-highlight", "near-black", "hard-edge", "soft-gradient"]
    static func generate(size: Int) -> Self {
        let colors: [SIMD3<Float>] = [SIMD3(0.58,0.34,0.24), SIMD3(0.27,0.14,0.095),
                                        SIMD3(0.75,0.04,0.03), SIMD3(0.04,0.7,0.08),
                                        SIMD3(0.04,0.1,0.8), SIMD3(0.05,0.72,0.72),
                                        SIMD3(0.72,0.05,0.7), SIMD3(0.83,0.75,0.05)]
        let image = SyntheticCharts.make(size:size) { x,y in
            let col=min(3,Int(x*4)), row=min(3,Int(y*4)), index=row*4+col
            let u=x*4-Double(col), v=y*4-Double(row)
            let wave=sin(u*82)*sin(v*71)
            switch index {
            case 0: return SIMD3(repeating:Float(u))
            case 1: return SIMD3(repeating:Float(0.055+0.022*wave))
            case 2: return SIMD3(repeating:Float(0.40+0.075*wave))
            case 3: return SIMD3(repeating:Float(0.78+0.075*wave))
            case 4...11: return colors[index-4]
            case 12: return SIMD3(repeating:Float(0.88+0.10*u))
            case 13: return SIMD3(repeating:Float(0.018+0.012*wave))
            case 14: return SIMD3(repeating:u<0.5 ? 0.035:0.92)
            default: return SIMD3(repeating:Float(0.1+0.8*(u*u*(3-2*u))))
            }
        }
        let side=size/4
        let regions=names.enumerated().map { i,name in
            ChartRegion(name:name,x:(i%4)*side,y:size-(i/4+1)*side,
                        width:side,height:side,ramp:name == "gray-ramp")
        }
        return Self(image:image,regions:regions)
    }
    func rect(_ name:String) -> CGRect { regions.first{$0.name == name}!.rect }
}

extension LumoraVisualTestLab {
    private func bleachPreset(_ title:String) -> CreativeEffect {
        CreativeFXPreset.all(for:.bleachBypass).first{$0.title == title}!.makeEffect()
    }
    private func bleachCrop(_ image:CIImage,x:Double,y:Double,side:Int=512) -> CIImage {
        let s=min(CGFloat(side),image.extent.width,image.extent.height)
        let px=min(image.extent.maxX-s,max(image.extent.minX,image.extent.minX+image.extent.width*x-s/2))
        let py=min(image.extent.maxY-s,max(image.extent.minY,image.extent.minY+image.extent.height*y-s/2))
        return image.cropped(to:CGRect(x:floor(px),y:floor(py),width:s,height:s))
    }
    private func bleachChroma(_ image:CIImage,_ rect:CGRect) -> Double {
        let p=gpu.read(image,rect.integral)
        var sum=0.0,count=0
        for i in stride(from:0,to:p.count,by:4) {
            let rgb=(0..<3).map{max(0,Double(p[i+$0]))}
            let hi=rgb.max()!,lo=rgb.min()!
            sum += hi-lo;count += 1
        }
        return sum/Double(max(1,count))
    }
    private func bleachHue(_ before:CIImage,_ after:CIImage,_ rect:CGRect) -> Double {
        let a=gpu.read(before,rect.integral),b=gpu.read(after,rect.integral)
        var error=0.0,count=0
        for i in stride(from:0,to:a.count,by:4) {
            let aa=(0..<3).map{max(0,Double(a[i+$0]))},bb=(0..<3).map{max(0,Double(b[i+$0]))}
            let u1=2*aa[0]-aa[1]-aa[2],v1=sqrt(3.0)*(aa[1]-aa[2])
            let u2=2*bb[0]-bb[1]-bb[2],v2=sqrt(3.0)*(bb[1]-bb[2])
            guard hypot(u1,v1)>1e-5,hypot(u2,v2)>1e-5 else {continue}
            let angle=abs(atan2(v1,u1)-atan2(v2,u2))
            error += min(angle,2*Double.pi-angle)/Double.pi
            count += 1
        }
        return error/Double(max(1,count))
    }
    func runBleachBypass() async throws {
        progress("Bleach Bypass synthetic chart")
        let chart=BleachBypassTestChart.generate(size:1024)
        try artifacts.png(chart.image,"BleachBypass/BleachBypassTestChart.png")
        try artifacts.json(chart.regions,"BleachBypass/chart_regions.json")
        do {
            try bleachSynthetic(chart)
            try bleachMasksAndStack(chart)
            try bleachResolutionPerformance()
            try await bleachPipeline(chart)
            try bleachPhotos()
        } catch {
            var c=LabCase(name:"BB_harness")
            c.check("Completed",false,hard:true,String(describing:error));cases.append(c)
            try bleachReport()
            throw error
        }
        try bleachReport()
    }
    private func bleachSynthetic(_ chart:BleachBypassTestChart) throws {
        let zero=try render(chart.image,[effect(.bleachBypass,["amount":0])])
        let neutral=gpu.compare(chart.image,zero)
        var identity=LabCase(name:"BB_identity")
        identity.metrics=["maxRGBError":neutral.maxError,"meanLuminanceChange":neutral.residual.mean,
                          "chromaticityDrift":neutral.chromaticityMAE,"nonFinitePixels":Double(neutral.nonFinite)]
        identity.check("Amount zero exact identity",neutral.maxError == 0,hard:true,"Production stack returns the original CI graph.")
        identity.check("Finite",neutral.nonFinite == 0,hard:true,"No NaN/Inf RGBA pixels.")
        cases.append(identity)

        let classicPreset=CreativeFXPreset.all(for:.bleachBypass).first{$0.title == "Classic Bypass"}!
        var existing=CreativeEffect(.bleachBypass,maskID:UUID())
        let originalID=existing.id,originalMask=existing.maskID
        existing=classicPreset.applying(to:existing)
        let matched=CreativeFXPreset.matching(existing)?.title == "Classic Bypass"
        existing["bleach"] += 1
        let custom=CreativeFXPreset.matching(existing) == nil
        var before=EditState(),after=before
        before.creative.effects=[classicPreset.makeEffect()]
        after.creative.effects=[existing]
        var history=HistoryManager();history.begin("Bleach slider",state:before);history.commit(after)
        let undone=history.undo(),redone=history.redo()
        let decoded=try JSONDecoder().decode(EditState.self,from:JSONEncoder().encode(after))
        var presetCase=LabCase(name:"BB_preset_history")
        presetCase.check("Preset snapshot matches",matched,hard:true,"Common preset matcher selects Classic.")
        presetCase.check("Slider becomes Custom",custom,hard:true,"Changing Bleach no longer matches a preset.")
        presetCase.check("Effect and mask identity retained",existing.id == originalID && existing.maskID == originalMask,
                         hard:true,"Preset application preserves stack identity and mask assignment.")
        presetCase.check("Undo/Redo restores states",undone == before && redone == after,hard:true,
                         "Unchanged EditState transaction machinery.")
        presetCase.check("Document round trip",decoded == after,hard:true,"Bleach settings survive Codable persistence.")
        cases.append(presetCase)

        let titles=["Subtle Bypass","Classic Bypass","Soft Silver","Hard Silver","Cinematic","Extreme Bypass"]
        var outputs:[String:CIImage]=[:]
        let ramp=chart.rect("gray-ramp")
        var curves:[(String,[Double])]=[]
        for title in titles {
            let fx=bleachPreset(title),output=try render(chart.image,[fx]);outputs[title]=output
            let comparison=gpu.compare(chart.image,output)
            let rampComparison=gpu.compare(chart.image,output,region:ramp,ramp:true)
            let key=title.lowercased().replacingOccurrences(of:" ",with:"_")
            var c=LabCase(name:"BB_"+key)
            c.metrics=["meanLuminanceChange":comparison.residual.mean,
                       "maxRGBError":comparison.maxError,"nonFinitePixels":Double(comparison.nonFinite),
                       "rampReversals":Double(rampComparison.monotonicityViolations),
                       "meanChroma":bleachChroma(output,chart.image.extent)]
            c.check("Finite",comparison.nonFinite == 0,hard:true,"RGBAf output has no NaN/Inf.")
            c.check("Monotone neutral curve",rampComparison.monotonicityViolations == 0,hard:true,
                    "No adjacent tonal inversion below -1e-6 on the neutral ramp.")
            c.images=["BleachBypass/\(key).png"]
            try artifacts.png(output,c.images[0])
            try artifacts.json(fx,"BleachBypass/\(key)_settings.json")
            curves.append((title,rampComparison.transferOutput))
            cases.append(c)
        }
        let originalRamp=gpu.compare(chart.image,chart.image,region:ramp,ramp:true).transferInput
        try artifacts.plot([("Original",originalRamp)]+curves.filter{["Subtle Bypass","Classic Bypass","Hard Silver","Extreme Bypass"].contains($0.0)},
                           "BleachBypass/tone_curve_response.png",title:"Bleach Bypass — linear tone response",yRange:0...1)
        let chroma=titles.map { ($0,bleachChroma(outputs[$0]!,chart.image.extent)) }
        var saturation=LabCase(name:"BB_saturation")
        for (title,value) in chroma { saturation.metrics[title]=value }
        saturation.check("Subtle retains more chroma than Classic",chroma[0].1>chroma[1].1,
                         "Quality heuristic on the synthetic color chart.")
        saturation.check("Classic retains more chroma than Hard Silver",chroma[1].1>chroma[3].1,
                         "Quality heuristic; Soft Silver has a separate soft-tone intent.")
        saturation.check("Hard Silver retains more chroma than Extreme",chroma[3].1>chroma[5].1,
                         "Quality heuristic on residual color.")
        cases.append(saturation)
        let classic=outputs["Classic Bypass"]!
        for name in ["light-skin","dark-skin","red","green","blue","cyan","magenta","yellow"] {
            let roi=chart.rect(name).insetBy(dx:12,dy:12),m=gpu.compare(chart.image,classic,region:roi)
            var c=LabCase(name:"BB_color_"+name)
            c.metrics=["sourceY":m.input.mean,"outputY":m.output.mean,
                       "sourceChroma":bleachChroma(chart.image,roi),"outputChroma":bleachChroma(classic,roi),
                       "hueDrift":bleachHue(chart.image,classic,roi),
                       "chromaticityDrift":m.chromaticityMAE,"nonFinitePixels":Double(m.nonFinite)]
            c.check("Finite",m.nonFinite == 0,hard:true,"Controlled patch RGBAf.")
            c.check("Residual hue stability",c.metrics["hueDrift"]!<0.12,
                    "Quality heuristic; desaturation may reduce saturation substantially.")
            cases.append(c)
        }
        let dark=chart.rect("dark-texture").insetBy(dx:10,dy:10)
        let lowDensity=try render(chart.image,[effect(.bleachBypass,["amount":85,"blackDensity":0,"shadowProtection":0])])
        let highDensity=try render(chart.image,[effect(.bleachBypass,["amount":85,"blackDensity":100,"shadowProtection":0])])
        let protected=try render(chart.image,[effect(.bleachBypass,["amount":85,"blackDensity":100,"shadowProtection":100])])
        let dark0=gpu.compare(chart.image,lowDensity,region:dark)
        let dark1=gpu.compare(chart.image,highDensity,region:dark)
        let dark2=gpu.compare(chart.image,protected,region:dark)
        var shadows=LabCase(name:"BB_shadow_density")
        shadows.metrics=["lowDensityMeanY":dark0.output.mean,"highDensityMeanY":dark1.output.mean,
                         "protectedMeanY":dark2.output.mean,"sourceRMS":sqrt(dark0.input.variance),
                         "highDensityRMS":sqrt(dark1.output.variance),
                         "protectedRMS":sqrt(dark2.output.variance)]
        shadows.check("Density darkens",dark1.output.mean<dark0.output.mean,
                      "Quality heuristic; shadow detail is reported by RMS.")
        shadows.check("Protection retains dark luminance",dark2.output.mean>dark1.output.mean,
                      "Quality heuristic on the dark textured patch.")
        cases.append(shadows)
        try artifacts.sheet([("Original",chart.image),("Density 0",lowDensity),("Density 100",highDensity),
                             ("Protected",protected)],"BleachBypass/shadow_density_comparison.png",cell:512)
        let highlight=chart.rect("white-highlight").insetBy(dx:8,dy:8)
        let noRoll=try render(chart.image,[effect(.bleachBypass,["amount":90,"highlightRollOff":0])])
        let roll=try render(chart.image,[effect(.bleachBypass,["amount":90,"highlightRollOff":100])])
        let noStats=gpu.compare(chart.image,noRoll,region:highlight,ramp:true)
        let rollStats=gpu.compare(chart.image,roll,region:highlight,ramp:true)
        var lights=LabCase(name:"BB_highlights")
        lights.metrics=["noRollPeakY":noStats.output.max,"rollPeakY":rollStats.output.max,
                        "noRollMeanY":noStats.output.mean,"rollMeanY":rollStats.output.mean,
                        "noRollClippedPixels":Double(noStats.whiteOutput),"rollClippedPixels":Double(rollStats.whiteOutput),
                        "noRollEndpointSlope":(noStats.transferOutput.last ?? 0)-(noStats.transferOutput.dropLast().last ?? 0),
                        "rollEndpointSlope":(rollStats.transferOutput.last ?? 0)-(rollStats.transferOutput.dropLast().last ?? 0)]
        lights.check("Roll-off lowers highlight mean",rollStats.output.mean<noStats.output.mean,
                     "Quality heuristic on 0.88...0.98 synthetic whites.")
        cases.append(lights)
        try artifacts.plot([("Input",gpu.compare(chart.image,chart.image,region:highlight,ramp:true).transferInput),
                            ("Roll-off 0",noStats.transferOutput),("Roll-off 100",rollStats.transferOutput)],
                           "BleachBypass/highlight_rolloff_profile.png",title:"Near-white response")
        try artifacts.sheet([("Original",chart.image),("Roll-off 0",noRoll),("Roll-off 100",roll)],
                           "BleachBypass/highlight_comparison.png",cell:512,maxColumns:3)

        let mono=try render(chart.image,[effect(.bleachBypass,["amount":100,"bleach":100])])
        let color=try render(chart.image,[effect(.bleachBypass,["amount":100,"bleach":0])])
        try artifacts.sheet([("Original",chart.image),("Monochrome density",mono),
                             ("Color tone layer",color),("Classic blend",classic)],
                           "BleachBypass/layer_decomposition.png",cell:512)
        // Intentionally simple comparator: linear-Y chroma attenuation plus
        // one global S curve, matched only approximately in overall strength.
        let chartPixels=gpu.read(chart.image,chart.image.extent)
        let baseline=SyntheticCharts.make(size:1024) { x,y in
            let index=4*(min(1023,Int(y*1024))*1024+min(1023,Int(x*1024)))
            let rgb=SIMD3(Double(chartPixels[index]),Double(chartPixels[index+1]),Double(chartPixels[index+2]))
            let l=0.2126*rgb.x+0.7152*rgb.y+0.0722*rgb.z
            let tone=max(0,l+0.22*l*(1-l)*(2*l-1))
            let next=SIMD3<Double>(repeating:tone)+(rgb-SIMD3(repeating:l))*0.60
            return SIMD3(Float(next.x),Float(next.y),Float(next.z))
        }
        let baselineDiff=gpu.compare(baseline,classic)
        var compare=LabCase(name:"BB_vs_simple_desaturation")
        compare.metrics=["baselineToBleachMAE":baselineDiff.mae,
                         "baselineMeanChroma":bleachChroma(baseline,chart.image.extent),
                         "bleachMeanChroma":bleachChroma(classic,chart.image.extent),
                         "baselineShadowY":gpu.compare(chart.image,baseline,region:dark).output.mean,
                         "bleachShadowY":gpu.compare(chart.image,classic,region:dark).output.mean,
                         "baselineHighlightY":gpu.compare(chart.image,baseline,region:highlight).output.mean,
                         "bleachHighlightY":gpu.compare(chart.image,classic,region:highlight).output.mean]
        compare.check("Structured result differs",baselineDiff.mae>1e-4,hard:true,
                      "Baseline uses only a global S curve and linear-Y chroma scaling.")
        cases.append(compare)
        try artifacts.sheet([("Original",chart.image),("Simple baseline",baseline),("Bleach Bypass",classic),
                             ("Difference x8",artifacts.difference(baseline,classic,gain:8))],
                           "BleachBypass/bleach_vs_simple_desat.png",cell:512)
        let comparisonReport="""
        # Bleach Bypass vs simple desaturation

        Baseline: linear Rec.709 Y, `Y' = Y + 0.22·Y·(1−Y)·(2Y−1)`, RGB residual chroma ×0.60. It has no separate density layer, toe, shoulder or shadow guard. Both renderings use the same synthetic chart; Bleach Bypass uses the production Classic preset.

        - Mean absolute RGB difference: \(baselineDiff.mae)
        - Mean chroma: simple \(compare.metrics["baselineMeanChroma"]!), Bleach \(compare.metrics["bleachMeanChroma"]!)
        - Dark textured mean Y: simple \(compare.metrics["baselineShadowY"]!), Bleach \(compare.metrics["bleachShadowY"]!)
        - Near-white mean Y: simple \(compare.metrics["baselineHighlightY"]!), Bleach \(compare.metrics["bleachHighlightY"]!)

        [Comparison and amplified difference](BleachBypass/bleach_vs_simple_desat.png). These measurements demonstrate structural difference, not aesthetic superiority.
        """
        try comparisonReport.write(to:artifacts.url("BleachBypass_vs_simple_desaturation.md"),atomically:true,encoding:.utf8)
    }
}

extension LumoraVisualTestLab {
    private func bleachPriority(_ index:Int) -> [(String,Double,Double)] {
        switch index {
        case 0: return [("skin",0.5,0.5),("hair",0.5,0.77)]
        case 1: return [("skin",0.5,0.5),("dark hair",0.5,0.77)]
        case 2: return [("clouds",0.5,0.28),("ridge",0.5,0.57)]
        case 3: return [("hair",0.48,0.57),("sun",0.5,0.28)]
        case 4: return [("street lamps",0.5,0.25),("dark stone",0.5,0.68)]
        case 5: return [("sunlit wall",0.5,0.3),("dark interior",0.5,0.7)]
        case 6: return [("white dress",0.5,0.68),("skin",0.5,0.52)]
        default:return [("skin",0.5,0.5),("knit",0.5,0.58),("water",0.5,0.25)]
        }
    }
    private func bleachPhotos() throws {
        let repo=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let folder=URL(fileURLWithPath:ProcessInfo.processInfo.environment["LUMORA_VISUAL_ASSETS"]
            ?? repo.appendingPathComponent("VisualTestAssets").path)
        let files=try FileManager.default.contentsOfDirectory(at:folder,includingPropertiesForKeys:nil)
            .filter{["png","jpg","jpeg","tif","tiff","heic"].contains($0.pathExtension.lowercased())}
            .sorted{$0.lastPathComponent<$1.lastPathComponent}
        guard files.count == 8 else {throw NSError(domain:"BleachBypassLab",code:1,
            userInfo:[NSLocalizedDescriptionKey:"Expected eight photos; found \(files.count) in \(folder.path)"])}
        let titles=["Subtle Bypass","Classic Bypass","Soft Silver","Hard Silver","Cinematic","Extreme Bypass"]
        for (index,file) in files.enumerated() {
            progress("Bleach photo \(index+1)/8: \(file.lastPathComponent)")
            try autoreleasepool {
                guard var input=CIImage(contentsOf:file,options:[.applyOrientationProperty:true]) else {throw LabError.render}
                input=input.transformed(by:CGAffineTransform(translationX:-input.extent.minX,y:-input.extent.minY))
                let root="BleachBypass/RealPhotos/"+file.deletingPathExtension().lastPathComponent
                try artifacts.png(input,root+"/Original.png")
                let centers=bleachPriority(index)
                var sheet:[(String,CIImage)]=[("Original",input)]
                var crops:[(String,CIImage)]=centers.map { ("Original · \($0.0)",bleachCrop(input,x:$0.1,y:$0.2)) }
                var outputs:[String:CIImage]=[:]
                var c=LabCase(name:"BB_photo_"+file.deletingPathExtension().lastPathComponent)
                c.notes=["Manual photographic judgment only; no Golden Master.",
                         "Native 512 px crop centers: \(centers.map{"\($0.0)=(\($0.1),\($0.2))"}.joined(separator:", "))."]
                for title in titles {
                    let fx=bleachPreset(title).validated
                    let output=try render(input,[fx])
                    let key=title.lowercased().replacingOccurrences(of:" ",with:"_")
                    let path=root+"/"+key
                    try artifacts.png(output,path+".png")
                    try artifacts.png(artifacts.difference(input,output,gain:6),path+"_difference_x6.png")
                    try artifacts.json(fx,path+"_settings.json")
                    let a=normalized(input,to:512),b=normalized(output,to:512),m=gpu.compare(a,b)
                    c.metrics[key+"-meanLuminanceChange"]=m.residual.mean
                    c.metrics[key+"-chromaticityDrift"]=m.chromaticityMAE
                    c.metrics[key+"-meanChromaChange"]=bleachChroma(b,b.extent)-bleachChroma(a,a.extent)
                    c.metrics[key+"-nonFinitePixels"]=Double(m.nonFinite)
                    c.check("Finite \(title)",m.nonFinite == 0,hard:true,"512 px photographic sample in RGBAf.")
                    outputs[title]=output;sheet.append((title,output))
                    for (label,x,y) in centers {
                        crops.append(("\(title) · \(label)",bleachCrop(output,x:x,y:y)))
                    }
                }
                let contact=root+"/BleachBypass_contact_sheet.png"
                let native=root+"/BleachBypass_crops_100percent.png"
                try artifacts.sheet(sheet,contact,cell:960,maxColumns:3)
                try artifacts.sheet(crops,native,nativeCrop:true,cell:512,maxColumns:4)
                c.images=[contact,native]
                if index <= 1 || index == 4 || index == 6 {
                    let special=index <= 1 ? "portrait_bleach_comparison.png"
                        : index == 4 ? "night_bleach_comparison.png":"white_subject_bleach_comparison.png"
                    let point=centers[0]
                    let items:[(String,CIImage)]=[("Original",input)]+titles.compactMap { title in
                        outputs[title].map { (title,$0) }
                    }
                    try artifacts.sheet(items.map { ($0.0,bleachCrop($0.1,x:point.1,y:point.2)) },
                                        root+"/"+special,nativeCrop:true,cell:512,maxColumns:4)
                    c.images.append(root+"/"+special)
                }
                cases.append(c)
            }
        }
    }
    private func bleachReport() throws {
        let selected=cases.filter{$0.name.hasPrefix("BB_")}
        try artifacts.json(selected,"BleachBypass/metrics.json")
        let counts=Dictionary(grouping:selected,by:\.status).mapValues(\.count)
        let presets=CreativeFXPreset.all(for:.bleachBypass)
        let lines=selected.map { c in
            "| \(c.name) | \(c.status) | \(c.checks.filter{$0.hard && $0.status == "FAIL"}.count) | \(c.checks.filter{$0.status == "WARN"}.count) | \(c.metrics.keys.sorted().map{"\($0)=\(String(format:"%.5g",c.metrics[$0]!))"}.joined(separator:"; ")) | \(c.images.map{"[image](\($0))"}.joined(separator:" ")) |"
        }.joined(separator:"\n")
        let report="""
        # Bleach Bypass — validation

        Production integration: `CreativeEffectKind.bleachBypass` → ordered `CreativeStackRenderer` → `BleachBypassRenderer` → the existing mask/opacity compositor, `RenderEngine` preview/HQ/export and normal `HistoryManager`. One pointwise Metal kernel, no CPU readback during editing, no spatial blur and no generated grain. Working domain: extended linear sRGB; Rec.709 luminance `Y=0.2126R+0.7152G+0.0722B`. No Golden Master.

        ## Photographic equation

        With `t=min(Y,1)`, `q=t(1−t)`, each layer uses `F(t)=t+cq(2t−1)−dt(1−t)²−ht²(1−t)`. The color layer uses `(c,d,h)=(0.25·Contrast,0.06·BlackDensity,0.08·HighlightRollOff)`. The silver-density layer uses `(0.38·Contrast,0.14·BlackDensity,0.12·HighlightRollOff)`. Those bounded coefficients retain a positive derivative on `[0,1]`; the HDR continuation above 1 matches the derivative at 1 and compresses progressively as `1+slope·(Y−1)/(1+0.65·HighlightRollOff·(Y−1))`. The color layer scales source RGB by `F_color(Y)/Y`; the silver layer is neutral `F_silver(Y)`. Bleach mixes their layers; Saturation scales only residual chroma around the blended Y, with slider zero as neutral. Shadow Protection multiplies the final Amount by a smooth guard rising between Y=0.005 and 0.22. Amount zero returns the input graph exactly.

        ## Contract and scope

        **Hard invariants:** Amount-zero identity, finite pixels, monotone ramp, mask isolation, effective mask response, preset/Custom and Undo/Redo state, actual stack order and preview cache invalidation. **Quality heuristics:** chroma hierarchy, hue drift, density and highlight behavior, cross-resolution agreement, preview/export similarity. Hue drift is the wrapped angular difference in the linear RGB opponent plane `(2R−G−B, √3·(G−B))`, normalized by π; chromaticity drift is reported separately, because desaturation changes RGB proportions without necessarily rotating hue. Timings are descriptive, without a machine-dependent threshold. `PASS` means no recorded issue; `WARN` marks photographic heuristics for review; `FAIL` marks a broken hard invariant. Counts: PASS \(counts["PASS"] ?? 0), WARN \(counts["WARN"] ?? 0), FAIL \(counts["FAIL"] ?? 0).

        Original presets: \(presets.map{$0.title}.joined(separator:", ")). Exact effective values are in each `*_settings.json` file. The preset selector uses the existing snapshot matcher: manual slider edits become Custom; applying a preset preserves effect ID, mask and stack position. Undo/Redo uses unchanged EditState transactions. The UI exposes Amount, Bleach, Contrast, Saturation, with Black Density, Highlight Roll-Off and Shadow Protection under Advanced.

        Synthetic chart includes neutral ramp, textured shadows/mid/high tones, light/dark skin, red/green/blue/cyan/magenta/yellow, near white/black, hard edge and soft gradient. [Chart](BleachBypass/BleachBypassTestChart.png), [tone curves](BleachBypass/tone_curve_response.png), [shadow density](BleachBypass/shadow_density_comparison.png), [highlight comparison](BleachBypass/highlight_comparison.png), [highlight profile](BleachBypass/highlight_rolloff_profile.png), [layer decomposition](BleachBypass/layer_decomposition.png), [simple-desaturation comparison](BleachBypass/bleach_vs_simple_desat.png), [separate baseline report](BleachBypass_vs_simple_desaturation.md), [mask comparison](BleachBypass/mask_comparison.png).

        The eight photographs are rendered with all six variants. Every photograph has a full-resolution contact sheet, native 100% crops around the requested subjects, per-variant difference maps and exact settings JSON. Portraits 01/02, night 05 and white subject 07 have dedicated comparison sheets. The numeric photographic metrics aid manual inspection and are not aesthetic verdicts.

        | Case | Status | Hard failures | Warnings | Metrics | Artifacts |
        |---|---|---:|---:|---|---|
        \(lines)
        """
        try report.write(to:artifacts.url("BleachBypassValidationReport.md"),atomically:true,encoding:.utf8)
    }
}

extension LumoraVisualTestLab {
    private func bleachMasksAndStack(_ chart:BleachBypassTestChart) throws {
        progress("Bleach Bypass masks and stack order")
        let source=chart.image,fx=bleachPreset("Hard Silver")
        var radial=RadialGradientMask();radial.center=MaskPoint(x:0.35,y:0.5)
        radial.radiusX=0.19;radial.radiusY=0.19;radial.feather=4
        let mask=LocalMask(name:"Bleach region",components:[MaskComponent(shape:.radial(radial))])
        var targeted=fx;targeted.maskID=mask.id
        let simple=try render(source,[targeted],masks:[mask])
        var inverse=mask;inverse.inverted=true
        let inverted=try render(source,[targeted],masks:[inverse])
        var otherRadial=radial;otherRadial.center=MaskPoint(x:0.75,y:0.5)
        let other=LocalMask(name:"Second region",components:[MaskComponent(shape:.radial(otherRadial))])
        var second=fx;second.maskID=other.id
        let stacked=try render(source,[targeted,second],masks:[mask,other])
        var hole=radial;hole.radiusX=0.055;hole.radiusY=0.055;hole.feather=0
        let subtraction=LocalMask(name:"Bleach minus centre",components:[
            MaskComponent(operation:.add,shape:.radial(radial)),
            MaskComponent(operation:.subtract,shape:.radial(hole))])
        var cutFX=fx;cutFX.maskID=subtraction.id
        let cut=try render(source,[cutFX],masks:[subtraction])
        let outside=CGRect(x:10,y:10,width:64,height:64)
        let center=CGRect(x:344,y:496,width:24,height:24)
        let otherCenter=CGRect(x:756,y:496,width:24,height:24)
        var c=LabCase(name:"BB_masks")
        c.metrics=["simpleOutsideMaxError":gpu.compare(source,simple,region:outside).maxError,
                   "invertedCenterMaxError":gpu.compare(source,inverted,region:center).maxError,
                   "stackedOutsideMaxError":gpu.compare(source,stacked,region:outside).maxError,
                   "subtractiveCenterMaxError":gpu.compare(source,cut,region:center).maxError,
                   "simpleCenterMAE":gpu.compare(source,simple,region:center).mae,
                   "stackedSecondMAE":gpu.compare(source,stacked,region:otherCenter).mae]
        for key in ["simpleOutsideMaxError","invertedCenterMaxError","stackedOutsideMaxError","subtractiveCenterMaxError"] {
            c.check("Mask isolation \(key)",c.metrics[key]!<2e-6,hard:true,
                    "The existing mask compositor preserves pixels outside the effective mask.")
        }
        c.check("Masked regions respond",c.metrics["simpleCenterMAE"]!>1e-6 && c.metrics["stackedSecondMAE"]!>1e-6,
                hard:true,"Both independently targeted regions respond.")
        c.images=["BleachBypass/mask_comparison.png"]
        try artifacts.sheet([("Original",source),("Simple",simple),("Inverted",inverted),
                             ("Stacked",stacked),("Subtractive",cut)],c.images[0],cell:512,maxColumns:3)
        cases.append(c)
        let others:[(String,CreativeEffect)]=[
            ("Grain",effect(.grain,["amount":75,"size":45])),
            ("Tonal Contrast",CreativeFXPreset.all(for:.tonalContrast).first{$0.title=="Strong Structure"}!.makeEffect()),
            ("Glamour Glow",CreativeFXPreset.all(for:.glamourGlow).first{$0.title=="Strong Glow"}!.makeEffect()),
            ("Detail Extractor",CreativeFXPreset.all(for:.detailExtractor).first{$0.title=="Natural Detail"}!.makeEffect())]
        for (name,otherFX) in others {
            let forward=try render(source,[fx,otherFX]),reverse=try render(source,[otherFX,fx])
            let m=gpu.compare(forward,reverse)
            var order=LabCase(name:"BB_stack_"+name.replacingOccurrences(of:" ",with:"_"))
            order.metrics=["forwardReverseMAE":m.mae,"nonFinitePixels":Double(m.nonFinite)]
            if name == "Grain" {
                let clean=try render(source,[fx])
                let roi=CGRect(x:384,y:384,width:256,height:256)
                let after = gpu.structure(clean,forward,region:roi)
                let before=gpu.structure(clean,reverse,region:roi)
                order.metrics["grainAfterSpectralCentroid"]=after.spectralCentroid
                order.metrics["grainBeforeSpectralCentroid"]=before.spectralCentroid
                order.metrics["grainAfterResidualEdgeRMS"]=after.edgeRMS
                order.metrics["grainBeforeResidualEdgeRMS"]=before.edgeRMS
                order.check("Grain after retains edge energy",after.edgeRMS>=before.edgeRMS*0.90,
                            "Quality heuristic; compare fine residual edges around a common Bleach-only baseline.")
            }
            order.check("Different order changes pixels",m.mae>1e-6,hard:true,
                        "The production ordered stack is intentionally noncommutative.")
            order.check("Finite",m.nonFinite == 0,hard:true,"No NaN/Inf in either order.")
            let path="BleachBypass/stack_"+name.lowercased().replacingOccurrences(of:" ",with:"_")+".png"
            try artifacts.sheet([("Bleach → \(name)",forward),("\(name) → Bleach",reverse),
                                 ("Difference x8",artifacts.difference(forward,reverse,gain:8))],
                                path,cell:512,maxColumns:3)
            order.images=[path];cases.append(order)
        }
    }
    private func bleachResolutionPerformance() throws {
        progress("Bleach Bypass resolution and GPU timing")
        var c=LabCase(name:"BB_resolution_performance")
        var reference:CIImage?
        for dimension in [1024,2048,4096] {
            try autoreleasepool {
                let source=SyntheticCharts.make(size:dimension) { x,y in
                    let texture=0.03*sin(x*97)*sin(y*83)
                    return SIMD3(Float(0.10+0.72*x+texture),Float(0.07+0.68*y+texture),
                                 Float(0.12+0.58*(x+y)/2+texture))
                }
                let start=ProcessInfo.processInfo.systemUptime
                let output=try render(source,[bleachPreset("Classic Bypass")])
                let sample=normalized(output,to:512)
                let m=gpu.compare(normalized(source,to:512),sample)
                c.metrics["\(dimension)-milliseconds"]=(ProcessInfo.processInfo.systemUptime-start)*1000
                c.metrics["\(dimension)-nonFinitePixels"]=Double(m.nonFinite)
                c.check("Finite \(dimension)",m.nonFinite == 0,hard:true,"GPU output sampled at 512 pixels.")
                if let reference {
                    let agreement=gpu.compare(reference,sample)
                    c.metrics["\(dimension)-normalizedRMSE"]=agreement.rmse
                    c.check("Resolution agreement \(dimension)",agreement.rmse<0.01,
                            "Quality heuristic after resizing the same analytic scene.")
                } else {reference=sample}
                try artifacts.png(sample,"BleachBypass/resolution_\(dimension).png")
            }
        }
        cases.append(c)
    }
    private func bleachPipeline(_ chart:BleachBypassTestChart) async throws {
        progress("Bleach Bypass preview, HQ and export")
        let source=normalized(chart.image,to:2048)
        let path=try artifacts.url("BleachBypass/Pipeline/source.png")
        try artifacts.png(source,"BleachBypass/Pipeline/source.png")
        let engine=RenderEngine()
        var state=EditState();state.creative.effects=[bleachPreset("Classic Bypass")]
        var c=LabCase(name:"BB_preview_HQ_export")
        var images:[(String,CIImage)]=[]
        for quality in [PreviewQuality.interactive,.high] {
            let result=try await engine.render(url:path,state:state,quality:quality)
            let title=quality == .interactive ? "interactive":"HQ"
            c.metrics[title+"-milliseconds"]=result.milliseconds
            c.metrics[title+"-width"]=Double(result.image.width)
            images.append((title,CIImage(cgImage:result.image)))
        }
        let repeatResult=try await engine.render(url:path,state:state,quality:.interactive)
        c.check("Preview cache hit",repeatResult.cacheHit,hard:true,"Second render uses the source cache.")
        state.creative.effects[0]["bleach"]=90
        let changed=try await engine.render(url:path,state:state,quality:.interactive)
        let changedImage=CIImage(cgImage:changed.image)
        c.metrics["parameterChangeMAE"]=gpu.compare(images[0].1,changedImage).mae
        c.check("Slider invalidates output",c.metrics["parameterChangeMAE"]!>1e-6,hard:true,
                "Changing Bleach changes the preview.")
        var settings=ExportSettings();settings.format = .png
        settings.colorSpace = .displayP3;settings.includeMetadata = false
        let exported=try await engine.export(request:ExportRequest(sourceURL:path,state:state,name:"bleach-bypass-lab"),
                                             settings:settings,directory:artifacts.url("BleachBypass/Pipeline/Export"))
        guard let exportImage=CIImage(contentsOf:exported.url) else {throw LabError.render}
        c.metrics["exportWidth"]=Double(exported.width)
        let agreement=gpu.compare(normalized(changedImage,to:512),normalized(exportImage,to:512))
        c.metrics["previewExportSSIM"]=agreement.ssim
        c.check("Preview/export agreement",agreement.ssim>0.9,
                "Quality heuristic after raster and color-space conversion.")
        images += [("Changed preview",changedImage),("Export",exportImage)]
        c.images=["BleachBypass/Pipeline/comparison.png"]
        try artifacts.sheet(images,c.images[0],cell:512)
        cases.append(c)
    }
}
