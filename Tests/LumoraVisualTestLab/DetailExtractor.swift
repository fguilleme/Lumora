import Foundation
import CoreImage
@testable import LumoraCore

/// Analytic, deterministic source. All frequencies are cycles per 3000-pixel image edge.
struct DetailExtractorChart {
    let image: CIImage
    let regions: [ChartRegion]
    static let names = ["flat", "fine-sine", "medium-sine", "coarse-sine",
                        "fine-random", "medium-random", "coarse-random", "hard-edge",
                        "soft-edge", "dark-texture", "midtone-texture", "bright-texture",
                        "skin", "hair", "fabric", "sky-gradient",
                        "low-noise", "moderate-noise", "strong-noise", "color-patches"]
    static func generate(size: Int) -> Self {
        let image = SyntheticCharts.make(size: size) { x, y in
            let col = min(3, Int(x * 4)), row = min(4, Int(y * 5)), index = row * 4 + col
            let u = x * 4 - Double(col)
            func sine(_ period: Double) -> Double { sin(2 * .pi * x * 3000 / period) * sin(2 * .pi * y * 3000 / period) }
            func noise(_ cells: Double) -> Double {
                let ix = UInt32(floor(x * cells)), iy = UInt32(floor(y * cells))
                var h = (ix &* 374761393) &+ (iy &* 668265263) &+ 137
                h = (h ^ (h >> 13)) &* 1274126177
                return Double(h & 65535) / 32767.5 - 1
            }
            let value: Double
            switch index {
            case 0: value = 0.48
            case 1: value = 0.48 + 0.045 * sine(4)
            case 2: value = 0.48 + 0.06 * sine(16)
            case 3: value = 0.48 + 0.08 * sine(64)
            case 4: value = 0.48 + 0.045 * noise(750)
            case 5: value = 0.48 + 0.06 * noise(190)
            case 6: value = 0.48 + 0.08 * noise(47)
            case 7: value = u < 0.5 ? 0.07 : 0.90
            case 8: value = 0.07 + 0.83 / (1 + exp(-(u - 0.5) * 18))
            case 9: value = 0.08 + 0.025 * sine(16)
            case 10: value = 0.45 + 0.055 * sine(16)
            case 11: value = 0.82 + 0.045 * sine(16)
            case 12: return SIMD3(Float(0.60 + 0.018 * sine(12)), Float(0.35 + 0.011 * sine(12)), Float(0.24 + 0.008 * sine(12)))
            case 13: value = 0.40 + (sin(2 * .pi * x * 3000 / 7) > 0.75 ? 0.09 : -0.01)
            case 14: value = 0.48 + 0.045 * sin(2 * .pi * x * 3000 / 13) + 0.03 * sin(2 * .pi * y * 3000 / 19)
            case 15: value = 0.28 + 0.57 * u + 0.01 * sine(70)
            case 16: value = 0.45 + 0.0008 * noise(3000)
            case 17: value = 0.45 + 0.008 * noise(3000)
            case 18: value = 0.45 + 0.04 * noise(3000)
            default:
                let colors: [SIMD3<Float>] = [.init(0.8,0.05,0.05),.init(0.05,0.8,0.05),.init(0.05,0.05,0.8),
                                               .init(0.05,0.8,0.8),.init(0.8,0.05,0.8),.init(0.8,0.8,0.05),.init(0.60,0.35,0.24)]
                return colors[min(6, Int(u * 7))] * Float(0.95 + 0.05 * sine(16))
            }
            return SIMD3(repeating: Float(value))
        }
        let regions = names.enumerated().map { index, name in
            let w = size / 4, h = size / 5, col = index % 4, row = index / 4
            return ChartRegion(name: name, x: col*w+w/8, y: size-(row+1)*h+h/8,
                               width: 3*w/4, height: 3*h/4, ramp: false)
        }
        return Self(image: image, regions: regions)
    }
    func region(_ name: String) -> CGRect { regions.first { $0.name == name }!.rect }
}

extension LumoraVisualTestLab {
    func runDetailExtractor() async throws {
        let chart = DetailExtractorChart.generate(size: full ? 2048 : 1024)
        try artifacts.json(chart.regions, "DetailExtractor/chart_regions.json")
        try artifacts.png(chart.image, "DetailExtractor/DetailExtractorTestChart.png")
        do {
            try detailSynthetic(chart)
            try detailComparison(chart)
            if cases.first(where: { $0.name == "DE_vs_TC_Natural" })?.status == "FAIL" {
                try detailReport()
                return
            }
            try detailMasksAndStack(chart)
            try detailPerformance()
            try await detailPipeline()
            try detailPhotos()
        } catch {
            var c = LabCase(name: "DE_harness")
            c.check("Completed", false, hard: true, String(describing: error)); cases.append(c)
            try detailReport()
            throw error
        }
        try detailReport()
    }

    private func detailCenter(_ rect: CGRect, side: Int = 128) -> CGRect {
        let s = min(CGFloat(side), rect.width, rect.height)
        return CGRect(x: floor(rect.midX-s/2), y: floor(rect.midY-s/2), width: s, height: s)
    }
    private func detailProfile(_ image: CIImage, _ rect: CGRect) -> [Double] {
        let line = CGRect(x: rect.minX, y: floor(rect.midY), width: rect.width, height: 1)
        let px = gpu.read(image, line)
        return (0..<Int(rect.width)).map { LabGPU.luma(px, $0*4) }
    }
    private func detailRMS(_ image: CIImage, _ rect: CGRect) -> Double {
        let px = gpu.read(image, rect), w = Int(rect.width), h = Int(rect.height)
        let y = (0..<w*h).map { LabGPU.luma(px, $0*4) }
        var energy = 0.0, count = 0
        guard w > 2 && h > 2 else { return 0 }
        for row in 1..<h-1 { for col in 1..<w-1 {
            var neighborhood = 0.0
            for dy in -1...1 { for dx in -1...1 { neighborhood += y[(row+dy)*w+col+dx] } }
            let d = y[row*w+col] - neighborhood/9
            energy += d*d; count += 1
        } }
        return sqrt(energy/Double(max(1,count)))
    }
    private func detailHueDrift(_ before: CIImage, _ after: CIImage, _ rect: CGRect) -> Double {
        let a=gpu.read(before,rect),b=gpu.read(after,rect)
        var sum=0.0,count=0
        for i in stride(from:0,to:a.count,by:4) {
            let ar=Double(a[i]),ag=Double(a[i+1]),ab=Double(a[i+2])
            let br=Double(b[i]),bg=Double(b[i+1]),bb=Double(b[i+2])
            guard max(ar,ag,ab)-min(ar,ag,ab)>0.02,
                  max(br,bg,bb)-min(br,bg,bb)>0.02 else {continue}
            let u=atan2(sqrt(3)*(ag-ab),2*ar-ag-ab)
            let v=atan2(sqrt(3)*(bg-bb),2*br-bg-bb)
            let d=abs(u-v)
            sum += min(d,2 * .pi-d)*180 / .pi;count += 1
        }
        return sum/Double(max(1,count))
    }
    /// Fit one global gain to Tonal's luminance residual. A substantial remaining
    /// error shows that Detail is not simply the same operation at another gain.
    private func detailGainFit(_ source:CIImage,_ detail:CIImage,_ tonal:CIImage,
                               regions:[CGRect])->(gain:Double,relativeError:Double,cosine:Double) {
        var dd=0.0,tt=0.0,dt=0.0
        for region in regions {
            let a=gpu.read(source,region),d=gpu.read(detail,region),t=gpu.read(tonal,region)
            for i in stride(from:0,to:a.count,by:4) {
                let dr=LabGPU.luma(d,i)-LabGPU.luma(a,i)
                let tr=LabGPU.luma(t,i)-LabGPU.luma(a,i)
                dd += dr*dr;tt += tr*tr;dt += dr*tr
            }
        }
        let gain=dt/max(tt,1e-20)
        let error=sqrt(max(0,dd-2*gain*dt+gain*gain*tt)/max(dd,1e-20))
        return(gain,error,dt/sqrt(max(dd*tt,1e-20)))
    }
    private func detailSynthetic(_ chart: DetailExtractorChart) throws {
        let zero = effect(.detailExtractor, ["amount": 0])
        let neutral = gpu.compare(chart.image, try render(chart.image, [zero]))
        var identity = LabCase(name: "DE_identity")
        identity.metrics = ["maxRGBError": neutral.maxError, "meanLuminanceChange": neutral.residual.mean,
                            "chromaticityDrift": neutral.chromaticityMAE, "nonFinitePixels": Double(neutral.nonFinite)]
        identity.check("Amount zero identity", neutral.maxError < 2e-6, hard: true, "Analytic reference = unchanged source.")
        identity.check("Finite", neutral.nonFinite == 0, hard: true, "No NaN/Inf.")
        cases.append(identity)
        let variants: [(String,[String:Double])] = [
            ("Fine", ["amount": 80,"fine": 100,"medium": 0,"large": 0]),
            ("Medium", ["amount": 80,"fine": 0,"medium": 100,"large": 0]),
            ("Large", ["amount": 80,"fine": 0,"medium": 0,"large": 100]),
            ("Natural", ["amount": 50,"fine": 40,"medium": 65,"large": 20]),
            ("Strong", ["amount": 80,"fine": 70,"medium": 80,"large": 55]),
            ("Negative", ["amount": -80,"fine": 60,"medium": 70,"large": 30])]
        var sheet: [(String,CIImage)] = [("Original",chart.image)]
        var response: [(String,[Double])] = []
        for (name, params) in variants {
            progress("Detail Extractor synthetic \(name)")
            let fx = effect(.detailExtractor, params).validated
            let output = try render(chart.image,[fx]); let base = "DetailExtractor/Synthetic/\(name)"
            try artifacts.png(output,base+".png")
            try artifacts.png(artifacts.difference(chart.image,output,gain:8),base+"_difference_x8.png")
            try artifacts.json(fx,base+"_settings.json")
            let whole = gpu.compare(chart.image,output)
            var c = LabCase(name:"DE_"+name)
            c.metrics = ["meanLuminanceChange":whole.residual.mean,"chromaticityDrift":whole.chromaticityMAE,
                         "nonFinitePixels":Double(whole.nonFinite)]
            c.metrics["netChannelClippedPixels"]=Double(whole.whiteOutput-whole.whiteInput)
            c.metrics["netShadowClippedPixels"]=Double(whole.blackOutput-whole.blackInput)
            c.check("Finite output",whole.nonFinite == 0,hard:true,"RGBA float result.")
            c.check("Mean luminance stable",abs(whole.residual.mean)<0.025,"Heuristic: |mean delta| < .025 linear.")
            let zones = ["fine-sine","medium-sine","coarse-sine"]
            var curve:[Double]=[]
            for zone in zones {
                let roi = detailCenter(chart.region(zone))
                let m = gpu.compare(chart.image,output,region:roi)
                c.metrics[zone+"-residualSD"] = m.residualStd
                c.metrics[zone+"-localRMSRatio"] = detailRMS(output,roi)/max(1e-9,detailRMS(chart.image,roi))
                curve.append(m.residualStd)
            }
            if zones.map({$0.lowercased().split(separator:"-")[0]}).contains(Substring(name.lowercased())) {
                let index = ["Fine":0,"Medium":1,"Large":2][name]!
                c.check("Spatial band selectivity",curve[index] >= curve.enumerated().filter{$0.offset != index}.map(\.element).max()! * 0.8,
                        "Target sinusoid residual SD should reach at least 80% of any other sinusoid; heuristic, not forced PASS.")
                response.append((name,curve))
            }
            let flat=gpu.compare(chart.image,output,region:detailCenter(chart.region("flat")))
            c.metrics["flatResidualSD"] = flat.residualStd
            c.check("Uniform patch stays flat",flat.residualStd < 2e-5,hard:true,"Interior patch has no source texture.")
            for zone in ["low-noise","moderate-noise","strong-noise","dark-texture","midtone-texture","bright-texture"] {
                let roi=detailCenter(chart.region(zone))
                c.metrics[zone+"-localRMSRatio"] = detailRMS(output,roi)/max(1e-9,detailRMS(chart.image,roi))
            }
            c.check("Very low noise remains bounded",c.metrics["low-noise-localRMSRatio"]! < 3,
                    "Heuristic: 3× local RMS ceiling for the 0.0008 linear synthetic noise patch.")
            let edge=detailCenter(chart.region("hard-edge"),side:192)
            let a=detailProfile(chart.image,edge),b=detailProfile(output,edge)
            c.metrics["hardEdgeOvershoot"] = max(0,(b.max() ?? 0)-(a.max() ?? 0))
            c.metrics["hardEdgeUndershoot"] = max(0,(a.min() ?? 0)-(b.min() ?? 0))
            c.metrics["hardEdgeReverseSteps"] = Double(zip(b,b.dropFirst()).filter{$1-$0 < -1e-5}.count)
            c.check("Hard-edge halo",max(c.metrics["hardEdgeOvershoot"]!,c.metrics["hardEdgeUndershoot"]!) < 0.03,
                    "Photographic heuristic: overshoot/undershoot < .03 linear.")
            if name == "Natural" {
                try artifacts.plot([("Input",a),("Detail",b)],"DetailExtractor/detail_edge_profile.png",title:"Detail hard edge — linear luminance")
                c.images.append("DetailExtractor/detail_edge_profile.png")
                for zone in ["skin","color-patches"] {
                    let m=gpu.compare(chart.image,output,region:detailCenter(chart.region(zone)))
                    c.metrics[zone+"-chromaticityDrift"] = m.chromaticityMAE
                    c.metrics[zone+"-meanLuminanceChange"] = m.residual.mean
                    c.metrics[zone+"-hueDriftDegrees"] = detailHueDrift(chart.image,output,detailCenter(chart.region(zone)))
                }
            }
            c.images += [base+".png",base+"_difference_x8.png",base+"_settings.json"]
            cases.append(c); sheet.append((name,output))
        }
        try artifacts.plot(response,"DetailExtractor/detail_frequency_response.png",
                           title:"Residual SD: fine / medium / coarse sinusoid",xMaximum:3)
        try artifacts.sheet(sheet,"DetailExtractor/Synthetic/contact_sheet.png",cell:768,maxColumns:3)
    }

    private func detailComparison(_ chart: DetailExtractorChart) throws {
        let detailFX=DetailExtractorProfile.naturalDetail.applying(to:effect(.detailExtractor))
        let tonalFX=TonalContrastProfile.naturalTexture.applying(to:effect(.tonalContrast))
        let detail=try render(chart.image,[detailFX]), tonal=try render(chart.image,[tonalFX])
        let zones=["fine-sine","medium-sine","coarse-sine"]
        let tonalZones=["dark-texture","midtone-texture","bright-texture"]
        var dFrequency:[Double]=[],tFrequency:[Double]=[],dTonal:[Double]=[],tTonal:[Double]=[]
        var c=LabCase(name:"DE_vs_TC_Natural")
        for zone in zones {
            let roi=detailCenter(chart.region(zone))
            let d=gpu.compare(chart.image,detail,region:roi).residualStd
            let t=gpu.compare(chart.image,tonal,region:roi).residualStd
            dFrequency.append(d);tFrequency.append(t)
            c.metrics[zone+"-detailResidualSD"]=d;c.metrics[zone+"-tonalResidualSD"]=t
            c.metrics[zone+"-detailLocalRMSRatio"]=detailRMS(detail,roi)/max(1e-9,detailRMS(chart.image,roi))
            c.metrics[zone+"-tonalLocalRMSRatio"]=detailRMS(tonal,roi)/max(1e-9,detailRMS(chart.image,roi))
        }
        for zone in tonalZones {
            let roi=detailCenter(chart.region(zone))
            let d=gpu.compare(chart.image,detail,region:roi).residualStd
            let t=gpu.compare(chart.image,tonal,region:roi).residualStd
            dTonal.append(d);tTonal.append(t)
            c.metrics[zone+"-detailResidualSD"]=d;c.metrics[zone+"-tonalResidualSD"]=t
        }
        let difference=gpu.compare(detail,tonal,region:detailCenter(chart.region("midtone-texture")))
        c.metrics["midPatchOutputDifferenceMAE"]=difference.mae
        c.metrics["midPatchOutputCorrelation"]=correlation(detail,tonal,region:detailCenter(chart.region("midtone-texture")))
        let edge=detailCenter(chart.region("hard-edge"),side:192)
        let sourceProfile=detailProfile(chart.image,edge),dEdge=detailProfile(detail,edge),tEdge=detailProfile(tonal,edge)
        c.metrics["detailHardEdgeOvershoot"]=max(0,(dEdge.max() ?? 0)-(sourceProfile.max() ?? 0))
        c.metrics["tonalHardEdgeOvershoot"]=max(0,(tEdge.max() ?? 0)-(sourceProfile.max() ?? 0))
        let frequencyShapeDifference=zip(dFrequency,tFrequency).map { abs($0/max(dFrequency.max() ?? 1,1e-9)-$1/max(tFrequency.max() ?? 1,1e-9)) }.reduce(0,+)/3
        let tonalShapeDifference=zip(dTonal,tTonal).map { abs($0/max(dTonal.max() ?? 1,1e-9)-$1/max(tTonal.max() ?? 1,1e-9)) }.reduce(0,+)/3
        c.metrics["frequencyShapeDifference"]=frequencyShapeDifference
        c.metrics["tonalShapeDifference"]=tonalShapeDifference
        let fit=detailGainFit(chart.image,detail,tonal,regions:(zones+tonalZones+["hard-edge"]).map{detailCenter(chart.region($0))})
        c.metrics["bestTonalResidualGainToDetail"]=fit.gain
        c.metrics["bestGainRelativeResidualError"]=fit.relativeError
        c.metrics["residualCosineSimilarity"]=fit.cosine
        c.check("Distinct spatial and tonal responses",frequencyShapeDifference>0.08 || tonalShapeDifference>0.08,
                hard:true,"At least one normalized response curve should differ by >.08 mean absolute proportion. If this fails, stop and redesign after review.")
        c.check("Distinct rendered output",difference.mae>0.001,hard:true,
                "The central textured patch should differ by >.001 mean absolute linear RGB.")
        c.check("Not a simple gain change",fit.relativeError>0.10,hard:true,
                "After fitting one scalar to Tonal's residual across seven controlled zones, >10% of Detail's residual energy must remain unexplained.")
        try artifacts.sheet([("Original",chart.image),("Tonal Natural",tonal),("Detail Natural",detail),
                             ("Tonal diff ×8",artifacts.difference(chart.image,tonal,gain:8)),
                             ("Detail diff ×8",artifacts.difference(chart.image,detail,gain:8)),
                             ("Between ×8",artifacts.difference(tonal,detail,gain:8))],
                            "DetailExtractor/TonalContrast_vs_DetailExtractor.png",cell:768,maxColumns:3)
        try artifacts.plot([("Tonal",tFrequency),("Detail",dFrequency)],
                           "DetailExtractor/tonal_vs_detail_frequency.png",title:"Spatial frequency response",xMaximum:3)
        try artifacts.plot([("Tonal",tTonal),("Detail",dTonal)],
                           "DetailExtractor/tonal_vs_detail_tones.png",title:"Dark / mid / bright texture",xMaximum:3)
        try artifacts.plot([("Source",sourceProfile),("Tonal",tEdge),("Detail",dEdge)],
                           "DetailExtractor/tonal_vs_detail_edge.png",title:"Structural edge profile")
        c.images=["DetailExtractor/TonalContrast_vs_DetailExtractor.png","DetailExtractor/tonal_vs_detail_frequency.png",
                  "DetailExtractor/tonal_vs_detail_tones.png","DetailExtractor/tonal_vs_detail_edge.png"]
        cases.append(c)
        var report="""
        # Tonal Contrast vs Detail Extractor — Natural

        Both renders use the production CreativeStackRenderer and the same analytic chart. Tonal Contrast
        uses luminance-zone controls and fixed weighted Laplacian bands; Detail Extractor uses independent
        spatial-scale controls, adaptive local-variance bases, and texture shrinkage. These values do not
        imply that one effect is photographically preferable. No Golden Master was made.

        | Metric | Value |
        | --- | ---: |
        """
        for key in c.metrics.keys.sorted() { report += String(format:"\n| `%@` | %.8g |",key,c.metrics[key]!) }
        report += "\n\n"
        for check in c.checks { report += "- **\(check.status)** \(check.name): \(check.detail)\n" }
        for path in c.images { report += "- [\(path)](\(path.replacingOccurrences(of:"DetailExtractor/",with:"")))\n" }
        try report.write(to:artifacts.url("DetailExtractor/TonalContrast_vs_DetailExtractor_Report.md"),atomically:true,encoding:.utf8)
    }

    private func detailMasksAndStack(_ chart: DetailExtractorChart) throws {
        let source=normalized(chart.image,to:1024)
        let fx=DetailExtractorProfile.naturalDetail.applying(to:effect(.detailExtractor))
        var radial=RadialGradientMask();radial.center=MaskPoint(x:0.375,y:0.5)
        radial.radiusX=0.20;radial.radiusY=0.20;radial.feather=5
        let mask=LocalMask(name:"Detail test",components:[MaskComponent(shape:.radial(radial))])
        var targeted=fx;targeted.maskID=mask.id
        let masked=try render(source,[targeted],masks:[mask])
        var inverse=mask;inverse.inverted=true
        let inverted=try render(source,[targeted],masks:[inverse])
        var radial2=radial;radial2.center=MaskPoint(x:0.78,y:0.5)
        let secondMask=LocalMask(name:"Second",components:[MaskComponent(shape:.radial(radial2))])
        var second=fx;second.maskID=secondMask.id
        let stacked=try render(source,[targeted,second],masks:[mask,secondMask])
        let outside=CGRect(x:10,y:10,width:64,height:64)
        let center=CGRect(x:342,y:464,width:64,height:64)
        let secondary=CGRect(x:766,y:464,width:64,height:64)
        var c=LabCase(name:"DE_masks")
        c.metrics=["outsideMaxError":gpu.compare(source,masked,region:outside).maxError,
                   "invertedCenterMaxError":gpu.compare(source,inverted,region:center).maxError,
                   "stackedOutsideMaxError":gpu.compare(source,stacked,region:outside).maxError,
                   "maskedCenterMAE":gpu.compare(source,masked,region:center).mae,
                   "stackedSecondMAE":gpu.compare(source,stacked,region:secondary).mae]
        c.check("Outside mask identity",c.metrics["outsideMaxError"]!<2e-6,hard:true,"No effect beyond radial mask.")
        c.check("Inverted centre identity",c.metrics["invertedCenterMaxError"]!<2e-6,hard:true,"Inverted mask excludes centre.")
        c.check("Stacked masks isolate outside",c.metrics["stackedOutsideMaxError"]!<2e-6,hard:true,"Both masks remain local.")
        c.check("Masked zones respond",c.metrics["maskedCenterMAE"]!>1e-6 && c.metrics["stackedSecondMAE"]!>1e-6,
                hard:true,"Both target regions must be affected.")
        var hole=radial;hole.radiusX=0.06;hole.radiusY=0.06;hole.feather=0
        let punched=LocalMask(name:"Positive minus centre",components:[
            MaskComponent(operation:.add,shape:.radial(radial)),
            MaskComponent(operation:.subtract,shape:.radial(hole))])
        var punchedFX=fx;punchedFX.maskID=punched.id
        let cutout=try render(source,[punchedFX],masks:[punched])
        c.metrics["subtractedCentreMaxError"]=gpu.compare(source,cutout,region:CGRect(x:372,y:500,width:24,height:24)).maxError
        c.check("Subtractive component makes a hole",c.metrics["subtractedCentreMaxError"]!<2e-6,hard:true,
                "Existing positive/negative mask combination excludes the centre.")
        try artifacts.sheet([("Original",source),("Masked",masked),("Inverted",inverted),("Stacked",stacked)],
                           "DetailExtractor/mask_comparison.png",cell:512)
        c.images=["DetailExtractor/mask_comparison.png"];cases.append(c)

        let tonal=TonalContrastProfile.naturalTexture.applying(to:effect(.tonalContrast))
        var grain=effect(.grain,["amount":65,"size":45]);grain.seed=137
        for (name,other) in [("Tonal",tonal),("Grain",grain)] {
            let a=try render(source,[fx,other]),b=try render(source,[other,fx])
            let m=gpu.compare(a,b,region:detailCenter(source.extent,side:256))
            var order=LabCase(name:"DE_stack_"+name)
            order.metrics=["forwardReverseMAE":m.mae,"nonFinitePixels":Double(m.nonFinite)]
            order.check("Order changes output",m.mae>1e-6,hard:true,"Creative Stack applies effects in list order.")
            order.check("Finite",m.nonFinite==0,hard:true,"No NaN/Inf.")
            let path="DetailExtractor/stack_\(name.lowercased()).png"
            try artifacts.sheet([("Detail → \(name)",a),("\(name) → Detail",b),
                                 ("Difference ×10",artifacts.difference(a,b,gain:10))],path,cell:512)
            order.images=[path];cases.append(order)
        }
    }

    private func detailPerformance() throws {
        let fx=DetailExtractorProfile.naturalDetail.applying(to:effect(.detailExtractor))
        var c=LabCase(name:"DE_resolution_performance")
        c.notes=["Wall time includes GPU graph evaluation and RGBA8 readback; machine-dependent, not a speed gate.",
                 "Texture frequencies are constant in photographic coordinates (3000-pixel long edge)."]
        var reference:CIImage?
        for dimension in full ? [1024,2048,4096] : [512,1024] {
            try autoreleasepool {
                let source=SyntheticCharts.make(size:dimension) { x,y in
                    SIMD3(repeating:Float(0.45+0.05*sin(2 * .pi * x*3000/16)*sin(2 * .pi * y*3000/16)+0.04*sin(2 * .pi * x*3000/64)))
                }
                let start=ContinuousClock.now
                let output=try render(source,[fx])
                guard let bitmap=gpu.context.createCGImage(output,from:output.extent,format:.RGBA8,colorSpace:gpu.linear) else {throw LabError.render}
                let elapsed=start.duration(to:.now)
                c.metrics["\(dimension)-millisecondsIncludingReadback"]=Double(elapsed.components.seconds)*1000+Double(elapsed.components.attoseconds)/1e15
                c.metrics["\(dimension)-bitmapBytes"]=Double(bitmap.width*bitmap.height*4)
                let roi=detailCenter(source.extent,side:min(256,dimension/2))
                c.metrics["\(dimension)-localRMSRatio"]=detailRMS(output,roi)/max(1e-9,detailRMS(source,roi))
                let comparable=normalized(output,to:512)
                if let reference {
                    let m=gpu.compare(reference,comparable)
                    c.metrics["\(dimension)-normalizedRMSE"]=m.rmse
                    c.check("Resolution agreement \(dimension)",m.rmse<0.03,"Quality heuristic after matching dimensions: RMSE < .03 linear.")
                } else {reference=comparable}
                try artifacts.png(comparable,"DetailExtractor/resolution_\(dimension).png")
            }
        }
        cases.append(c)
    }

    private func detailPipeline() async throws {
        let image=SyntheticCharts.make(size:2048) { x,y in
            SIMD3(repeating:Float(0.45+0.06*sin(2 * .pi * x*80)*sin(2 * .pi * y*60)))
        }
        let source=try artifacts.url("DetailExtractor/Pipeline/source.png")
        try artifacts.png(image,"DetailExtractor/Pipeline/source.png")
        let engine=RenderEngine()
        var state=EditState();state.creative.effects=[DetailExtractorProfile.naturalDetail.applying(to:effect(.detailExtractor))]
        var c=LabCase(name:"DE_preview_HQ_export")
        var images:[(String,CIImage)]=[]
        for quality in [PreviewQuality.interactive,.high] {
            let result=try await engine.render(url:source,state:state,quality:quality)
            let name=quality == .interactive ? "interactive":"HQ"
            c.metrics[name+"-milliseconds"]=result.milliseconds
            c.metrics[name+"-width"]=Double(result.image.width)
            images.append((name,CIImage(cgImage:result.image)))
        }
        let repeated=try await engine.render(url:source,state:state,quality:.interactive)
        c.check("Preview cache reused",repeated.cacheHit,hard:true,"Source decode cache remains active.")
        state.creative.effects[0]["medium"]=50
        let changed=try await engine.render(url:source,state:state,quality:.interactive)
        c.metrics["parameterChangeMAE"]=gpu.compare(images[0].1,CIImage(cgImage:changed.image)).mae
        c.check("Parameter invalidates output",c.metrics["parameterChangeMAE"]!>1e-6,hard:true,"Changing Medium updates preview.")
        var settings=ExportSettings();settings.format = .png;settings.colorSpace = .displayP3;settings.includeMetadata = false
        let exported=try await engine.export(request:ExportRequest(sourceURL:source,state:state,name:"detail-lab"),
                                             settings:settings,directory:artifacts.url("DetailExtractor/Pipeline/Export"))
        guard let exportImage=CIImage(contentsOf:exported.url) else {throw LabError.render}
        c.metrics["exportWidth"]=Double(exported.width)
        let agreement=gpu.compare(normalized(CIImage(cgImage:changed.image),to:512),normalized(exportImage,to:512))
        c.metrics["previewExportSSIM"]=agreement.ssim
        c.check("Preview/export consistency",agreement.ssim>0.9,"Heuristic after color conversion and resizing.")
        images += [("changed preview",CIImage(cgImage:changed.image)),("export",exportImage)]
        try artifacts.sheet(images,"DetailExtractor/Pipeline/comparison.png",cell:512)
        c.images=["DetailExtractor/Pipeline/comparison.png"];cases.append(c)
    }

    private func detailCrop(_ image:CIImage,x:Double,y:Double,side:Int=512)->CIImage {
        let s=min(CGFloat(side),image.extent.width,image.extent.height)
        let ox=min(image.extent.maxX-s,max(image.extent.minX,image.extent.minX+image.extent.width*x-s/2))
        let oy=min(image.extent.maxY-s,max(image.extent.minY,image.extent.minY+image.extent.height*y-s/2))
        return image.cropped(to:CGRect(x:floor(ox),y:floor(oy),width:s,height:s))
    }
    private func detailPriority(_ index:Int)->[(String,Double,Double)] {
        switch index {
        case 0: [("skin",0.5,0.5),("hair",0.5,0.77)]
        case 1: [("skin",0.5,0.5),("curly-hair",0.5,0.77)]
        case 2: [("clouds",0.5,0.28),("rocks",0.5,0.68),("ridge",0.5,0.57)]
        case 3: [("hair-sky",0.48,0.57)]
        case 4: [("stone",0.5,0.68),("dark-wall",0.3,0.45)]
        case 5: [("wood",0.5,0.7),("wall",0.5,0.3),("shadow",0.5,0.7)]
        case 6: [("white-fabric",0.5,0.68),("white-plaster",0.26,0.43)]
        default: [("hair",0.5,0.7),("knit",0.5,0.58),("water",0.5,0.25)]
        }
    }
    private func detailPhotos() throws {
        let repo=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let folder=URL(fileURLWithPath:ProcessInfo.processInfo.environment["LUMORA_VISUAL_ASSETS"] ?? repo.appendingPathComponent("VisualTestAssets").path)
        let files=try FileManager.default.contentsOfDirectory(at:folder,includingPropertiesForKeys:nil)
            .filter{["png","jpg","jpeg","tif","tiff","heic"].contains($0.pathExtension.lowercased())}
            .sorted{$0.lastPathComponent<$1.lastPathComponent}
        guard files.count == 8 else {throw NSError(domain:"DetailExtractorLab",code:1,userInfo:[NSLocalizedDescriptionKey:"Expected eight photographs, found \(files.count) in \(folder.path)"])}
        let variants:[(String,(CreativeEffect)->CreativeEffect)]=[
            ("Subtle Detail",{DetailExtractorProfile.subtleDetail.applying(to:$0)}),
            ("Fine Texture",{DetailExtractorProfile.fineTexture.applying(to:$0)}),
            ("Medium Detail",{var fx=$0;fx["amount"]=65;fx["fine"]=0;fx["medium"]=90;fx["large"]=0;return fx}),
            ("Large Detail",{var fx=$0;fx["amount"]=65;fx["fine"]=0;fx["medium"]=0;fx["large"]=90;return fx}),
            ("Natural Detail",{DetailExtractorProfile.naturalDetail.applying(to:$0)}),
            ("Strong Detail",{var fx=$0;fx["amount"]=80;fx["fine"]=70;fx["medium"]=80;fx["large"]=55;return fx}),
            ("Extreme Detail",{DetailExtractorProfile.extremeDetail.applying(to:$0)})]
        for (index,file) in files.enumerated() {
            progress("Detail photo \(index+1)/8: \(file.lastPathComponent)")
            try autoreleasepool {
                guard var input=CIImage(contentsOf:file,options:[.applyOrientationProperty:true]) else {throw LabError.render}
                input=input.transformed(by:CGAffineTransform(translationX:-input.extent.minX,y:-input.extent.minY))
                let name=file.deletingPathExtension().lastPathComponent
                let root="DetailExtractor/RealPhotos/\(name)"
                try artifacts.png(input,root+"/Original.png")
                let centers=detailPriority(index)
                var sheet:[(String,CIImage)]=[("Original",input)]
                var crops:[(String,CIImage)]=centers.map{("Original · \($0.0)",detailCrop(input,x:$0.1,y:$0.2))}
                var selected:[String:CIImage]=["Original":input]
                var c=LabCase(name:"DE_photo_"+name)
                c.notes=["Manual photographic review only. No aesthetic PASS/FAIL or Golden Master.",
                         "Crop centres: \(centers.map{"\($0.0)=(\($0.1),\($0.2))"}.joined(separator:", ")). Native 512×512 pixels."]
                for (title,configure) in variants {
                    let fx=configure(effect(.detailExtractor)).validated
                    let output=try render(input,[fx])
                    let variant=title.lowercased().replacingOccurrences(of:" ",with:"_")
                    let path=root+"/"+variant
                    try artifacts.png(output,path+".png")
                    try artifacts.png(artifacts.difference(input,output,gain:8),path+"_difference_x8.png")
                    try artifacts.json(fx,path+"_settings.json")
                    let roi=detailCenter(input.extent,side:256),m=gpu.compare(input,output,region:roi)
                    c.metrics[variant+"-centerMeanLuminanceChange"]=m.residual.mean
                    c.metrics[variant+"-centerChromaticityDrift"]=m.chromaticityMAE
                    c.metrics[variant+"-centerLocalRMSRatio"]=detailRMS(output,roi)/max(1e-9,detailRMS(input,roi))
                    c.metrics[variant+"-centerNonFinitePixels"]=Double(m.nonFinite)
                    c.check("Finite \(title) crop",m.nonFinite==0,hard:true,"Central 256×256 RGBA float crop.")
                    sheet.append((title,output)); selected[title]=output
                    for (label,x,y) in centers {crops.append(("\(title) · \(label)",detailCrop(output,x:x,y:y)))}
                    c.images += [path+".png",path+"_difference_x8.png",path+"_settings.json"]
                }
                let sheetPath=root+"/DetailExtractor_contact_sheet.png"
                let cropsPath=root+"/DetailExtractor_crops_100percent.png"
                try artifacts.sheet(sheet,sheetPath,cell:960,maxColumns:3)
                try artifacts.sheet(crops,cropsPath,nativeCrop:true,cell:512,maxColumns:4)
                c.images += [sheetPath,cropsPath]
                if index <= 1 {
                    let point=centers[0]
                    let titles=["Original","Subtle Detail","Fine Texture","Natural Detail","Strong Detail","Extreme Detail"]
                    let skin=titles.compactMap{title -> (String,CIImage)? in
                        guard let image=selected[title] else{return nil}
                        let roi=detailCrop(image,x:point.1,y:point.2)
                        let stats=gpu.compare(detailCrop(input,x:point.1,y:point.2),roi)
                        c.metrics[title+"-skinLocalRMS"]=detailRMS(roi,detailCenter(roi.extent,side:256))
                        c.metrics[title+"-skinMeanLuminanceChange"]=stats.residual.mean
                        c.metrics[title+"-skinChromaticityDrift"]=stats.chromaticityMAE
                        return(title,roi)
                    }
                    try artifacts.sheet(skin,root+"/skin_detail_comparison.png",nativeCrop:true,cell:512,maxColumns:3)
                    c.images.append(root+"/skin_detail_comparison.png")
                }
                if index == 4 || index == 5 {
                    let point=centers.last!
                    let titles=["Original","Fine Texture","Natural Detail","Strong Detail","Extreme Detail"]
                    let shadows=titles.compactMap{title -> (String,CIImage)? in
                        guard let image=selected[title] else{return nil}
                        return(title,detailCrop(image,x:point.1,y:point.2))
                    }
                    try artifacts.sheet(shadows,root+"/shadow_noise_comparison.png",nativeCrop:true,cell:512,maxColumns:3)
                    let enlarged=shadows.map{($0.0+" · 200%",$0.1.transformed(by:CGAffineTransform(scaleX:2,y:2)))}
                    try artifacts.sheet(enlarged,root+"/shadow_noise_comparison_200percent.png",nativeCrop:true,cell:512,maxColumns:3)
                    c.images += [root+"/shadow_noise_comparison.png",root+"/shadow_noise_comparison_200percent.png"]
                }
                cases.append(c)
            }
        }
    }

    private func detailReport() throws {
        let selected=cases.filter{$0.name.hasPrefix("DE_")}
        try artifacts.json(selected,"DetailExtractor/metrics.json")
        var report="""
        # Lumora — Detail Extractor Validation

        Generated: \(ISO8601DateFormatter().string(from:Date())). Device: \(gpu.deviceName).
        Production `CreativeStackRenderer` and `RenderEngine` used throughout. Measurements use
        extended linear sRGB RGBA Float32; PNG files are sRGB presentations. No Golden Master.

        The renderer derives Rec.709 luminance, local mean and variance at three spatial scales
        (1.6, 5.5 and 18 photographic pixels on a 3000-pixel long edge). Each variance-guided
        base partially follows structural edges. Its adjacent detail bands receive independent
        Fine/Medium/Large gains and smooth noise shrinkage, then a bounded luminance reconstruction.
        RGB scales by Y′/Y to preserve chromaticity. Shadow and highlight protection taper gains.
        This differs from Tonal Contrast's luminance-zone controls and fixed weighted Laplacian bands.
        Shader code, not this text, is the executable mathematical contract.

        Hard FAIL marks a functional invariant. WARN marks a heuristic for visual inspection.
        Photographs have numerical measures only, with no aesthetic judgement.

        ## Summary

        | Case | Status |
        | --- | --- |
        """
        for c in selected {report += "\n| \(c.name) | \(c.status) |"}
        report += "\n\n## Main artifacts\n\n"
        for path in ["DetailExtractor/DetailExtractorTestChart.png","DetailExtractor/detail_frequency_response.png",
                     "DetailExtractor/detail_edge_profile.png","DetailExtractor/TonalContrast_vs_DetailExtractor.png",
                     "DetailExtractor/TonalContrast_vs_DetailExtractor_Report.md","DetailExtractor/Synthetic/contact_sheet.png"] {
            report += "- [\(path)](\(path))\n"
        }
        for c in selected {
            report += "\n## \(c.name) — \(c.status)\n\n"
            for key in c.metrics.keys.sorted(){report += String(format:"- `%@`: %.8g\n",key,c.metrics[key]!)}
            for check in c.checks {report += "- **\(check.status)** \(check.name) [\(check.hard ? "hard invariant":"quality heuristic")]: \(check.detail)\n"}
            for note in c.notes {report += "- \(note)\n"}
            for path in c.images {report += "- [\(path)](\(path))\n"}
        }
        try report.write(to:artifacts.url("DetailExtractorValidationReport.md"),atomically:true,encoding:.utf8)
    }
}
