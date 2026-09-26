import Foundation
import CoreImage
import Testing
@testable import LumoraCore

struct SilverToningTestChart {
    static let levels:[Double]=[0,0.01,0.05,0.18,0.5,0.9,1,2,4,8]
    static func generate(size:Int=1024)->CIImage {
        SyntheticCharts.make(size:size){x,y in
            if y<0.25 { return SIMD3(repeating:Float(x*4)) }
            if y<0.5 { return SIMD3(repeating:Float(x)) }
            return SIMD3(repeating:Float(levels[min(9,Int(x*10))]))
        }
    }
}
@Test func silverToningValidation() async throws {
    let repo=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let lab=try LumoraVisualTestLab(root:repo.appendingPathComponent("Validation/TestArtifacts"),full:true)
    do {
        try lab.toningNumerical()
        try lab.toningExtendedControls()
        try await lab.toningIntegration()
        try lab.toningPerformance()
        try lab.toningPhotographs()
    } catch {
        var c=LabCase(name:"ST_harness");c.check("Completed",false,hard:true,String(describing:error));lab.cases.append(c)
        try lab.toningReport();throw error
    }
    try lab.toningReport()
    for c in lab.cases {for check in c.checks where check.hard {#expect(check.status != "FAIL","\(c.name): \(check.name)")}}
}

extension LumoraVisualTestLab {
    func toningFX(_ values:[String:Double]=[:])->CreativeEffect { effect(.silverToning,values) }
    func toningPreset(_ title:String)->CreativeEffect { CreativeFXPreset.all(for:.silverToning).first{$0.title==title}!.makeEffect() }
    func toningOutput(_ image:CIImage,_ fx:CreativeEffect) throws -> CIImage { try render(image,[fx]) }
    func toningRatios(_ p:[Float])->[[Double]] {
        (0..<3).map{channel in stride(from:0,to:p.count,by:4).map{i in Double(p[i+channel])/max(1e-6,LabGPU.luma(p,i))-1}}
    }
    func toningOverlay(_ input:CIImage,ratios:[Double])->CIImage {
        input.applyingFilter("CIColorMatrix",parameters:["inputRVector":CIVector(x:1+ratios[0],y:0,z:0,w:0),
            "inputGVector":CIVector(x:0,y:1+ratios[1],z:0,w:0),"inputBVector":CIVector(x:0,y:0,z:1+ratios[2],w:0)])
    }
    func toningBestOverlay(_ input:CIImage,_ output:CIImage)->[Double] {
        let a=silverPixels(input),b=silverPixels(output)
        return (0..<3).map{channel in
            var numerator=0.0,denominator=0.0
            for i in stride(from:0,to:a.count,by:4) {let x=Double(a[i+channel]);numerator+=x*Double(b[i+channel]-a[i+channel]);denominator+=x*x}
            return numerator/max(1e-12,denominator)
        }
    }
    func toningVisualRamp(_ image:CIImage)->CIImage {image.transformed(by:CGAffineTransform(scaleX:1,y:256))}
    func toningNumerical() throws {
        progress("Silver Toning: identities, 4096-point density responses, continuity, HDR and overlay fit")
        let chart=SilverToningTestChart.generate(),ramp=silverRamp{SIMD3(repeating:Float($0))}
        try artifacts.png(chart,"SilverToning/SilverToningTestChart.png")
        let colorChart=SilverBWTestChart.generate(size:256).image
        var all:[(String,CIImage)]=[],overlayItems:[(String,CIImage)]=[],residualSeries:[(String,[Double])]=[]
        var overlayReport="# Silver Toning vs best constant overlay\n\nLeast-squares per-channel gain minimizes linear RGB squared error on the 4096-point neutral ramp. Residual MAE is evaluated independently; Neutral is the expected identity. No automatic retuning.\n\n| Toner | RGB gain minus 1 | Residual MAE |\n|---|---|---:|\n"
        for toner in SilverToner.allCases {
            var c=LabCase(name:"ST_"+toner.title)
            let fx=toningFX(["toner":Double(toner.rawValue),"strength":100]),output=try toningOutput(ramp,fx)
            let a=silverPixels(ramp),b=silverPixels(output),ratios=toningRatios(b)
            var deltaY:[Double]=[],hues:[Double]=[],chromas:[Double]=[]
            for i in stride(from:0,to:a.count,by:4) {
                deltaY.append(abs(LabGPU.luma(a,i)-LabGPU.luma(b,i)))
                let r=Double(b[i]),g=Double(b[i+1]),bl=Double(b[i+2]),u=2*r-g-bl,v=sqrt(3)*(g-bl)
                hues.append(atan2(v,u));chromas.append(hypot(u,v)/max(1e-6,LabGPU.luma(b,i)))
            }
            try artifacts.json(["inputY":(0..<4096).map{Double($0)/4095},"hueRadians":hues,"relativeChroma":chromas,
                                "RoverYminus1":ratios[0],"GoverYminus1":ratios[1],"BoverYminus1":ratios[2],"absDeltaY":deltaY],
                               "SilverToning/samples_"+String(toner.rawValue)+".json")
            let sorted=deltaY.sorted()
            c.metrics["meanAbsDeltaY"]=deltaY.reduce(0,+)/Double(deltaY.count)
            c.metrics["P95AbsDeltaY"]=sorted[Int(Double(sorted.count-1)*0.95)]
            c.metrics["maxAbsDeltaY"]=sorted.last!
            c.check("Luminance preservation",sorted.last!<2e-5,hard:true,"Analytic constant-Y projection; 2e-5 linear absolute allows GPU arithmetic, far below photographic exposure differences")
            c.check("Finite",b.allSatisfy(\.isFinite),hard:true,"RGBAf output")
            var step=0.0,hueStep=0.0
            for k in 1..<4096 {
                if k>4 {for channel in 0..<3 {step=max(step,abs(ratios[channel][k]-ratios[channel][k-1]))}}
                if chromas[k]>0.001 && chromas[k-1]>0.001 {
                    let d=hues[k]-hues[k-1];hueStep=max(hueStep,abs(atan2(sin(d),cos(d))))
                }
            }
            c.metrics["maxAdjacentRatioStep"]=step;c.metrics["maxHueStepRadians"]=hueStep
            c.check("Continuous ratios",step<0.02,hard:true,"4096 linear samples, skip first 4 near-zero divisions; <2% channel-ratio jump")
            c.check("Continuous hue",hueStep<0.08,hard:true,"Wrapped angle, chroma > .001, 0.08 radians at sample spacing 1/4095")
            for (name,y) in [("shadow",0.05),("lowerMidtone",0.18),("upperMidtone",0.5),("highlight",0.9)] {
                c.metrics[name+"Chroma"]=chromas[Int(y*4095)]
            }
            let variation=ratios.map{($0.dropFirst(4).max() ?? 0)-($0.dropFirst(4).min() ?? 0)}.max()!
            c.metrics["ratioRange"]=variation
            if toner != .neutral {c.check("Density dependent",variation>0.001,"toner behaves like constant overlay if chromaticity range <= .001")}
            let fit=toningBestOverlay(ramp,output),baseline=toningOverlay(ramp,ratios:fit),m=gpu.compare(baseline,output)
            c.metrics["bestOverlayResidualMAE"]=m.mae
            if toner != .neutral {c.check("Nonconstant overlay residual",m.mae>0.0001,"Linear RGB mean absolute residual > .0001; subtle toners deliberately allowed")}
            overlayReport += "| \(toner.title) | \(fit) | \(m.mae) |\n"
            residualSeries.append((toner.title,(0..<4096).map{i in (0..<3).map{abs(Double(b[i*4+$0])-Double(a[i*4+$0])*(1+fit[$0]))}.reduce(0,+)/3}))
            let path="SilverToning/density_response_"+toner.title.lowercased().replacingOccurrences(of:" ",with:"_")+".png"
            try artifacts.plot(zip(["R/Y − 1","G/Y − 1","B/Y − 1"],ratios).map{($0,$1)},path,title:toner.title+" / linear input Y → channel ratios")
            all.append((toner.title,toningVisualRamp(output)))
            if [.selenium,.sepia,.split].contains(toner) {
                overlayItems += [(toner.title+" Neutral",toningVisualRamp(ramp)),("Best constant overlay",toningVisualRamp(baseline)),("Density toning",toningVisualRamp(output)),("Difference ×8",toningVisualRamp(artifacts.difference(baseline,output,gain:8)))]
            }
            for strength in [0.0,25,50,75,100] {
                let f=toningFX(["toner":Double(toner.rawValue),"strength":strength,"paperTone":100])
                let o=try toningOutput(ramp,f),mm=gpu.compare(ramp,o)
                c.metrics["strength\(Int(strength))-meanDeltaY"]=mm.residual.mean
                c.check("Strength \(strength) Y",abs(mm.residual.mean)<2e-5,hard:true,"Paper and silver share the same Strength")
            }
            for (label,parameters) in [("Amount zero",["amount":0.0,"strength":100,"paperTone":100]),("Strength zero",["strength":0.0,"paperTone":100])] {
                var values=parameters;values["toner"]=Double(toner.rawValue)
                let identity=try toningOutput(colorChart,toningFX(values)),mm=gpu.compare(colorChart,identity)
                c.metrics[label+"-maxRGBError"]=mm.maxError;c.metrics[label+"-meanRGBError"]=mm.mae
                c.metrics[label+"-maxYError"]=max(abs(mm.residual.min),abs(mm.residual.max));c.metrics[label+"-nonFinitePixels"]=Double(mm.nonFinite)
                c.check(label,mm.maxError==0 && mm.nonFinite==0,hard:true,"Strict early return, including Paper Tone nonzero")
            }
            var lastY = -Double.infinity
            for y in [-0.05,-0.01,-0.001,0,0.01,0.05,0.18,0.5,1,1.5,2,3,4,6,8] {
                let input=silverSample(SIMD3(repeating:Float(y))),out=silverPixels(try toningOutput(input,fx)),actual=LabGPU.luma(out,0)
                c.metrics["HDR-Y\(y)"]=actual
                c.check("Extended \(y)",out.allSatisfy(\.isFinite) && abs(actual-y)<2e-5 && actual>lastY,hard:true,"Signed luminance, no clamp, monotone Y; negative Y is unchanged")
                lastY=actual
            }
            let repeatOutput=try toningOutput(ramp,fx)
            c.check("Deterministic",gpu.compare(output,repeatOutput).maxError==0,hard:true,"No random component")
            if toner == .neutral {c.check("Neutral identity",gpu.compare(ramp,output).maxError==0,hard:true,"Neutral bypasses all coloration")}
            let colorOutput=try toningOutput(colorChart,fx)
            c.check("Color input retained",silverNeutralError(silverPixels(colorOutput))>0.2,hard:true,"Original chroma is not discarded")
            cases.append(c)
        }
        try artifacts.sheet(all,"SilverToning/all_density_responses.png",cell:512,maxColumns:3)
        try artifacts.sheet(overlayItems,"SilverToning/toning_vs_constant_overlay.png",cell:512,maxColumns:4)
        try artifacts.plot(residualSeries,"SilverToning/overlay_residuals.png",title:"Best constant overlay / residual RGB MAE")
        try overlayReport.write(to:artifacts.url("SilverToning_vs_constant_overlay.md"),atomically:true,encoding:.utf8)
        try toningControlTests(chart:chart,ramp:ramp)
    }
    func toningControlTests(chart:CIImage,ramp:CIImage) throws {
        var c=LabCase(name:"ST_control_isolation")
        for (name,toner) in [("selenium",1.0),("sepia",2.0)] {
            var images:[(String,CIImage)]=[],previous=0.0
            for strength in [0.0,25,50,75,100] {
                let o=try toningOutput(chart,toningFX(["toner":toner,"strength":strength])),m=gpu.compare(chart,o)
                c.check("\(name) strength \(strength)",m.mae>=previous,hard:true,"Progressive chroma magnitude")
                previous=m.mae;images.append(("Strength \(strength)",o))
            }
            try artifacts.sheet(images,"SilverToning/\(name)_strength.png",cell:512,maxColumns:5)
        }
        var papers:[(String,CIImage)]=[],splits:[(String,CIImage)]=[],balances:[(String,CIImage)]=[]
        for strength in [0.0,25,50,100] {
            papers.append(("Paper \(strength)",try toningOutput(chart,toningFX(["toner":2,"strength":100,"silverTone":0,"paperTone":strength]))))
        }
        try artifacts.sheet(papers,"SilverToning/paper_tone_response.png",cell:512,maxColumns:4)
        for y in SilverToningTestChart.levels {
            let source=silverSample(SIMD3(repeating:Float(y))),out=try toningOutput(source,toningFX(["toner":2,"strength":100,"silverTone":0,"paperTone":100]))
            c.metrics["paper-\(y)-maxError"]=gpu.compare(source,out).maxError
        }
        c.check("Paper black isolation",c.metrics["paper-0.0-maxError"]! == 0 && c.metrics["paper-0.01-maxError"]!<c.metrics["paper-1.0-maxError"]!*0.001,hard:true,"Paper must not color deep black")
        let silver=try toningOutput(chart,toningFX(["toner":2,"strength":100,"paperTone":0]))
        try artifacts.sheet([("Neutral",chart),("Silver only",silver),("Paper only",papers.last!.1)],"SilverToning/silver_vs_paper_contribution.png",cell:512,maxColumns:3)
        var transitions:[Double]=[]
        for balance in stride(from:-100.0,through:100,by:25) {
            let fx=toningFX(["toner":8,"strength":100,"balance":balance,"shadowHue":220,"highlightHue":40])
            let out=try toningOutput(silverRamp{SIMD3(repeating:Float($0*4))},fx),p=silverPixels(out)
            // R-B crosses zero between cool shadows and warm highlights.
            let cross=(1..<4096).first{p[$0*4]>=p[$0*4+2]} ?? 4095
            transitions.append(Double(cross)*4/4095)
            c.metrics["balance\(balance)-transitionY"]=Double(cross)*4/4095
            splits.append(("Balance \(balance)",toningVisualRamp(out)))
            if Int(balance)%50==0 {balances.append(("Balance \(balance)",try toningOutput(chart,fx)))}
        }
        c.check("Balance shifts toward light",zip(transitions.dropFirst(),transitions).allSatisfy{$0>$1},hard:true,"Measured cool/warm transition increases with Balance; overlapping functions")
        try artifacts.sheet(splits,"SilverToning/split_toning_response.png",cell:512,maxColumns:3)
        try artifacts.sheet(balances,"SilverToning/balance_response.png",cell:512,maxColumns:5)
        for (path,titles) in [("sepia_vs_copper",["Classic Sepia","Copper Print"]),("gold_vs_cool_silver",["Cool Gold","Cool Silver"]),("platinum_ab",["Neutral Print","Platinum Print"])] {
            try artifacts.sheet(try titles.map{($0,try toningOutput(chart,toningPreset($0)))},"SilverToning/\(path).png",cell:512,maxColumns:2)
        }
        var banding:[(String,CIImage)]=[],hdr:[(String,CIImage)]=[]
        for name in ["Deep Selenium","Classic Sepia","Copper Print","Cool Gold","Split Warm/Cool"] {
            for (label,input) in [("0–1",ramp),("0–4",silverRamp{SIMD3(repeating:Float($0*4))}),("log near black",silverRamp{SIMD3(repeating:Float(pow(10,-5+4*$0)))})] {
                banding.append((name+" "+label,toningVisualRamp(try toningOutput(input,toningPreset(name)))))
            }
        }
        try artifacts.sheet(banding,"SilverToning/banding_stress_test.png",cell:1024,maxColumns:3)
        for toner in SilverToner.allCases {
            hdr.append((toner.title,toningVisualRamp(try toningOutput(silverRamp{SIMD3(repeating:Float($0*8))},toningFX(["toner":Double(toner.rawValue),"strength":100,"paperTone":35])))))
        }
        try artifacts.sheet(hdr,"SilverToning/hdr_toning_response.png",cell:512,maxColumns:3)
        let spatial=SyntheticCharts.make(size:256){x,y in SIMD3(repeating:Float(0.4+0.1*sin(x*32*Double.pi)+0.06*cos(y*24*Double.pi)))}
        let toned=try toningOutput(spatial,toningPreset("Copper Print")),m=gpu.compare(spatial,toned)
        let spectrum=gpu.structure(spatial,toned,region:spatial.extent)
        c.metrics["spatialLuminanceResidualRMS"]=m.residualStd;c.metrics["spatialResidualHighFrequency"]=spectrum.highFrequencyEnergy
        c.check("No spatial luminance change",m.residualStd<2e-6,hard:true,"Existing FFT/structure protocol; nonlinear chroma may contain input-derived harmonics, no neighboring samples")
        let flat=silverSample(SIMD3(repeating:0.18)),flatOut=try toningOutput(flat,toningPreset("Copper Print"))
        c.check("No noise",gpu.compare(flatOut,flatOut).output.standardDeviation<1e-7,hard:true,"Uniform patch remains spatially uniform")
        cases.append(c)
    }
}

extension LumoraVisualTestLab {
    func toningExtendedControls() throws {
        var c=LabCase(name:"ST_extended_controls_alpha")
        let signed=silverRamp{t in .init(Float(-0.05+8.05*t),Float(-0.01+4.01*t),Float(-0.001+2.001*t))}
        let low=silverRamp{SIMD3(repeating:Float(-0.001+$0*0.002))}
        for toner in SilverToner.allCases {
            for balance in [-100.0,0,100] {for paper in [-100.0,0,100] {
                let fx=toningFX(["toner":Double(toner.rawValue),"strength":100,"balance":balance,"paperTone":paper])
                let output=try toningOutput(signed,fx),m=gpu.compare(signed,output)
                c.check("Signed/HDR \(toner.rawValue)/\(balance)/\(paper)",m.nonFinite==0 && max(abs(m.residual.min),abs(m.residual.max))<2e-5,hard:true,"Mixed extended RGB and extreme controls retain Y")
                let p=silverPixels(try toningOutput(low,fx))
                let step=(1..<4096).map{i in (0..<3).map{abs(Double(p[4*i+$0]-p[4*(i-1)+$0]))}.max()!}.max()!
                c.check("Black continuity \(toner.rawValue)/\(balance)/\(paper)",step<1e-6,hard:true,"Dense signed ramp across Y=0, C1 amplitude")
            }}
        }
        let source=SilverBWTestChart.generate(size:128).image
        let full=try toningOutput(source,toningPreset("Classic Sepia"))
        for amount in [0.0,25,50,75,100] {
            var fx=toningPreset("Classic Sepia");fx["amount"]=amount
            let expected=try FXBlend.mix(source,full,amount:amount/100),actual=try toningOutput(source,fx)
            c.check("Final blend \(amount)",gpu.compare(expected,actual).maxError<2e-6,hard:true,"Amount only mixes the complete pointwise effect")
        }
        for alpha:Float in [0,0.2,0.5,1] {
            let p:[Float]=[0.3*alpha,0.3*alpha,0.3*alpha,alpha]
            let input=CIImage(bitmapData:p.withUnsafeBytes{Data($0)},bytesPerRow:16,size:CGSize(width:1,height:1),format:.RGBAf,colorSpace:gpu.linear)
            let out=silverPixels(try toningOutput(input,toningPreset("Classic Sepia")))
            c.check("Alpha \(alpha)",out.allSatisfy(\.isFinite) && abs(out[3]-alpha)<1e-7,hard:true,"Premultiplication preserved, including transparent black")
        }
        let hdr=silverRamp{SIMD3(repeating:Float(1+$0*7))}
        for toner in SilverToner.allCases {
            let out=try toningOutput(hdr,toningFX(["toner":Double(toner.rawValue),"strength":100,"paperTone":70]))
            let ratios=toningRatios(silverPixels(out))
            let step=ratios.map{r in zip(r.dropFirst(),r).map{abs($0-$1)}.max()!}.max()!
            c.metrics[toner.title+"-HDR-maxRatioStep"]=step
            c.check(toner.title+" HDR continuity",step<0.002,hard:true,"4096 samples between 1 and 8")
        }
        // Equal intensities with recognizable split test hues: measure chromatic orientation.
        for (name,y) in [("shadow",0.01),("midtone",0.18),("highlight",2.0)] {
            let out=silverPixels(try toningOutput(silverSample(SIMD3(repeating:Float(y))),toningFX(["toner":8,"strength":100,"shadowHue":220,"highlightHue":40])))
            let r=Double(out[0]),g=Double(out[1]),b=Double(out[2])
            c.metrics[name+"-hueDegrees"]=atan2(sqrt(3)*(g-b),2*r-g-b)*180/Double.pi
            if name != "midtone" {c.check(name+" split orientation",name=="shadow" ? b>r:r>b,hard:true,"Cool shadow and warm highlight contributions isolated by density")}
        }
        cases.append(c)
    }
}
