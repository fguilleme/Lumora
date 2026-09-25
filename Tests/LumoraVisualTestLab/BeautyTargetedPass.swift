import CoreGraphics
import CoreImage
import Foundation
import Testing
@testable import LumoraCore

private struct TargetedCorpus: Decodable { let cases: [TargetedEntry] }
private struct TargetedEntry: Decodable {
    let id: String
    let source: String
    let frame: [CGFloat]
}

private func targetedInput(_ entry: TargetedEntry, repo: URL,
    base: String = "BeautyValidation") throws -> CIImage {
    let url = repo.appendingPathComponent(base).appendingPathComponent(entry.source)
    var input = try #require(CIImage(contentsOf: url, options: [.applyOrientationProperty: true]))
    input = input.transformed(by: CGAffineTransform(translationX: -input.extent.minX,
                                                     y: -input.extent.minY))
    let frame = CGRect(x: entry.frame[0] * input.extent.width,
                       y: entry.frame[1] * input.extent.height,
                       width: entry.frame[2] * input.extent.width,
                       height: entry.frame[3] * input.extent.height).integral.intersection(input.extent)
    return input.cropped(to: frame).transformed(by:
        CGAffineTransform(translationX: -frame.minX, y: -frame.minY))
}

@Test func beautyFinalTargetedValidation() throws {
    let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
    let root = repo.appendingPathComponent("BeautyValidation/FinalTargetedValidation")
    let artifacts = LabArtifacts(root: root.appendingPathComponent("Results"), gpu: try LabGPU())
    let gpu = artifacts.gpu
    let newCorpus = try JSONDecoder().decode(TargetedCorpus.self,
        from: Data(contentsOf: root.appendingPathComponent("corpus.json")))
    #expect(newCorpus.cases.count == 3)
    var metricRows = """
    # Final targeted Beauty diagnostics

    The three new cases are **synthetic**, generated expressly for this test.
    They have not been retouched after generation, but they cannot establish
    real-camera photographic performance. Crops are 320 native source pixels;
    no upscaling is used for sweep comparisons. Amount = 100; only Dark Circles
    varies. ΔY and Δchroma are measured within the cached under-eye matte.

    | Case | Face width % | Eye | Slider | Mask support % | RGB MAE | ΔY | Δchroma | Nonfinite |
    |---|---:|---|---:|---:|---:|---:|---:|---:|

    """
    var overview: [(String, CIImage)] = []
    for entry in newCorpus.cases {
        let input = try targetedInput(entry, repo: repo,
            base: "BeautyValidation/FinalTargetedValidation")
        let bitmap = try #require(gpu.context.createCGImage(input, from: input.extent.integral,
            format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!))
        let masks = try BeautyFaceAnalysis.analyze(bitmap)
        #expect(masks.faceCount == 1, "\(entry.id): one reliable face required")
        let f = try #require(masks.faceRects.first)
        let mask = try #require(masks.underEyes)
        let fullMask = finalScaleMask(mask, to: input.extent)
        let faceWidth = Double(masks.faceWidthFraction) * 100
        var fullVariants: [(String, CIImage)] = []
        for value in [0, 25, 50, 75, 100] {
            var state = BeautyState()
            state.darkCircles = Double(value)
            let output = try BeautyRenderer.apply(input, settings: state, masks: masks)
            fullVariants.append(("\(entry.id) / \(value)", output))
            overview.append(("\(entry.id) / \(value)", output))
        }
        try artifacts.sheet(fullVariants, "DarkCircles/\(entry.id)_full.png",
            cell: 384, maxColumns: 5)
        for (side, x) in [("left", 0.30), ("right", 0.70)] {
            let crop = finalFaceCrop(face: f, extent: input.extent,
                x: x, y: 0.65, side: 320)
            let before = gpu.read(input, crop)
            let matte = gpu.read(fullMask, crop)
            let crops = fullVariants.map { ("\(side) / \($0.0)", $0.1.cropped(to: crop)) }
            try artifacts.sheet(crops, "DarkCircles/\(entry.id)_\(side)_100pct.png",
                nativeCrop: true, cell: 320, maxColumns: 5)
            for (index, item) in fullVariants.enumerated() {
                let metric = targetedMetrics(before, gpu.read(item.1, crop), matte)
                metricRows += String(format:
                    "| %@ | %.1f | %@ | %d | %.2f | %.6f | %+.6f | %.6f | %d |\n",
                    entry.id, faceWidth, side, index * 25, metric.support * 100,
                    metric.mae, metric.deltaY, metric.deltaChroma, metric.nonFinite)
                #expect(metric.nonFinite == 0)
                if index == 0 { #expect(metric.mae == 0) }
            }
        }
        let maskItems: [(String, CIImage)] = [
            ("Source", input), ("Under-eye matte", CIImage(cgImage: mask)),
            ("Mask overlay", finalMaskOverlay(input: input, matte: fullMask))
        ]
        try artifacts.sheet(maskItems, "DarkCircles/\(entry.id)_mask.png",
            cell: 480, maxColumns: 3)
    }
    try artifacts.sheet(overview, "dark_circle_contact_sheet.png",
        cell: 384, maxColumns: 5)

    let oldCorpus = try JSONDecoder().decode(TargetedCorpus.self,
        from: Data(contentsOf: repo.appendingPathComponent("BeautyValidation/corpus.json")))
    for id in ["03_acne_redness", "04_strong_freckles"] {
        let entry = try #require(oldCorpus.cases.first { $0.id == id })
        let input = try targetedInput(entry, repo: repo)
        let bitmap = try #require(gpu.context.createCGImage(input, from: input.extent.integral,
            format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!))
        let masks = try BeautyFaceAnalysis.analyze(bitmap)
        let f = try #require(masks.faceRects.first)
        let newMask = try #require(masks.blemishes)
        let oldURL = repo.appendingPathComponent(
            "BeautyValidation/TargetedPass/Baseline/\(id)_old_matte_raw.png")
        let oldMask = try #require(CIImage(contentsOf: oldURL))
        let oldFull = finalScaleImageMask(oldMask, to: input.extent)
        let newFull = finalScaleMask(newMask, to: input.extent)
        let oldOverlay = finalMaskOverlay(input: input, matte: oldFull)
        let newOverlay = finalMaskOverlay(input: input, matte: newFull)
        var variants: [(String, CIImage)] = []
        for value in [0, 25, 50, 75, 100] {
            var state = BeautyState()
            state.blemishes = Double(value)
            variants.append(("\(id) / \(value)",
                try BeautyRenderer.apply(input, settings: state, masks: masks)))
        }
        for (region, x, y) in id == "03_acne_redness"
            ? [("cheek", 0.74, 0.54), ("chin", 0.52, 0.22)]
            : [("forehead", 0.52, 0.83), ("cheek", 0.72, 0.53)] {
            let crop = finalFaceCrop(face: f, extent: input.extent,
                x: x, y: y, side: 240)
            let enlarged: [(String, CIImage)] = [
                ("Source", input), ("Old matte", oldFull),
                ("Old overlay", oldOverlay), ("New matte", newFull),
                ("New overlay", newOverlay), ("100", variants[4].1)
            ].map { ($0.0, $0.1.cropped(to: crop).transformed(by:
                CGAffineTransform(scaleX: 2, y: 2))) }
            try artifacts.sheet(enlarged,
                "Imperfections/\(id)_\(region)_old_new_200pct.png",
                nativeCrop: true, cell: 480, maxColumns: 3)
            let sweep = variants.map { ($0.0, $0.1.cropped(to: crop)) }
            try artifacts.sheet(sweep,
                "Imperfections/\(id)_\(region)_sweep_100pct.png",
                nativeCrop: true, cell: 240, maxColumns: 5)
            let oldPixels = gpu.read(oldFull, crop)
            let newPixels = gpu.read(newFull, crop)
            let oldSupport = oldPixels.enumerated().filter { $0.offset % 4 == 0 && $0.element > 0.01 }.count
            let newSupport = newPixels.enumerated().filter { $0.offset % 4 == 0 && $0.element > 0.01 }.count
            metricRows += String(format:
                "\n%@/%@: old matte support %.2f%%, new matte support %.2f%% of native crop.\n",
                id, region, Double(oldSupport) / Double(oldPixels.count/4) * 100,
                Double(newSupport) / Double(newPixels.count/4) * 100)
        }
    }
    try metricRows.write(to: artifacts.url("final_targeted_metrics.md"),
        atomically: true, encoding: .utf8)
}

private func finalScaleMask(_ mask: CGImage, to extent: CGRect) -> CIImage {
    finalScaleImageMask(CIImage(cgImage: mask), to: extent)
}

private func finalScaleImageMask(_ mask: CIImage, to extent: CGRect) -> CIImage {
    mask.transformed(by: CGAffineTransform(scaleX: extent.width / mask.extent.width,
        y: extent.height / mask.extent.height)).cropped(to: extent)
}

private func finalMaskOverlay(input: CIImage, matte: CIImage) -> CIImage {
    let red = matte.applyingFilter("CIColorMatrix", parameters: [
        "inputRVector": CIVector(x: 1, y: 0, z: 0, w: 0),
        "inputGVector": CIVector(x: 0, y: 0, z: 0, w: 0),
        "inputBVector": CIVector(x: 0, y: 0, z: 0, w: 0),
        "inputAVector": CIVector(x: 0.85, y: 0, z: 0, w: 0)
    ])
    return red.applyingFilter("CISourceOverCompositing",
        parameters: [kCIInputBackgroundImageKey: input]).cropped(to: input.extent)
}

private func finalFaceCrop(face f: CGRect, extent: CGRect,
    x: CGFloat, y: CGFloat, side: CGFloat) -> CGRect {
    CGRect(x: min(max(extent.minX, (f.minX + f.width * x) * extent.width - side/2),
                  extent.maxX - side),
           y: min(max(extent.minY, (f.minY + f.height * y) * extent.height - side/2),
                  extent.maxY - side), width: side, height: side).integral
}

@Test func beautyBlemishStageDiagnostics() throws {
    let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
    let root = repo.appendingPathComponent("BeautyValidation/FinalBlemishPass")
    let phase = ProcessInfo.processInfo.environment["BEAUTY_BLEMISH_DIAGNOSTIC_PHASE"] ?? "CurrentDiagnostics"
    let artifacts = LabArtifacts(root: root.appendingPathComponent(phase), gpu: try LabGPU())
    let gpu = artifacts.gpu
    let corpus = try JSONDecoder().decode(TargetedCorpus.self,
        from: Data(contentsOf: repo.appendingPathComponent("BeautyValidation/corpus.json")))
    var componentRows = """
    # Blemish candidate components

    Coordinates are in the analysis bitmap (top-first). Every candidate
    component whose centroid falls inside a requested crop is included.

    | Photo | Crop | X | Y | Area | Compactness | Eccentricity | Red mean | Red max | Pigment | Local contrast | Nearby similar | Feature distance px | Seed mean | Red term | Shape term | Skin term | Pigment penalty | Repeat penalty | Feature penalty | Size penalty | Score | Reason |
    |---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|

    """
    for id in ["03_acne_redness", "04_strong_freckles"] {
        let entry = try #require(corpus.cases.first { $0.id == id })
        let input = try targetedInput(entry, repo: repo)
        let bitmap = try #require(gpu.context.createCGImage(input, from: input.extent.integral,
            format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!))
        var diagnostic: BeautyMaskDiagnostics?
        let masks = try BeautyFaceAnalysis.analyze(bitmap, diagnostics: { diagnostic = $0 })
        let stages = try #require(diagnostic?.blemishStages)
        let components = try #require(diagnostic?.blemishComponents)
        let analysisMask = try #require(masks.blemishes)
        let face = try #require(masks.faceRects.first)
        let regions: [(String, Double, Double)] = id == "03_acne_redness"
            ? [("cheek", 0.74, 0.54), ("chin", 0.52, 0.22)]
            : [("forehead", 0.52, 0.83), ("cheek", 0.72, 0.53)]
        for (name, x, y) in regions {
            let crop = finalFaceCrop(face: face, extent: input.extent,
                x: x, y: y, side: 240)
            if id == "03_acne_redness" && name == "chin" {
                let seeds = try #require(stages["accepted_seeds"])
                let grown = try #require(stages["grown_regions"])
                let seedValues = gpu.read(finalScaleMask(seeds, to: input.extent), crop)
                let grownValues = gpu.read(finalScaleMask(grown, to: input.extent), crop)
                #expect(seedValues.contains { $0 > 0.01 }, "chin needs an accepted seed")
                #expect(grownValues.contains { $0 > 0.01 }, "chin needs region growth")
            }
            for component in components {
                let sourceX = component.centerX * input.extent.width / Double(analysisMask.width)
                let sourceY = (Double(analysisMask.height - 1) - component.centerY)
                    * input.extent.height / Double(analysisMask.height)
                guard crop.contains(CGPoint(x: sourceX, y: sourceY)) else { continue }
                componentRows += String(format:
                    "| %@ | %@ | %.1f | %.1f | %d | %.3f | %.3f | %.5f | %.5f | %.3f | %.5f | %d | %.1f | %.3f | %.3f | %.3f | %.3f | %.3f | %.3f | %.3f | %.3f | %.3f | %@ |\n",
                    id, name, component.centerX, component.centerY,
                    component.area, component.compactness, component.eccentricity,
                    component.redOpponentMean, component.redOpponentMax,
                    component.pigmentationConfidence, component.localContrast,
                    component.nearbySimilarComponents, component.featureDistance,
                    component.inflammatorySeedMean, component.redContribution,
                    component.shapeContribution, component.skinContribution,
                    component.pigmentationPenalty, component.repetitionPenalty,
                    component.featurePenalty, component.sizePenalty,
                    component.acceptanceScore, component.reason)
            }
            var items: [(String, CIImage)] = [("Source", input)]
            for stage in ["skin_confidence", "inflammatory_seed_confidence",
                "pigmentation_freckle_confidence", "accepted_seeds",
                "grown_regions", "final_soft_matte", "blemish_skin_confidence",
                "raw_chroma_anomaly", "raw_dark_anomaly",
                "raw_light_anomaly", "multiscale_candidate", "edge_detail_protection",
                "repetition_suppression", "repeated_dark_density", "prethreshold_evidence",
                "final_confidence"] {
                if let image = stages[stage] {
                    items.append((stage, finalScaleMask(image, to: input.extent)))
                }
            }
            if let exclusion = diagnostic?.featureExclusions {
                items.append(("feature_exclusions", finalScaleMask(exclusion, to: input.extent)))
            }
            let enlarged = items.map { ($0.0,
                $0.1.cropped(to: crop).transformed(by: CGAffineTransform(scaleX: 2, y: 2))) }
            try artifacts.sheet(enlarged, "Stages/\(id)_\(name)_200pct.png",
                nativeCrop: true, cell: 480, maxColumns: 4)
            for (stage, image) in items.dropFirst() {
                let matte = image.cropped(to: crop)
                let overlay = finalMaskOverlay(input: input, matte: image)
                try artifacts.sheet([
                    ("Source", input.cropped(to: crop)),
                    (stage, matte), ("Overlay", overlay.cropped(to: crop))],
                    "Overlays/\(id)_\(name)_\(stage).png",
                    nativeCrop: true, cell: 240, maxColumns: 3)
            }
        }
    }
    try componentRows.write(to: artifacts.url("component_diagnostics.md"),
        atomically: true, encoding: .utf8)
}

@Test func beautyFinalBlemishValidation() throws {
    let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
    let root = repo.appendingPathComponent("BeautyValidation/FinalBlemishPass")
    let artifacts = LabArtifacts(root: root.appendingPathComponent("ComponentAcceptanceFix"), gpu: try LabGPU())
    let gpu = artifacts.gpu
    let corpus = try JSONDecoder().decode(TargetedCorpus.self,
        from: Data(contentsOf: repo.appendingPathComponent("BeautyValidation/corpus.json")))
    var table = """
    # Final blemish detector — descriptive measurements

    ROI values are native source pixels. Selected-area fraction uses final
    matte > 0.01. RGB MAE compares value 100 against value 0 over the entire
    ROI, including unselected pixels. These numbers are not a quality score.

    | Photo | Region | Mean confidence | P95 confidence | Selected area % | RGB MAE at 100 | Nonfinite |
    |---|---|---:|---:|---:|---:|---:|

    """
    var sweepTable = """
    # Blemish amount progression

    Mean RGB absolute difference from Original in the native ROI. The five
    amounts are evaluated with every other Beauty control at zero.

    | Photo | Region | 0 | 25 | 50 | 75 | 100 |
    |---|---|---:|---:|---:|---:|---:|

    """
    for id in ["03_acne_redness", "04_strong_freckles", "05_older_wrinkles", "06_beard_moustache"] {
        let entry = try #require(corpus.cases.first { $0.id == id })
        let input = try targetedInput(entry, repo: repo)
        let bitmap = try #require(gpu.context.createCGImage(input, from: input.extent.integral,
            format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!))
        let masks = try BeautyFaceAnalysis.analyze(bitmap)
        let matte = finalScaleMask(try #require(masks.blemishes), to: input.extent)
        let face = try #require(masks.faceRects.first)
        let regions: [(String, CGRect)]
        if id == "03_acne_redness" {
            let cheek = finalFaceCrop(face: face, extent: input.extent,
                x: 0.74, y: 0.54, side: 240)
            let chin = finalFaceCrop(face: face, extent: input.extent,
                x: 0.52, y: 0.22, side: 240)
            regions = [("cheek lesion", CGRect(x: cheek.minX + 192, y: cheek.minY + 100,
                                               width: 48, height: 55)),
                       ("chin lesion", CGRect(x: chin.minX + 94, y: chin.minY,
                                              width: 58, height: 47))]
        } else if id == "04_strong_freckles" {
            let forehead = finalFaceCrop(face: face, extent: input.extent,
                x: 0.52, y: 0.83, side: 240)
            let cheek = finalFaceCrop(face: face, extent: input.extent,
                x: 0.72, y: 0.53, side: 240)
            regions = [("forehead freckles", forehead), ("cheek freckles", cheek)]
        } else {
            regions = [(id == "05_older_wrinkles" ? "wrinkles" : "beard",
                targetedCrop(control: .blemishes, face: face, extent: input.extent, id: id))]
        }
        for (name, roi) in regions {
            let crop = roi.integral.intersection(input.extent)
            let before = gpu.read(input, crop)
            let confidence = gpu.read(matte, crop)
            var values: [Double] = []
            for i in stride(from: 0, to: confidence.count, by: 4) {
                values.append(Double(confidence[i]))
            }
            let sorted = values.sorted()
            let mean = values.reduce(0, +) / Double(max(1, values.count))
            let p95 = sorted[Int(0.95 * Double(max(0, sorted.count - 1)))]
            let selected = Double(values.filter { $0 > 0.01 }.count) / Double(max(1, values.count))
            if id == "03_acne_redness" {
                #expect(selected > 0.01, "\(name) lesion must remain selected")
            } else if id == "04_strong_freckles" {
                #expect(selected < 0.02, "\(name) freckles must stay nearly unselected")
            } else {
                #expect(selected < 0.03, "\(name) must stay effectively unselected")
            }
            var sweep: [(String, CIImage)] = []
            var after100 = before
            var sweepMAE: [Double] = []
            for amount in [0, 25, 50, 75, 100] {
                var state = BeautyState()
                state.blemishes = Double(amount)
                let output = try BeautyRenderer.apply(input, settings: state, masks: masks)
                sweep.append(("\(amount)", output.cropped(to: crop)))
                let rendered = gpu.read(output, crop)
                if amount == 100 { after100 = rendered }
                var difference = 0.0
                for i in stride(from: 0, to: before.count, by: 4) {
                    for channel in 0..<3 {
                        difference += abs(Double(rendered[i + channel] - before[i + channel]))
                    }
                }
                sweepMAE.append(difference / Double(max(1, before.count / 4 * 3)))
            }
            #expect(sweepMAE[0] < 0.00001)
            if id == "03_acne_redness" {
                for index in 1..<sweepMAE.count {
                    #expect(sweepMAE[index] > sweepMAE[index - 1],
                        "\(id) \(name): non-progressive blemish response")
                }
            }
            sweepTable += String(format: "| %@ | %@ | %.6f | %.6f | %.6f | %.6f | %.6f |\n",
                id, name, sweepMAE[0], sweepMAE[1], sweepMAE[2],
                sweepMAE[3], sweepMAE[4])
            let safeName = name.replacingOccurrences(of: " ", with: "_")
            try artifacts.sheet(sweep, "Sweeps/\(id)_\(safeName)_100pct.png",
                nativeCrop: true, cell: Int(max(crop.width, crop.height)), maxColumns: 5)
            var mae = 0.0
            var nonFinite = 0
            for i in stride(from: 0, to: before.count, by: 4) {
                for channel in 0..<3 {
                    if !after100[i + channel].isFinite { nonFinite += 1 }
                    mae += abs(Double(after100[i + channel] - before[i + channel]))
                }
            }
            mae /= Double(max(1, before.count / 4 * 3))
            #expect(nonFinite == 0)
            table += String(format: "| %@ | %@ | %.5f | %.5f | %.2f | %.6f | %d |\n",
                id, name, mean, p95, selected * 100, mae, nonFinite)
            let overlay = finalMaskOverlay(input: input, matte: matte)
            let displayCrop: CGRect
            if id == "03_acne_redness" {
                displayCrop = finalFaceCrop(face: face, extent: input.extent,
                    x: name.contains("cheek") ? 0.74 : 0.52,
                    y: name.contains("cheek") ? 0.54 : 0.22, side: 240)
            } else if id == "04_strong_freckles" {
                displayCrop = finalFaceCrop(face: face, extent: input.extent,
                    x: name.contains("forehead") ? 0.52 : 0.72,
                    y: name.contains("forehead") ? 0.83 : 0.53, side: 240)
            } else { displayCrop = crop }
            var comparison: [(String, CIImage)] = [("Source", input.cropped(to: displayCrop))]
            if id == "03_acne_redness" || id == "04_strong_freckles" {
                let oldURL = root.appendingPathComponent(
                    "Current/Comparisons/\(id)_\(safeName).png")
                if let oldSheet = CIImage(contentsOf: oldURL) {
                    comparison.append(("Old final matte (diagnostic raster)",
                        oldSheet.cropped(to: CGRect(x: 640, y: 0, width: 320, height: 320))))
                }
            }
            comparison += [("New final matte", matte.cropped(to: displayCrop)),
                           ("New overlay", overlay.cropped(to: displayCrop))]
            try artifacts.sheet(comparison, "Comparisons/\(id)_\(safeName).png",
                cell: 320, maxColumns: 4)
        }
    }
    try table.write(to: artifacts.url("blemish_region_metrics.md"),
        atomically: true, encoding: .utf8)
    try sweepTable.write(to: artifacts.url("amount_progression.md"),
        atomically: true, encoding: .utf8)
}

@Test func beautyTargetedPassValidation() throws {
    let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
    let root = repo.appendingPathComponent("BeautyValidation/TargetedPass")
    let gpu = try LabGPU()
    let artifacts = LabArtifacts(root: root, gpu: gpu)
    let corpus = try JSONDecoder().decode(TargetedCorpus.self,
        from: Data(contentsOf: repo.appendingPathComponent("BeautyValidation/corpus.json")))
    let cases: [(String, BeautyControl)] = [
        ("03_acne_redness", .blemishes), ("04_strong_freckles", .blemishes),
        ("05_older_wrinkles", .blemishes), ("06_beard_moustache", .blemishes),
        ("09_pronounced_dark_circles", .darkCircles),
        ("01_light_skin_pores", .darkCircles),
        ("02_dark_skin_texture", .darkCircles),
        ("10_detailed_eyes", .darkCircles)
    ]
    var report = """
    # Targeted Beauty renderer pass — diagnostic measurements

    All rows use the dedicated, unchanged BeautyValidation portraits. Amount is
    100; the named control alone is varied. Mask support means weight > 0.01 in
    a native 320 × 320 source-pixel crop. RGB MAE and affected fraction (> 0.001
    linear RGB) are restricted to this support. ΔY and Δchroma are signed/absolute
    changes within that support. Metrics describe, rather than score, appearance.

    | Photo | Control | Value | Support % | Mean matte | P95 matte | Affected % | RGB MAE | ΔY | Δchroma | Nonfinite |
    |---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|

    """
    var maskSheet: [(String, CIImage)] = []
    var darkTable = """

    For dark circles, the low-frequency cheek gap is the masked mean of
    |Y(under-eye blur) − Y(nearby cheek blur)|, before/after. Texture retention
    compares mean absolute high-pass luminance within the unchanged under-eye
    matte; 1.0 means equal high-frequency amplitude. This is descriptive and
    cannot by itself rule out a visible halo.

    | Photo | Cheek gap before | Cheek gap after 100 | High-pass retention |
    |---|---:|---:|---:|

    """
    for (id, control) in cases {
        let entry = try #require(corpus.cases.first { $0.id == id })
        let input = try targetedInput(entry, repo: repo)
        let bitmap = try #require(gpu.context.createCGImage(input, from: input.extent.integral,
            format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!))
        let masks = try BeautyFaceAnalysis.analyze(bitmap)
        #expect(masks.faceCount > 0, "\(id): face required")
        let mask = try #require(control == .blemishes ? masks.blemishes : masks.underEyes)
        let fullMask = CIImage(cgImage: mask).transformed(by: CGAffineTransform(
            scaleX: input.extent.width / CGFloat(mask.width),
            y: input.extent.height / CGFloat(mask.height))).cropped(to: input.extent)
        let crop = targetedCrop(control: control, face: masks.faceRects.first,
                                extent: input.extent, id: id)
        let before = gpu.read(input, crop)
        let matte = gpu.read(fullMask, crop)
        var sweep: [(String, CIImage)] = []
        var finalOutput = input
        for value in [0, 25, 50, 75, 100] {
            var state = BeautyState()
            state[control] = Double(value)
            let output = try BeautyRenderer.apply(input, settings: state, masks: masks)
            let metric = targetedMetrics(before, gpu.read(output, crop), matte)
            report += String(format: "| %@ | %@ | %d | %.2f | %.3f | %.3f | %.2f | %.6f | %+.6f | %.6f | %d |\n",
                id, control.rawValue, value, metric.support * 100,
                metric.meanMatte, metric.p95Matte, metric.affected * 100,
                metric.mae, metric.deltaY, metric.deltaChroma, metric.nonFinite)
            #expect(metric.nonFinite == 0)
            if value == 0 { #expect(metric.mae == 0) }
            sweep.append(("\(id) / \(value)", output.cropped(to: crop)))
            if value == 100 { finalOutput = output }
        }
        try artifacts.sheet(sweep, "Sweeps/\(id)_\(control.rawValue).png",
            nativeCrop: true, cell: 320, maxColumns: 5)
        try artifacts.sheet([("Original", input), ("100", finalOutput)],
            "Full/\(id)_before_after.png", cell: 640, maxColumns: 2)
        if id == "03_acne_redness" || id == "09_pronounced_dark_circles" {
            let baselineName = control == .blemishes ? "blemishes.png" : "darkCircles.png"
            let baseline = try #require(CIImage(contentsOf:
                root.appendingPathComponent("Baseline/\(baselineName)")))
            let oldTiles = (0..<5).map { index in
                ("Old / \(index * 25)", baseline.cropped(to: CGRect(
                    x: index * 320, y: 0, width: 320, height: 320)))
            }
            try artifacts.sheet(oldTiles + sweep,
                "BeforeAfter/\(id)_old_vs_new.png", nativeCrop: true,
                cell: 320, maxColumns: 5)
        }
        if control == .darkCircles {
            let lowBefore = targetedBlur(input, radius: 7)
            let lowAfter = targetedBlur(finalOutput, radius: 7)
            let cheek = targetedBlur(input, radius: 18).clampedToExtent()
                .transformed(by: CGAffineTransform(translationX: 0,
                    y: input.extent.width * masks.faceWidthFraction * 0.11))
                .cropped(to: input.extent)
            let diagnostic = targetedDarkCircleMetric(
                before: before, after: gpu.read(finalOutput, crop),
                lowBefore: gpu.read(lowBefore, crop),
                lowAfter: gpu.read(lowAfter, crop),
                cheek: gpu.read(cheek, crop), matte: matte)
            darkTable += String(format: "| %@ | %.5f | %.5f | %.3f |\n", id,
                diagnostic.gapBefore, diagnostic.gapAfter, diagnostic.textureRetention)
        }
        if control == .blemishes {
            let oldURL = root.appendingPathComponent("Baseline/\(id)_old_matte_raw.png")
            let old = try #require(CIImage(contentsOf: oldURL))
            let overlayColor = fullMask.applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: 1, y: 0, z: 0, w: 0),
                "inputGVector": CIVector(x: 0, y: 0, z: 0, w: 0),
                "inputBVector": CIVector(x: 0, y: 0, z: 0, w: 0),
                "inputAVector": CIVector(x: 0.7, y: 0, z: 0, w: 0)
            ])
            let overlay = overlayColor.applyingFilter("CISourceOverCompositing",
                parameters: [kCIInputBackgroundImageKey: input]).cropped(to: input.extent)
            maskSheet += [("\(id) source", input), ("\(id) old matte", old),
                          ("\(id) new matte", CIImage(cgImage: mask)),
                          ("\(id) new overlay", overlay)]
            try artifacts.sheet(Array(maskSheet.suffix(4)), "Masks/\(id).png",
                cell: 384, maxColumns: 4)
        }
    }
    try artifacts.sheet(maskSheet, "blemish_mask_before_after.png", cell: 300, maxColumns: 4)
    report += "\n" + darkTable
    try report.write(to: artifacts.url("targeted_metrics.md"), atomically: true,
                     encoding: .utf8)
}

private func targetedBlur(_ image: CIImage, radius: CGFloat) -> CIImage {
    image.clampedToExtent().applyingFilter("CIGaussianBlur",
        parameters: [kCIInputRadiusKey: radius]).cropped(to: image.extent)
}

private func targetedDarkCircleMetric(before: [Float], after: [Float],
    lowBefore: [Float], lowAfter: [Float], cheek: [Float], matte: [Float])
    -> (gapBefore: Double, gapAfter: Double, textureRetention: Double) {
    var gapBefore = 0.0, gapAfter = 0.0
    var highBefore = 0.0, highAfter = 0.0, count = 0.0
    for i in stride(from: 0, to: before.count, by: 4) where matte[i] > 0.01 {
        let yCheek = LabGPU.luma(cheek, i)
        let yLowBefore = LabGPU.luma(lowBefore, i)
        let yLowAfter = LabGPU.luma(lowAfter, i)
        gapBefore += abs(yCheek - yLowBefore)
        gapAfter += abs(yCheek - yLowAfter)
        highBefore += abs(LabGPU.luma(before, i) - yLowBefore)
        highAfter += abs(LabGPU.luma(after, i) - yLowAfter)
        count += 1
    }
    return (gapBefore / max(1, count), gapAfter / max(1, count),
            highAfter / max(1e-8, highBefore))
}

private struct TargetedMetric {
    var support = 0.0
    var meanMatte = 0.0
    var p95Matte = 0.0
    var affected = 0.0
    var mae = 0.0
    var deltaY = 0.0
    var deltaChroma = 0.0
    var nonFinite = 0
}

private func targetedMetrics(_ before: [Float], _ after: [Float],
                             _ matte: [Float]) -> TargetedMetric {
    var result = TargetedMetric()
    var weights: [Double] = []
    var changed = 0
    for i in stride(from: 0, to: before.count, by: 4) {
        let weight = Double(matte[i])
        guard weight > 0.01 else { continue }
        if !(0..<3).allSatisfy({ before[i+$0].isFinite && after[i+$0].isFinite }) {
            result.nonFinite += 1
            continue
        }
        weights.append(weight)
        let y0 = LabGPU.luma(before, i), y1 = LabGPU.luma(after, i)
        let c0 = sqrt((0..<3).reduce(0.0) { $0 + pow(Double(before[i+$1]) - y0, 2) })
        let c1 = sqrt((0..<3).reduce(0.0) { $0 + pow(Double(after[i+$1]) - y1, 2) })
        let diff = (0..<3).reduce(0.0) { $0 + abs(Double(after[i+$1] - before[i+$1])) } / 3
        result.mae += diff
        result.deltaY += y1 - y0
        result.deltaChroma += abs(c1 - c0)
        if diff > 0.001 { changed += 1 }
    }
    result.support = Double(weights.count) / Double(max(1, before.count / 4))
    guard !weights.isEmpty else { return result }
    let n = Double(weights.count)
    result.meanMatte = weights.reduce(0, +) / n
    result.p95Matte = weights.sorted()[Int(0.95 * Double(weights.count - 1))]
    result.affected = Double(changed) / n
    result.mae /= n
    result.deltaY /= n
    result.deltaChroma /= n
    return result
}

private func targetedCrop(control: BeautyControl, face: CGRect?, extent: CGRect,
                          id: String) -> CGRect {
    let f = face ?? CGRect(x: 0.25, y: 0.2, width: 0.5, height: 0.6)
    let center: CGPoint
    switch (control, id) {
    case (.blemishes, "03_acne_redness"), (.blemishes, "04_strong_freckles"):
        center = CGPoint(x: f.minX + f.width * 0.68,
                         y: f.minY + f.height * 0.40)
    case (.blemishes, "05_older_wrinkles"):
        center = CGPoint(x: f.midX, y: f.minY + f.height * 0.83)
    case (.blemishes, "06_beard_moustache"):
        center = CGPoint(x: f.midX, y: f.minY + f.height * 0.19)
    default: center = CGPoint(x: f.midX, y: f.minY + f.height * 0.63)
    }
    let side: CGFloat = 320
    return CGRect(x: min(max(extent.minX, center.x * extent.width - side/2),
                         extent.maxX - side),
                  y: min(max(extent.minY, center.y * extent.height - side/2),
                         extent.maxY - side), width: side, height: side).integral
}
