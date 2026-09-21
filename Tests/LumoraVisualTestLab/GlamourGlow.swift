import Foundation
import CoreImage
import CryptoKit
@testable import LumoraCore

/// Twelve analytic tiles in extended linear sRGB. Coordinates are based on the
/// full photographic frame, so the same scene can be regenerated at any size.
struct GlamourGlowTestChart {
    let image: CIImage
    let regions: [ChartRegion]
    static let names = ["white-point", "white-disc", "bright-line", "gray-gradient",
                        "bright-gradient", "red-light", "green-light", "blue-light",
                        "orange-light", "skin-like", "hard-edge", "soft-source"]
    static func generate(size: Int) -> Self {
        let image = SyntheticCharts.make(size: size) { x, y in
            let col = min(3, Int(x * 4)), row = min(2, Int(y * 3))
            let index = row * 4 + col
            let u = x * 4 - Double(col), v = y * 3 - Double(row)
            let dx = u - 0.5, dy = v - 0.5, r = sqrt(dx*dx + dy*dy)
            let light = max(0.0, 1 - r / 0.42)
            switch index {
            case 0: return SIMD3(repeating: r < 2.0 / Double(size) ? 1 : 0)
            case 1: return SIMD3(repeating: r < 0.13 ? 0.96 : 0)
            case 2: return SIMD3(repeating: abs(dx) < 1.5 / Double(size) ? 0.95 : 0.02)
            case 3: return SIMD3(repeating: Float(u))
            case 4: return SIMD3(repeating: Float(0.7 + 0.3*u))
            case 5: return SIMD3<Float>(0.95, 0.025, 0.015) * Float(light)
            case 6: return SIMD3<Float>(0.025, 0.95, 0.025) * Float(light)
            case 7: return SIMD3<Float>(0.02, 0.05, 0.95) * Float(light)
            case 8: return SIMD3<Float>(0.95, 0.32, 0.025) * Float(light)
            case 9:
                let texture = 0.012 * sin(2 * .pi * u * 75) * sin(2 * .pi * v * 63)
                return SIMD3(Float(0.59+texture), Float(0.34+texture*0.65), Float(0.23+texture*0.5))
            case 10: return SIMD3(repeating: u < 0.5 ? 0.03 : 0.92)
            default: return SIMD3(repeating: Float(0.02 + 0.95 * exp(-r*r / 0.018)))
            }
        }
        let regions = names.enumerated().map { index, name in
            let col = index % 4, row = index / 4, w = size/4, h = size/3
            return ChartRegion(name: name, x: col*w, y: size-(row+1)*h, width: w, height: h, ramp: false)
        }
        return Self(image: image, regions: regions)
    }
    func region(_ name: String) -> CGRect { regions.first { $0.name == name }!.rect }
}

extension LumoraVisualTestLab {
    private func glowPreset(_ title: String) -> CreativeEffect {
        CreativeFXPreset.all(for: .glamourGlow).first { $0.title == title }!.makeEffect()
    }
    private func glowCrop(_ image: CIImage, x: Double, y: Double, side: Int = 512) -> CIImage {
        let extent = image.extent, s = min(CGFloat(side), extent.width, extent.height)
        let ox = min(extent.maxX-s, max(extent.minX, extent.minX + extent.width*x-s/2))
        let oy = min(extent.maxY-s, max(extent.minY, extent.minY + extent.height*y-s/2))
        return image.cropped(to: CGRect(x: floor(ox), y: floor(oy), width: s, height: s))
    }
    private func glowProfile(_ image: CIImage, y: CGFloat, x: CGFloat, width: CGFloat) -> [Double] {
        let rect = CGRect(x: x, y: y, width: width, height: 1)
        let px = gpu.read(image, rect)
        return stride(from: 0, to: px.count, by: 4).map { LabGPU.luma(px, $0) }
    }
    private func glowMetrics(_ before: CIImage, _ after: CIImage) -> [String: Double] {
        let m = gpu.compare(before, after)
        return ["meanLuminanceBefore":m.input.mean, "meanLuminanceAfter":m.output.mean,
                "peakLuminanceBefore":m.input.max, "peakLuminanceAfter":m.output.max,
                "netHighlightClippingIncreasePixels":Double(max(0,m.whiteOutput-m.whiteInput)),
                "meanLuminanceChange":m.residual.mean, "maxRGBError":m.maxError,
                "chromaticityDrift":m.chromaticityMAE, "nonFinitePixels":Double(m.nonFinite)]
    }
    func runGlamourGlow() async throws {
        try FileManager.default.createDirectory(at: artifacts.root, withIntermediateDirectories: true)
        let chart = GlamourGlowTestChart.generate(size: full ? 2048 : 768)
        try artifacts.png(chart.image, "GlamourGlow/GlamourGlowTestChart.png")
        try artifacts.json(chart.regions, "GlamourGlow/chart_regions.json")
        do {
            try glowSynthetic(chart)
            try glowMasksAndStack(chart)
            try glowResolutionPerformance()
            try await glowPipeline(chart)
            try glowPhotos()
        } catch {
            var c = LabCase(name: "GG_harness")
            c.check("Completed", false, hard: true, String(describing: error))
            cases.append(c)
            try glowReport()
            throw error
        }
        try glowReport()
    }

    private func glowSynthetic(_ chart: GlamourGlowTestChart) throws {
        progress("Glamour Glow synthetic chart and optical profiles")
        let zero = effect(.glamourGlow, ["amount":0])
        let neutral = gpu.compare(chart.image, try render(chart.image, [zero]))
        var identity = LabCase(name: "GG_identity")
        identity.metrics = ["maxRGBError":neutral.maxError, "meanLuminanceChange":neutral.residual.mean,
                            "chromaticityDrift":neutral.chromaticityMAE, "nonFinitePixels":Double(neutral.nonFinite)]
        identity.check("Amount zero identity", neutral.maxError == 0, hard:true, "Exact unchanged CI graph.")
        identity.check("Finite", neutral.nonFinite == 0, hard:true, "No NaN/Inf in RGBA float output.")
        cases.append(identity)

        let point = SyntheticCharts.make(size: full ? 1024 : 512) { x,y in
            SIMD3(repeating: hypot(x-0.5,y-0.5) < 1.5/Double(full ? 1024 : 512) ? 1 : 0)
        }
        var pointItems:[(String,CIImage)] = [("Original",point)]
        var profiles:[(String,[Double])] = []
        for (name, softness) in [("Low Softness",10.0),("Medium Softness",50.0),("High Softness",90.0)] {
            let fx = effect(.glamourGlow,["amount":100,"glow":100,"softness":softness,
                                          "threshold":20,"shadowProtection":0,"highlightProtection":0])
            let output = try render(point,[fx])
            let m = gpu.compare(point,output)
            var c = LabCase(name:"GG_point_\(Int(softness))")
            c.metrics = glowMetrics(point,output)
            let radius = min(120,Int(point.extent.width/3))
            let row = glowProfile(output,y:floor(point.extent.midY),x:point.extent.midX-CGFloat(radius),width:CGFloat(radius))
            let values = row.reversed().map { max(0,$0) }
            profiles.append((name,values))
            let rises = zip(values,values.dropFirst()).filter { $1 > $0 + 0.00002 }.count
            c.metrics["radialRiseCount"] = Double(rises)
            c.check("Finite point spread",m.nonFinite == 0,hard:true,"No non-finite pixels.")
            c.check("Smooth radial decay",rises <= 3,"Quality heuristic; inspect the plotted profile for rings.")
            pointItems.append((name,output));cases.append(c)
        }
        try artifacts.sheet(pointItems,"GlamourGlow/glow_point_spread.png",nativeCrop:true,cell:512,maxColumns:4)
        try artifacts.plot(profiles,"GlamourGlow/point_spread_profile.png",title:"Radial point spread",xMaximum:Double(profiles[0].1.count))
        let distant = CGRect(x:8,y:8,width:64,height:64)
        let strong = pointItems.last!.1
        let floor = gpu.compare(point,strong,region:distant)
        var floorCase = LabCase(name:"GG_black_floor")
        floorCase.metrics=["distantMeanLuminanceChange":floor.residual.mean,"distantMaxRGBError":floor.maxError]
        floorCase.check("Distant black remains black",floor.maxError<1e-5,hard:true,
                        "Measured 64×64 patch far from a local point source.")
        floorCase.images=["GlamourGlow/black_floor_test.png"]
        try artifacts.sheet([("Original",point),("Strong diffusion",strong),
                             ("Difference ×20",artifacts.difference(point,strong,gain:20))],
                            "GlamourGlow/black_floor_test.png",cell:512,maxColumns:3)
        cases.append(floorCase)

        let white = SyntheticCharts.make(size:512) { x,y in
            SIMD3(repeating: Float(0.03+0.91*exp(-((x-0.5)*(x-0.5)+(y-0.5)*(y-0.5))/0.009)))
        }
        var warmthItems:[(String,CIImage)] = [("Original",white)]
        for (name,warmth) in [("Cool",-70.0),("Neutral",0.0),("Warm",70.0)] {
            let output=try render(white,[effect(.glamourGlow,["warmth":warmth,"amount":80,"glow":75])])
            var c=LabCase(name:"GG_warmth_\(name)")
            c.metrics=glowMetrics(white,output)
            c.metrics["distantMaxRGBError"]=gpu.compare(white,output,region:CGRect(x:0,y:0,width:32,height:32)).maxError
            c.check("Warmth remains local",c.metrics["distantMaxRGBError"]!<0.002,
                    "Quality heuristic; warmth should tint the field, not the full photograph.")
            cases.append(c);warmthItems.append((name,output))
        }
        try artifacts.sheet(warmthItems,"GlamourGlow/glow_warmth_comparison.png",cell:512,maxColumns:4)

        var colorItems:[(String,CIImage)]=[]
        for (name,color) in [("red",SIMD3<Float>(0.95,0.02,0.02)),
                             ("green",SIMD3<Float>(0.02,0.95,0.02)),
                             ("blue",SIMD3<Float>(0.02,0.04,0.95)),
                             ("orange",SIMD3<Float>(0.95,0.32,0.02))] {
            let input=SyntheticCharts.make(size:512) { x,y in
                let r=hypot(x-0.5,y-0.5)
                return r<0.13 ? color:SIMD3<Float>(repeating:0)
            }
            let output=try render(input,[effect(.glamourGlow,["amount":90,"glow":90,
                "softness":65,"warmth":0,"shadowProtection":0])])
            let ring=CGRect(x:246,y:345,width:20,height:20)
            let sourceRGB=gpu.read(input,CGRect(x:246,y:246,width:20,height:20))
            let haloRGB=gpu.read(output,ring)
            let sourceSum=Double(color.x+color.y+color.z)
            var halo=SIMD3<Double>(repeating:0)
            for i in stride(from:0,to:haloRGB.count,by:4) {
                halo += SIMD3(Double(haloRGB[i]),Double(haloRGB[i+1]),Double(haloRGB[i+2]))
            }
            let haloSum=halo.x+halo.y+halo.z
            let chromaError = haloSum > 1e-10 ?
                (abs(halo.x / haloSum - Double(color.x) / sourceSum) +
                 abs(halo.y / haloSum - Double(color.y) / sourceSum) +
                 abs(halo.z / haloSum - Double(color.z) / sourceSum)) / 3 : 1
            var colorCase=LabCase(name:"GG_color_\(name)")
            colorCase.metrics=["haloMeanLuminance":gpu.compare(input,output,region:ring).output.mean,
                               "haloChromaticityError":chromaError,
                               "sourcePeakRGB":Double(sourceRGB[0])]
            colorCase.check("Visible colored halo",haloSum>0.0001,
                            "Quality heuristic; inspect the corresponding light source and halo.")
            colorCase.check("Source chromaticity retained",chromaError<0.08,
                            "Quality heuristic, measured on the RGB halo with Warmth=0.")
            cases.append(colorCase)
            colorItems += [("\(name) original",input),("\(name) glow",output)]
        }
        try artifacts.sheet(colorItems,"GlamourGlow/colored_light_halos.png",cell:512,maxColumns:4)

        let edge = SyntheticCharts.make(size:1024) { x,_ in SIMD3(repeating: x<0.5 ? 0.03:0.92) }
        let edgeOutput=try render(edge,[effect(.glamourGlow,["amount":90,"glow":90,"softness":60,"shadowProtection":0])])
        let inputLine=glowProfile(edge,y:512,x:300,width:424)
        let outputLine=glowProfile(edgeOutput,y:512,x:300,width:424)
        let darkSide=Array(outputLine.prefix(212))
        let undershoots=darkSide.filter{$0<0.03-0.0001}.count
        let reversals=zip(darkSide,darkSide.dropFirst()).filter{$1<$0-0.0001}.count
        var halo=LabCase(name:"GG_edge_profile")
        halo.metrics=["darkSideUndershoots":Double(undershoots),"darkSideReversals":Double(reversals)]
        halo.check("No undershoot",undershoots==0,hard:true,"Diffusion may cross the edge but must not darken it.")
        halo.check("Smooth approach to edge",reversals<=2,"Quality heuristic; no obvious ringing before the bright half.")
        halo.images=["GlamourGlow/halo_profile.png"];cases.append(halo)
        try artifacts.plot([("Original",inputLine),("Glow",outputLine)],"GlamourGlow/halo_profile.png",
                           title:"Dark to bright edge profile",xMaximum:424)

        let unprotected=try render(edge,[effect(.glamourGlow,["amount":90,"glow":90,"softness":60,
                                                      "highlightProtection":0,"shadowProtection":0])])
        let protected=try render(edge,[effect(.glamourGlow,["amount":90,"glow":90,"softness":60,
                                                    "highlightProtection":100,"shadowProtection":100])])
        let brightROI=CGRect(x:520,y:400,width:80,height:80)
        let shadowROI=CGRect(x:440,y:400,width:60,height:80)
        var protectionCase=LabCase(name:"GG_protection")
        let brightUnprotected=gpu.compare(edge,unprotected,region:brightROI).residual.mean
        let brightProtected=gpu.compare(edge,protected,region:brightROI).residual.mean
        let shadowUnprotected=gpu.compare(edge,unprotected,region:shadowROI).residual.mean
        let shadowProtected=gpu.compare(edge,protected,region:shadowROI).residual.mean
        protectionCase.metrics=["brightUnprotectedDelta":brightUnprotected,
                                "brightProtectedDelta":brightProtected,
                                "shadowUnprotectedDelta":shadowUnprotected,
                                "shadowProtectedDelta":shadowProtected]
        protectionCase.check("Highlight protection reduces reconstruction",brightProtected<=brightUnprotected,
                             "Quality heuristic on the bright side of a hard edge.")
        protectionCase.check("Shadow protection reduces dark contamination",shadowProtected<=shadowUnprotected,
                             "Quality heuristic on the dark side near a bright edge.")
        cases.append(protectionCase)

        let fx=glowPreset("Portrait Glow")
        let output=try render(chart.image,[fx])
        var chartCase=LabCase(name:"GG_chart")
        chartCase.metrics=glowMetrics(chart.image,output)
        chartCase.check("Finite chart",chartCase.metrics["nonFinitePixels"]==0,hard:true,"12 analytic tiles.")
        for name in ["red-light","green-light","blue-light","orange-light"] {
            let roi=chart.region(name).insetBy(dx:chart.region(name).width*0.3,dy:chart.region(name).height*0.3)
            let m=gpu.compare(chart.image,output,region:roi)
            chartCase.metrics[name+"-chromaticityDrift"]=m.chromaticityMAE
            chartCase.check("Color preservation \(name)",m.chromaticityMAE<0.08,
                            "Quality heuristic on a colored source; inspect halo chromaticity separately.")
        }
        let darkROI=chart.region("white-disc").insetBy(dx:16,dy:16)
        chartCase.metrics["whiteDiscMeanLuminanceChange"]=gpu.compare(chart.image,output,region:darkROI).residual.mean
        chartCase.images=["GlamourGlow/GlamourGlowTestChart.png","GlamourGlow/chart_comparison.png"]
        try artifacts.sheet([("Original",chart.image),("Portrait Glow",output),
                             ("Difference ×8",artifacts.difference(chart.image,output,gain:8))],
                            "GlamourGlow/chart_comparison.png",cell:768,maxColumns:3)
        cases.append(chartCase)
    }
}

extension LumoraVisualTestLab {
    private func glowPriority(_ index:Int)->[(String,Double,Double)] {
        switch index {
        case 0: return [("skin",0.53,0.52),("eye",0.51,0.61),("hair",0.28,0.69)]
        case 1: return [("skin",0.53,0.51),("eye",0.50,0.60),("dark-curly-hair",0.27,0.69)]
        case 2: return [("sun-clouds",0.50,0.72),("ridge",0.50,0.45)]
        case 3: return [("hair",0.31,0.72),("sun",0.63,0.70),("shoulder",0.46,0.47)]
        case 4: return [("street-lamp",0.37,0.79),("dark-wall",0.18,0.68)]
        case 5: return [("sunlit-wall",0.50,0.72),("dark-interior",0.50,0.30)]
        case 6: return [("white-dress",0.52,0.43),("skin",0.53,0.67)]
        default: return [("skin",0.50,0.49),("hair",0.42,0.69),("knitted-fabric",0.50,0.27)]
        }
    }
    private func glowPhotos() throws {
        progress("Glamour Glow eight-photograph manual review corpus")
        let repo=URL(fileURLWithPath:#filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let folder=URL(fileURLWithPath:ProcessInfo.processInfo.environment["LUMORA_VISUAL_ASSETS"]
            ?? repo.appendingPathComponent("VisualTestAssets").path)
        let files=try FileManager.default.contentsOfDirectory(at:folder,includingPropertiesForKeys:nil)
            .filter{["png","jpg","jpeg","tif","tiff","heic"].contains($0.pathExtension.lowercased())}
            .sorted{$0.lastPathComponent<$1.lastPathComponent}
        guard files.count == 8 else {
            throw NSError(domain:"GlamourGlowLab",code:1,userInfo:[NSLocalizedDescriptionKey:
                "Expected eight photographs, found \(files.count) in \(folder.path)"])
        }
        let presets=CreativeFXPreset.all(for:.glamourGlow)
        for (index,file) in files.enumerated() {
            progress("Glamour Glow photo \(index+1)/8: \(file.lastPathComponent)")
            try autoreleasepool {
                guard var input=CIImage(contentsOf:file,options:[.applyOrientationProperty:true])
                else {throw LabError.render}
                input=input.transformed(by:CGAffineTransform(translationX:-input.extent.minX,
                                                              y:-input.extent.minY))
                let name=file.deletingPathExtension().lastPathComponent
                let root="GlamourGlow/RealPhotos/\(name)"
                try artifacts.png(input,root+"/Original.png")
                let centers=glowPriority(index)
                var sheet:[(String,CIImage)]=[("Original",input)]
                var crops:[(String,CIImage)]=centers.map{("Original · \($0.0)",
                    glowCrop(input,x:$0.1,y:$0.2))}
                var outputs:[String:CIImage]=["Original":input]
                var c=LabCase(name:"GG_photo_"+name)
                c.notes=["Manual photographic review only; no aesthetic PASS/FAIL or Golden Master.",
                         "Native 512×512 crops; positions in lower-left normalized coordinates: " +
                         centers.map{"\($0.0)=(\($0.1),\($0.2))"}.joined(separator:", ")]
                for preset in presets {
                    let fx=preset.makeEffect(),output=try render(input,[fx])
                    let label=preset.title.lowercased().replacingOccurrences(of:" ",with:"_")
                    let stem=root+"/"+label
                    try artifacts.png(output,stem+".png")
                    try artifacts.png(artifacts.difference(input,output,gain:8),stem+"_difference_x8.png")
                    try artifacts.json(fx.validated,stem+"_settings.json")
                    let metrics=glowMetrics(input,output)
                    for (key,value) in metrics {c.metrics[label+"-"+key]=value}
                    c.check("Finite \(preset.title)",metrics["nonFinitePixels"]==0,hard:true,
                            "Full-image RGBA float comparison.")
                    c.images += [stem+".png",stem+"_difference_x8.png",stem+"_settings.json"]
                    sheet.append((preset.title,output));outputs[preset.title]=output
                    for (region,x,y) in centers {
                        crops.append(("\(preset.title) · \(region)",glowCrop(output,x:x,y:y)))
                    }
                }
                let sheetPath=root+"/GlamourGlow_contact_sheet.png"
                let cropsPath=root+"/GlamourGlow_crops_100percent.png"
                try artifacts.sheet(sheet,sheetPath,cell:768,maxColumns:3)
                try artifacts.sheet(crops,cropsPath,nativeCrop:true,cell:512,maxColumns:4)
                c.images += [sheetPath,cropsPath]
                if index <= 1 {
                    let titles=["Original","Subtle Glow","Portrait Glow","Warm Glow","Dreamy","Strong Glow"]
                    let items=titles.flatMap{ title -> [(String,CIImage)] in
                        guard let image=outputs[title] else{return []}
                        return centers.map{("\(title) · \($0.0)",glowCrop(image,x:$0.1,y:$0.2))}
                    }
                    let path=root+"/portrait_glow_comparison.png"
                    try artifacts.sheet(items,path,nativeCrop:true,cell:512,maxColumns:3)
                    c.images.append(path)
                }
                if index == 4 {
                    let lamp=centers[0]
                    let titles=["Original","Subtle Glow","Warm Glow","Dreamy","Strong Glow"]
                    let items=titles.compactMap{title -> (String,CIImage)? in
                        guard let image=outputs[title] else{return nil}
                        return(title,glowCrop(image,x:lamp.1,y:lamp.2))
                    }
                    let path=root+"/night_light_glow_comparison.png"
                    try artifacts.sheet(items,path,nativeCrop:true,cell:512,maxColumns:3)
                    c.images.append(path)
                }
                if index == 3 {
                    let titles=["Original","Subtle Glow","Portrait Glow","Warm Glow","Dreamy","Strong Glow"]
                    let items=titles.flatMap{title -> [(String,CIImage)] in
                        guard let image=outputs[title] else{return []}
                        return centers.map{("\(title) · \($0.0)",glowCrop(image,x:$0.1,y:$0.2))}
                    }
                    let path=root+"/backlight_glow_comparison.png"
                    try artifacts.sheet(items,path,nativeCrop:true,cell:512,maxColumns:3)
                    c.images.append(path)
                }
                cases.append(c)
            }
        }
    }

    private func glowReport() throws {
        let selected=cases.filter{$0.name.hasPrefix("GG_")}
        try artifacts.json(selected,"GlamourGlow/metrics.json")
        var report="""
        # Lumora — Glamour Glow Validation

        Generated: \(ISO8601DateFormatter().string(from:Date())). Device: \(gpu.deviceName).
        Production `CreativeStackRenderer` and `RenderEngine` are used throughout. Analysis uses
        extended linear sRGB / RGBA Float32; PNGs are sRGB presentation images. No Golden Master.

        ## Architecture and optical response

        The effect derives Rec.709 linear luminance, takes its square root for a perceptual
        lightness gate, then applies `smoothstep(knee−0.20, knee+0.25, lightness)` where
        `knee = 0.30 + 0.55 × Threshold/100`. Only RGB from selected luminous pixels enters the
        diffusion field. Three Gaussian scales have photographic radii `1.5 + 8 × Softness/100`
        multiplied by 1, 3 and 10, then by image long edge / 3000. Their weights are .50/.32/.18.
        Medium and large scales are processed at half and quarter resolution and upsampled on GPU.
        Warmth changes only the field's RGB multipliers, normalized to preserve approximate
        luminance. Receiving shadows use a continuous guard; receiving highlights use a continuous
        attenuation and channel headroom limit. A black pixel can receive nearby light, while a
        distant black pixel remains black because its field is zero. Amount=0 and Glow=0 return
        the original CI graph exactly. The shader is the executable mathematical contract.

        ## Reading the results

        **FAIL** is reserved for hard functional invariants (identity, finiteness, mask isolation,
        effect-order noncommutativity, cache behavior). **WARN** marks a quality heuristic to inspect,
        never an automatic judgement of photographic quality. Runtime is machine-dependent and has
        no pass/fail threshold. The photo corpus has numerical measures and review sheets only.
        `netHighlightClippingIncreasePixels` is the positive difference in clipped-pixel counts,
        not a per-pixel newly-clipped count. It excludes no already-clipped pixels and must be read
        only as a net measure. `chromaticityDrift` compares per-pixel RGB proportions where both
        channel sums are positive. Native crops preserve one source pixel per sheet pixel.

        ## Summary

        | Case | Status |
        | --- | --- |
        """
        for c in selected {report += "\n| \(c.name) | \(c.status) |"}
        report += "\n\n## Detailed results\n\n"
        for c in selected {
            report += "### \(c.name) — \(c.status)\n\n"
            if !c.metrics.isEmpty {
                report += "| Metric | Value |\n| --- | ---: |\n"
                for key in c.metrics.keys.sorted() {
                    report += String(format:"| `%@` | %.8g |\n",key,c.metrics[key]!)
                }
                report += "\n"
            }
            for check in c.checks {
                report += "- **\(check.status)** \(check.name) (\(check.hard ? "hard invariant":"quality heuristic")): \(check.detail)\n"
            }
            for note in c.notes {report += "- \(note)\n"}
            for image in c.images {report += "- [\(image)](\(image))\n"}
            report += "\n"
        }
        report += """
        ## Review priorities

        Inspect the [point spread](GlamourGlow/glow_point_spread.png),
        [radial profile](GlamourGlow/point_spread_profile.png),
        [black floor](GlamourGlow/black_floor_test.png),
        [warmth comparison](GlamourGlow/glow_warmth_comparison.png),
        [edge profile](GlamourGlow/halo_profile.png), and per-photo contact sheets/crops above.
        Do not alter the renderer or presets to suppress a WARN before manual image review.

        """
        try report.write(to:artifacts.url("GlamourGlowValidationReport.md"),atomically:true,encoding:.utf8)
    }
}

extension LumoraVisualTestLab {
    private func glowMasksAndStack(_ chart: GlamourGlowTestChart) throws {
        progress("Glamour Glow masks and stack ordering")
        let source=normalized(chart.image,to:1024),fx=glowPreset("Strong Glow")
        var radial=RadialGradientMask();radial.center=MaskPoint(x:0.375,y:0.5)
        radial.radiusX=0.19;radial.radiusY=0.19;radial.feather=4
        let mask=LocalMask(name:"Glow region",components:[MaskComponent(shape:.radial(radial))])
        var targeted=fx;targeted.maskID=mask.id
        let masked=try render(source,[targeted],masks:[mask])
        var invertedMask=mask;invertedMask.inverted=true
        let inverted=try render(source,[targeted],masks:[invertedMask])
        var secondRadial=radial;secondRadial.center=MaskPoint(x:0.78,y:0.5)
        let secondMask=LocalMask(name:"Second glow region",components:[MaskComponent(shape:.radial(secondRadial))])
        var second=fx;second.maskID=secondMask.id
        let stacked=try render(source,[targeted,second],masks:[mask,secondMask])
        var hole=radial;hole.radiusX=0.055;hole.radiusY=0.055;hole.feather=0
        let subtractive=LocalMask(name:"Glow minus centre",components:[
            MaskComponent(operation:.add,shape:.radial(radial)),
            MaskComponent(operation:.subtract,shape:.radial(hole))])
        var cutFX=fx;cutFX.maskID=subtractive.id
        let cut=try render(source,[cutFX],masks:[subtractive])
        let outside=CGRect(x:10,y:10,width:64,height:64)
        let centre=CGRect(x:368,y:496,width:32,height:32)
        let secondCentre=CGRect(x:780,y:496,width:32,height:32)
        var c=LabCase(name:"GG_masks")
        c.metrics=["simpleOutsideMaxRGBError":gpu.compare(source,masked,region:outside).maxError,
                   "invertedCentreMaxRGBError":gpu.compare(source,inverted,region:centre).maxError,
                   "stackedOutsideMaxRGBError":gpu.compare(source,stacked,region:outside).maxError,
                   "subtractiveCentreMaxRGBError":gpu.compare(source,cut,region:centre).maxError,
                   "simpleInsideMAE":gpu.compare(source,masked,region:centre).mae,
                   "stackedSecondInsideMAE":gpu.compare(source,stacked,region:secondCentre).mae]
        for key in ["simpleOutsideMaxRGBError","invertedCentreMaxRGBError",
                    "stackedOutsideMaxRGBError","subtractiveCentreMaxRGBError"] {
            c.check("Mask isolation \(key)",c.metrics[key]!<2e-6,hard:true,
                    "Outside the effective mask, the production stack must preserve RGB.")
        }
        c.check("Masked zones respond",c.metrics["simpleInsideMAE"]!>1e-6 &&
                c.metrics["stackedSecondInsideMAE"]!>1e-6,hard:true,"Both local regions receive glow.")
        try artifacts.sheet([("Original",source),("Simple",masked),("Inverted",inverted),
                             ("Stacked",stacked),("Subtractive",cut)],
                            "GlamourGlow/mask_comparison.png",cell:512,maxColumns:3)
        c.images=["GlamourGlow/mask_comparison.png"];cases.append(c)

        let grain=effect(.grain,["amount":70,"size":40])
        let detail=CreativeFXPreset.all(for:.detailExtractor).first{$0.title=="Natural Detail"}!.makeEffect()
        let high=effect(.highKey,["amount":65,"dynamic":50])
        for (title,other) in [("Grain",grain),("Detail",detail),("HighKey",high)] {
            let forward=try render(source,[fx,other]),reverse=try render(source,[other,fx])
            let m=gpu.compare(forward,reverse)
            var order=LabCase(name:"GG_stack_\(title)")
            order.metrics=["forwardReverseMAE":m.mae,"nonFinitePixels":Double(m.nonFinite)]
            order.check("Stack order differs",m.mae>1e-6,hard:true,
                        "Glow before and after \(title) should remain distinct.")
            order.check("Finite",m.nonFinite==0,hard:true,"No NaN/Inf.")
            let path="GlamourGlow/stack_\(title.lowercased()).png"
            try artifacts.sheet([("Glow → \(title)",forward),("\(title) → Glow",reverse),
                                 ("Difference ×12",artifacts.difference(forward,reverse,gain:12))],
                                path,cell:512,maxColumns:3)
            order.images=[path];cases.append(order)
        }
    }

    private func glowResolutionPerformance() throws {
        progress("Glamour Glow resolution and GPU performance")
        var c=LabCase(name:"GG_resolution_performance")
        c.notes=["Wall time includes CI GPU evaluation and RGBA8 readback; machine dependent, never a speed gate.",
                 "The synthetic scene uses frame-relative geometry and identical scene coordinates."]
        var reference:CIImage?
        for dimension in full ? [1024,2048,4096] : [512,1024] {
            try autoreleasepool {
                let source=SyntheticCharts.make(size:dimension) { x,y in
                    let r=hypot(x-0.55,y-0.5)
                    let sky=0.12+0.32*x
                    return SIMD3(repeating:Float(sky+0.52*exp(-r*r/0.002)))
                }
                let start=ContinuousClock.now
                let output=try render(source,[glowPreset("Portrait Glow")])
                guard let bitmap=gpu.context.createCGImage(output,from:output.extent,
                                                           format:.RGBA8,colorSpace:gpu.linear)
                else {throw LabError.render}
                let elapsed=start.duration(to:.now)
                c.metrics["\(dimension)-fullRenderMilliseconds"]=Double(elapsed.components.seconds)*1000 +
                    Double(elapsed.components.attoseconds)/1e15
                c.metrics["\(dimension)-bitmapPixels"]=Double(bitmap.width*bitmap.height)
                let comparable=normalized(output,to:512)
                if let reference {
                    let comparison=gpu.compare(reference,comparable)
                    c.metrics["\(dimension)-normalizedRMSE"]=comparison.rmse
                    c.check("Resolution agreement \(dimension)",comparison.rmse<0.03,
                            "Quality heuristic after matching output dimensions; inspect the point spread.")
                } else {reference=comparable}
                try artifacts.png(comparable,"GlamourGlow/resolution_\(dimension).png")
            }
        }
        cases.append(c)
    }

    private func glowPipeline(_ chart:GlamourGlowTestChart) async throws {
        progress("Glamour Glow interactive, HQ, export and cache")
        let source=normalized(chart.image,to:2048)
        let path=try artifacts.url("GlamourGlow/Pipeline/source.png")
        try artifacts.png(source,"GlamourGlow/Pipeline/source.png")
        let engine=RenderEngine()
        var state=EditState();state.creative.effects=[glowPreset("Portrait Glow")]
        var c=LabCase(name:"GG_preview_HQ_export")
        var images:[(String,CIImage)]=[]
        for quality in [PreviewQuality.interactive,.high] {
            let result=try await engine.render(url:path,state:state,quality:quality)
            let title=quality == .interactive ? "interactive":"HQ"
            c.metrics[title+"-milliseconds"]=result.milliseconds
            c.metrics[title+"-width"]=Double(result.image.width)
            images.append((title,CIImage(cgImage:result.image)))
        }
        let repeatResult=try await engine.render(url:path,state:state,quality:.interactive)
        c.check("Preview source cache hit",repeatResult.cacheHit,hard:true,
                "Second render uses the existing preview decode cache.")
        state.creative.effects[0]["glow"]=70
        let changed=try await engine.render(url:path,state:state,quality:.interactive)
        let previewChanged=CIImage(cgImage:changed.image)
        c.metrics["parameterChangeMAE"]=gpu.compare(images[0].1,previewChanged).mae
        c.check("Glow updates preview",c.metrics["parameterChangeMAE"]!>1e-6,hard:true,
                "Changing Glow invalidates the rendered output.")
        var exportSettings=ExportSettings();exportSettings.format = .png
        exportSettings.colorSpace = .displayP3;exportSettings.includeMetadata = false
        let exported=try await engine.export(request:ExportRequest(sourceURL:path,state:state,name:"glamour-glow-lab"),
                                             settings:exportSettings,directory:artifacts.url("GlamourGlow/Pipeline/Export"))
        guard let exportImage=CIImage(contentsOf:exported.url) else {throw LabError.render}
        c.metrics["exportWidth"]=Double(exported.width)
        let agreement=gpu.compare(normalized(previewChanged,to:512),normalized(exportImage,to:512))
        c.metrics["previewExportSSIM"]=agreement.ssim
        c.check("Preview/export agreement",agreement.ssim>0.90,
                "Quality heuristic after resizing and color conversion.")
        images += [("Changed preview",previewChanged),("Export",exportImage)]
        try artifacts.sheet(images,"GlamourGlow/Pipeline/comparison.png",cell:512)
        c.images=["GlamourGlow/Pipeline/comparison.png"];cases.append(c)
    }
}
