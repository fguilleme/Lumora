import CoreGraphics
import CoreImage
import Foundation
import Testing
import Vision
@testable import LumoraCore

@Test func beautyPhotographicValidation() throws {
    let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
    let root = URL(fileURLWithPath: ProcessInfo.processInfo.environment["LUMORA_VISUAL_OUTPUT"]
        ?? repo.appendingPathComponent("TestArtifacts").path)
    let gpu = try LabGPU()
    let artifacts = LabArtifacts(root: root, gpu: gpu)
    let document = try JSONDecoder().decode(BeautyCorpus.self,
        from: Data(contentsOf: repo.appendingPathComponent("BeautyValidation/corpus.json")))
    #expect(document.schema == 1)
    #expect(document.cases.count == 12)
    var overview: [(String, CIImage)] = []
    var aestheticOverview: [(String, CIImage)] = []
    var aestheticCrops: [(String, CIImage)] = []
    var maskOverview: [(String, CIImage)] = []
    var skinComparison: [(String, CIImage)] = []
    var skinCoverageRows: [(String, Double, Double, Double, Double, Double)] = []
    var report = """
    # Beauty V1 — dedicated photographic corpus

    Renderer: production `BeautyRenderer`; working space: extended-linear sRGB float.
    Face analysis: Vision on at most 1024-pixel sRGB preview. Sources are framed by the fixed, normalized rectangles in `BeautyValidation/corpus.json`; no pixels are retouched or resampled during corpus preparation. All 320×320 crops use the source's native pixels at 100%, without enlargement. Auto Stress portraits are excluded from photographic quality validation.
    No golden masters. These diagnostics require human inspection before any aesthetic tuning; MAE is a change magnitude, not a quality score.

    | Case | Framed px | Vision face width | Faces | Natural MAE | Portrait MAE | Beauty MAE | Non-finite | Vision+mask ms | GPU render ms (3 presets) |
    |---|---:|---:|---:|---:|---:|---:|---:|---:|---:|

    """
    var warnings: [String] = []
    var stageRows: [(String, BeautyAnalysisTimings, Double, Double, Double, Double)] = []
    for entry in document.cases {
        let file = repo.appendingPathComponent("BeautyValidation").appendingPathComponent(entry.source)
        guard var input = CIImage(contentsOf: file, options: [.applyOrientationProperty: true]) else {
            throw PhotoError.unreadable
        }
        input = input.transformed(by: CGAffineTransform(translationX: -input.extent.minX,
                                                        y: -input.extent.minY))
        guard entry.frame.count == 4 else { throw PhotoError.unreadable }
        let frame = CGRect(x: entry.frame[0] * input.extent.width,
                           y: entry.frame[1] * input.extent.height,
                           width: entry.frame[2] * input.extent.width,
                           height: entry.frame[3] * input.extent.height).integral.intersection(input.extent)
        input = input.cropped(to: frame).transformed(by:
            CGAffineTransform(translationX: -frame.minX, y: -frame.minY))
        let ciToCGStart = ContinuousClock.now
        guard let color = CGColorSpace(name: CGColorSpace.sRGB),
              let bitmap = gpu.context.createCGImage(input, from: input.extent.integral,
                                                     format: .RGBA8, colorSpace: color)
        else { throw PhotoError.renderFailed }
        let ciToCGMS = milliseconds(ciToCGStart.duration(to: .now))
        let analysisStart = ContinuousClock.now
        var stageTiming = BeautyAnalysisTimings()
        var skinDiagnostic: BeautyMaskDiagnostics?
        let masks = try BeautyFaceAnalysis.analyze(bitmap,
            timing: { stageTiming = $0 }, diagnostics: { skinDiagnostic = $0 })
        let visionMS = milliseconds(analysisStart.duration(to: .now))
        // Warm isolated Vision probes split face detection from landmarks.
        // Production still uses the single combined request measured above.
        let visionHandler = VNImageRequestHandler(cgImage: bitmap, options: [:])
        let faceRequest = VNDetectFaceRectanglesRequest()
        let faceStart = ContinuousClock.now
        try visionHandler.perform([faceRequest])
        let faceMS = milliseconds(faceStart.duration(to: .now))
        let landmarkRequest = VNDetectFaceLandmarksRequest()
        landmarkRequest.inputFaceObservations = faceRequest.results
        let landmarkStart = ContinuousClock.now
        try visionHandler.perform([landmarkRequest])
        let landmarkMS = milliseconds(landmarkStart.duration(to: .now))
        stageRows.append((entry.id, stageTiming, visionMS, ciToCGMS, faceMS, landmarkMS))
        let title = entry.id
        var variants: [(String, CIImage)] = [("Original", input)]
        var differences: [Double] = []
        var invalid = 0
        var renderMS = 0.0
        for preset in BeautyPreset.allCases {
            let renderStart = ContinuousClock.now
            let result = try BeautyRenderer.apply(input, settings: preset.settings, masks: masks)
            guard gpu.context.createCGImage(result, from: result.extent,
                                            format: .RGBAh, colorSpace: gpu.linear) != nil
            else { throw PhotoError.renderFailed }
            renderMS += milliseconds(renderStart.duration(to: .now))
            let metricScale = min(1, 512 / max(input.extent.width, input.extent.height))
            let measured = gpu.compare(input.transformed(by: CGAffineTransform(scaleX: metricScale, y: metricScale)),
                                       result.transformed(by: CGAffineTransform(scaleX: metricScale, y: metricScale)))
            differences.append(measured.mae)
            invalid += measured.nonFinite
            variants.append((preset.rawValue.capitalized, result))
        }
        try artifacts.sheet(variants, "BeautyValidation/\(title)/comparison.png", cell: 512, maxColumns: 4)
        overview += variants.map { ("\(title) / \($0.0)", $0.1) }
        aestheticOverview += variants.map { ("\(title) / \($0.0)", $0.1) }
        let aestheticRegion: String? = switch title {
        case "01_light_skin_pores", "02_dark_skin_texture": "skin"
        case "03_acne_redness": "blemishes"
        case "04_strong_freckles": "blemishes"
        case "05_older_wrinkles": "forehead"
        case "06_beard_moustache": "chin"
        case "07_glasses": "eyes"
        case "08_open_smile_teeth": "teeth"
        case "09_pronounced_dark_circles": "under_eyes"
        case "10_detailed_eyes": "eyes"
        default: nil
        }
        if let aestheticRegion {
            let rect = beautyNativeCrop(region: aestheticRegion,
                                        face: masks.faceRects.first,
                                        extent: input.extent, caseID: title)
            aestheticCrops += variants.map {
                ("\(title) / \($0.0)", $0.1.cropped(to: rect))
            }
        }
        let maskItems: [(String, CIImage)] = [("Source", input)] + [
            ("Skin", masks.skin), ("Eyes", masks.eyes),
            ("Under-eyes", masks.underEyes), ("Teeth", masks.teeth),
            ("Blemishes", masks.blemishes)
        ].compactMap { item in item.1.map { (item.0, CIImage(cgImage: $0)) } }
        try artifacts.sheet(maskItems, "BeautyValidation/\(title)/masks.png", cell: 384, maxColumns: 3)
        maskOverview += maskItems.map { ("\(title) / \($0.0)", $0.1) }
        if let old = CIImage(contentsOf: repo.appendingPathComponent(
                "BeautyValidation/Results/BaselineSkinMasks/\(title).png")),
           let raw = skinDiagnostic?.skinBeforeDetailProtection,
           let effective = masks.skin {
            if let protection = skinDiagnostic?.detailProtection {
                try artifacts.sheet([("Source", input),
                    ("Detail protection", CIImage(cgImage: protection))],
                    "BeautyValidation/\(title)/detail_protection.png",
                    cell: 384, maxColumns: 2)
            }
            let effectiveImage = beautyMaskAtSourceSize(effective, extent: input.extent)
            skinComparison += [
                ("\(title) / Old Skin Mask", old),
                ("\(title) / New Skin Mask", CIImage(cgImage: raw)),
                ("\(title) / Effective Skin Mask", CIImage(cgImage: effective)),
                ("\(title) / Overlay", beautyMaskOverlay(input: input,
                    mask: effectiveImage, rect: input.extent))
            ]
            let oldArea = beautyMaskWeightedArea(old, context: gpu.context)
            let rawArea = beautyMaskWeightedArea(CIImage(cgImage: raw), context: gpu.context)
            let effectiveArea = beautyMaskWeightedArea(CIImage(cgImage: effective),
                                                      context: gpu.context)
            let imageArea = Double(effective.width * effective.height)
            let faceArea = masks.faceRects.reduce(0.0) { $0 + Double($1.width * $1.height) }
            skinCoverageRows.append((title, oldArea / imageArea,
                rawArea / imageArea, effectiveArea / imageArea,
                effectiveArea / max(1, faceArea * imageArea),
                1 - effectiveArea / max(1, rawArea)))
        }
        if let skinMask = masks.skin {
            let fullSizeMask = beautyMaskAtSourceSize(skinMask, extent: input.extent)
            for region in ["cheek", "forehead", "chin"] {
                let rect = beautyNativeCrop(region: region, face: masks.faceRects.first,
                                            extent: input.extent, caseID: title)
                try artifacts.sheet([("Original", input.cropped(to: rect)),
                                     ("Skin mask", fullSizeMask.cropped(to: rect)),
                                     ("Overlay", beautyMaskOverlay(input: input,
                                         mask: fullSizeMask, rect: rect))],
                    "BeautyValidation/\(title)/Skin/\(region)_100pct.png",
                    nativeCrop: true, cell: 320, maxColumns: 3)
            }
        }
        for (name, mask, region) in [("teeth", masks.teeth, "teeth"),
                                     ("eyes", masks.eyes, "eyes")] {
            guard let mask else { continue }
            let rect = beautyNativeCrop(region: region, face: masks.faceRects.first,
                                        extent: input.extent, caseID: title)
            try artifacts.sheet([("Original", input.cropped(to: rect)),
                                 ("\(name) mask", beautyMaskAtSourceSize(mask, extent: input.extent)
                                    .cropped(to: rect))],
                "BeautyValidation/\(title)/Crops/\(name)_mask_100pct.png",
                nativeCrop: true, cell: 320, maxColumns: 2)
        }
        for region in ["skin", "eyes", "under_eyes", "teeth", "blemishes"] {
            let rect = beautyNativeCrop(region: region, face: masks.faceRects.first,
                                        extent: input.extent, caseID: title)
            try artifacts.sheet(variants.map { ($0.0, $0.1.cropped(to: rect)) },
                "BeautyValidation/\(title)/Crops/\(region)_100pct.png",
                nativeCrop: true, cell: 320, maxColumns: 4)
        }
        report += String(format: "| %@ | %d×%d | %.1f%% | %d | %.5f | %.5f | %.5f | %d | %.1f | %.1f |\n",
            title, Int(input.extent.width), Int(input.extent.height), Double(masks.faceWidthFraction) * 100,
            masks.faceCount, differences[0], differences[1], differences[2], invalid, visionMS, renderMS)
        #expect(invalid == 0, "\(title): non-finite pixels")
        if masks.faceCount == 0 {
            warnings.append("\(title): Vision found no reliable landmark face; preset outputs are expected to remain identical. Inspect masks and crops.")
        } else if !(0.40...0.60).contains(Double(masks.faceWidthFraction)) {
            warnings.append(String(format: "%@: Vision face width %.1f%% falls outside the approximate 40–60%% framing target.",
                                   title, Double(masks.faceWidthFraction) * 100))
        }
    }
    try artifacts.sheet(overview, "BeautyValidation/contact_sheet.png", cell: 384, maxColumns: 4)
    #expect(aestheticOverview.count == 48)
    #expect(aestheticCrops.count == 40)
    try artifacts.sheet(aestheticOverview, "BeautyValidation/aesthetic_contact_sheet.png",
                        cell: 384, maxColumns: 4)
    try artifacts.sheet(aestheticCrops, "BeautyValidation/aesthetic_crops_100pct.png",
                        nativeCrop: true, cell: 320, maxColumns: 4)
    try artifacts.sheet(maskOverview, "BeautyValidation/all_masks_contact_sheet.png",
                        cell: 256, maxColumns: 6)
    #expect(skinComparison.count == 48, "Old/new/effective/overlay for all 12 cases")
    try artifacts.sheet(skinComparison, "BeautyValidation/skin_mask_before_after.png",
                        cell: 300, maxColumns: 4)
    report += """

    ## Per-stage analysis timings (ms)

    The production Vision request combines face detection and landmarks. Isolated warm probes split them without changing the production request. CI→CG is test-harness image preparation; geometry, exclusions, skin, detail and blemishes are measured in the new vector/Core Image pipeline. Skin and final composition include GPU materialization of cached masks. The diagnostic unprotected/protection masks add overhead only when requested by this test. Stage and total times are wall times but run-to-run frequency/cache variation remains.

    | Case | CI→CG | Bitmap prep | Vision combined | Face probe | Landmarks probe | Geometry/cheek | Face raster | Feature exclusions | Detail prep | Skin raster/compose | Final masks | Blemishes | Analysis total |
    |---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|

    """
    for (name, stage, total, ciToCG, face, landmarks) in stageRows {
        report += String(format: "| %@ | %.1f | %.1f | %.1f | %.1f | %.1f | %.1f | %.1f | %.1f | %.1f | %.1f | %.1f | %.1f | %.1f |\n",
                         name, ciToCG, stage.imagePreparationMS,
                         stage.visionFaceAndLandmarksMS, face, landmarks,
                         stage.geometryAndColorSamplingMS, stage.geometryRasterMS,
                         stage.featureExclusionsMS, stage.detailPreparationMS,
                         stage.skinRasterMS, stage.finalMaskCompositionMS,
                         stage.blemishesMS, total)
    }
    report += """

    | Case | Old mask area % image | New mask area % image | Effective area % image | Effective area / face area | Detail-protected fraction |
    |---|---:|---:|---:|---:|---:|

    """
    for (name, old, raw, effective, relative, protected) in skinCoverageRows {
        report += String(format: "| %@ | %.1f | %.1f | %.1f | %.2f | %.1f%% |\n",
                         name, old * 100, raw * 100, effective * 100,
                         relative, protected * 100)
    }
    // The source file is 1536 pixels wide; larger timings deliberately upscale
    // the same pixels so only the rendering cost changes, not the face identity.
    let speedFile = repo.appendingPathComponent("VisualTestAssets/01_portrait_light_skin.png")
    guard let speedInput = CIImage(contentsOf: speedFile),
          let color = CGColorSpace(name: CGColorSpace.sRGB),
          let faceBitmap = gpu.context.createCGImage(speedInput, from: speedInput.extent,
                                                    format: .RGBA8, colorSpace: color)
    else { throw PhotoError.renderFailed }
    let speedMasks = try BeautyFaceAnalysis.analyze(faceBitmap)
    report += "\n## GPU render by resolution (Portrait preset)\n\n| Long side | GPU materialization ms |\n|---:|---:|\n"
    var previewOutput: CIImage?
    var hqOutput: CIImage?
    for dimension in [1_024, 2_048, 4_096] {
        let factor = CGFloat(dimension) / max(speedInput.extent.width, speedInput.extent.height)
        let image = speedInput.transformed(by: CGAffineTransform(scaleX: factor, y: factor))
        let start = ContinuousClock.now
        let output = try BeautyRenderer.apply(image, settings: BeautyPreset.portrait.settings,
                                              masks: speedMasks)
        guard gpu.context.createCGImage(output, from: output.extent.integral,
                                        format: .RGBAh, colorSpace: gpu.linear) != nil
        else { throw PhotoError.renderFailed }
        report += String(format: "| %d | %.1f |\n", dimension,
                         milliseconds(start.duration(to: .now)))
        if dimension == 1_024 { previewOutput = output }
        if dimension == 2_048 { hqOutput = output }
    }
    if let previewOutput, let hqOutput {
        let normalizedHQ = hqOutput.transformed(by: CGAffineTransform(scaleX: 0.5, y: 0.5))
            .cropped(to: previewOutput.extent)
        let comparison = gpu.compare(previewOutput, normalizedHQ)
        report += String(format: "\nPreview/HQ normalized MAE: %.6f; non-finite: %d. " +
                         "This includes input resampling differences and is a quality diagnostic.\n",
                         comparison.mae, comparison.nonFinite)
        #expect(comparison.nonFinite == 0)
    }
    report += "\n## Corpus and quality status\n\nTwelve dedicated photographs are used; the source links, authors, licenses and fixed framing rectangles are recorded in `BeautyValidation/corpus.json`. The mask sheet and five native 100% crop sheets are generated for every case. All feature labels describe visible photographic content, not verified camera-original status.\n\n"
    report += warnings.isEmpty ? "No automated framing/detection warnings.\n" :
        "### WARN requiring human inspection\n\n" + warnings.map { "- " + $0 }.joined(separator: "\n") + "\n"
    report += """

    **PASS technical:** finite renders above; neutral identity, HDR reconstruction, no-face identity and persistence remain covered by `BeautyTests`.

    **Quality assessment:** compare `BeautyValidation/skin_mask_before_after.png` and each 100% skin sheet. The new contour extends forehead, cheeks and chin and reduces local detail weight, but residual leakage near hair, beard or glasses remains a visual WARN. Mask area is descriptive, not an accuracy score. Teeth/profile/coordinate fixes from the prior targeted pass remain in place. No renderer intensity or Beauty preset was retuned.

    **Priority:** `BeautyValidation/skin_mask_before_after.png`, `BeautyValidation/all_masks_contact_sheet.png`, `BeautyValidation/02_dark_skin_texture/Skin/forehead_diagnostic.png`, then the per-case Skin/cheek, forehead and chin 100% sheets.
    """
    try report.write(to: root.appendingPathComponent("BeautyValidationReport.md"),
                     atomically: true, encoding: .utf8)
}

private struct BeautyCorpus: Decodable {
    let schema: Int
    let cases: [BeautyCorpusEntry]
}

@Test func beautyForeheadMaskDiagnostic() throws {
    let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
    let document = try JSONDecoder().decode(BeautyCorpus.self,
        from: Data(contentsOf: repo.appendingPathComponent("BeautyValidation/corpus.json")))
    let entry = try #require(document.cases.first { $0.id == "02_dark_skin_texture" })
    var input = try #require(CIImage(contentsOf: repo.appendingPathComponent("BeautyValidation")
        .appendingPathComponent(entry.source), options: [.applyOrientationProperty: true]))
    input = input.transformed(by: CGAffineTransform(translationX: -input.extent.minX,
                                                    y: -input.extent.minY))
    let frame = CGRect(x: entry.frame[0] * input.extent.width,
                       y: entry.frame[1] * input.extent.height,
                       width: entry.frame[2] * input.extent.width,
                       height: entry.frame[3] * input.extent.height).integral.intersection(input.extent)
    input = input.cropped(to: frame).transformed(by:
        CGAffineTransform(translationX: -frame.minX, y: -frame.minY))
    let gpu = try LabGPU()
    let bitmap = try #require(gpu.context.createCGImage(input, from: input.extent.integral,
        format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!))
    var diagnostic: BeautyMaskDiagnostics?
    let masks = try BeautyFaceAnalysis.analyze(bitmap, diagnostics: { diagnostic = $0 })
    let raw = try #require(diagnostic?.skinBeforeDetailProtection)
    let effective = try #require(masks.skin)
    let protection = try #require(diagnostic?.detailProtection)
    let region = try #require(diagnostic?.faceRegion)
    let exclusions = try #require(diagnostic?.featureExclusions)
    let rect = beautyNativeCrop(region: "forehead", face: masks.faceRects.first,
                                extent: input.extent, caseID: entry.id)
    let artifacts = LabArtifacts(root: repo.appendingPathComponent("TestArtifacts"), gpu: gpu)
    try artifacts.sheet([("Source", input.cropped(to: rect)),
        ("Face region", beautyMaskAtSourceSize(region, extent: input.extent).cropped(to: rect)),
        ("Exclusions", beautyMaskAtSourceSize(exclusions, extent: input.extent).cropped(to: rect)),
        ("Before detail", beautyMaskAtSourceSize(raw, extent: input.extent).cropped(to: rect)),
        ("Protection", beautyMaskAtSourceSize(protection, extent: input.extent).cropped(to: rect)),
        ("Effective", beautyMaskAtSourceSize(effective, extent: input.extent).cropped(to: rect))],
        "BeautyValidation/02_dark_skin_texture/Skin/forehead_diagnostic.png",
        nativeCrop: true, cell: 320, maxColumns: 6)
}

private struct BeautyCorpusEntry: Decodable {
    let id: String
    let source: String
    let frame: [CGFloat]
}

private func beautyNativeCrop(region: String, face: CGRect?, extent: CGRect,
                              caseID: String) -> CGRect {
    let f = face ?? CGRect(x: 0.25, y: 0.2, width: 0.5, height: 0.6)
    let x: CGFloat
    let y: CGFloat
    switch region {
    case "cheek": x = f.minX + f.width * 0.30; y = f.minY + f.height * 0.45
    case "forehead": x = f.midX; y = f.minY + f.height * 0.83
    case "chin": x = f.midX; y = f.minY + f.height * 0.19
    case "skin": x = f.minX + f.width * 0.31; y = f.minY + f.height * 0.45
    case "eyes": x = f.midX; y = f.minY + f.height * 0.68
    case "under_eyes": x = f.midX; y = f.minY + f.height * 0.63
    case "teeth": x = f.midX; y = f.minY + f.height * 0.25
    case "blemishes" where caseID == "04_strong_freckles":
        x = f.minX + f.width * 0.40; y = f.minY + f.height * 0.82
    default:
        x = f.minX + f.width * (caseID == "03_acne_redness" ? 0.68 : 0.33)
        y = f.minY + f.height * 0.40
    }
    let side: CGFloat = 320
    return CGRect(x: min(max(extent.minX, x * extent.width - side / 2), extent.maxX - side),
                  y: min(max(extent.minY, y * extent.height - side / 2), extent.maxY - side),
                  width: side, height: side).integral
}

private func beautyMaskAtSourceSize(_ mask: CGImage, extent: CGRect) -> CIImage {
    CIImage(cgImage: mask).transformed(by: CGAffineTransform(
        scaleX: extent.width / CGFloat(mask.width), y: extent.height / CGFloat(mask.height)))
}

private func beautyMaskOverlay(input: CIImage, mask: CIImage, rect: CGRect) -> CIImage {
    let tint = CIImage(color: CIColor(red: 1, green: 0.05, blue: 0.03, alpha: 0.55))
        .cropped(to: rect)
        .applyingFilter("CIBlendWithMask", parameters: [
            kCIInputBackgroundImageKey: CIImage(color: .clear).cropped(to: rect),
            kCIInputMaskImageKey: mask.cropped(to: rect)
        ])
    return tint.applyingFilter("CISourceOverCompositing", parameters: [
        kCIInputBackgroundImageKey: input.cropped(to: rect)
    ])
}

@Test func beautyMaskCoordinatesMatchSource() throws {
    let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
    let document = try JSONDecoder().decode(BeautyCorpus.self,
        from: Data(contentsOf: repo.appendingPathComponent("BeautyValidation/corpus.json")))
    let context = CIContext()
    let artifacts = LabArtifacts(root: repo.appendingPathComponent("TestArtifacts"), gpu: try LabGPU())
    for (id, region) in [("08_open_smile_teeth", "teeth"),
                         ("12_profile_face", "eyes")] {
        let entry = try #require(document.cases.first { $0.id == id })
        var input = try #require(CIImage(contentsOf: repo.appendingPathComponent("BeautyValidation")
            .appendingPathComponent(entry.source), options: [.applyOrientationProperty: true]))
        input = input.transformed(by: CGAffineTransform(translationX: -input.extent.minX,
                                                        y: -input.extent.minY))
        let frame = CGRect(x: entry.frame[0] * input.extent.width,
                           y: entry.frame[1] * input.extent.height,
                           width: entry.frame[2] * input.extent.width,
                           height: entry.frame[3] * input.extent.height).integral
        input = input.cropped(to: frame).transformed(by:
            CGAffineTransform(translationX: -frame.minX, y: -frame.minY))
        let bitmap = try #require(context.createCGImage(input, from: input.extent.integral,
            format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!))
        let masks = try BeautyFaceAnalysis.analyze(bitmap)
        let mask = try #require(region == "teeth" ? masks.teeth : masks.eyes)
        #expect(mask.colorSpace?.name == CGColorSpace.linearGray as CFString,
                "Beauty masks must retain linear weights for the renderer")
        let rect = beautyNativeCrop(region: region, face: masks.faceRects.first,
                                    extent: input.extent, caseID: id)
        let mirrored = CGRect(x: rect.minX, y: input.extent.height - rect.maxY,
                              width: rect.width, height: rect.height)
        let full = beautyMaskAtSourceSize(mask, extent: input.extent)
        try artifacts.sheet([("Original", input.cropped(to: rect)),
                             ("\(region) mask", full.cropped(to: rect))],
                            "BeautyValidation/\(id)/Crops/\(region)_mask_100pct.png",
                            nativeCrop: true, cell: 320, maxColumns: 2)
        let overlay = beautyMaskOverlay(input: input, mask: full, rect: rect)
        try artifacts.sheet([("Original", input.cropped(to: rect)), ("Mask overlay", overlay)],
                            "BeautyValidation/\(id)/Crops/\(region)_overlay_100pct.png",
                            nativeCrop: true, cell: 320, maxColumns: 2)
        let actual = beautyMaskEnergy(full, in: rect, context: context)
        let opposite = beautyMaskEnergy(full, in: mirrored, context: context)
        print("Beauty mask alignment \(id): source region \(actual), vertically mirrored \(opposite)")
        #expect(actual > opposite * 4, "\(id): mask must align with its source region")
        if id == "12_profile_face" {
            let components = beautyMaskComponents(mask)
            print("Beauty profile eye components: \(components)")
            #expect(components == 1, "A profile must use only the visible eye region")
        } else {
            let highSaturationFraction = beautySelectedHighSaturationFraction(
                source: bitmap, mask: mask)
            print("Beauty teeth mask selected high-saturation fraction: \(highSaturationFraction)")
            #expect(highSaturationFraction < 0.05,
                    "The teeth mask must exclude saturated lips and gums")
        }
    }
}

private func beautyMaskComponents(_ image: CGImage) -> Int {
    guard let source = MaskBitmapSource(image: image, maximumDimension: 1_024) else { return 0 }
    let width = source.width, height = source.height
    var visited = [Bool](repeating: false, count: width * height)
    var count = 0
    for y in 0..<height {
        for x in 0..<width {
            let start = y * width + x
            if visited[start] || source.rgb(x: x, y: y).red < 0.5 { continue }
            count += 1
            var queue = [start]
            visited[start] = true
            var index = 0
            while index < queue.count {
                let point = queue[index]; index += 1
                let px = point % width, py = point / width
                for (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1)] {
                    let nx = px + dx, ny = py + dy
                    guard nx >= 0, nx < width, ny >= 0, ny < height else { continue }
                    let neighbor = ny * width + nx
                    if !visited[neighbor], source.rgb(x: nx, y: ny).red >= 0.5 {
                        visited[neighbor] = true
                        queue.append(neighbor)
                    }
                }
            }
        }
    }
    return count
}

private func beautySelectedHighSaturationFraction(source image: CGImage,
                                                   mask: CGImage) -> Double {
    guard let source = MaskBitmapSource(image: image, maximumDimension: 1_024),
          let matte = MaskBitmapSource(image: mask, maximumDimension: 1_024),
          source.width == matte.width, source.height == matte.height else { return 1 }
    var selected = 0, saturated = 0
    for y in 0..<source.height {
        for x in 0..<source.width where matte.rgb(x: x, y: y).red >= 0.5 {
            selected += 1
            let (r, g, b) = source.rgb(x: x, y: y)
            let peak = max(r, max(g, b))
            if peak > 0.001, (peak - min(r, min(g, b))) / peak > 0.38 {
                saturated += 1
            }
        }
    }
    return Double(saturated) / Double(max(1, selected))
}

private func beautyMaskEnergy(_ image: CIImage, in rect: CGRect, context: CIContext) -> Int {
    let width = Int(rect.width), height = Int(rect.height)
    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    pixels.withUnsafeMutableBytes { bytes in
        context.render(image, toBitmap: bytes.baseAddress!, rowBytes: width * 4,
                       bounds: rect, format: .RGBA8,
                       colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!)
    }
    return stride(from: 0, to: pixels.count, by: 4).reduce(0) { $0 + Int(pixels[$1]) }
}

private func beautyMaskWeightedArea(_ image: CIImage, context: CIContext) -> Double {
    let rect = image.extent.integral
    let width = Int(rect.width), height = Int(rect.height)
    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    pixels.withUnsafeMutableBytes { bytes in
        context.render(image, toBitmap: bytes.baseAddress!, rowBytes: width * 4,
                       bounds: rect, format: .RGBA8,
                       colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!)
    }
    return Double(stride(from: 0, to: pixels.count, by: 4)
        .reduce(0) { $0 + Int(pixels[$1]) }) / 255
}

private func milliseconds(_ duration: Duration) -> Double {
    Double(duration.components.seconds) * 1_000 + Double(duration.components.attoseconds) / 1e15
}

@Test func beautyCropAndMirrorAnalysis() throws {
    let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
    let gpu = try LabGPU()
    guard let original = CIImage(contentsOf: repo.appendingPathComponent(
        "VisualTestAssets/01_portrait_light_skin.png")),
        let space = CGColorSpace(name: CGColorSpace.sRGB),
        let originalBitmap = gpu.context.createCGImage(original, from: original.extent,
                                                     format: .RGBA8, colorSpace: space)
    else { throw PhotoError.renderFailed }
    let faces = try BeautyFaceAnalysis.analyze(originalBitmap)
    let face = try #require(faces.faceRects.first)
    #expect(faces.faceCount == 1)
    let mirror = original.transformed(by: CGAffineTransform(scaleX: -1, y: 1))
        .transformed(by: CGAffineTransform(translationX: original.extent.width, y: 0))
    let mirroredBitmap = try #require(gpu.context.createCGImage(mirror, from: mirror.extent,
                                                          format: .RGBA8, colorSpace: space))
    #expect(try BeautyFaceAnalysis.analyze(mirroredBitmap).faceCount == 1)
    let rotated = original.transformed(by: CGAffineTransform(rotationAngle: .pi / 2))
        .transformed(by: CGAffineTransform(translationX: original.extent.height, y: 0))
    let rotatedBitmap = try #require(gpu.context.createCGImage(rotated, from: rotated.extent,
                                                         format: .RGBA8, colorSpace: space))
    #expect(try BeautyFaceAnalysis.analyze(rotatedBitmap).faceCount == 1)
    let faceRect = CGRect(x: max(0, (face.minX - 0.10) * original.extent.width),
                          y: max(0, (face.minY - 0.10) * original.extent.height),
                          width: min(original.extent.width, (face.width + 0.20) * original.extent.width),
                          height: min(original.extent.height, (face.height + 0.20) * original.extent.height))
        .intersection(original.extent)
    let cropped = original.cropped(to: faceRect)
        .transformed(by: CGAffineTransform(translationX: -faceRect.minX, y: -faceRect.minY))
    let cropBitmap = try #require(gpu.context.createCGImage(cropped, from: cropped.extent,
                                                      format: .RGBA8, colorSpace: space))
    #expect(try BeautyFaceAnalysis.analyze(cropBitmap).faceCount == 1)
}

@Test func beautyAnalysisCacheAndGeometryInvalidation() async throws {
    let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
    let url = repo.appendingPathComponent("VisualTestAssets/01_portrait_light_skin.png")
    let engine = RenderEngine()
    let state = EditState()
    let first = try await engine.beautyAnalysis(url: url, state: state)
    let firstSkin = try #require(first.skin)
    var sliderOnly = state
    sliderOnly.beauty = BeautyPreset.portrait.settings
    let reused = try await engine.beautyAnalysis(url: url, state: sliderOnly)
    let reusedSkin = try #require(reused.skin)
    #expect(reusedSkin === firstSkin)
    var mirrored = sliderOnly
    mirrored.geometry.flipHorizontal = true
    let rebuilt = try await engine.beautyAnalysis(url: url, state: mirrored)
    #expect(rebuilt.faceCount == first.faceCount)
    let rebuiltSkin = try #require(rebuilt.skin)
    #expect(rebuiltSkin !== firstSkin)
}
