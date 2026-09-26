import Foundation
import CoreImage
@testable import LumoraCore

extension GradingPresetValidation {
    func report() throws {
        var parameters="| ID | Display name | Family | Shadows H/S/L | Midtones H/S/L | Highlights H/S/L | Balance | Blending | Mean corpus distance to Neutral | Closest preset | Distance |\n|---|---|---|---|---|---|---:|---:|---:|---|---:|\n"
        var distances="| Preset A | Preset B | Parameter distance | Gray ramp RGB MAE | Mean corpus RGB MAE |\n|---|---|---:|---:|---:|\n"
        func vector(_ preset:ColorGradingPreset)->[Double] {
            let g=preset.settings
            return GradingRange.allCases.flatMap {r -> [Double] in let w=g[r],v=ColorWheelCoordinates.position(hue:w.hue,saturation:w.saturation);return [v.x,v.y,w.luminance/100]}+[g.balance/100,g.blending/100]
        }
        var pm=[[Double]](repeating:[Double](repeating:0,count:16),count:16),gm=pm
        var diversity=LabCase(name:"Preset diversity — first definitions frozen")
        for i in presets.indices {
            let preset=presets[i],g=preset.settings,near=presets.indices.filter{$0 != i}.min{photoDistances[i][$0]<photoDistances[i][$1]}!
            func wheel(_ w:GradingWheel)->String {"\(w.hue) / \(w.saturation) / \(w.luminance)"}
            parameters += "| \(preset.id) | \(preset.title) | \(preset.family?.rawValue ?? "neutral") | \(wheel(g.shadows)) | \(wheel(g.midtones)) | \(wheel(g.highlights)) | \(g.balance) | \(g.blending) | \(photoDistances[i][0]) | \(presets[near].id) | \(photoDistances[i][near]) |\n"
            for j in presets.indices {
                let delta=zip(vector(preset),vector(presets[j])).map{abs($0-$1)}
                pm[i][j]=delta.reduce(0,+)/Double(delta.count)
                gm[i][j]=gray.count==16 ? mae(gray[i],gray[j]):0
                if i<j {
                    distances += "| \(preset.id) | \(presets[j].id) | \(pm[i][j]) | \(gm[i][j]) | \(photoDistances[i][j]) |\n"
                    diversity.check(preset.id+" / "+presets[j].id,!(pm[i][j]<0.035 && gm[i][j]<0.002 && photoDistances[i][j]<0.0015),"Duplicate heuristic requires all three: parameter mean <.035, gray RGB MAE <.002, corpus MAE <.0015; inspect preset_distance_matrix.png and family sheets")
                }
            }
            if preset == .softPortrait {diversity.check("Soft Portrait measurable",photoDistances[i][0]>0.0005,"Subtle by design; mean corpus RGB difference below .0005 warrants A/B inspection")}
        }
        diversity.check("Muted Cinema scope",false,"No global desaturation control exists in Grading: muted refers to restrained added coloration, not guaranteed lower input saturation. Inspect cinematic_presets.png.")
        diversity.images=[root+"preset_distance_matrix.png",root+"cinematic_presets.png"];lab.cases.append(diversity)
        var matrices:[(String,CIImage)]=[]
        for (name,matrix) in [("Parameter distance",pm),("Gray ramp RGB MAE",gm),("Corpus RGB MAE",photoDistances)] {
            let maximum=max(1e-8,matrix.flatMap{$0}.max() ?? 1)
            let image=SyntheticCharts.make(size:512){x,y in let value=matrix[min(15,Int((1-y)*16))][min(15,Int(x*16))]/maximum;return .init(Float(value),Float(value*0.7),Float(0.12+0.6*value))}
            matrices.append((name+"; rows/cols = preset_parameters order",image))
        }
        // Keep per-preset review flags next to its exact controls and nearest neighbor.
        let parameterLines=parameters.components(separatedBy:"\n")
        parameters=parameterLines.enumerated().map { index,line in
            guard !line.isEmpty else {return line}
            if index==0 {return line+" Review flags |"}
            if index==1 {return line+"---|"}
            let id=presets[index-2].id
            var flags:[String]=[]
            if id != "neutral" {flags.append("existing SDR/HDR limit")}
            if ["warmCinema","goldenHour","splitWarmCool"].contains(id) {flags.append("white-subject crops")}
            if diversity.checks.contains(where:{$0.status=="WARN" && $0.name.components(separatedBy:" / ").contains(id)}) {flags.append("nearby preset")}
            if id=="mutedCinema" {flags.append("no global desaturation")}
            return line+" "+flags.joined(separator:"; ")+" |"
        }.joined(separator:"\n")
        try sheet(matrices,"preset_distance_matrix.png",cell:640,columns:3)
        try save(parameters,"preset_parameters.md");try save(distances,"preset_distances.md")
        let checks=lab.cases.flatMap(\.checks),counts=Dictionary(grouping:checks,by:{$0.status}).mapValues(\.count)
        try lab.artifacts.json(lab.cases,root+"checks.json")
        let initial=try lab.artifacts.url(root+"ValidationHistory/initial_results.json")
        if !FileManager.default.fileExists(atPath:initial.path) {try lab.artifacts.json(lab.cases,root+"ValidationHistory/initial_results.json")}
        try lab.artifacts.json(performance,root+"performance.json")
        var performanceRows="| Operation ms | Median | P95 | Max |\n|---|---:|---:|---:|\n"
        for (name,values) in performance {let v=values.sorted();performanceRows += "| \(name) | \(v[v.count/2]) | \(v[Int(Double(v.count-1)*0.95)]) | \(v.last!) |\n"}
        let priority=["all_presets_contact_sheet","portrait_presets","cinematic_presets","atmosphere_presets","special_presets","portrait_skin_crops","backlight_crops","night_crops","white_subject_crops","gray_ramp","tonal_zone_chart","color_wheels_overview","preset_distance_matrix","preset_strength_overview"]
        var text="""
        # Color Grading Presets Validation Report

        PASS \(counts["PASS",default:0]) / WARN \(counts["WARN",default:0]) / FAIL \(counts["FAIL",default:0]). First fixed definitions; no aesthetic tuning, no Golden Masters. Device: \(lab.gpu.deviceName), \(ProcessInfo.processInfo.operatingSystemVersionString), Debug.

        ## Architecture / real controls

        Sixteen constant ColorGrading settings; stable IDs, localized names owned by the definition. Three tonal wheels (hue 0…360, saturation 0…100, luminance −100…100), Balance −100…100, Blending 0…100. No Global wheel, Amount, global desaturation or hidden LUT. All preset luminance values are zero. Muted Cinema is restrained coloration, not a desaturation operation. Bleach Grade is only a cool tint, not the Bleach Bypass Creative FX. No scene/content detection or adaptive preset values.

        Selection replaces the entire ColorGrading value, creating one existing history transaction. Equality recognizes Preset/Custom and returning exact values restores the label. Documents persist settings, not preset IDs; future definition changes cannot change saved pixels. Copying a document copies value settings. Local masked grading uses the existing compositor. No Auto, Light, Color, Curves, manual Grading renderer, Creative FX or pipeline change.

        ## UI and thumbnails

        Neutral remains directly accessible; horizontal bordered capsules grouped Portrait/Cinema/Atmosphere/Special keep names readable. Selected state has a checkmark and accessibility selected trait. Buttons have >=44pt content height; wheels and all numeric controls remain editable below. No thumbnail gallery was added: thumbnail generation, thumbnail cache, cold/warm thumbnail timings and thumbnail/full-render comparisons are **not applicable**. There is no preview/CIImage cache in the selector. Rendering uses existing generation/cancellation guards and source/LUT cache. Compact/large UI, Undo/Redo and rapid selection verification are recorded separately in verification.md.

        ## HDR and luminance policy

        The unchanged manual Grading lives in a 32³ perceptual SDR LUT. Neutral uses identity bypass. Activating a nonneutral Grading can clamp extended values to the existing SDR domain; each affected preset receives a documented HDR quality WARN. This is not a new preset clamp. Finite values and continuous transition through 1 are hard checks. Encoded weighted RGB luminance preservation does **not** guarantee linear photometric luminance preservation, so both linear mean/max deltas are measured. Gray ramp RGB separation and clipping are in checks.json; hue/linear luminance/chroma/gamut changes for named-order color patches are in color_patch_metrics.md. Hue of near-neutral patches is diagnostic only.

        ## Exact preset parameters / nearest neighbors

        \(parameters)
        Full pairwise parameter, gray and corpus distances: [preset_distances.md](ColorGradingPresets/preset_distances.md). Numeric similarity is not an aesthetic score. No preset is strengthened, merged or removed from these results.

        ## Synthetic / manual reproduction

        \(manualRows)
        Preset and manual settings use exactly the same graph; timing differences reflect cache/warmup, not intrinsic preset overhead. Neutral is compared pixel-for-pixel with untouched input. Persistence, determinism, valid ranges, full switching, Custom restoration and all-pair replacement are hard tests. Balance/Blending artifacts show existing continuous transitions; tonal_contribution_map uses the real weight primitive. Global/Amount tests are not applicable.

        ## Photographic results

        \(photoTable)
        ## Skin Tone Inspection / White Preservation / Shadow Coloration / Highlight Coloration

        Fixed manually specified crop coordinates, no skin detector. A crop can contain other materials; these are inspection triggers, not universal skin hue scores. Both portraits and white subject use identical preset settings. Regional Δchroma >.025 or RGB MAE >.04 triggers skin inspection; white Δchroma >.025, dark region >.015, highlight >.03 are conservative review thresholds. No numeric PASS establishes aesthetic quality. Inspect lamp/sun/dress/reflections and both skin types together.

        \(roiTable)
        ## Families

        Portrait: Soft/Warm/Cool Portrait — restrained tonal warmth or cool opposition, inspect portrait_presets and skin crops. Cinematic: Cinematic/Teal & Warm/Cool Cinema/Warm Cinema/Muted Cinema — different shadow hues, amplitudes and overlap, inspect cinematic_presets and split_family_comparison. Atmosphere: Golden Hour/Blue Hour/Moody/Pastel/Autumn — golden highlights, cool dusk, teal shadows, light pastel separation and earthy warm midtones; inspect atmosphere_presets plus warm/cool comparisons. Special: Bleach Grade/Split Warm/Cool — restrained cool finish or stronger didactic tonal separation. No ranking of presets. Golden Hour includes already-warm backlight/fine texture; Blue Hour includes landscape/night/white subject. Final quality judgment remains manual.

        ## Auto / Creative FX / preview / export

        Auto+grading and workflow sheets use one existing Auto proposal; preset selection only replaces Grading, and reapplying Auto preserves it. Creative interactions use actual grading→Creative order; downstream Silver B&W removes chroma as expected. Six representative presets compare interactive/HQ/export at common 256px, standard .015 MAE inspection tolerance. Settings and renderer are shared, with no preset-specific export branch.

        ## Performance and memory

        \(performanceRows)
        RSS samples after each 16-selection batch: \(memory). Four source photos / 64 preset selections. Cache/memory tests use the existing engine; no preset thumbnail cache. Warm memory growth >64MiB is a quality warning, not proof of a leak. Physical-device performance is not measured.

        ## Build / UI / non-regression

        \((try? String(contentsOf:lab.artifacts.url(root+"verification.md"),encoding:.utf8)) ?? "Verification still pending; update after build/UI/regression runs.")

        ## PASS / WARN / FAIL details

        """
        for c in lab.cases {
            text += "### \(c.name) — \(c.status)\n\n"
            for check in c.checks {text += "- **\(check.status)** [\(check.hard ? "hard invariant":"quality heuristic")] \(check.name): \(check.detail)\n"}
            text += "\nMetrics: \(c.metrics)\nInspect: \(c.images.joined(separator:", "))\n\n"
        }
        text += "## Priority Visual Inspection\n\n"+priority.map{"- [\($0).png](ColorGradingPresets/\($0).png)"}.joined(separator:"\n")
        text += "\n\nInitial campaign: [initial_results.json](ColorGradingPresets/ValidationHistory/initial_results.json). Stop after technical validation; photographic inspection required before any tuning.\n"
        try helper.save(text,"ColorGradingPresetsValidationReport.md")
    }
}
