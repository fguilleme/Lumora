import Foundation
import CoreImage
import Testing
@testable import LumoraCore

struct SilverBWTestChart {
    static let colorNames=["red","orange","yellow","green","cyan","blue","magenta"]
    static let equalColors: [SIMD3<Float>] = [SIMD3<Float>(1,0,0),.init(1,0.3,0),.init(1,1,0),.init(0,1,0),
        .init(0,1,1),.init(0,0,1),.init(1,0,1)].map { c in c * (0.05/(c.x*0.2126+c.y*0.7152+c.z*0.0722)) }
    static let names=["neutral ramp"]+colorNames+["light skin","dark skin","foliage green","blue sky",
        "red fabric","white cloth","dark texture","midtone texture","highlight texture","HDR ramp","near black","specular"]
    let image:CIImage
    let regions:[ChartRegion]
    static func generate(size:Int=1024)->Self {
        let image=SyntheticCharts.make(size:size){x,y in
            let col=min(3,Int(x*4)),row=min(4,Int(y*5)),i=row*4+col,u=x*4-Double(col)
            let wave=Float(sin(x*3000*0.21)*cos(y*3000*0.17)),t=Float(u)
            switch i {
            case 0:return SIMD3(repeating:t)
            case 1...7:return equalColors[i-1]
            case 8:return .init(0.59,0.35,0.24)
            case 9:return .init(0.28,0.15,0.10)
            case 10:return .init(0.065,0.26,0.045)
            case 11:return .init(0.09,0.25,0.58)
            case 12:return .init(0.50+0.015*wave,0.035,0.025)
            case 13:return SIMD3(repeating:0.82+0.025*wave)
            case 14:return SIMD3(repeating:0.045+0.012*wave)
            case 15:return SIMD3(repeating:0.40+0.025*wave)
            case 16:return SIMD3(repeating:0.87+0.035*wave)
            case 17:return SIMD3(repeating:8*t)
            case 18:return SIMD3(repeating:0.06*t)
            default:return SIMD3(repeating:1.8+0.1*wave)
            }
        }
        let regions=names.enumerated().map{i,n in
            ChartRegion(name:n,x:i%4*(size/4)+size/64,y:size-(i/4+1)*(size/5)+size/64,
                        width:size/4-size/32,height:size/5-size/32,ramp:n.contains("ramp"))
        }
        return Self(image:image,regions:regions)
    }
    func rect(_ name:String)->CGRect { regions.first{$0.name==name}!.rect }
}

@Test func silverBWValidation() async throws {
    let repo=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let root=ProcessInfo.processInfo.environment["LUMORA_VISUAL_OUTPUT"].map{URL(fileURLWithPath:$0)} ?? repo.appendingPathComponent("Validation/TestArtifacts")
    let lab=try LumoraVisualTestLab(root:root,full:true)
    try await lab.runSilverBW()
    for c in lab.cases { for check in c.checks where check.hard {
        #expect(check.status != "FAIL","\(c.name): \(check.name). See SilverBWValidationReport.md")
    } }
}

extension LumoraVisualTestLab {
    func silverPreset(_ title:String)->CreativeEffect { CreativeFXPreset.all(for:.silverBW).first{$0.title==title}!.makeEffect() }
    func silverFX(_ values:[String:Double]=[:])->CreativeEffect { effect(.silverBW,values) }
    func silverPixels(_ image:CIImage)->[Float] { gpu.read(image,image.extent.integral) }
    func silverNeutralError(_ p:[Float])->Double {
        var error=0.0
        for i in stride(from:0,to:p.count,by:4) { error=max(error,Double(max(abs(p[i]-p[i+1]),abs(p[i]-p[i+2]),abs(p[i+1]-p[i+2])))) }
        return error
    }
    func silverRamp(width:Int=4096,_ make:(Double)->SIMD3<Float>)->CIImage {
        var p=[Float](repeating:1,count:width*4)
        for i in 0..<width {let c=make(Double(i)/Double(width-1));p[i*4]=c.x;p[i*4+1]=c.y;p[i*4+2]=c.z}
        return CIImage(bitmapData:p.withUnsafeBytes{Data($0)},bytesPerRow:width*16,size:CGSize(width:width,height:1),
                       format:.RGBAf,colorSpace:SyntheticCharts.linearSpace)
    }
    func silverSample(_ color:SIMD3<Float>)->CIImage {
        CIImage(color:CIColor(red:Double(color.x),green:Double(color.y),blue:Double(color.z),colorSpace:SyntheticCharts.linearSpace)!)
            .cropped(to:CGRect(x:0,y:0,width:32,height:32))
    }
    func silverFullFrame(_ image:CIImage,side:Int)->CIImage {
        let e=image.extent,scale=Double(side)/max(e.width,e.height)
        return image.transformed(by:CGAffineTransform(translationX:-e.minX,y:-e.minY))
            .applyingFilter("CILanczosScaleTransform",parameters:[kCIInputScaleKey:scale,kCIInputAspectRatioKey:1])
            .cropped(to:CGRect(x:0,y:0,width:floor(e.width*scale),height:floor(e.height*scale)))
    }
    func runSilverBW() async throws {
        let chart=SilverBWTestChart.generate()
        try artifacts.png(chart.image,"SilverBW/SilverBWTestChart.png")
        try artifacts.json(chart.regions,"SilverBW/chart_regions.json")
        do {
            progress("Silver B&W: equal-luminance colors, continuous filters and film responses")
            try silverSpectral(chart)
            progress("Silver B&W: identity, monotonicity, HDR, neutrality and no grain")
            try silverInvariants(chart)
            try silverStructureAndTone()
            progress("Silver B&W: existing mask/history/stack/pipeline protocols")
            try await silverIntegration(chart)
            try silverPerformance()
            progress("Silver B&W: eight original photographs and preset diversity")
            try silverPhotographs(chart)
        } catch {
            var c=LabCase(name:"SBW_harness");c.check("Completed",false,hard:true,String(describing:error));cases.append(c)
            try silverReport();throw error
        }
        try silverReport()
    }
    private func silverSpectral(_ chart:SilverBWTestChart) throws {
        var equal=LabCase(name:"SBW_equiluminant_colors")
        for (i,rgb) in SilverBWTestChart.equalColors.enumerated() {
            let source=silverSample(rgb),input=silverPixels(source),name=SilverBWTestChart.colorNames[i]
            let actual=LabGPU.luma(input,0)
            equal.metrics[name+"-actualY"]=actual
            equal.check(name+" real luminance",abs(actual-0.05)<1e-7,hard:true,"Scaled by Rec.709 linear Y, not equal RGB peaks")
            for response in SilverFilmResponse.allCases {
                let out=silverPixels(try render(source,[silverFX(["filmResponse":Double(response.rawValue)])]))
                equal.metrics[name+"-"+response.title+"-Y"]=LabGPU.luma(out,0)
            }
        }
        cases.append(equal)
        var filmItems:[(String,CIImage)]=[("Original color",chart.image)]
        for response in SilverFilmResponse.allCases {
            filmItems.append((response.title,try render(chart.image,[silverFX(["filmResponse":Double(response.rawValue)])])))
        }
        try artifacts.sheet(filmItems,"SilverBW/film_response_color_chart.png",cell:384,maxColumns:8)
        for (name,hue) in [("red",0.0),("green",120.0)] {
            var c=LabCase(name:"SBW_"+name+"_filter_progression")
            var series:[(String,[Double])]=[],images:[(String,CIImage)]=[]
            for i in [0,3,5,4] {
                let rgb=SilverBWTestChart.equalColors[i],source=silverSample(rgb),label=SilverBWTestChart.colorNames[i]
                var values:[Double]=[]
                for strength in [0.0,25,50,75,100] {
                    let output=try render(source,[silverFX(["filterHue":hue,"filterStrength":strength])])
                    let value=LabGPU.luma(silverPixels(output),0)
                    values.append(value);c.metrics["\(label)-strength\(Int(strength))-Y"]=value
                    c.metrics["\(label)-strength\(Int(strength))-opticalDensity"] = -log10(max(1e-8,value))
                }
                let increasing=(name=="red" && i==0)||(name=="green" && (i==3 || i==4))
                let deltas=zip(values.dropFirst(),values).map(-)
                c.check("Progressive "+label,increasing ? deltas.allSatisfy{$0>0}:deltas.allSatisfy{$0<0},hard:true,
                        "Density means rendered Y in summaries; optical density −log10(Y) is also recorded")
                series.append((label,values))
            }
            for strength in [0.0,25,50,75,100] {
                images.append(("\(name) \(Int(strength))",try render(chart.image,[silverFX(["filterHue":hue,"filterStrength":strength])])))
            }
            try artifacts.sheet(images,"SilverBW/\(name)_filter_response.png",cell:384,maxColumns:5)
            try artifacts.plot(series,"SilverBW/\(name)_filter_curves.png",title:name+" filter / equal-Y colors",xMaximum:100)
            cases.append(c)
        }
        var mixed:[(String,CIImage)]=[]
        for (label,hue,strength) in [("None",60.0,0.0),("Yellow",60,60),("Orange",30,60),("Red",0,60),("Green",120,60),("Blue",240,60)] {
            mixed.append((label,try render(chart.image,[silverFX(["filterHue":hue,"filterStrength":strength])])))
        }
        try artifacts.sheet(mixed,"SilverBW/yellow_orange_filter_response.png",cell:384,maxColumns:3)
        var c=LabCase(name:"SBW_continuous_filter_hue"),series:[(String,[Double])]=[]
        for (i,rgb) in SilverBWTestChart.equalColors.enumerated() {
            let input=silverSample(rgb)
            var ys:[Double]=[]
            for hue in 0...360 {
                ys.append(LabGPU.luma(silverPixels(try render(input,[silverFX(["filterHue":Double(hue),"filterStrength":100])])),0))
            }
            let step=zip(ys.dropFirst(),ys).map{abs($0-$1)}.max() ?? 0
            c.metrics[SilverBWTestChart.colorNames[i]+"-maxOneDegreeStep"]=step
            c.check("Hue seam \(i)",ys.first==ys.last,hard:true,"0 and 360 are the same filter")
            c.check("Continuous hue \(i)",step<0.02,hard:true,"1-degree steps; no hard hue sectors")
            series.append((SilverBWTestChart.colorNames[i],ys))
        }
        try artifacts.plot(series,"SilverBW/filter_hue_response.png",title:"Continuous filter hue / equal-Y colors",xMaximum:360)
        cases.append(c)
        var skinItems:[(String,CIImage)]=[],skin=LabCase(name:"SBW_skin_filter_matrix")
        for response in [SilverFilmResponse.neutral,.portrait,.panchromatic,.orthochromatic] {
            for (label,hue,strength) in [("None",0.0,0.0),("Yellow",60,50),("Orange",30,50),("Red",0,50),("Green",120,50)] {
                let fx=silverFX(["filmResponse":Double(response.rawValue),"filterHue":hue,"filterStrength":strength])
                let output=try render(chart.image,[fx])
                skinItems.append((response.title+" / "+label,output))
                for name in ["light skin","dark skin","blue sky","foliage green"] {
                    let rect=chart.rect(name),p=gpu.read(output,rect)
                    skin.metrics[response.title+" / "+label+" / "+name]=LabGPU.luma(p,0)
                }
                skin.check(response.title+" / "+label,skin.metrics[response.title+" / "+label+" / light skin"]! > skin.metrics[response.title+" / "+label+" / dark skin"]!,
                           "Synthetic skin separation; real skin/lips/eyes reviewed on photographs")
            }
        }
        for label in ["Yellow","Orange","Red"] {
            let ratio=skin.metrics["Neutral Silver / "+label+" / blue sky"]!/skin.metrics["Neutral Silver / "+label+" / light skin"]!
            let base=skin.metrics["Neutral Silver / None / blue sky"]!/skin.metrics["Neutral Silver / None / light skin"]!
            skin.check(label+" darkens sky relative to skin",ratio<base,hard:true,"Same original colors through photographic filter")
        }
        try artifacts.sheet(skinItems,"SilverBW/skin_filter_matrix.png",cell:256,maxColumns:5)
        cases.append(skin)
    }
    private func silverInvariants(_ chart:SilverBWTestChart) throws {
        let sample=silverFullFrame(chart.image,side:256)
        var identity=LabCase(name:"SBW_amount_identity_and_blend")
        for response in SilverFilmResponse.allCases {
            var fx=silverFX(["filmResponse":Double(response.rawValue),"brightness":100,"contrast":100,"structure":100,
                             "filterStrength":100,"filterHue":240,"dynamicBrightness":-100,"softContrast":100,"blacks":100,"whites":-100,"amount":0])
            let m=gpu.compare(sample,try render(sample,[fx]))
            identity.check(response.title+" Amount 0",m.maxError==0 && m.nonFinite==0,hard:true,"All other controls active; RGB identity")
            fx["amount"]=100
            let full=try render(sample,[fx]);fx["amount"]=50
            let half=try render(sample,[fx]),expected=try FXBlend.mix(sample,full,amount:0.5)
            identity.check(response.title+" Amount 50",gpu.compare(half,expected).maxError<2e-6,hard:true,"Blend occurs after Structure")
        }
        cases.append(identity)
        for response in SilverFilmResponse.allCases {
            var c=LabCase(name:"SBW_neutrality_"+response.title)
            for hue in [0.0,30,60,120,240,360] {for strength in [0.0,50,100] {
                let fx=silverFX(["filmResponse":Double(response.rawValue),"filterHue":hue,"filterStrength":strength,"structure":50])
                let p=silverPixels(try render(sample,[fx])),error=silverNeutralError(p)
                c.metrics["\(hue)-\(strength)-maxChannelDifference"]=error
                c.check("\(hue) / \(strength)",p.allSatisfy(\.isFinite) && error<2e-6,hard:true,"RGBAf with Structure, Amount 100")
            }}
            cases.append(c)
        }
        // All corners of the four signed tone controls, two brightness controls,
        // every film. These are predeclared invariants, not fitted quality bounds.
        let ramp=silverRamp{SIMD3(repeating:Float(-0.1+8.1*$0))}
        var curveImages:[(String,[Double])]=[]
        for response in SilverFilmResponse.allCases {
            var c=LabCase(name:"SBW_tone_HDR_"+response.title)
            for corner in 0..<64 {
                var values=["filmResponse":Double(response.rawValue)]
                for (bit,key) in ["contrast","softContrast","blacks","whites","brightness","dynamicBrightness"].enumerated() {
                    values[key]=(corner & (1<<bit))==0 ? -100:100
                }
                let p=silverPixels(try render(ramp,[silverFX(values)]))
                let ys=(0..<p.count/4).map{LabGPU.luma(p,$0*4)},steps=zip(ys.dropFirst(),ys).map(-)
                c.check("Finite corner \(corner)",p.allSatisfy(\.isFinite),hard:true,"−0.1…8, brightness ×2^±1.5; signed controls at extremes")
                c.check("Monotone corner \(corner)",steps.allSatisfy{$0>=(-1e-6)},hard:true,"Pointwise tonal pipeline, Structure zero")
            }
            let ordinary=silverRamp{SIMD3(repeating:Float($0))}
            let p=silverPixels(try render(ordinary,[silverFX(["filmResponse":Double(response.rawValue)])]))
            let ys=(0..<p.count/4).map{LabGPU.luma(p,$0*4)}
            curveImages.append((response.title,ys))
            let steps=zip(ys.dropFirst(),ys).map(-)
            c.check("Useful positive slope",steps.allSatisfy{$0>0},hard:true,"4096-sample SDR ramp")
            c.check("Continuous slope",zip(steps.dropFirst(),steps).allSatisfy{abs($0-$1)<1e-5},hard:true,"No abrupt slope steps in 4096-point SDR response")
            for level in [0.0,0.01,0.1,0.5,1,2,4,8] {
                let p=silverPixels(try render(SyntheticCharts.gray(level,size:8),[silverFX(["filmResponse":Double(response.rawValue)])]))
                c.metrics["input\(level)-outputY"]=LabGPU.luma(p,0)
            }
            cases.append(c)
        }
        try artifacts.plot(curveImages,"SilverBW/characteristic_curves.png",title:"Silver film response / neutral gray")
        var extended=LabCase(name:"SBW_extended_color_HDR")
        let extendedSource=silverRamp { t in SIMD3(Float(-0.25+8.25*t),Float(-0.1+4.1*t),Float(-0.15+16.15*t)) }
        for response in SilverFilmResponse.allCases {for hue in [0.0,60,120,240] {
            let p=silverPixels(try render(extendedSource,[silverFX(["filmResponse":Double(response.rawValue),"filterHue":hue,"filterStrength":100])]))
            extended.check(response.title+" / \(hue)",p.allSatisfy(\.isFinite) && silverNeutralError(p)<2e-6,hard:true,"Mixed negative/extended channels through full spectral/filter path")
        }}
        cases.append(extended)
        var uniform=LabCase(name:"SBW_uniform_no_grain_and_alpha")
        for structure in [0.0,25,100] { for level in [0.01,0.18,0.82,2.0] {
            let source=SyntheticCharts.gray(level,size:128),fx=silverFX(["structure":structure])
            let a=try render(source,[fx]),b=try render(source,[fx]),m=gpu.compare(a,b)
            var moment=Moments()
            let p=gpu.read(a,CGRect(x:16,y:16,width:96,height:96))
            for i in stride(from:0,to:p.count,by:4){moment.add(LabGPU.luma(p,i))}
            uniform.metrics["\(structure)-\(level)-variance"]=moment.variance
            uniform.check("Uniform \(structure) / \(level)",moment.variance<1e-10 && m.maxError==0,hard:true,"No grain generator; deterministic input remains uniform")
        }}
        for alpha in [0.0,0.25,0.75,1] {
            let source=CIImage(color:CIColor(red:0.5,green:0.25,blue:0.1,alpha:alpha,colorSpace:SyntheticCharts.linearSpace)!)
                .cropped(to:CGRect(x:0,y:0,width:16,height:16))
            let p=silverPixels(try render(source,[silverFX(["structure":50])]))
            uniform.check("Alpha \(alpha)",p.allSatisfy(\.isFinite) && abs(Double(p[3])-alpha)<1e-6 && silverNeutralError(p)<2e-6,hard:true,"Premultiplied RGBA contract")
        }
        cases.append(uniform)
    }
    private func silverStructureAndTone() throws {
        progress("Silver B&W: existing Tonal Contrast texture/edge fixtures")
        let chart=TonalContrastTestChart.generate(size:1024)
        let baseline=try render(chart.image,[silverFX()])
        var sheets:[(String,CIImage)]=[]
        for amount in [0.0,25,50,75,100] {
            let output=try render(chart.image,[silverFX(["structure":amount])])
            sheets.append(("Structure \(Int(amount))",output))
            var c=LabCase(name:"SBW_structure_\(Int(amount))")
            for region in ["skin-like","fine-texture","medium-texture","coarse-texture","dark-texture","bright-texture"] {
                let m=gpu.compare(baseline,output,region:chart.region(region))
                c.metrics[region+"-RMSRatio"]=m.output.standardDeviation/max(1e-8,m.input.standardDeviation)
                c.check(region+" finite",m.nonFinite==0,hard:true,"Existing calibrated spatial fixture")
                if region=="skin-like" && amount<=25 {
                    c.check("Moderate skin",c.metrics[region+"-RMSRatio"]!<1.20,"At most 20% synthetic skin RMS increase; photo inspection remains necessary")
                }
            }
            let rect=chart.region("hard-edge"),a=gpu.read(baseline,rect),b=gpu.read(output,rect)
            let va=stride(from:0,to:a.count,by:4).map{LabGPU.luma(a,$0)},vb=stride(from:0,to:b.count,by:4).map{LabGPU.luma(b,$0)}
            let overshoot=max(0,(vb.max() ?? 0)-(va.max() ?? 0)),undershoot=max(0,(va.min() ?? 0)-(vb.min() ?? 0))
            c.metrics["edgeOvershoot"]=overshoot;c.metrics["edgeUndershoot"]=undershoot
            c.check("Edge halo",max(overshoot,undershoot)<0.03,"Existing Tonal Contrast linear halo heuristic")
            cases.append(c)
        }
        try artifacts.sheet(sheets,"SilverBW/structure_synthetic_comparison.png",cell:512,maxColumns:5)
        let source=SilverBWTestChart.generate(size:1024).image
        let ordinary=try render(source,[silverFX()])
        let contrast=try render(source,[silverFX(["contrast":45])])
        // Reverse soft-contrast sign to compare increases of broadly similar
        // amplitude. Positive soft contrast additionally demonstrates compression.
        let soft=try render(source,[silverFX(["softContrast":-70])])
        let softPositive=try render(source,[silverFX(["softContrast":70])])
        let a=gpu.compare(ordinary,contrast),b=gpu.compare(ordinary,soft),difference=gpu.compare(contrast,soft)
        var c=LabCase(name:"SBW_contrast_vs_soft_contrast")
        c.metrics=["contrastMAE":a.mae,"softContrastMAE":b.mae,"betweenMAE":difference.mae,"amplitudeRatio":b.mae/max(1e-8,a.mae)]
        c.check("Distinct controls",difference.mae>1e-4,hard:true,"Different analytic scales; no blur/glow")
        c.check("Comparable amplitude",b.mae/max(1e-8,a.mae)>0.35 && b.mae/max(1e-8,a.mae)<2.5,"Fixed settings, no fit after rendering")
        try artifacts.sheet([("Neutral",ordinary),("Contrast +45",contrast),("Soft Contrast -70",soft),("Soft Contrast +70",softPositive)],
                            "SilverBW/contrast_vs_soft_contrast.png",cell:512,maxColumns:4)
        cases.append(c)
        var toneSeries:[(String,[Double])]=[]
        let ramp=silverRamp{SIMD3(repeating:Float($0*2))}
        for key in ["blacks","whites","brightness","dynamicBrightness","contrast","softContrast"] {
            var lines:[(String,[Double])]=[]
            for v in [-100.0,0,100] {
                let p=silverPixels(try render(ramp,[silverFX([key:v])]))
                let ys=(0..<p.count/4).map{LabGPU.luma(p,$0*4)}
                lines.append(("\(key) \(Int(v))",ys))
            }
            try artifacts.plot(lines,"SilverBW/\(key)_response.png",title:key+" / extended gray ramp",xMaximum:2)
            if key=="blacks" || key=="whites" {toneSeries += lines.filter{!$0.0.contains(" 0")}}
        }
        try artifacts.plot(toneSeries,"SilverBW/blacks_whites_response.png",title:"Black density / white presence",xMaximum:2)
    }
}

@Test func silverBWKernelSmoke() throws {
    let gpu=try LabGPU(),input=SilverBWTestChart.generate(size:256).image
    let fx=CreativeEffect(.silverBW)
    let output=try CreativeStackRenderer.apply(input,stack:.init(effects:[fx]),masks:[])
    let m=gpu.compare(input,output)
    #expect(m.nonFinite==0)
    #expect(m.mae>1e-6)
}
