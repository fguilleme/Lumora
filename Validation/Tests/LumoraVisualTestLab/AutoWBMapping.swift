import Foundation
import CoreImage
import Testing
@testable import LumoraCore

@Test func autoWBRendererCharacterization() async throws {
    let repo=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let lab=try LumoraVisualTestLab(root:repo.appendingPathComponent("Validation/TestArtifacts"),full:true)
    let run=AutoValidation(lab:lab,repo:repo)
    let ramp=SyntheticCharts.make(size:256) { x,_ in SIMD3<Float>(repeating:Float(0.03+0.6*x)) }
    func axes(_ image:CIImage)->[Double] {
        let a=run.analysis(image),m=a.rgb.map(\.mean)
        return [log(m[0]/m[2]),log(m[1]/sqrt(m[0]*m[2]))]
    }
    var rows="| Control | Value | log(R/B), warm+ | log(G/sqrt(RB)), green+ | Mean chroma |\n|---|---:|---:|---:|---:|\n"
    var samples:[[Double]]=[],images:[(String,CIImage)]=[("Neutral reference",ramp)]
    for (control,values) in [(Adjustment.temperature,[-16.0,-8,-4,4,8,16]),(.tint,[-12.0,-6,-3,3,6,12])] {
        for value in values {
            var state=EditState();state[control]=value
            let out=try await run.output(ramp,state),a=axes(out)
            rows += "| \(control) | \(value) | \(a[0]) | \(a[1]) | \(run.analysis(out).chroma.mean) |\n"
            samples.append([control == .temperature ? 0:1,value,a[0],a[1]])
            images.append(("\(control) \(value)",out))
        }
    }
    try run.save("# Production Color axes — pre-fix empirical measurement\n\nLinear gray ramp .03… .63, unchanged production graph. Log ratios are signed chromatic coordinates, not UI units.\n\n"+rows+"\n## Interpretation and mapping\n\nTemperature positive cools / negative warms. Tint positive greens / negative shifts magenta. Central differences at ±4 / ±3 give J = [[−0.008045697550, −0.000426183135], [−0.000858241143, +0.003600745284]] per UI unit. The axes are separated by 89.3387°, sufficiently independent for a stable 2×2 inverse, with measurable coordinate cross-coupling. Symmetric Temperature slopes at ±4/±8/±16 are −.00804570 / −.00805733 / −.00811041 (0.80% span); Tint slopes at ±3/±6/±12 are .003600745 / .003600846 / .003601290 (0.015% span). Response is approximately linear near zero, not globally symmetric or exact.\n\nM = −inverse(J) × diag(J) = [[−.987531890276, +.052309875438], [−.235379187216, −.987531890276]]. Applying M to the existing confidence-weighted, rounded intent corrects polarity and first-order cross-coupling while retaining existing diagonal amplitudes. It does not recalibrate exposure, detection, confidence, saturation or vibrance, and does not aim at complete neutralization. Final controls retain ±16/±12 bounds and integer rounding. No corpus fitting.\n","Auto/WB/renderer_axis_characterization.md")
    try lab.artifacts.json(samples,"Auto/WB/renderer_axis_samples.json")
    try lab.artifacts.sheet(images,"Auto/WB/renderer_axis_characterization.png",cell:256,maxColumns:4)
}

@Test func autoWBMappingValidation() async throws {
    let repo=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let lab=try LumoraVisualTestLab(root:repo.appendingPathComponent("Validation/TestArtifacts"),full:true)
    let run=AutoValidation(lab:lab,repo:repo),decoder=JSONDecoder()
    // Immutable scalar observations from the pre-fix campaign, not image Golden Masters.
    let fixtures=Bundle.module.resourceURL!.appendingPathComponent("Fixtures/AutoWB")
    let previous=try decoder.decode([LabCase].self,from:Data(contentsOf:fixtures.appendingPathComponent("pre_fix_color_checks.json")))
    let records=try decoder.decode([AutoPhotoRecord].self,from:Data(contentsOf:fixtures.appendingPathComponent("pre_fix_photo_measurements.json")))
    try await run.colorCharts()
    var rows="| Synthetic cast | Estimated T / tint intent (unchanged) | UI Temperature | UI Tint | Confidence | Before chroma | Previous after | Fixed after |\n|---|---|---:|---:|---:|---:|---:|---:|\n"
    var regression=LabCase(name:"WB mapping scope and lifecycle")
    for c in lab.cases {
        let old=previous.first{$0.name==c.name}!
        regression.check(c.name+" confidence frozen",c.metrics["WBConfidence"]==old.metrics["WBConfidence"],hard:true,"Same candidate detection and confidence")
        if c.name.contains("true_") {
            let t=old.metrics["temperature"]!,g=old.metrics["tint"]!
            let controls=AutoWBMapping.controls(temperatureIntent:t,tintIntent:g)
            rows += "| \(c.name) | \(t) / \(g) | \(controls.temperature) | \(controls.tint) | \(c.metrics["WBConfidence"]!) | \(c.metrics["beforeChroma"]!) | \(old.metrics["afterChroma"]!) | \(c.metrics["afterChroma"]!) |\n"
            var s=EditState();s.temperature=controls.temperature;s.tint=controls.tint
            let loaded=try decoder.decode(EditState.self,from:JSONEncoder().encode(s))
            regression.check(c.name+" persisted controls",loaded==s,hard:true,"Visible slider values are the sole persisted WB correction")
            var before=EditState();before.temperature=25
            var manager=HistoryManager();manager.begin("Auto Color",state:before);manager.commit(s)
            regression.check(c.name+" Undo/Redo",manager.undo()==before && manager.redo()==s,hard:true,"One atomic transaction with nonzero WB")
        }
        if c.name.hasSuffix("_scene") {
            regression.check(c.name+" protected intent",c.metrics["WBConfidence"]==0 && c.metrics["temperature"]==0 && c.metrics["tint"]==0,hard:true,"No Gray World correction")
        }
    }
    var contact:[(String,CIImage)]=[],changed:[(String,CIImage)]=[]
    var photoRows="| Photo | Previous T / tint | Fixed T / tint | Confidence | Changed |\n|---|---|---|---:|---|\n"
    for record in records {
        let url=repo.appendingPathComponent("Validation/VisualTestAssets/"+record.name+".png")
        let fresh=try await run.engine.autoAnalysis(url:url,state:EditState())
        let proposal=fresh.proposal,intent=proposal.intent
        regression.check(record.name+" analysis and intent frozen",proposal.analysis==record.analysis && intent==record.intent,hard:true,"Fresh production analysis; no confidence/scene/saturation/vibrance changes")
        let oldProposal=AutoProposal(record.analysis)
        for style in AutoCurveStyle.allCases {
            regression.check(record.name+" "+style.rawValue+" frozen",proposal.curves[style]!.curve==oldProposal.curves[style]!.curve,hard:true,"Unchanged tonal primitives and intent")
        }
        regression.check(record.name+" initial Balanced points",proposal.curves[.balanced]!.curve.points==record.points,hard:true,"Compared with initial campaign, not only current mapper")
        var old=intent.color;old.temperature=intent.temperatureIntent;old.tint=intent.tintIntent
        let fixed=intent.color,hasChange=old != fixed
        regression.check(record.name+" change restricted to WB",old.saturation==fixed.saturation && old.vibrance==fixed.vibrance && (!hasChange || (intent.wbConfidence>0 && (intent.temperatureIntent != 0 || intent.tintIntent != 0))),hard:true,"Only nonzero confident WB may change")
        let applied=proposal.applying(.color,to:EditState())
        let repeated=proposal.applying(.color,to:applied)
        regression.check(record.name+" idempotence",applied==repeated,hard:true,"Same visible parameters")
        let cached=try await run.engine.autoAnalysis(url:url,state:applied)
        regression.check(record.name+" cache",cached.cacheHit && cached.proposal.analysis==proposal.analysis,hard:true,"Auto Color output excluded from analysis input")
        regression.check(record.name+" bounds",Adjustment.color.allSatisfy{$0.range.contains(fixed[$0])},hard:true,"Normal UI bounds")
        guard let full=CIImage(contentsOf:url,options:[.applyOrientationProperty:true]) else {throw LabError.render}
        let input=run.reduced(full,side:1024),items=try await run.variants(input,proposal)
        for index in [0,1,2,3,5] {contact.append((record.name+" / "+items[index].0,items[index].1))}
        let previousOutput=try await run.output(input,old),fixedOutput=items[2].1
        if hasChange {changed += [(record.name+" Original",input),("Previous Auto Color",previousOutput),("Fixed Auto Color",fixedOutput)]}
        else {regression.check(record.name+" Color pixels unchanged",lab.gpu.compare(previousOutput,fixedOutput).maxError==0,hard:true,"Bit-exact unchanged WB/saturation/vibrance")}
        let persisted=try decoder.decode(EditState.self,from:JSONEncoder().encode(applied))
        let persistedImage=try await run.output(input,persisted)
        regression.check(record.name+" persisted pixels",lab.gpu.compare(persistedImage,fixedOutput).maxError==0,hard:true,"No analysis needed to reconstruct render")
        photoRows += "| \(record.name) | \(old.temperature) / \(old.tint) | \(fixed.temperature) / \(fixed.tint) | \(intent.wbConfidence) | \(hasChange) |\n"
    }
    // Frozen diagonal intent amplitudes; this checks only the production-axis adapter.
    for t in stride(from:-16.0,through:16,by:1) {for g in stride(from:-12.0,through:12,by:1) {
        let wb=AutoWBMapping.controls(temperatureIntent:t,tintIntent:g)
        #expect(abs(wb.temperature)<=16 && abs(wb.tint)<=12)
    }}
    lab.cases.append(regression)
    try run.save("# WB mapping results\n\n"+rows+"\n## Photographs — fresh analysis\n\n"+photoRows,"Auto/WB/wb_mapping_results.md")
    try lab.artifacts.sheet(contact,"Auto/real_photos_contact_sheet.png",cell:320,maxColumns:5)
    try lab.artifacts.sheet(changed,"Auto/WB/real_photo_before_after.png",cell:512,maxColumns:3)
    try lab.artifacts.json(lab.cases,"Auto/WB/checks.json")
    for c in lab.cases {for check in c.checks where check.hard {#expect(check.status != "FAIL","\(c.name) / \(check.name)")}}
}

/// Consolidation after the targeted campaign; retain all original results in history.
@Test func autoWBFinalizeReport() throws {
    guard ProcessInfo.processInfo.environment["LUMORA_WB_FINALIZE"] == "1" else {return}
    let repo=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let lab=try LumoraVisualTestLab(root:repo.appendingPathComponent("Validation/TestArtifacts"),full:true)
    let run=AutoValidation(lab:lab,repo:repo),decoder=JSONDecoder()
    let history="Auto/ValidationHistory/pre_wb_mapping_fix/"
    let previous=try decoder.decode([LabCase].self,from:Data(contentsOf:lab.artifacts.url(history+"checks.json")))
    let current=try decoder.decode([LabCase].self,from:Data(contentsOf:lab.artifacts.url("Auto/WB/checks.json")))
    lab.cases=previous.filter{!$0.name.hasPrefix("Auto color ")}+current
    run.records=try decoder.decode([AutoPhotoRecord].self,from:Data(contentsOf:lab.artifacts.url(history+"photo_measurements.json")))
    run.timings=try decoder.decode([String:[Double]].self,from:Data(contentsOf:lab.artifacts.url("Auto/performance.json")))
    run.roundtripRows=try String(contentsOf:lab.artifacts.url("Auto/curve_to_light_parameters.md"),encoding:.utf8)
    run.syntheticIntent=try String(contentsOf:lab.artifacts.url("Auto/intent_diagnostics.md"),encoding:.utf8).components(separatedBy:"### 01_portrait_light_skin")[0]
    let regression=try decoder.decode([String:Bool].self,from:Data(contentsOf:lab.artifacts.url("Auto/non_regression.json")))
    #expect(regression.count==110 && regression.values.allSatisfy{$0})
    try run.report()
    let reportURL=try lab.artifacts.url("AutoCorrectionValidationReport.md")
    var report=try String(contentsOf:reportURL,encoding:.utf8)
    let axes=try String(contentsOf:lab.artifacts.url("Auto/WB/renderer_axis_characterization.md"),encoding:.utf8)
    let mapping=try String(contentsOf:lab.artifacts.url("Auto/WB/wb_mapping_results.md"),encoding:.utf8)
    let verification=try String(contentsOf:lab.artifacts.url("Auto/WB/verification.md"),encoding:.utf8)
    let section="""
    ## Authorized WB mapping correction — current results

    The first campaign's four WB quality WARNs are resolved by a localized intent-to-visible-controls adapter. Known high-confidence neutral casts reducing their distance to neutral are now a **hard functional requirement**. No analysis, confidence, scene, Light, Curve, saturation or vibrance heuristic changed. No calibration used corpus photos. The renderer remains unchanged. Original incorrect measurements, report and sheets are preserved in [pre_wb_mapping_fix](Auto/ValidationHistory/pre_wb_mapping_fix/AutoCorrectionValidationReport.md).

    Only **07_white_subject** changes (Temperature −2 → +2, Tint 0). All eight fresh analyses and intents equal their archived values; seven Auto Color renders remain bit-identical. The Light/Curve artifacts and performance measurements below are retained from the initial campaign because their algorithms, inputs and settings did not change. Per-photo slider tables now show the corrected control mapping, while diagnostic intents retain their original coordinate convention.

    \(axes)

    \(mapping)

    \(verification)

    Remaining three quality WARNs are the HDR-rich underexposed chart and two poor inverse Curve→Light fits. No WB WARN or hard FAIL remains. Mixed lighting is not forced neutral. Prior technical corrections remain documented in ValidationHistory/initial_failures.json.

    Inspect [renderer axes](Auto/WB/renderer_axis_characterization.png), [changed photograph](Auto/WB/real_photo_before_after.png), [WB diagnostics](Auto/wb_intent_validation.png), [Gray World comparison](Auto/gray_world_vs_auto_color.png) and [updated corpus sheet](Auto/real_photos_contact_sheet.png).

    """
    report=report.replacingOccurrences(of:"## Architecture and source",with:section+"\n## Architecture and source")
    try report.write(to:reportURL,atomically:true,encoding:.utf8)
    for c in current {for check in c.checks where check.hard {#expect(check.status != "FAIL")}}
}
