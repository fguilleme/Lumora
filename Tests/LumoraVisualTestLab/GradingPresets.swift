import Foundation
import CoreImage
import Testing
import Darwin
@testable import LumoraCore

@Test func colorGradingPresetsValidation() async throws {
    let run=try GradingPresetValidation()
    do {try await run.synthetic();try await run.photographs();try await run.integration()}
    catch {var c=LabCase(name:"Campaign completion");c.check("Complete",false,hard:true,String(describing:error));run.lab.cases.append(c);try run.report();throw error}
    try run.report()
    for c in run.lab.cases {for check in c.checks where check.hard {#expect(check.status != "FAIL","\(c.name): \(check.name)")}}
}

final class GradingPresetValidation {
    let root="ColorGradingPresets/"
    let repo:URL,lab:LumoraVisualTestLab,helper:AutoValidation
    let presets=ColorGradingPreset.allCases
    var gray:[[Float]]=[],photoDistances=[[Double]](repeating:[Double](repeating:0,count:16),count:16)
    var photoTable="| Photo | Preset | RGB MAE | Mean ΔY | Max abs ΔY | P05 Δ | P50 Δ | P95 Δ | P99 Δ | Mean chroma Δ | Clipping Δ | Nonfinite |\n|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|\n"
    var roiTable="| Photo / region | Preset | Mean ΔY | Max abs ΔY | Mean chroma Δ | Clipping Δ | RGB MAE |\n|---|---|---:|---:|---:|---:|---:|\n"
    var manualRows="| Preset | Max RGB error | Preset ms | Manual ms |\n|---|---:|---:|---:|\n"
    var performance:[String:[Double]]=[:],memory:[Double]=[]
    var files:[URL]=[]
    init() throws {
        repo=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        lab=try LumoraVisualTestLab(root:repo.appendingPathComponent("TestArtifacts"),full:true)
        helper=AutoValidation(lab:lab,repo:repo)
    }
    func render(_ input:CIImage,_ g:ColorGrading) async throws -> CIImage {var s=EditState();s.colorGrading=g;return try await helper.output(input,s)}
    func save(_ text:String,_ path:String) throws {try helper.save(text,root+path)}
    func sheet(_ items:[(String,CIImage)],_ path:String,cell:Int=320,columns:Int=4) throws {try lab.artifacts.sheet(items,root+path,cell:cell,maxColumns:columns)}
    func samples(_ image:CIImage,side:Int=256)->[Float] {AutoAnalysisInput.pixels(image,context:lab.gpu.context,maximum:side)}
    func mae(_ a:[Float],_ b:[Float])->Double {zip(a,b).enumerated().reduce(0){$0+($1.offset%4==3 ? 0:abs(Double($1.element.0-$1.element.1)))} / Double(a.count/4*3)}
    func metric(_ input:CIImage,_ output:CIImage)->[String:Double] {
        let a=samples(input),b=samples(output),x=ImageAnalysis.measure(a),y=ImageAnalysis.measure(b)
        let errors=stride(from:0,to:min(a.count,b.count),by:4).map{abs(LabGPU.luma(a,$0)-LabGPU.luma(b,$0))}
        return ["rgb":mae(a,b),"meanY":y.luminance.mean-x.luminance.mean,"maxY":errors.max() ?? 0,
                "p05":y.luminance.percentiles[2]-x.luminance.percentiles[2],"p50":y.luminance.median-x.luminance.median,
                "p95":y.luminance.percentiles[4]-x.luminance.percentiles[4],"p99":y.luminance.percentiles[5]-x.luminance.percentiles[5],
                "chroma":y.chroma.mean-x.chroma.mean,"clip":y.whiteFraction-x.whiteFraction,"nonfinite":Double(y.nonFinite)]
    }
    func manual(_ source:ColorGrading)->ColorGrading {
        var g=ColorGrading()
        for range in GradingRange.allCases {var w=GradingWheel();w.hue=source[range].hue;w.saturation=source[range].saturation;w.luminance=source[range].luminance;g[range]=w}
        g.balance=source.balance;g.blending=source.blending;return g
    }
    func synthetic() async throws {
        lab.progress("Grading presets: first frozen definitions, synthetic/identity/manual/HDR campaign")
        try lab.artifacts.json(presets.map{PresetDefinition(id:$0.id,settings:$0.settings)},root+"preset_definitions.json")
        let ramp=SyntheticCharts.make(size:512){x,_ in SIMD3<Float>(repeating:Float(x))}
        let extended=SyntheticCharts.make(size:512){x,_ in SIMD3<Float>(repeating:Float(x*8))}
        let levels:[Float]=[0,0.001,0.01,0.05,0.18,0.4,0.7,0.9,1,2,4,8]
        let chart=SyntheticCharts.make(size:512){x,_ in SIMD3<Float>(repeating:levels[min(11,Int(x*12))])}
        let colors:[SIMD3<Float>]=[.init(repeating:0.18),.init(0.55,0.3,0.2),.init(0.12,0.065,0.04),.init(0.7,0.03,0.03),.init(0.8,0.25,0.02),.init(0.7,0.7,0.04),.init(0.03,0.5,0.04),.init(0.03,0.5,0.5),.init(0.03,0.04,0.7),.init(0.6,0.03,0.5),.init(0.01,0.001,0.08),.init(0.7,0.5,0.6)]
        let patches=SyntheticCharts.make(size:512){x,_ in colors[min(11,Int(x*12))]}
        var ramps:[(String,CIImage)]=[],charts:[(String,CIImage)]=[],patchImages:[(String,CIImage)]=[],hdr:[(String,CIImage)]=[]
        var patchRows="| Preset | Patch index | ΔY | Δchroma | Hue delta degrees | Outside SDR gamut |\n|---|---:|---:|---:|---:|---|\n"
        for preset in presets {
            let g=preset.settings,start=ContinuousClock.now,out=try await render(ramp,g)
            _=samples(out);let pt=helper.elapsed(start)
            let t=ContinuousClock.now,copy=try await render(ramp,manual(g));_=samples(copy);let mt=helper.elapsed(t)
            let error=lab.gpu.compare(out,copy).maxError
            manualRows += "| \(preset.title) | \(error) | \(pt) | \(mt) |\n"
            var c=LabCase(name:"Synthetic / "+preset.id)
            c.check("Manual reproduction",error==0,hard:true,"All eleven visible values set individually from Neutral; exact production pixels")
            c.check("Bounds",g==g.validated,hard:true,"All settings remain within UI ranges")
            c.check("Finite",samples(out).allSatisfy(\.isFinite),hard:true,"RGBAf production graph")
            let loaded=try JSONDecoder().decode(ColorGrading.self,from:JSONEncoder().encode(g)),persisted=try await render(ramp,loaded)
            c.check("Persisted pixels",lab.gpu.compare(out,persisted).maxError==0,hard:true,"No preset ID needed")
            let again=try await render(ramp,g)
            c.check("Determinism",lab.gpu.compare(out,again).maxError==0,hard:true,"Same graph and parameters")
            if preset == .neutral {c.check("Neutral exact",lab.gpu.compare(ramp,out).maxError==0,hard:true,"Existing identity bypass")}
            let extendedOut=try await render(extended,g)
            c.check("HDR finite",samples(extendedOut).allSatisfy(\.isFinite),hard:true,"Renderer's existing SDR LUT policy; no new clamp")
            let hdrStats=ImageAnalysis.measure(samples(extendedOut))
            c.metrics["HDR maximum"]=hdrStats.rgb.map{$0.percentiles.last!}.max()!
            c.check("HDR domain preserved",preset == .neutral || c.metrics["HDR maximum"]!>1,"Active existing SDR LUT clips extended values; renderer unchanged, inspect hdr_response.png")
            let values=(0..<4096).flatMap { i -> [Float] in let x=Float(i)/4095*1.1;return [x,x,x,1] }
            let dense=values.withUnsafeBytes { CIImage(bitmapData:Data($0),bytesPerRow:4096*16,size:CGSize(width:4096,height:1),format:.RGBAf,colorSpace:lab.gpu.linear) }
            let denseOut=try await render(dense,g),p=samples(denseOut,side:4096)
            let jump=stride(from:4,to:p.count,by:4).map{i in (0..<3).map{abs(Double(p[i+$0]-p[i-4+$0]))}.max()!}.max() ?? 0
            c.metrics["maxAdjacentRGB"]=jump;c.check("Continuity",jump<0.01,hard:true,"4096 samples through white, max step < .01 linear including existing LUT interpolation")
            let m=metric(ramp,out);c.metrics.merge(m){_,n in n}
            c.check("Luminance drift",abs(m["meanY"]!)<0.02 && m["maxY"]!<0.12,"Heuristic: .02 mean / .12 max linear, encoded-luma preservation is not linear-luma preservation")
            gray.append(samples(out));ramps.append((preset.title,out));charts.append((preset.title,try await render(chart,g)));hdr.append((preset.title,extendedOut))
            patchImages.append((preset.title,try await render(patches,g)))
            for (index,color) in colors.enumerated() {
                let patch=SyntheticCharts.make(size:8){_,_ in color},graded=try await render(patch,g),v=samples(graded,side:8)
                let a=SIMD3<Double>(Double(color.x),Double(color.y),Double(color.z)),b=SIMD3<Double>(Double(v[0]),Double(v[1]),Double(v[2]))
                func hue(_ v:SIMD3<Double>)->Double {atan2(sqrt(3)*(v.y-v.z),2*v.x-v.y-v.z)*180 / .pi}
                let delta=atan2(sin((hue(b)-hue(a)) * .pi/180),cos((hue(b)-hue(a)) * .pi/180))*180 / .pi
                let metric=metric(patch,graded)
                patchRows += "| \(preset.id) | \(index) | \(metric["meanY"]!) | \(metric["chroma"]!) | \(delta) | \(min(b.x,b.y,b.z)<0 || max(b.x,b.y,b.z)>1) |\n"
            }
            c.images=[root+"gray_ramp.png",root+"tonal_zone_chart.png"];lab.cases.append(c)
        }
        try sheet(ramps,"gray_ramp.png");try sheet(charts,"tonal_zone_chart.png");try sheet(patchImages,"color_patch_chart.png");try sheet(hdr,"hdr_response.png")
        try save(patchRows,"color_patch_metrics.md");try save(manualRows,"manual_reproduction.md")
        for (name,preset) in [("balance",ColorGradingPreset.splitWarmCool),("blending",.tealWarm)] {
            var items:[(String,CIImage)]=[]
            for value in name=="balance" ? [-100.0,-50,0,50,100]:[0.0,25,50,75,100] {
                var g=preset.settings;if name=="balance" {g.balance=value}else{g.blending=value}
                items.append(("\(name) \(value)",try await render(ramp,g)))
            }
            try sheet(items,name+"_response.png",columns:5)
        }
        let weights=(0...512).map{GradingTransform.weights(luminance:Double($0)/512,blending:50,balance:0)}
        try lab.artifacts.plot([("Shadows",weights.map(\.x)),("Midtones",weights.map(\.y)),("Highlights",weights.map(\.z))],root+"tonal_contribution_map.png",title:"Existing encoded-luminance tonal weights",yRange:0...1)
        var wheels:[(String,CIImage)]=[]
        for preset in presets {for range in GradingRange.allCases {
            let w=preset.settings[range],marker=ColorWheelCoordinates.position(hue:w.hue,saturation:w.saturation)
            let image=SyntheticCharts.make(size:256){x,y in
                let dx=2*x-1,dy=2*y-1,r=hypot(dx,dy)
                if hypot(dx-marker.x,dy-marker.y)<0.035 {return .init(repeating:1)}
                if r>1 {return .init(repeating:0.02)}
                let rgb=HSLColor(hue:atan2(dy,dx)*180 / .pi,saturation:min(1,r),lightness:0.5).rgb
                return .init(Float(rgb.0),Float(rgb.1),Float(rgb.2))
            }
            wheels.append(("\(preset.title) \(range.rawValue) H\(w.hue) S\(w.saturation) L\(w.luminance) B\(preset.settings.balance) Mix\(preset.settings.blending)",image))
        }}
        try sheet(wheels,"color_wheels_overview.png",cell:400,columns:3)
    }
}
struct PresetDefinition:Codable {let id:String;let settings:ColorGrading}
