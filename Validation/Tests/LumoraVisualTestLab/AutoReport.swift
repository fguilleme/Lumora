import Foundation
import Testing
@testable import LumoraCore

extension AutoValidation {
    func report() throws {
        let checks=lab.cases.flatMap(\.checks)
        let counts=Dictionary(grouping:checks,by:{$0.status}).mapValues(\.count)
        try lab.artifacts.json(lab.cases,"Auto/checks.json")
        let failures=lab.cases.flatMap { c in c.checks.filter{$0.status=="FAIL"}.map { ["test":c.name+" / "+$0.name,"observed":"FAIL; see metrics in checks.json","expected":$0.detail,"cause":"Pending technical diagnosis","correction":"None yet"] } }
        let history=try lab.artifacts.url("Auto/ValidationHistory/initial_failures.json")
        if !FileManager.default.fileExists(atPath:history.path) {try lab.artifacts.json(failures,"Auto/ValidationHistory/initial_failures.json")}
        var parameters="| Photo | Scene | EV | Highlights | Shadows | Whites | Blacks | Contrast | Temperature | Tint | Saturation | Vibrance | WB confidence | Correction confidence | Status |\n|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|\n"
        var statistics="| Photo | Mean Y | P001 | P01 | P05 | P50 | P95 | P99 | P999 | Black fraction | White-boundary fraction | HDR Y>1 | Mean chroma | Saturation P05/P50/P95 | Neutral confidence |\n|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|\n"
        var fits="| Photo | Points | SDR MAE | SDR RMSE | SDR P95 | SDR Max | HDR MAE | HDR RMSE | HDR P95 | HDR Max | Photo MAE | Photo Max | SDR classification |\n|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|\n"
        var diagnostics=syntheticIntent
        for r in records {
            let i=r.intent,a=r.analysis,p=a.luminance.percentiles
            let status=lab.cases.first{$0.name=="Auto photo "+r.name}?.status ?? "WARN"
            parameters += "| \(r.name) | \(i.scene.rawValue) | \(i.exposureShiftEV) | \(i.highlightCompression) | \(i.shadowLift) | \(i.whitePointIntent) | \(i.blackPointIntent) | \(i.globalContrastIntent) | \(i.color.temperature) | \(i.color.tint) | \(i.saturationIntent) | \(i.vibranceIntent) | \(i.wbConfidence) | \(i.correctionConfidence) | \(status) |\n"
            statistics += "| \(r.name) | \(a.luminance.mean) | \(p[0]) | \(p[1]) | \(p[2]) | \(p[3]) | \(p[4]) | \(p[5]) | \(p[6]) | \(a.blackFraction) | \(a.whiteFraction) | \(a.hdrFraction) | \(a.chroma.mean) | \([a.saturation.percentiles[2],a.saturation.median,a.saturation.percentiles[4]]) | \(a.neutralConfidence) |\n"
            fits += "| \(r.name) | \(r.points.count) | \(r.sdr.mae) | \(r.sdr.rmse) | \(r.sdr.p95) | \(r.sdr.maximum) | \(r.hdr.mae) | \(r.hdr.rmse) | \(r.hdr.p95) | \(r.hdr.maximum) | \(r.photoMAE) | \(r.photoMax) | \(r.sdr.classification) |\n"
            diagnostics += "### \(r.name)\n\nObserved: \(a)\n\nIntent: \(i)\n\nCurve points: \(r.points)\n\n"
        }
        try save(parameters,"Auto/real_photos_parameters.md")
        try save(parameters,"Auto/auto_light_parameters.md")
        try save(parameters,"Auto/auto_color_parameters.md")
        try save(diagnostics,"Auto/intent_diagnostics.md")
        try save(fits,"Auto/light_vs_curve_metrics.md")
        var performance="| Operation (ms) | n | Median | P95 | Max |\n|---|---:|---:|---:|---:|\n"
        for name in timings.keys.sorted() {
            let t=timings[name]!.sorted()
            performance += "| \(name) | \(t.count) | \(t[t.count/2]) | \(t[Int(Double(t.count-1)*0.95)]) | \(t.last!) |\n"
        }
        try save(performance,"Auto/performance.md")
        try lab.artifacts.json(timings,"Auto/performance.json")
        var text="""
        # Auto Correction Validation Report

        PASS \(counts["PASS",default:0]) · WARN \(counts["WARN",default:0]) · FAIL \(counts["FAIL",default:0])

        Platform (Debug build): \(lab.gpu.deviceName), \(ProcessInfo.processInfo.operatingSystemVersionString). No Auto Golden Masters. First photographic heuristics are frozen; quality WARNs are not corrected. Full machine-readable hard/quality results: [Auto/checks.json](Auto/checks.json).

        ## Architecture and source

        `ImageAnalysis → AutoCorrectionIntent → Light / Color / editable RGB Curve`. One actor-owned, single-entry cache stores scalar observations plus the proposal/points, never source previews or pixel buffers. URL + file modification version/size + upstream state + selected matte + analysis size form the key. Module selection/UI and downstream Creative FX do not affect it. A different image evicts the prior entry. Analysis runs off the UI actor; applying a result checks request token, document, URL, import generation, render generation, complete snapshot and selected layer. An obsolete request cannot apply to a replacement image or overwrite a manual edit.

        Base-layer input: oriented source / RAW as-shot linear output → lens profile + manual Optics → current Geometry/crop, before all base development and before masked development/Creative FX. Geometry is brought forward **for analysis only** to measure visible pixels. Light, Color and Curves all analyze this same upstream input; their own output is excluded. Existing renderer order is unchanged. For a masked layer, analyze the actual incoming base + earlier visible masked development, then select pixels whose target matte coverage is at least 5%, excluding the target layer's own settings. No face/sky/subject analysis is added.

        ## Statistics and confidence

        Long edge 512 pixels, deterministic float RGBA in extended linear sRGB. No clamp before statistics; HDR through 8 and negative samples remain representable. Native-resolution reference and 1024/2048/4096 resizes are compared. CPU sorting on a reduced buffer is deliberate; no per-frame readback or ML. Sorted P001/P01/P05/P50/P95/P99/P999, RGB distributions, mean Y, dynamic range P99/P01 in EV, black occupancy, white-boundary occupancy, HDR fraction, saturation/chroma and coherent low-chroma candidates are observed separately from decisions. A white-boundary count in a rendered photograph does not prove sensor clipping; a known hard-clipped synthetic chart explicitly has no recoverable detail.

        WB excludes deep blacks, highlights and saturation >=.28. Robust median channel/Y ratios plus candidate coverage, count and chromaticity spread control confidence. Corrections are bounded to 16 temperature / 12 tint units before confidence and rounded to normal UI steps. Log R/B and green relative to sqrt(RB) separate warm/cool and green/magenta axes approximately. This is an estimate mapped to the existing CI temperature/tint primitive, not a calibrated illuminant measurement. Gray World is diagnostic only. Monochromatic colored scenes without neutral candidates receive no WB correction. A low-saturation intentional wash is inherently ambiguous and requires visual judgment.

        ## Light and canonical transfer

        Conservative distribution-based low-key/high-key/backlit/flat/normal/uniform classification. No universal P50 target. Broad underexposure may receive at most +1.5 EV; recoverable broad overexposure at most −1.5 EV. Shadow lift is small in low-key scenes. Flat images can receive modest contrast, black and white shaping. Uniform images receive no exposure correction. Saturation may decrease slightly near gamut; low-but-nonzero saturation can receive +5 vibrance; there is no automatic sharpening, blur or grain.

        Canonical T(Y) uses the **existing** exposure + `TonalResponse.map` neutral-axis primitives and sRGB encoding/decoding. Light adds a luminance delta to colored channels; existing master RGB Curves map each channel independently, so a neutral-axis fit does not imply identical color rendering. The original LUT and curve domain are SDR; Auto does not secretly extend or replace either renderer. HDR evaluations and errors are reported explicitly, including cases where equivalent curve conversion cannot retain exposure-only HDR. Finite/monotone evaluation is a hard invariant; photographic approximation is a quality heuristic.

        ## Curves, conversions and application semantics

        Balanced fits canonical Light. Natural blends 50% toward identity. Punchy applies a bounded, monotone log-domain separation around .18, protecting zero. Five initial points, greedy largest-residual insertion above .004 encoded error, at most ten points, with the existing .02 minimum spacing and PCHIP interpolation. No manual curve behavior is changed. Fit metrics use 4097 independent linear samples per SDR/HDR interval. Curve→Light uses deterministic bounded coordinate descent (six scales, up to four sweeps each) on 257 perceptually spaced samples. This inverse is an API/diagnostic, not a misleading exact-conversion UI.

        Classification uses max absolute linear error: Exact only zero; Near Exact <.005; Approximate <.05; otherwise Poor Approximation. These are inspection guides, not perceptual equivalence guarantees.

        Auto Light and Auto Curves explicitly replace the **Light + master RGB curve pair** with the requested representation. The UI says so before the action. This avoids provenance-dependent double application even after document reload. Color channel curves and unrelated controls remain intact. Manual Light + Curves may still be combined after Auto. Auto Color modifies only the four Color controls. Global Light+Color is available internally, with no extra curve. All settings remain editable; Auto/Custom is determined from matching current parameters to the current proposal. Only parameters are persisted; after a fresh launch the provenance label is not reconstructed until Auto is requested again. There is no permanent Auto mode.

        Each application uses one existing history transaction. Reapply ignores the module's previous corrections; exact parameter idempotence, action-order independence, serialization, neutral color, bounds and no-double-application have automated checks. Supplemental UI/build verification is recorded in Auto/verification.md. No cache or analysis is needed to render a saved result.

        ## Final build/test verification

        \((try? String(contentsOf: lab.artifacts.url("Auto/verification.md"), encoding: .utf8)) ?? "Supplemental verification pending")

        ## Per-photo decisions

        \(parameters)
        ## Observations (not decisions)

        \(statistics)
        ## Light → Curve

        \(fits)
        ## Arbitrary Curve → Light

        \(roundtripRows)
        ## Performance

        \(performance)
        Analysis timings include GPU reduced-buffer preparation where indicated; cached times include file-version lookup. Cold first-run and post-warmup costs are not conflated. RSS/cache cycles and preview/HQ/export metrics are in checks.json. No physical-device latency claim.

        ## Results and WARN/FAIL analysis

        """
        for c in lab.cases {
            text += "### \(c.name) — \(c.status)\n\n"
            for check in c.checks {text += "- **\(check.status)** [\(check.hard ? "hard invariant":"quality heuristic")] \(check.name): \(check.detail)\n"}
            if c.name.contains("true_") && c.status == "WARN" {
                text += "\nObserved cast distance increases despite high neutral confidence. The current signed temperature/tint intent mapped to the CI adaptation primitive does not correct these known casts. This is an unresolved Auto WB quality/functionality limitation, not a PASS. Inspect Auto/wb_intent_validation.png and Auto/gray_world_vs_auto_color.png. No post-run axis/strength adjustment was made.\n"
            }
            if c.name == "Auto synthetic underexposed" {
                text += "\nThe chart includes large HDR patches before the known .12 gain. The conservative distribution classifier does not infer a positive EV from this HDR-rich dark distribution. Inspect Auto/Synthetic/underexposed.png; no target exposure was tuned.\n"
            }
            if c.name.contains("Curve→Light") && c.status == "WARN" {
                text += "\nThe bounded Light model cannot reproduce these endpoint/local curve changes within the stated error tolerance. Inspect Auto/curve_light_curve_roundtrip.png. The renderer and fitting thresholds are unchanged.\n"
            }
            if !c.metrics.isEmpty {text += "\nObserved metrics: \(c.metrics)\n"}
            if !c.images.isEmpty {text += "\nInspect: "+c.images.map{"[\($0)](\($0))"}.joined(separator:", ")+"\n"}
            text += "\n"
        }
        text += """
        ## Interpretation and limits

        No aesthetic PASS replaces human inspection. Portrait skin detail, night intent, high-key whites, backlight compromise, warm scenes and saturation must be judged on the supplied comparison/crop sheets. Large Light/Curve color differences may come from the existing per-channel curve model, SDR clipping, exposure domain or point simplification; do not infer a fitted curve is exact from its neutral-axis MAE. Poor inverse fits reflect the limited Light parameter family. Reduced/native decisions and memory drift are heuristics with thresholds stated in each check. The production manual/Creative renderers are unchanged; their existing regression suites must pass independently.

        ## Priority Visual Inspection

        Inspect **[Auto/real_photos_contact_sheet.png](Auto/real_photos_contact_sheet.png)** first: Original / Auto Light / Auto Color / Light+Color / Curve Balanced for all eight photos.

        - [Backlight](Auto/backlight_intent_validation.png)
        - [Night](Auto/night_intent_validation.png)
        - [High key](Auto/high_key_intent_validation.png)
        - [Already good](Auto/already_good_validation.png)
        - [WB intent](Auto/wb_intent_validation.png)
        - [Light/Curve equivalence](Auto/light_curve_equivalence_priority.png)
        - [No double correction](Auto/no_double_correction.png)
        - [SDR transfer curves](Auto/transfer_curves.png) and [HDR](Auto/transfer_curves_HDR.png)
        - [Gray World comparison](Auto/gray_world_vs_auto_color.png)
        - [Light skin portrait](Auto/RealPhotos/01_portrait_light_skin/auto_comparison.png)
        - [Dark skin portrait](Auto/RealPhotos/02_portrait_dark_skin/auto_comparison.png)

        Initial hard-failure history: [initial_failures.json](Auto/ValidationHistory/initial_failures.json). No automatic photographic tuning. No Golden Masters.
        """
        try save(text,"AutoCorrectionValidationReport.md")
    }
}

/// Revalidate affected outputs after technical-only fixes without retuning/rerunning
/// photographic selection. The initial full campaign and its metrics stay archived.
@Test func autoFinalizeValidationReport() throws {
    guard ProcessInfo.processInfo.environment["LUMORA_AUTO_FINALIZE"] == "1" else { return }
    let repo=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let lab=try LumoraVisualTestLab(root:repo.appendingPathComponent("Validation/TestArtifacts"),full:true)
    let run=AutoValidation(lab:lab,repo:repo)
    let decoder=JSONDecoder()
    lab.cases=try decoder.decode([LabCase].self,from:Data(contentsOf:lab.artifacts.url("Auto/ValidationHistory/initial_checks.json")))
    lab.cases += try decoder.decode([LabCase].self,from:Data(contentsOf:lab.artifacts.url("Auto/supplementary_checks.json")))
    run.records=try decoder.decode([AutoPhotoRecord].self,from:Data(contentsOf:lab.artifacts.url("Auto/photo_measurements.json")))
    run.timings=try decoder.decode([String:[Double]].self,from:Data(contentsOf:lab.artifacts.url("Auto/performance.json")))
    run.roundtripRows=try String(contentsOf:lab.artifacts.url("Auto/curve_to_light_parameters.md"),encoding:.utf8)
    run.syntheticIntent=try String(contentsOf:lab.artifacts.url("Auto/intent_diagnostics.md"),encoding:.utf8).components(separatedBy:"### 01_portrait_light_skin")[0]
    var checks=LabCase(name:"Final technical revalidation")
    for record in run.records {
        let proposal=AutoProposal(record.analysis)
        checks.check(record.name+" frozen photographic output",proposal.intent==record.intent && proposal.curves[.balanced]!.curve.points==record.points,hard:true,"Same parameters/points as initial campaign; production renderers bit-exact against pre-Auto HEAD")
    }
    let regression=try decoder.decode([String:Bool].self,from:Data(contentsOf:lab.artifacts.url("Auto/non_regression.json")))
    checks.check("Manual/Creative non-regression",!regression.isEmpty && regression.values.allSatisfy{$0},hard:true,"\(regression.count) bit-exact comparisons against commit 89c7e73")
    let identity=AutoTonalMapping.fit(light:EditState())
    checks.check("Exact identity HDR fix",identity.curve.isIdentity && AutoTonalMapping.curve(8,identity.curve)==8,hard:true,"Avoid activating SDR LUT for round-off-only identity points")
    lab.cases.append(checks)
    try run.report()
    for check in checks.checks {#expect(check.status != "FAIL", "\(check.name)")}
}
