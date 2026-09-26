import Foundation
import CoreImage
@testable import LumoraCore

struct ProContrastTestChart {
    let image: CIImage
    let regions: [ChartRegion]
    static let names = ["full-ramp","compressed-ramp","low-ramp","high-ramp",
                        "dark-texture","mid-texture","highlight-texture","neutral-patches",
                        "warm-cast","cool-cast","green-cast","magenta-cast",
                        "light-skin","dark-skin","specular","soft-gradient"]
    static func generate(size:Int) -> Self {
        let image=SyntheticCharts.make(size:size) { x,y in
            let col=min(3,Int(x*4)),row=min(3,Int(y*4)),index=row*4+col
            let u=x*4-Double(col),v=y*4-Double(row)
            let texture=sin(u*83)*sin(v*67)
            switch index {
            case 0:return SIMD3(repeating:Float(u))
            case 1:return SIMD3(repeating:Float(0.25+0.45*u))
            case 2:return SIMD3(repeating:Float(0.35+0.30*u))
            case 3:return SIMD3(repeating:Float(0.03+0.94*u))
            case 4:return SIMD3(repeating:Float(0.06+0.025*texture))
            case 5:return SIMD3(repeating:Float(0.45+0.07*texture))
            case 6:return SIMD3(repeating:Float(0.82+0.045*texture))
            case 7:return SIMD3(repeating:Float(0.15+0.65*floor(u*4)/3))
            case 8:return SIMD3(0.49,0.42,0.35)
            case 9:return SIMD3(0.34,0.40,0.48)
            case 10:return SIMD3(0.38,0.49,0.37)
            case 11:return SIMD3(0.48,0.37,0.47)
            case 12:return SIMD3(0.59,0.35,0.24)
            case 13:return SIMD3(0.28,0.15,0.10)
            case 14:return SIMD3(repeating:Float(hypot(u-0.5,v-0.5)<0.015 ? 3.0:0.36))
            default:return SIMD3(repeating:Float(0.08+0.84*u*u*(3-2*u)))
            }
        }
        let cell=size/4
        let regions=names.enumerated().map { i,name in
            ChartRegion(name:name,x:(i%4)*cell,y:size-(i/4+1)*cell,
                        width:cell,height:cell,ramp:name.contains("ramp"))
        }
        return Self(image:image,regions:regions)
    }
    func rect(_ name:String)->CGRect { regions.first{$0.name == name}!.rect }
}

extension LumoraVisualTestLab {
    private func proPreset(_ title:String)->CreativeEffect {
        CreativeFXPreset.all(for:.proContrast).first{$0.title == title}!.makeEffect()
    }
    private func proCrop(_ image:CIImage,x:Double,y:Double,side:Int=512)->CIImage {
        let s=min(CGFloat(side),image.extent.width,image.extent.height)
        let px=min(image.extent.maxX-s,max(image.extent.minX,image.extent.minX+image.extent.width*x-s/2))
        let py=min(image.extent.maxY-s,max(image.extent.minY,image.extent.minY+image.extent.height*y-s/2))
        return image.cropped(to:CGRect(x:floor(px),y:floor(py),width:s,height:s))
    }
    private func proChroma(_ image:CIImage,_ rect:CGRect)->Double {
        let pixels=gpu.read(image,rect.integral)
        var sum=0.0,count=0
        for i in stride(from:0,to:pixels.count,by:4) {
            let rgb=(0..<3).map{max(0,Double(pixels[i+$0]))}
            sum += rgb.max()!-rgb.min()!;count += 1
        }
        return sum/Double(max(1,count))
    }
    private func proHue(_ before:CIImage,_ after:CIImage,_ rect:CGRect)->Double {
        let a=gpu.read(before,rect.integral),b=gpu.read(after,rect.integral)
        var error=0.0,count=0
        for i in stride(from:0,to:a.count,by:4) {
            let x=(0..<3).map{Double(a[i+$0])},y=(0..<3).map{Double(b[i+$0])}
            let u1=2*x[0]-x[1]-x[2],v1=sqrt(3.0)*(x[1]-x[2])
            let u2=2*y[0]-y[1]-y[2],v2=sqrt(3.0)*(y[1]-y[2])
            guard hypot(u1,v1)>1e-5,hypot(u2,v2)>1e-5 else {continue}
            let angle=abs(atan2(v1,u1)-atan2(v2,u2))
            error += min(angle,2*Double.pi-angle)/Double.pi;count += 1
        }
        return error/Double(max(1,count))
    }
    private func proFlatScene(size:Int=768,range:ClosedRange<Double>=0.25...0.70,
                              outliers:Bool=false)->CIImage {
        SyntheticCharts.make(size:size) { x,y in
            if outliers && x<1.0/Double(size) && y<1.0/Double(size) {return SIMD3(repeating:0)}
            if outliers && x>1-1.0/Double(size) && y>1-1.0/Double(size) {return SIMD3(repeating:8)}
            let t=(x+0.3*y)/1.3
            return SIMD3(repeating:Float(range.lowerBound+(range.upperBound-range.lowerBound)*t))
        }
    }
    private func proToneScene(size:Int=1024)->CIImage {
        SyntheticCharts.make(size:size) { x,y in
            let value=y<0.13 ? x : 0.25+0.45*x
            return SIMD3(repeating:Float(value))
        }
    }
    func runProContrast() async throws {
        progress("Pro Contrast synthetic chart and global analysis")
        let chart=ProContrastTestChart.generate(size:1024)
        try artifacts.png(chart.image,"ProContrast/ProContrastTestChart.png")
        try artifacts.json(chart.regions,"ProContrast/chart_regions.json")
        do {
            try proSynthetic(chart)
            try proCastTests()
            let separated=try proVsTonal(chart)
            guard separated else {
                var c=LabCase(name:"PC_architecture")
                c.check("Global/local distinction",false,hard:true,
                        "Pro Contrast resembled Tonal Contrast; stop before photographic campaign.")
                cases.append(c);try proReport();return
            }
            try proMasksAndStack(chart)
            try proResolutionPerformance()
            try await proPipeline(chart)
            try proPhotos()
        } catch {
            var c=LabCase(name:"PC_harness")
            c.check("Completed",false,hard:true,String(describing:error));cases.append(c)
            try proReport();throw error
        }
        try proReport()
    }
    private func proSynthetic(_ chart:ProContrastTestChart) throws {
        let zero=try render(chart.image,[effect(.proContrast,["amount":0])])
        let identity=gpu.compare(chart.image,zero)
        var c=LabCase(name:"PC_identity")
        c.metrics=["maxRGBError":identity.maxError,"meanLuminanceChange":identity.residual.mean,
                   "nonFinitePixels":Double(identity.nonFinite)]
        c.check("Amount zero identity",identity.maxError == 0,hard:true,"Unchanged input graph.")
        c.check("Finite",identity.nonFinite == 0,hard:true,"No NaN/Inf.")
        cases.append(c)
        let analyzer=ProContrastAnalyzer.shared
        let countersBefore=analyzer.counters()
        let stats=analyzer.analyze(chart.image).0
        let cacheHit=analyzer.analyze(chart.image).1
        let countersAfter=analyzer.counters()
        var cache=LabCase(name:"PC_analysis_cache")
        cache.metrics=["p01":stats.p01,"p05":stats.p05,"p25":stats.p25,"p50":stats.p50,
                       "p75":stats.p75,"p95":stats.p95,"p99":stats.p99,
                       "neutralFraction":stats.neutralFraction,"confidence":stats.confidence,
                       "newHits":Double(countersAfter.hits-countersBefore.hits),
                       "newMisses":Double(countersAfter.misses-countersBefore.misses)]
        cache.check("Repeated pixels reuse statistics",cacheHit,hard:true,
                    "Content-addressed 128×128 analysis cache, max 16 entries.")
        let changedUpstream=try render(chart.image,[effect(.bleachBypass,["amount":80])])
        let changedLookup=analyzer.analyze(changedUpstream)
        let croppedLookup=analyzer.analyze(chart.image.cropped(to:CGRect(x:128,y:128,width:768,height:768)))
        let countersInvalidated=analyzer.counters()
        cache.metrics["upstreamMisses"] = Double(countersInvalidated.misses-countersAfter.misses)
        cache.check("Previous effect invalidates",!changedLookup.1,hard:true,
                    "Changed upstream pixels produce a new content fingerprint.")
        cache.check("Crop invalidates",!croppedLookup.1,hard:true,
                    "The transformed/cropped source has a different 128×128 fingerprint.")
        cases.append(cache)
        let preset=CreativeFXPreset.all(for:.proContrast).first{$0.title == "Natural Contrast"}!
        var existing=CreativeEffect(.proContrast,maskID:UUID())
        let id=existing.id,maskID=existing.maskID
        existing=preset.applying(to:existing)
        let matched=CreativeFXPreset.matching(existing)?.title == "Natural Contrast"
        existing["dynamicContrast"] += 1
        let custom=CreativeFXPreset.matching(existing) == nil
        var before=EditState(),after=EditState()
        before.creative.effects=[preset.makeEffect()];after.creative.effects=[existing]
        var history=HistoryManager();history.begin("Pro Contrast slider",state:before);history.commit(after)
        let undone=history.undo(),redone=history.redo()
        let persisted=try JSONDecoder().decode(EditState.self,from:JSONEncoder().encode(after))
        var state=LabCase(name:"PC_preset_history")
        state.check("Preset matches",matched,hard:true,"Shared preset matcher.")
        state.check("Slider becomes Custom",custom,hard:true,"Manual parameter edit no longer matches a preset.")
        state.check("Identity and mask retained",existing.id == id && existing.maskID == maskID,
                    hard:true,"Applying a preset keeps the effect in the same stack position.")
        state.check("Undo/Redo",undone == before && redone == after,hard:true,"Existing EditState history.")
        state.check("Persistence",persisted == after,hard:true,"Codable document round trip.")
        cases.append(state)

        let compressed=proFlatScene(),wide=proFlatScene(range:0.03...0.97)
        let fx=proPreset("Flat Recovery")
        let narrowOutput=try render(compressed,[fx]),wideOutput=try render(wide,[fx])
        let narrowBefore=ProContrastAnalyzer.shared.analyze(compressed).0
        let narrowAfter=ProContrastAnalyzer.shared.analyze(narrowOutput).0
        let wideBefore=ProContrastAnalyzer.shared.analyze(wide).0
        let wideAfter=ProContrastAnalyzer.shared.analyze(wideOutput).0
        let lowGain=narrowAfter.usefulSpan/max(1e-8,narrowBefore.usefulSpan)
        let wideGain=wideAfter.usefulSpan/max(1e-8,wideBefore.usefulSpan)
        var contrast=LabCase(name:"PC_low_vs_existing_contrast")
        contrast.metrics=["lowP05Before":narrowBefore.p05,"lowP50Before":narrowBefore.p50,
                          "lowP95Before":narrowBefore.p95,"lowP05After":narrowAfter.p05,
                          "lowP50After":narrowAfter.p50,"lowP95After":narrowAfter.p95,
                          "lowContrastGain":lowGain,"alreadyContrastedGain":wideGain,
                          "lowRMSBefore":gpu.compare(compressed,compressed).input.standardDeviation,
                          "lowRMSAfter":gpu.compare(compressed,narrowOutput).output.standardDeviation]
        contrast.check("Compressed range expands",lowGain>1.03,hard:true,"Robust P05–P95 span increases.")
        contrast.check("Wide scene receives less",wideGain<lowGain-0.02,hard:true,
                       "Adaptation is based on robust global distribution, not a fixed gain.")
        cases.append(contrast)
        let contaminated=proFlatScene(outliers:true)
        let outlierStats=ProContrastAnalyzer.shared.analyze(contaminated).0
        var outlier=LabCase(name:"PC_outliers")
        outlier.metrics=["p05Difference":abs(outlierStats.p05-narrowBefore.p05),
                         "p95Difference":abs(outlierStats.p95-narrowBefore.p95),
                         "curveStrengthDifference":abs(outlierStats.strength(ProContrastSettings(effect:fx)) -
                                                       narrowBefore.strength(ProContrastSettings(effect:fx)))]
        outlier.check("Robust percentile stability",outlier.metrics["p05Difference"]!<0.01 &&
                      outlier.metrics["p95Difference"]!<0.01,hard:true,"One black and one HDR outlier.")
        outlier.check("Curve stability",outlier.metrics["curveStrengthDifference"]!<0.03,
                      "Quality heuristic against two isolated outliers.")
        cases.append(outlier)
        let toneScene=proToneScene()
        let toneRamp=CGRect(x:0,y:896,width:1024,height:128)
        let titles=["Subtle Correction","Natural Contrast","Flat Recovery","Punch","Strong Correction"]
        let original=gpu.compare(toneScene,toneScene,region:toneRamp,ramp:true)
        var curves:[(String,[Double])]=[("Original",original.transferInput)]
        var histograms:[(String,[Double])]=[("Original",original.histogramInput.map(Double.init))]
        for title in titles {
            let output=try render(toneScene,[proPreset(title)])
            let m=gpu.compare(toneScene,output,region:toneRamp,ramp:true)
            var ramp=LabCase(name:"PC_ramp_"+title.replacingOccurrences(of:" ",with:"_"))
            ramp.metrics=["rampReversals":Double(m.monotonicityViolations),
                          "maxAdjacentStep":m.maxAdjacentStep,"nonFinitePixels":Double(m.nonFinite)]
            ramp.check("Monotone",m.monotonicityViolations == 0,hard:true,"No step below -1e-6.")
            ramp.check("Finite",m.nonFinite == 0,hard:true,"RGBAf ramp.")
            ramp.check("Continuous sampling",m.maxAdjacentStep<0.01,hard:true,
                       "A 1024-pixel smooth ramp has no large discrete jump.")
            cases.append(ramp)
            curves.append((title,m.transferOutput))
            if ["Natural Contrast","Flat Recovery","Punch"].contains(title) {
                histograms.append((title,m.histogramOutput.map(Double.init)))
            }
        }
        try artifacts.plot(curves,"ProContrast/tone_curve_response.png",
                           title:"Global tone response on a midtone-dominated scene",yRange:0...1)
        try artifacts.plot(histograms,"ProContrast/histogram_before_after.png",
                           title:"Ramp luminance histogram, robust global correction")
        let hdr=SyntheticCharts.make(size:1024) { x,_ in SIMD3(repeating:Float(x*4)) }
        let hdrOutput=try render(hdr,[proPreset("Strong Correction")])
        let hdrRamp=gpu.compare(hdr,hdrOutput,region:CGRect(x:0,y:512,width:1024,height:1),ramp:true)
        var high=LabCase(name:"PC_HDR")
        high.metrics=["inputPeakY":hdrRamp.input.max,"outputPeakY":hdrRamp.output.max,
                      "rampReversals":Double(hdrRamp.monotonicityViolations),
                      "nonFinitePixels":Double(hdrRamp.nonFinite)]
        high.check("Extended values survive",hdrRamp.output.max>1,hard:true,"No pre-clamp at SDR white.")
        high.check("HDR monotone",hdrRamp.monotonicityViolations == 0,hard:true,"0…4 linear ramp.")
        high.check("Finite",hdrRamp.nonFinite == 0,hard:true,"No NaN/Inf.")
        cases.append(high)
        try artifacts.plot([("Input",hdrRamp.transferInput),("Output",hdrRamp.transferOutput)],
                           "ProContrast/hdr_response.png",title:"Extended-linear response 0...4",xMaximum:4)
    }
}

extension LumoraVisualTestLab {
    private func proNeutralScene(cast:SIMD3<Double>=SIMD3(repeating:1),skin:Bool=false)->CIImage {
        SyntheticCharts.make(size:512) { x,y in
            let shade=0.16+0.64*x
            let neutral=SIMD3<Double>(repeating:shade)
            let base:SIMD3<Double>
            if skin && y>0.55 {base=y<0.78 ? SIMD3(0.58,0.35,0.24):SIMD3(0.27,0.15,0.10)}
            else {base=neutral}
            let rgb=base*cast
            return SIMD3(Float(rgb.x),Float(rgb.y),Float(rgb.z))
        }
    }
    private func proMonochromeScene(_ color:SIMD3<Double>,neutralPatch:Bool=false)->CIImage {
        SyntheticCharts.make(size:512) { x,y in
            let shade=0.50+0.15*sin(x*19)*sin(y*11)
            let rgb=neutralPatch && x>0.05 && x<0.32 && y>0.30 && y<0.80
                ? SIMD3<Double>(repeating:0.48)*SIMD3(1.18,1.0,0.85)
                : color*shade
            return SIMD3(Float(rgb.x),Float(rgb.y),Float(rgb.z))
        }
    }
    private func proSunset()->CIImage {
        SyntheticCharts.make(size:512) { x,y in
            let sun=hypot(x-0.72,y-0.34)<0.035
            if sun {return SIMD3(repeating:1.8)}
            if y>0.75 {return SIMD3(repeating:0.025)}
            let rgb=y<0.55 ? SIMD3<Double>(0.9,0.35+0.22*y,0.08+0.10*y)
                             : SIMD3<Double>(0.5,0.16,0.045)
            return SIMD3(Float(rgb.x),Float(rgb.y),Float(rgb.z))
        }
    }
    private func proCastTests() throws {
        progress("Pro Contrast cast confidence and skin")
        let reference=proNeutralScene()
        let variants:[(String,SIMD3<Double>)]=[
            ("Warm",SIMD3(1.18,1,0.85)),("Cool",SIMD3(0.86,1,1.16)),
            ("Green",SIMD3(0.90,1.12,0.90)),("Magenta",SIMD3(1.10,0.90,1.10))]
        let castFX=effect(.proContrast,["amount":100,"correctColorCast":100,
                                          "correctContrast":0,"dynamicContrast":0])
        let halfFX=effect(.proContrast,["amount":100,"correctColorCast":50,
                                          "correctContrast":0,"dynamicContrast":0])
        var sheet:[(String,CIImage)]=[("Neutral reference",reference)]
        for (name,cast) in variants {
            let input=proNeutralScene(cast:cast)
            let halfway=try render(input,[halfFX]),corrected=try render(input,[castFX])
            let scene=ProContrastAnalyzer.shared.analyze(input).0
            let inputNeutral=proChroma(input,input.extent),outputNeutral=proChroma(corrected,corrected.extent)
            var c=LabCase(name:"PC_cast_"+name)
            c.metrics=["estimatedLogRG":scene.castRG,"estimatedLogBG":scene.castBG,
                       "confidence":scene.confidence,"neutralFraction":scene.neutralFraction,
                       "appliedCorrection":scene.confidence,
                       "chromaBefore":inputNeutral,"chromaAfter":outputNeutral,
                       "nonFinitePixels":Double(gpu.compare(input,corrected).nonFinite)]
            c.check("Credible neutral reference",scene.confidence>0.20,
                    "Quality heuristic on a known neutral synthetic scene with a global cast.")
            c.check("Neutrality improves",outputNeutral<inputNeutral,
                    "Quality heuristic; correction is controlled by confidence and slider.")
            c.check("Finite",c.metrics["nonFinitePixels"] == 0,hard:true,"No NaN/Inf.")
            cases.append(c)
            sheet += [("\(name) cast",input),("\(name) 50%",halfway),("\(name) 100%",corrected)]
        }
        try artifacts.sheet(sheet,"ProContrast/color_cast_correction.png",cell:320,maxColumns:4)
        let foliage=proMonochromeScene(SIMD3(0.15,0.78,0.14))
        let ocean=proMonochromeScene(SIMD3(0.08,0.37,0.88))
        let orange=proMonochromeScene(SIMD3(0.92,0.36,0.08))
        let sunset=proSunset()
        let referenceScene=proMonochromeScene(SIMD3(0.92,0.36,0.08),neutralPatch:true)
        var sceneSheet:[(String,CIImage)]=[]
        var confidenceSeries:[(String,[Double])]=[]
        for (name,input) in [("Foliage",foliage),("Ocean",ocean),("Orange",orange),
                             ("Sunset",sunset),("Warm + gray object",referenceScene)] {
            let stats=ProContrastAnalyzer.shared.analyze(input).0
            let output=try render(input,[castFX])
            let m=gpu.compare(input,output)
            var c=LabCase(name:"PC_scene_"+name.replacingOccurrences(of:" ",with:"_"))
            c.metrics=["confidence":stats.confidence,"neutralFraction":stats.neutralFraction,
                       "estimatedLogRG":stats.castRG,"estimatedLogBG":stats.castBG,
                       "appliedCorrection":stats.confidence,
                       "meanLuminanceChange":m.residual.mean,"chromaticityDrift":m.chromaticityMAE]
            if name != "Warm + gray object" {
                c.check("Scene mood protected",stats.confidence<0.20,
                        "Quality heuristic: saturated scenes alone are not credible neutral references.")
            }
            if name == "Sunset" {
                c.check("Sunset is not fully neutralized",m.chromaticityMAE<0.03,
                        "Quality heuristic; preserves a deliberate orange atmosphere.")
            }
            if name == "Warm + gray object" {
                let sunsetConfidence=ProContrastAnalyzer.shared.analyze(sunset).0.confidence
                c.metrics["sunsetConfidence"]=sunsetConfidence
                c.check("Known gray raises confidence",stats.confidence>sunsetConfidence+0.10,
                        "Quality heuristic: gray reference supports more correction than a pure sunset.")
            }
            cases.append(c)
            sceneSheet += [("\(name) input",input),("\(name) corrected",output)]
            confidenceSeries.append((name,[stats.confidence,stats.neutralFraction]))
        }
        try artifacts.sheet(sceneSheet,"ProContrast/scene_color_confidence.png",cell:320,maxColumns:4)
        try artifacts.plot(confidenceSeries,"ProContrast/scene_confidence_metrics.png",
                           title:"Scene confidence / neutral fraction",yRange:0...1)
        // SyntheticCharts stores its first row at the top; CI coordinates are
        // lower-left. Skin bands y=0.55...0.78 and 0.78...1 map below y=230.
        let skinROI=CGRect(x:100,y:145,width:280,height:60)
        for (name,cast) in [("Neutral",SIMD3<Double>(repeating:1)),
                            ("Warm",SIMD3(1.18,1,0.85)),("Cool",SIMD3(0.86,1,1.16))] {
            let input=proNeutralScene(cast:cast,skin:true)
            let output=try render(input,[proPreset("Natural Contrast")])
            for (tone,roi) in [("light",skinROI),("dark",CGRect(x:100,y:30,width:280,height:60))] {
                let m=gpu.compare(input,output,region:roi)
                var c=LabCase(name:"PC_skin_\(name)_\(tone)")
                c.metrics=["inputY":m.input.mean,"outputY":m.output.mean,
                           "inputChroma":proChroma(input,roi),"outputChroma":proChroma(output,roi),
                           "hueDrift":proHue(input,output,roi),
                           "chromaticityDrift":m.chromaticityMAE,"nonFinitePixels":Double(m.nonFinite)]
                c.check("Finite",m.nonFinite == 0,hard:true,"Synthetic skin patch.")
                c.check("Skin hue stable",c.metrics["hueDrift"]!<0.12,
                        "Quality heuristic: opponent-plane angular drift/π.")
                cases.append(c)
            }
        }
    }
    private func proVsTonal(_ chart:ProContrastTestChart) throws -> Bool {
        progress("Pro Contrast vs Tonal Contrast distinction")
        let source=proFlatScene(size:1024)
        let pro=try render(source,[proPreset("Natural Contrast")])
        let tonalFX=CreativeFXPreset.all(for:.tonalContrast).first{$0.title == "Natural Texture"}!.makeEffect()
        let tonal=try render(source,[tonalFX])
        let proStats=gpu.compare(source,pro),tonalStats=gpu.compare(source,tonal)
        let region=CGRect(x:384,y:384,width:256,height:256)
        let proSpatial=gpu.structure(source,pro,region:region)
        let tonalSpatial=gpu.structure(source,tonal,region:region)
        let point=SyntheticCharts.make(size:512) { x,y in
            SIMD3(repeating:Float(hypot(x-0.5,y-0.5)<0.04 ? 0.90:0.42))
        }
        let pointPro=try render(point,[proPreset("Punch")])
        let pointTonal=try render(point,[tonalFX])
        let near=CGRect(x:284,y:250,width:8,height:12)
        let far=CGRect(x:360,y:250,width:8,height:12)
        let proNearFar=abs(gpu.compare(point,pointPro,region:near).output.mean -
                           gpu.compare(point,pointPro,region:far).output.mean)
        let tonalNearFar=abs(gpu.compare(point,pointTonal,region:near).output.mean -
                             gpu.compare(point,pointTonal,region:far).output.mean)
        var c=LabCase(name:"PC_vs_TonalContrast")
        c.metrics=["proGlobalHistogramMAE":zip(proStats.histogramInput,proStats.histogramOutput)
                   .map{abs($0-$1)}.reduce(0,+).toDouble()/Double(max(1,source.extent.width*source.extent.height)),
                   "tonalGlobalHistogramMAE":zip(tonalStats.histogramInput,tonalStats.histogramOutput)
                   .map{abs($0-$1)}.reduce(0,+).toDouble()/Double(max(1,source.extent.width*source.extent.height)),
                   "proLocalResidualEdgeRMS":proSpatial.edgeRMS,
                   "tonalLocalResidualEdgeRMS":tonalSpatial.edgeRMS,
                   "proResidualSpectralCentroid":proSpatial.spectralCentroid,
                   "tonalResidualSpectralCentroid":tonalSpatial.spectralCentroid,
                   "proNeighborResponse":proNearFar,"tonalNeighborResponse":tonalNearFar,
                   "proMeanYChange":proStats.residual.mean,"tonalMeanYChange":tonalStats.residual.mean]
        let separated=proNearFar<2e-5 && tonalNearFar>proNearFar+1e-6
        c.check("Pointwise versus local response",separated,hard:true,
                "Pro output is uniform on equal-input neighbors; Tonal's spatial pyramid responds near the source.")
        cases.append(c)
        try artifacts.sheet([("Original",source),("Pro Natural",pro),("Tonal Natural",tonal),
                             ("Pro difference x8",artifacts.difference(source,pro,gain:8)),
                             ("Tonal difference x8",artifacts.difference(source,tonal,gain:8))],
                            "ProContrast_vs_TonalContrast.png",cell:512,maxColumns:3)
        return separated
    }
}

private extension Int { func toDouble()->Double { Double(self) } }

extension LumoraVisualTestLab {
    private func proMasksAndStack(_ chart:ProContrastTestChart) throws {
        progress("Pro Contrast masks and stack order")
        let source=chart.image,fx=proPreset("Punch")
        var radial=RadialGradientMask();radial.center=MaskPoint(x:0.35,y:0.5)
        radial.radiusX=0.19;radial.radiusY=0.19;radial.feather=4
        let mask=LocalMask(name:"Pro region",components:[MaskComponent(shape:.radial(radial))])
        var targeted=fx;targeted.maskID=mask.id
        let simple=try render(source,[targeted],masks:[mask])
        var inverse=mask;inverse.inverted=true
        let inverted=try render(source,[targeted],masks:[inverse])
        var radial2=radial;radial2.center=MaskPoint(x:0.75,y:0.5)
        let mask2=LocalMask(name:"Second",components:[MaskComponent(shape:.radial(radial2))])
        var second=fx;second.maskID=mask2.id
        let stacked=try render(source,[targeted,second],masks:[mask,mask2])
        var hole=radial;hole.radiusX=0.055;hole.radiusY=0.055;hole.feather=0
        let subtraction=LocalMask(name:"Pro minus center",components:[
            MaskComponent(operation:.add,shape:.radial(radial)),
            MaskComponent(operation:.subtract,shape:.radial(hole))])
        var cutFX=fx;cutFX.maskID=subtraction.id
        let cut=try render(source,[cutFX],masks:[subtraction])
        let outside=CGRect(x:10,y:10,width:64,height:64)
        let center=CGRect(x:344,y:496,width:24,height:24)
        let secondCenter=CGRect(x:756,y:496,width:24,height:24)
        var c=LabCase(name:"PC_masks")
        c.metrics=["simpleOutsideMaxError":gpu.compare(source,simple,region:outside).maxError,
                   "invertedCenterMaxError":gpu.compare(source,inverted,region:center).maxError,
                   "stackedOutsideMaxError":gpu.compare(source,stacked,region:outside).maxError,
                   "subtractiveCenterMaxError":gpu.compare(source,cut,region:center).maxError,
                   "simpleCenterMAE":gpu.compare(source,simple,region:center).mae,
                   "stackedSecondMAE":gpu.compare(source,stacked,region:secondCenter).mae]
        for key in ["simpleOutsideMaxError","invertedCenterMaxError",
                    "stackedOutsideMaxError","subtractiveCenterMaxError"] {
            c.check("Mask isolation \(key)",c.metrics[key]!<2e-6,hard:true,
                    "No modification outside the effective existing mask.")
        }
        c.check("Masked regions respond",c.metrics["simpleCenterMAE"]!>1e-6 &&
                c.metrics["stackedSecondMAE"]!>1e-6,hard:true,"Both regions respond.")
        c.images=["ProContrast/mask_comparison.png"]
        try artifacts.sheet([("Original",source),("Simple",simple),("Inverted",inverted),
                             ("Stacked",stacked),("Subtractive",cut)],c.images[0],cell:512,maxColumns:3)
        cases.append(c)
        let others:[(String,CreativeEffect)]=[
            ("Tonal Contrast",CreativeFXPreset.all(for:.tonalContrast).first{$0.title=="Natural Texture"}!.makeEffect()),
            ("Bleach Bypass",CreativeFXPreset.all(for:.bleachBypass).first{$0.title=="Classic Bypass"}!.makeEffect()),
            ("Glamour Glow",CreativeFXPreset.all(for:.glamourGlow).first{$0.title=="Portrait Glow"}!.makeEffect()),
            ("Grain",effect(.grain,["amount":60,"size":40]))]
        for (name,other) in others {
            let forward=try render(source,[fx,other]),reverse=try render(source,[other,fx])
            let m=gpu.compare(forward,reverse)
            var order=LabCase(name:"PC_stack_"+name.replacingOccurrences(of:" ",with:"_"))
            order.metrics=["forwardReverseMAE":m.mae,"nonFinitePixels":Double(m.nonFinite)]
            order.check("Order differs",m.mae>1e-6,hard:true,"Ordered Creative stack is noncommutative.")
            order.check("Finite",m.nonFinite == 0,hard:true,"No NaN/Inf.")
            let path="ProContrast/stack_"+name.lowercased().replacingOccurrences(of:" ",with:"_")+".png"
            try artifacts.sheet([("Pro → \(name)",forward),("\(name) → Pro",reverse),
                                 ("Difference x8",artifacts.difference(forward,reverse,gain:8))],
                                path,cell:512,maxColumns:3)
            order.images=[path];cases.append(order)
        }
    }
    private func proResolutionPerformance() throws {
        progress("Pro Contrast analysis/render timing and resolution")
        var c=LabCase(name:"PC_resolution_performance")
        var reference:CIImage?
        for dimension in [1024,2048,4096] {
            try autoreleasepool {
                let input=proFlatScene(size:dimension)
                let start=ProcessInfo.processInfo.systemUptime
                let statistics=ProContrastAnalyzer.shared.analyze(input).0
                let afterAnalysis=ProcessInfo.processInfo.systemUptime
                let output=try render(input,[proPreset("Flat Recovery")])
                let sample=normalized(output,to:512)
                let m=gpu.compare(normalized(input,to:512),sample)
                c.metrics["\(dimension)-analysisMilliseconds"]=(afterAnalysis-start)*1000
                c.metrics["\(dimension)-renderMilliseconds"]=(ProcessInfo.processInfo.systemUptime-afterAnalysis)*1000
                c.metrics["\(dimension)-p05"]=statistics.p05
                c.metrics["\(dimension)-p50"]=statistics.p50
                c.metrics["\(dimension)-p95"]=statistics.p95
                c.metrics["\(dimension)-confidence"]=statistics.confidence
                c.metrics["\(dimension)-nonFinitePixels"]=Double(m.nonFinite)
                c.check("Finite \(dimension)",m.nonFinite == 0,hard:true,"512 px measured output.")
                if let reference {
                    let agreement=gpu.compare(reference,sample)
                    c.metrics["\(dimension)-normalizedRMSE"]=agreement.rmse
                    c.check("Resolution agreement \(dimension)",agreement.rmse<0.015,
                            "Quality heuristic after matching output dimensions.")
                } else {reference=sample}
                try artifacts.png(sample,"ProContrast/resolution_\(dimension).png")
            }
        }
        cases.append(c)
    }
    private func proPipeline(_ chart:ProContrastTestChart) async throws {
        progress("Pro Contrast preview, HQ and export")
        let source=normalized(chart.image,to:2048)
        let path=try artifacts.url("ProContrast/Pipeline/source.png")
        try artifacts.png(source,"ProContrast/Pipeline/source.png")
        let engine=RenderEngine()
        var state=EditState();state.creative.effects=[proPreset("Natural Contrast")]
        var c=LabCase(name:"PC_preview_HQ_export")
        var images:[(String,CIImage)]=[]
        var statistics:[String:ProContrastSceneStats]=[:]
        for quality in [PreviewQuality.interactive,.high] {
            let result=try await engine.render(url:path,state:state,quality:quality)
            let name=quality == .interactive ? "interactive":"HQ"
            c.metrics[name+"-milliseconds"]=result.milliseconds
            c.metrics[name+"-width"]=Double(result.image.width)
            statistics[name]=ProContrastAnalyzer.shared.analyze(CIImage(cgImage:result.original)).0
            images.append((name,CIImage(cgImage:result.image)))
        }
        let repeated=try await engine.render(url:path,state:state,quality:.interactive)
        c.check("Preview cache hit",repeated.cacheHit,hard:true,"RenderEngine source cache.")
        state.creative.effects[0]["correctContrast"]=90
        let changed=try await engine.render(url:path,state:state,quality:.interactive)
        let changedImage=CIImage(cgImage:changed.image)
        c.metrics["parameterChangeMAE"]=gpu.compare(images[0].1,changedImage).mae
        c.check("Slider updates preview",c.metrics["parameterChangeMAE"]!>1e-6,hard:true,
                "Correct Contrast change changes pixels.")
        var settings=ExportSettings();settings.format = .png
        settings.colorSpace = .displayP3;settings.includeMetadata = false
        let exported=try await engine.export(request:ExportRequest(sourceURL:path,state:state,name:"pro-contrast-lab"),
                                             settings:settings,directory:artifacts.url("ProContrast/Pipeline/Export"))
        guard let exportImage=CIImage(contentsOf:exported.url) else {throw LabError.render}
        let exportStats=ProContrastAnalyzer.shared.analyze(source).0
        for (name,stats) in statistics {
            c.metrics[name+"-p05"]=stats.p05;c.metrics[name+"-p50"]=stats.p50
            c.metrics[name+"-p95"]=stats.p95;c.metrics[name+"-confidence"]=stats.confidence
        }
        c.metrics["export-p05"]=exportStats.p05;c.metrics["export-p50"]=exportStats.p50
        c.metrics["export-p95"]=exportStats.p95;c.metrics["export-confidence"]=exportStats.confidence
        c.metrics["exportWidth"]=Double(exported.width)
        c.metrics["previewExportSSIM"]=gpu.compare(normalized(changedImage,to:512),
                                                     normalized(exportImage,to:512)).ssim
        c.check("Preview/export agreement",c.metrics["previewExportSSIM"]!>0.90,
                "Quality heuristic after color conversion and resizing.")
        c.check("Analysis percentiles agree",abs(statistics["HQ"]!.p50-exportStats.p50)<0.03,
                "Quality heuristic across development/preview/export representations.")
        images += [("Changed preview",changedImage),("Export",exportImage)]
        c.images=["ProContrast/Pipeline/comparison.png"]
        try artifacts.sheet(images,c.images[0],cell:512)
        cases.append(c)
    }
}

extension LumoraVisualTestLab {
    private func proPriority(_ index:Int)->[(String,Double,Double)] {
        switch index {
        case 0:return [("skin",0.5,0.5),("hair",0.5,0.77)]
        case 1:return [("skin",0.5,0.5),("dark hair",0.5,0.77)]
        case 2:return [("clouds",0.5,0.28),("ridge",0.5,0.57)]
        case 3:return [("subject",0.48,0.57),("sun",0.5,0.28)]
        case 4:return [("lamps",0.5,0.25),("stone",0.5,0.68)]
        case 5:return [("window",0.5,0.3),("interior",0.5,0.7)]
        case 6:return [("dress",0.5,0.68),("skin",0.5,0.52)]
        default:return [("skin",0.5,0.5),("knit",0.5,0.58),("water",0.5,0.25)]
        }
    }
    private func proPhotos() throws {
        let repo=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let folder=URL(fileURLWithPath:ProcessInfo.processInfo.environment["LUMORA_VISUAL_ASSETS"]
            ?? repo.appendingPathComponent("Validation/VisualTestAssets").path)
        let files=try FileManager.default.contentsOfDirectory(at:folder,includingPropertiesForKeys:nil)
            .filter{["png","jpg","jpeg","tif","tiff","heic"].contains($0.pathExtension.lowercased())}
            .sorted{$0.lastPathComponent<$1.lastPathComponent}
        guard files.count == 8 else {throw NSError(domain:"ProContrastLab",code:1,
            userInfo:[NSLocalizedDescriptionKey:"Expected eight photos; found \(files.count) in \(folder.path)"])}
        let titles=["Subtle Correction","Natural Contrast","Flat Recovery",
                    "Punch","Color Neutralize","Strong Correction"]
        for (index,file) in files.enumerated() {
            progress("Pro Contrast photo \(index+1)/8: \(file.lastPathComponent)")
            try autoreleasepool {
                guard var input=CIImage(contentsOf:file,options:[.applyOrientationProperty:true]) else {throw LabError.render}
                input=input.transformed(by:CGAffineTransform(translationX:-input.extent.minX,y:-input.extent.minY))
                let root="ProContrast/RealPhotos/"+file.deletingPathExtension().lastPathComponent
                try artifacts.png(input,root+"/Original.png")
                let stats=ProContrastAnalyzer.shared.analyze(input).0
                let centers=proPriority(index)
                var sheet:[(String,CIImage)]=[("Original",input)]
                var crops:[(String,CIImage)]=centers.map{("Original · \($0.0)",proCrop(input,x:$0.1,y:$0.2))}
                var selected:[String:CIImage]=[:]
                var c=LabCase(name:"PC_photo_"+file.deletingPathExtension().lastPathComponent)
                c.metrics=["p01":stats.p01,"p05":stats.p05,"p25":stats.p25,"p50":stats.p50,
                           "p75":stats.p75,"p95":stats.p95,"p99":stats.p99,
                           "estimatedCastRG":stats.castRG,"estimatedCastBG":stats.castBG,
                           "confidence":stats.confidence,"neutralFraction":stats.neutralFraction]
                c.notes=["Manual photographic inspection, no aesthetic PASS/FAIL or Golden Master.",
                         "Native 512 px crop centers: \(centers.map{"\($0.0)=(\($0.1),\($0.2))"}.joined(separator:", "))."]
                for title in titles {
                    let fx=proPreset(title).validated
                    let output=try render(input,[fx])
                    let key=title.lowercased().replacingOccurrences(of:" ",with:"_")
                    let path=root+"/"+key
                    try artifacts.png(output,path+".png")
                    try artifacts.png(artifacts.difference(input,output,gain:6),path+"_difference_x6.png")
                    try artifacts.json(fx,path+"_settings.json")
                    let a=normalized(input,to:512),b=normalized(output,to:512),m=gpu.compare(a,b)
                    c.metrics[key+"-meanLuminanceChange"]=m.residual.mean
                    c.metrics[key+"-chromaticityDrift"]=m.chromaticityMAE
                    c.metrics[key+"-chromaChange"]=proChroma(b,b.extent)-proChroma(a,a.extent)
                    c.metrics[key+"-appliedCorrection"]=stats.confidence*fx["correctColorCast"]/100*fx["amount"]/100
                    c.metrics[key+"-nonFinitePixels"]=Double(m.nonFinite)
                    c.check("Finite \(title)",m.nonFinite == 0,hard:true,"512 px photographic sample in RGBAf.")
                    sheet.append((title,output));selected[title]=output
                    for (label,x,y) in centers {crops.append(("\(title) · \(label)",proCrop(output,x:x,y:y)))}
                }
                let contact=root+"/ProContrast_contact_sheet.png"
                let native=root+"/ProContrast_crops_100percent.png"
                try artifacts.sheet(sheet,contact,cell:960,maxColumns:3)
                try artifacts.sheet(crops,native,nativeCrop:true,cell:512,maxColumns:4)
                c.images=[contact,native]
                let special:[Int:String]=[3:"backlight_procontrast_comparison.png",
                                          4:"night_procontrast_comparison.png",
                                          5:"indoor_procontrast_comparison.png",
                                          6:"white_subject_procontrast_comparison.png"]
                if let name=special[index] {
                    let point=centers[0]
                    let items:[(String,CIImage)]=[("Original",input)]+titles.compactMap{title in
                        selected[title].map{(title,$0)}
                    }
                    try artifacts.sheet(items.map{($0.0,proCrop($0.1,x:point.1,y:point.2))},
                                        root+"/"+name,nativeCrop:true,cell:512,maxColumns:4)
                    c.images.append(root+"/"+name)
                }
                cases.append(c)
            }
        }
    }
    private func proReport() throws {
        let selected=cases.filter{$0.name.hasPrefix("PC_")}
        try artifacts.json(selected,"ProContrast/metrics.json")
        let counts=Dictionary(grouping:selected,by:\.status).mapValues(\.count)
        let lines=selected.map{c in
            "| \(c.name) | \(c.status) | \(c.checks.filter{$0.hard && $0.status == "FAIL"}.count) | \(c.checks.filter{$0.status == "WARN"}.count) | \(c.metrics.keys.sorted().map{"\($0)=\(String(format:"%.5g",c.metrics[$0]!))"}.joined(separator:"; ")) | \(c.images.map{"[image](\($0))"}.joined(separator:" ")) |"
        }.joined(separator:"\n")
        let report="""
        # Pro Contrast — validation

        `CreativeEffectKind.proContrast` uses the ordered Creative stack, its existing mask/opacity compositor and `RenderEngine` preview/HQ/export. Tonal Contrast, High/Low Key, Bleach Bypass and other effect algorithms were not changed. Pro Contrast performs a fixed-size 128×128 extended-linear sRGB scene analysis followed by one pointwise Metal kernel. It has no spatial pyramid, unsharp mask, local texture filtering or generated noise. No Golden Master was created.

        ## Global scene model

        The analyzer sorts Rec.709 linear luminance `Y=0.2126R+0.7152G+0.0722B` from the thumbnail and reports P01/P05/P25/P50/P75/P95/P99, including HDR values. It ignores extrema for adaptation: useful span is `P95−P05`; the pivot is P50 clamped to `[0.2,0.8]`. Range need is `clamp((0.88−span)/0.60)` and middle-cluster need is `clamp((0.50−(P75−P25))/0.40)`. Curve strength is `min(1.15, rangeNeed·(1.05·CorrectContrast + 0.75·DynamicContrast·middleNeed))`, with controls normalized to `[0,1]`. Thus a wide-range scene receives little or no adjustment. This is not min/max auto-levels.

        For `0≤Y≤1`, the GPU applies `F(Y)=Y+k·(Y−pivot)·Y·(1−Y)·shadowGuard(Y)·highlightGuard(Y)`, then mixes with the original by Amount. Guards are smoothstep functions over `[0,0.20]` and `[0.80,1]`; the protected setting suppresses endpoint movement. This bounded curve is continuous and tested for positive slope. Above 1, `F(Y)=1+slope·(Y−1)/(1+0.35k·(Y−1))`, with `slope=1−k(1−pivot)(1−HighlightProtection)`, matching the derivative at 1 and preserving HDR values. RGB is reconstructed by `F(Y)/Y`, preserving chromaticity absent color-cast correction.

        For cast estimation, only pixels with `0.06≤Y≤0.90`, every channel above 0.02 and `(maxRGB−minRGB)/Y<0.42` become possible neutral references. Median `log(R/G)` and `log(B/G)` values are taken after a 10% trim at each end and clamped to ±0.35. Confidence is `min(1,neutralFraction/0.10)·min(1,meanNeutralQuality/0.60)`. Color gains are applied at user strength × confidence, then re-normalized per pixel to keep luminance unchanged. Saturated sunsets, foliage and ocean scenes should therefore have weak correction unless credible gray areas exist. The bounded 16-entry content-addressed cache is keyed by the exact RGBAf thumbnail; slider changes reuse quantiles, while changed upstream pixels naturally invalidate the key. The thumbnail render remains bounded rather than reading the full photograph on CPU.

        **Hard invariants:** Amount-zero identity, finite pixels, monotone/continuous ramp samples, source statistics cache reuse, outlier robustness, mask isolation, stack order, preset/Custom, Undo/Redo, document persistence and preview cache invalidation. **Quality heuristics:** skin hue, cast confidence, sunset mood, color correction, resolution agreement and preview/export similarity. Hue drift is the wrapped angular difference in the linear RGB opponent plane; chromaticity drift is reported separately. Timings are descriptive with no hard threshold. `PASS` means no recorded issue, `WARN` requests manual review and `FAIL` marks a broken hard invariant. Counts: PASS \(counts["PASS"] ?? 0), WARN \(counts["WARN"] ?? 0), FAIL \(counts["FAIL"] ?? 0).

        Presets: \(CreativeFXPreset.all(for:.proContrast).map{$0.title}.joined(separator:", ")). Parameter snapshots are saved beside each image. The shared selector shows Custom when sliders depart from those snapshots; editing preserves effect ID, mask and stack position.

        [Synthetic chart](ProContrast/ProContrastTestChart.png), [tone curves](ProContrast/tone_curve_response.png), [histograms](ProContrast/histogram_before_after.png), [cast correction](ProContrast/color_cast_correction.png), [scene confidence](ProContrast/scene_color_confidence.png), [HDR curve](ProContrast/hdr_response.png), [comparison with Tonal Contrast](ProContrast_vs_TonalContrast.png), [masks](ProContrast/mask_comparison.png).

        The eight real photographs have Original and all six presets, a full contact sheet, native 100% crops, difference maps, exact settings JSON and scene estimates. Night, backlight, indoor high contrast and white subject have dedicated comparison sheets. Their metrics aid inspection; no variant is automatically judged photographically good or bad.

        | Case | Status | Hard failures | Warnings | Metrics | Artifacts |
        |---|---|---:|---:|---|---|
        \(lines)
        """
        try report.write(to:artifacts.url("ProContrastValidationReport.md"),atomically:true,encoding:.utf8)
    }
}
