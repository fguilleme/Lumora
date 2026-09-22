import Foundation
import CoreImage
import Testing
import Darwin
@testable import LumoraCore

struct AutoCorrectionTestChart {
    static func generate(_ kind: String = "normal", size: Int = 512) -> CIImage {
        SyntheticCharts.make(size:size) { x,y in
            let levels:[Double]=[0,0.001,0.01,0.05,0.18,0.5,0.9,1,2,4,8]
            var value=y<0.5 ? x : levels[min(10,Int(x*11))]
            switch kind {
            case "underexposed": value *= 0.12
            case "overexposed": value *= 2
            case "flat": value=0.18+min(1,value)*0.12
            case "high_contrast": value=pow(min(1,value),3)
            case "low_key": value=x<0.95 ? pow(x,4)*0.04 : 0.8
            case "high_key": value=0.55+min(1,value)*0.4
            case "already_good": value=pow(x,2.2)*0.85
            case "hard_clipped": value=min(1,value*3)
            default: break
            }
            return SIMD3(repeating:Float(value))
        }
    }
}
struct AutoPhotoRecord: Codable {
    let name: String
    let analysis: ImageAnalysis
    let intent: AutoCorrectionIntent
    let points: [CurvePoint]
    let sdr: AutoFitError
    let hdr: AutoFitError
    let photoMAE: Double
    let photoMax: Double
    let metrics: [String:Double]
}

@Test func autoCorrectionValidation() async throws {
    let repo=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let lab=try LumoraVisualTestLab(root:repo.appendingPathComponent("TestArtifacts"),full:true)
    let run=AutoValidation(lab:lab,repo:repo)
    do {
        try await run.synthetic()
        try await run.photographs()
        try await run.integration()
    } catch {
        var c=LabCase(name:"Auto harness");c.check("Completed",false,hard:true,String(describing:error));lab.cases.append(c)
        try run.report();throw error
    }
    try run.report()
    for c in lab.cases { for check in c.checks where check.hard { #expect(check.status != "FAIL","\(c.name): \(check.name)") } }
}

final class AutoValidation {
    let lab: LumoraVisualTestLab
    let repo: URL
    let engine=RenderEngine()
    var records:[AutoPhotoRecord]=[]
    var timings:[String:[Double]]=[:]
    var syntheticIntent=""
    var resolutionRows=""
    var roundtripRows=""
    var files:[URL]=[]
    init(lab:LumoraVisualTestLab,repo:URL) { self.lab=lab;self.repo=repo }
    func pixels(_ image:CIImage,maximum:Int=512)->[Float] { AutoAnalysisInput.pixels(image,context:lab.gpu.context,maximum:maximum) }
    func analysis(_ image:CIImage,maximum:Int=512)->ImageAnalysis { ImageAnalysis.measure(pixels(image,maximum:maximum)) }
    func reduced(_ image:CIImage,side:Int=512)->CIImage {
        let e=image.extent,s=min(1,Double(side)/max(e.width,e.height))
        return image.transformed(by:CGAffineTransform(translationX:-e.minX,y:-e.minY)).transformed(by:CGAffineTransform(scaleX:s,y:s))
    }
    func output(_ image:CIImage,_ settings:EditState) async throws -> CIImage {
        try await engine.autoDiagnosticDevelopment(image,state:settings)
    }
    func variants(_ image:CIImage,_ proposal:AutoProposal) async throws -> [(String,CIImage)] {
        var result:[(String,CIImage)]=[("Original",image)]
        for (name,module,style) in [("Auto Light",AutoModule.light,AutoCurveStyle.balanced),("Auto Color",.color,.balanced),
                                     ("Light + Color",.global,.balanced),("Curve Natural",.curves,.natural),
                                     ("Curve Balanced",.curves,.balanced),("Curve Punchy",.curves,.punchy)] {
            result.append((name,try await output(image,proposal.applying(module,style:style,to:EditState()))))
        }
        return result
    }
    func elapsed(_ start:ContinuousClock.Instant)->Double {
        let t=start.duration(to:.now);return Double(t.components.seconds)*1000+Double(t.components.attoseconds)/1e15
    }
    func save(_ text:String,_ path:String) throws { try text.write(to:lab.artifacts.url(path),atomically:true,encoding:.utf8) }
    func grayWorld(_ image:CIImage)->CIImage {
        let a=analysis(image),m=a.rgb.map(\.mean),average=m.reduce(0,+)/3
        return image.applyingFilter("CIColorMatrix",parameters:["inputRVector":CIVector(x:average/max(1e-8,m[0]),y:0,z:0,w:0),
            "inputGVector":CIVector(x:0,y:average/max(1e-8,m[1]),z:0,w:0),"inputBVector":CIVector(x:0,y:0,z:average/max(1e-8,m[2]),w:0)])
    }
    func synthetic() async throws {
        lab.progress("Auto: initial frozen heuristics; synthetic tonal/color charts and transfer fitting")
        var chartVariants:[(String,CIImage)]=[],transfer:[(String,[Double])]=[],hdrTransfer:[(String,[Double])]=[]
        for name in ["normal","underexposed","overexposed","flat","high_contrast","low_key","high_key","already_good","hard_clipped"] {
            let image=AutoCorrectionTestChart.generate(name),a=analysis(image),proposal=AutoProposal(a)
            let items=try await variants(image,proposal),root="Auto/Synthetic/"+name
            try lab.artifacts.sheet(items,root+".png",cell:256,maxColumns:7)
            try lab.artifacts.json(a,root+"_analysis.json");try lab.artifacts.json(proposal.intent,root+"_intent.json")
            syntheticIntent += "### \(name)\n\n\(proposal.intent)\n\n"
            chartVariants.append((name,image))
            var c=LabCase(name:"Auto synthetic "+name)
            for (title,out) in items { c.check(title+" finite",pixels(out).allSatisfy(\.isFinite),hard:true,"Production development graph, RGBAf") }
            if name=="low_key" {c.check("Dark intent retained",analysis(items[1].1).luminance.mean<0.12,"mean Y below .12 for intentional night chart")}
            if name=="high_key" {c.check("Light intent retained",analysis(items[1].1).luminance.median>0.45,"high-key median remains above .45")}
            if name=="underexposed" {c.check("Exposure direction",proposal.intent.exposureShiftEV>0,"Known .12 gain; should propose positive EV")}
            if name=="overexposed" {c.check("Recoverable highlight direction",proposal.intent.exposureShiftEV<0 || proposal.intent.highlightCompression<0,"Known x2 exposure includes recoverable HDR")}
            if name=="hard_clipped" { c.check("Unrecoverable clipping identified",a.whiteFraction>0.1,hard:true,"Observed boundary occupancy; cannot prove sensor recovery or invent detail") }
            if ["low_key","high_key"].contains(name) {try lab.artifacts.sheet(items,"Auto/"+name+"_comparison.png",cell:384,maxColumns:7)}
            if name=="flat" {try lab.artifacts.sheet([items[0],items[1],items[4],items[5],items[6]],"Auto/auto_curve_comparison.png",cell:384,maxColumns:5)}
            let balanced=proposal.curves[.balanced]!
            c.metrics["fitSDR-MAE"]=balanced.sdr.mae;c.metrics["fitSDR-max"]=balanced.sdr.maximum
            c.metrics["fitHDR-max"]=balanced.hdr.maximum
            c.check("Equivalent curve SDR",balanced.sdr.maximum<0.05,"Linear neutral-axis max > .05 warrants inspection; <=10 editable points")
            c.check("Equivalent curve HDR",balanced.hdr.maximum<0.05,"Existing SDR curve domain can lose extended highlights; no renderer change")
            let levels=(0...1024).map{Double($0)/1024}
            let levelsHDR=levels.map{$0*8}
            if ["low_key","high_key","underexposed"].contains(name) {
                transfer.append((name+" Light",levels.map{AutoTonalMapping.light($0,proposal.intent.light)}))
                hdrTransfer.append((name+" Light",levelsHDR.map{AutoTonalMapping.light($0,proposal.intent.light)}))
                for style in AutoCurveStyle.allCases {
                    transfer.append((name+" "+style.rawValue,levels.map{AutoTonalMapping.curve($0,proposal.curves[style]!.curve)}))
                    hdrTransfer.append((name+" "+style.rawValue,levelsHDR.map{AutoTonalMapping.curve($0,proposal.curves[style]!.curve)}))
                }
            }
            for module in [AutoModule.light,.color,.curves] {
                let s=proposal.applying(module,to:EditState())
                c.check(module.rawValue+" idempotence",proposal.applying(module,to:s)==s,hard:true,"Bit-exact settings")
                let restored=try JSONDecoder().decode(EditState.self,from:JSONEncoder().encode(s))
                c.check(module.rawValue+" persistence",restored==s,hard:true,"No saved analysis required")
            }
            let light=proposal.applying(.light,to:EditState()),converted=proposal.applying(.curves,to:light)
            c.check("No double correction",converted==proposal.applying(.curves,to:EditState()),hard:true,"Explicit replacement of Light + master RGB curve")
            lab.cases.append(c)
        }
        transfer.insert(("identity",(0...1024).map{Double($0)/1024}),at:0)
        hdrTransfer.insert(("identity",(0...1024).map{Double($0)*8/1024}),at:0)
        try lab.artifacts.plot(transfer,"Auto/transfer_curves.png",title:"SDR canonical Light and editable curve representations",yRange:0...1)
        try lab.artifacts.plot(hdrTransfer,"Auto/transfer_curves_HDR.png",title:"HDR limitation of existing SDR curves",yRange:0...8,xMaximum:8)
        try lab.artifacts.sheet(chartVariants,"Auto/AutoCorrectionTestChart.png",cell:256,maxColumns:3)
        try await colorCharts()
        try await curveRoundTrips()
    }
    func colorCharts() async throws {
        var all:[(String,CIImage)]=[]
        let configurations:[(String,SIMD3<Float>)]=[("true_warm_cast",.init(1.12,1,0.9)),("true_cool_cast",.init(0.9,1,1.12)),
            ("true_green_cast",.init(1,1.12,1)),("true_magenta_cast",.init(1.08,0.94,1.08)),("neutral",.init(repeating:1)),
            ("warm_scene",.init(1,0.4,0.12)),("green_scene",.init(0.2,1,0.2)),("blue_scene",.init(0.12,0.35,1)),
            ("mixed_lighting",.init(repeating:1)),("low_saturation",.init(1,0.92,0.9)),("high_saturation",.init(1,0.02,0.01))]
        for (name,color) in configurations {
            let input=SyntheticCharts.make(size:256) { x,_ in
                let base=Float(0.03+0.6*x)
                if name=="mixed_lighting" {return base*(x<0.5 ? SIMD3<Float>(1.15,1,0.9) : SIMD3<Float>(0.9,1,1.15))}
                return color*base
            }
            let a=analysis(input),proposal=AutoProposal(a),out=try await output(input,proposal.intent.color),b=analysis(out)
            var c=LabCase(name:"Auto color "+name)
            c.metrics=["WBConfidence":proposal.intent.wbConfidence,"temperature":proposal.intent.temperatureIntent,"tint":proposal.intent.tintIntent,
                       "beforeChroma":a.chroma.mean,"afterChroma":b.chroma.mean,"additionalClippedFraction":b.whiteFraction-a.whiteFraction]
            c.check("Finite",pixels(out).allSatisfy(\.isFinite),hard:true,"Production WB/vibrance renderer")
            if name=="neutral" {c.check("Neutral stays neutral",proposal.intent.temperatureIntent==0 && proposal.intent.tintIntent==0 && b.chroma.mean<1e-6,hard:true,"Neutral image must not gain a cast")}
            if name.hasPrefix("true_") {c.check("Known cast reduced",b.chroma.mean<a.chroma.mean,"Measured distance to neutral RGB axis; no automatic WB tuning")}
            if name.hasSuffix("_scene") {c.check("Intentional color retained",b.chroma.mean>0.8*a.chroma.mean,"At least 80% of scene chroma retained; no gray-world neutralization")}
            all += [(name+" Original",input),("Gray World baseline",grayWorld(input)),("Auto Color",out)]
            try lab.artifacts.sheet(Array(all.suffix(3)),"Auto/Synthetic/"+name+".png",cell:256,maxColumns:3)
            if name=="warm_scene" {try lab.artifacts.sheet(Array(all.suffix(3)),"Auto/warm_scene_wb.png",cell:384,maxColumns:3)}
            syntheticIntent += "### \(name)\n\n\(proposal.intent)\n\n"
            lab.cases.append(c)
        }
        try lab.artifacts.sheet(all,"Auto/wb_intent_validation.png",cell:256,maxColumns:3)
        try lab.artifacts.sheet(all,"Auto/gray_world_vs_auto_color.png",cell:256,maxColumns:3)
    }
    func curveRoundTrips() async throws {
        let curves:[(String,ToneCurve)]=[
            ("S gentle",ToneCurve(points:[.init(x:0,y:0),.init(x:0.25,y:0.2),.init(x:0.75,y:0.8),.init(x:1,y:1)])),
            ("S strong",ToneCurve(points:[.init(x:0,y:0),.init(x:0.25,y:0.1),.init(x:0.75,y:0.9),.init(x:1,y:1)])),
            ("Lifted blacks",ToneCurve(points:[.init(x:0,y:0.12),.init(x:0.5,y:0.5),.init(x:1,y:1)])),
            ("Compressed highlights",ToneCurve(points:[.init(x:0,y:0),.init(x:0.5,y:0.5),.init(x:1,y:0.8)])),
            ("Shadow only",ToneCurve(points:[.init(x:0,y:0),.init(x:0.15,y:0.25),.init(x:0.4,y:0.4),.init(x:1,y:1)])),
            ("Multiple local changes",ToneCurve(points:[.init(x:0,y:0.03),.init(x:0.15,y:0.22),.init(x:0.3,y:0.25),.init(x:0.5,y:0.6),.init(x:0.75,y:0.65),.init(x:1,y:0.92)]))]
        var series:[(String,[Double])]=[]
        roundtripRows="| Curve | Light settings | MAE | RMSE | Max | Classification | Round-trip MAE |\n|---|---|---:|---:|---:|---|---:|\n"
        for (name,curve) in curves {
            let start=ContinuousClock.now,fit=AutoTonalMapping.approximate(curve)
            timings["Curve→Light",default:[]].append(elapsed(start))
            let back=AutoTonalMapping.fit(light:fit.settings)
            let loss=AutoFitError((0...4096).map {let y=Double($0)/4096;return AutoTonalMapping.curve(y,back.curve)-AutoTonalMapping.curve(y,curve)})
            roundtripRows += "| \(name) | \(Adjustment.light.map{fit.settings[$0]}) | \(fit.sdr.mae) | \(fit.sdr.rmse) | \(fit.sdr.maximum) | \(fit.sdr.classification) | \(loss.mae) |\n"
            var c=LabCase(name:"Auto Curve→Light "+name)
            c.check("Approximation usable",fit.sdr.maximum<0.05,"Five percent linear max threshold flags missing model expressivity; not a renderer defect")
            c.metrics["MAE"]=fit.sdr.mae;c.metrics["max"]=fit.sdr.maximum;lab.cases.append(c)
            series.append((name,(0...512).map{AutoTonalMapping.curve(Double($0)/512,curve)}))
            series.append((name+" best-fit Light",(0...512).map{AutoTonalMapping.light(Double($0)/512,fit.settings)}))
        }
        try lab.artifacts.plot(series,"Auto/curve_light_curve_roundtrip.png",title:"Arbitrary curve → bounded deterministic Light fit",yRange:0...1)
        try save(roundtripRows,"Auto/curve_to_light_parameters.md")
    }
}
