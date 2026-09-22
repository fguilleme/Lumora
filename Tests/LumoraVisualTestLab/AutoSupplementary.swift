import Foundation
import CoreImage
import Testing
@testable import LumoraCore

/// Additional production-graph invariants, independent of photographic tuning.
@Test func autoSupplementaryInvariants() async throws {
    let repo=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let lab=try LumoraVisualTestLab(root:repo.appendingPathComponent("TestArtifacts"),full:true)
    let engine=RenderEngine()
    let files=try FileManager.default.contentsOfDirectory(at:repo.appendingPathComponent("VisualTestAssets"),includingPropertiesForKeys:nil)
        .filter{$0.pathExtension=="png"}.sorted{$0.lastPathComponent<$1.lastPathComponent}
    var cases:[LabCase]=[]
    for file in files {
        var c=LabCase(name:"Supplementary "+file.lastPathComponent)
        let result=try await engine.autoAnalysis(url:file,state:EditState()),p=result.proposal
        for module in [AutoModule.light,.color,.curves,.global] {
            let first=p.applying(module,to:EditState()),second=p.applying(module,to:first)
            c.check(module.rawValue+" exact reapply",first==second,hard:true,"Same input produces exactly equal controls")
            var manual=first
            for adjustment in module == .color ? Adjustment.color : Adjustment.light {manual[adjustment]=3}
            if module == .curves {manual.curves.rgb=ToneCurve(points:[.init(x:0,y:0.1),.init(x:1,y:0.9)])}
            c.check(module.rawValue+" reapplied after edit",p.matches(module,state:p.applying(module,to:manual)),hard:true,"Manual values do not become cumulative analysis input")
            c.check(module.rawValue+" bounds",Adjustment.allCases.allSatisfy{$0.range.contains(first[$0])},hard:true,"No hidden/out-of-range sliders")
        }
        for tonal in [AutoModule.light,.curves] {
            let a=p.applying(.color,to:p.applying(tonal,to:EditState()))
            let b=p.applying(tonal,to:p.applying(.color,to:EditState()))
            c.check(tonal.rawValue+" Color order",a==b,hard:true,"Identical persisted state implies same fixed renderer order")
        }
        for style in AutoCurveStyle.allCases {
            let curve=p.curves[style]!.curve
            let mapped=(0...8192).map{AutoTonalMapping.curve(Double($0)*8/8192,curve)}
            c.check(style.rawValue+" monotone HDR",zip(mapped,mapped.dropFirst()).allSatisfy{$0.isFinite && $1.isFinite && $1+1e-12 >= $0},hard:true,"Dense interpolation validation through HDR 8")
        }
        // Check how accurately the neutral-axis primitive models the real LUT interpolation.
        let levels=(0..<2048).map { Double($0)*8/2047 }
        let data=levels.flatMap{[Float($0),Float($0),Float($0),Float(1)]}.withUnsafeBytes{Data($0)}
        let ramp=CIImage(bitmapData:data,bytesPerRow:2048*16,size:CGSize(width:2048,height:1),format:.RGBAf,colorSpace:lab.gpu.linear)
        let rendered=try await engine.autoDiagnosticDevelopment(ramp,state:p.intent.light)
        let actual=lab.gpu.read(rendered,rendered.extent)
        let errors=levels.indices.map{abs(Double(actual[$0*4])-AutoTonalMapping.light(levels[$0],p.intent.light))}
        let metric=AutoFitError(errors)
        c.metrics["primitiveVsProduction-max"]=metric.maximum
        c.check("Neutral primitive vs production",metric.maximum<0.025,"Existing 32³ LUT interpolation and HDR behavior, independent of fit approximation")
        c.check("Finite production HDR",actual.allSatisfy(\.isFinite),hard:true,"0…8 float ramp")
        cases.append(c)
    }
    // Sparse outliers and deterministic shadow noise: same distribution, no scene-specific rules.
    let base=AutoCorrectionTestChart.generate("already_good",size:256)
    var values=AutoAnalysisInput.pixels(base,context:lab.gpu.context,maximum:256)
    let original=AutoCorrectionIntent(analysis:ImageAnalysis.measure(values))
    for i in stride(from:0,to:values.count,by:4096) {values[i]=8;values[i+1]=8;values[i+2]=8}
    let outlier=AutoCorrectionIntent(analysis:ImageAnalysis.measure(values))
    var c=LabCase(name:"Supplementary outlier stability")
    c.check("Small HDR sources",abs(original.exposureShiftEV-outlier.exposureShiftEV)<0.1,"Less than .1 EV shift for sparse HDR outliers")
    for i in stride(from:0,to:values.count,by:4096) {values[i]=0;values[i+1]=0;values[i+2]=0}
    let blacks=AutoCorrectionIntent(analysis:ImageAnalysis.measure(values))
    c.check("Small dark sources",abs(original.exposureShiftEV-blacks.exposureShiftEV)<0.1,"Less than .1 EV shift for sparse black outliers")
    for i in stride(from:0,to:values.count,by:4) {
        let noise=Float((i/4)%7-3)*0.0001
        for j in 0..<3 {values[i+j]+=noise}
    }
    let noisy=AutoCorrectionIntent(analysis:ImageAnalysis.measure(values))
    c.check("Shadow noise",abs(original.exposureShiftEV-noisy.exposureShiftEV)<0.1,"Deterministic +/- .0003 linear noise")
    cases.append(c)
    if let file=files.first, let photo=CIImage(contentsOf:file) {
        var exposureCase=LabCase(name:"Known exposure changes on normal portrait")
        var items:[(String,CIImage)]=[]
        for (name,ev) in [("Underexposed",-2.0),("Overexposed recoverable",1.0)] {
            let input=photo.applyingFilter("CIExposureAdjust",parameters:[kCIInputEVKey:ev])
            let a=ImageAnalysis.measure(AutoAnalysisInput.pixels(input,context:lab.gpu.context)),p=AutoProposal(a)
            let corrected=try await engine.autoDiagnosticDevelopment(input,state:p.intent.light)
            exposureCase.metrics[name+"-EV"]=p.intent.exposureShiftEV
            exposureCase.metrics[name+"-Highlights"]=p.intent.highlightCompression
            exposureCase.check(name+" direction",ev<0 ? p.intent.exposureShiftEV>0 : (p.intent.exposureShiftEV<0 || p.intent.highlightCompression<0),"Known exposure perturbation of an otherwise normal source; preserve high-key classification where appropriate")
            items += [(name,input),("Auto Light",corrected)]
        }
        try lab.artifacts.sheet(items,"Auto/known_photo_exposure_comparison.png",cell:384,maxColumns:2)
        cases.append(exposureCase)
    }
    try lab.artifacts.json(cases,"Auto/supplementary_checks.json")
    for c in cases {for check in c.checks where check.hard {#expect(check.status != "FAIL","\(c.name): \(check.name)")}}
}
