import CoreGraphics
import CoreImage
import Foundation
import Testing
@testable import LumoraCore

/// Diagnostic only: no preset, mask, or Beauty renderer value is written.
@Test func beautyRendererResponseSweeps() throws {
    let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
    let artifactRoot = repo.appendingPathComponent("BeautyValidation/SliderSweeps")
    let gpu = try LabGPU()
    let artifacts = LabArtifacts(root: artifactRoot, gpu: gpu)
    let corpus = try JSONDecoder().decode(ResponseCorpus.self,
        from: Data(contentsOf: repo.appendingPathComponent("BeautyValidation/corpus.json")))
    let sweeps: [(BeautyControl, [String], String)] = [
        (.uniformity, ["01_light_skin_pores", "02_dark_skin_texture"], "cheek"),
        (.texture, ["01_light_skin_pores", "05_older_wrinkles", "06_beard_moustache"], "texture"),
        (.blemishes, ["03_acne_redness"], "blemishes"),
        (.darkCircles, ["09_pronounced_dark_circles"], "under_eyes"),
        (.eyeBrightness, ["10_detailed_eyes"], "eyes"),
        (.eyeDetail, ["10_detailed_eyes"], "eyes"),
        (.teeth, ["08_open_smile_teeth"], "teeth")
    ]
    var table = """
    # Beauty renderer — isolated slider response

    Working space: extended-linear sRGB. The only active control is the one named
    in each row; Amount = 100 and every other control = 0. Each crop is exactly
    320 × 320 source pixels. Metrics include only pixels whose corresponding
    cached matte weight exceeds 0.01; mask support is reported relative to the
    crop. RGB MAE is the mean of absolute linear-channel changes. ΔY is signed;
    Δchroma is the mean absolute change of RGB distance from equal-channel gray.
    P50/P95 use per-pixel mean absolute RGB change. "Changed" means amplitude
    > 0.001 linear. These are descriptive measurements, not quality thresholds.

    | Control | Photo | Slider | Mask support % | Mean mask | Max mask | Clamp %¹ | Input Y | RGB MAE | ΔY | Δchroma | Changed % | P50 | P95 | Nonfinite |
    |---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|

    """
    for (control, photoIDs, region) in sweeps {
        var sheet: [(String, CIImage)] = []
        for photoID in photoIDs {
            let entry = try #require(corpus.cases.first { $0.id == photoID })
            let path = repo.appendingPathComponent("BeautyValidation")
                .appendingPathComponent(entry.source)
            var input = try #require(CIImage(contentsOf: path,
                options: [.applyOrientationProperty: true]))
            input = input.transformed(by: CGAffineTransform(
                translationX: -input.extent.minX, y: -input.extent.minY))
            let frame = CGRect(x: entry.frame[0] * input.extent.width,
                y: entry.frame[1] * input.extent.height,
                width: entry.frame[2] * input.extent.width,
                height: entry.frame[3] * input.extent.height)
                .integral.intersection(input.extent)
            input = input.cropped(to: frame).transformed(by:
                CGAffineTransform(translationX: -frame.minX, y: -frame.minY))
            let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!
            let bitmap = try #require(gpu.context.createCGImage(input,
                from: input.extent.integral, format: .RGBA8, colorSpace: sRGB))
            let masks = try BeautyFaceAnalysis.analyze(bitmap)
            #expect(masks.faceCount > 0, "\(photoID): reliable face required")
            let chosenMask: CGImage? = switch control {
            case .uniformity, .texture: masks.skin
            case .blemishes: masks.blemishes
            case .darkCircles: masks.underEyes
            case .eyeBrightness, .eyeDetail: masks.eyes
            case .teeth: masks.teeth
            case .amount: nil
            }
            let mask = try #require(chosenMask, "\(photoID): mask for \(control.rawValue)")
            let crop = responseCrop(region: region, face: masks.faceRects.first,
                extent: input.extent, photoID: photoID)
            let maskImage = CIImage(cgImage: mask)
                .transformed(by: CGAffineTransform(
                    scaleX: input.extent.width / CGFloat(mask.width),
                    y: input.extent.height / CGFloat(mask.height)))
                .cropped(to: crop)
            let originalPixels = gpu.read(input, crop)
            let maskPixels = gpu.read(maskImage, crop)
            let levels = control == .texture ? [0, -25, -50, -75, -100]
                                             : [0, 25, 50, 75, 100]
            var previousMAE = -1.0
            for level in levels {
                var settings = BeautyState()
                settings[control] = Double(level)
                let output = try BeautyRenderer.apply(input, settings: settings,
                    masks: masks).cropped(to: crop)
                sheet.append(("\(photoID) / \(level)", output))
                let outputPixels = gpu.read(output, crop)
                let result = responseMetrics(original: originalPixels,
                    output: outputPixels, mask: maskPixels, level: abs(level))
                table += String(format:
                    "| %@ | %@ | %d | %.2f | %.3f | %.3f | %.2f | %.4f | %.6f | %+.6f | %.6f | %.2f | %.6f | %.6f | %d |\n",
                    control.rawValue, photoID, level, result.support * 100,
                    result.meanMask, result.maxMask,
                    control == .blemishes ? result.clamped * 100 : 0,
                    result.inputY, result.mae, result.deltaY,
                    result.deltaChroma, result.changed * 100,
                    result.p50, result.p95, result.nonFinite)
                #expect(result.nonFinite == 0)
                if level == 0 { #expect(result.mae == 0) }
                if previousMAE >= 0 {
                    #expect(result.mae + 1e-7 >= previousMAE,
                            "\(control.rawValue)/\(photoID): response magnitude must progress")
                }
                previousMAE = result.mae
            }
        }
        #expect(sheet.count == photoIDs.count * 5)
        try artifacts.sheet(sheet, "\(control.rawValue).png",
            nativeCrop: true, cell: 320, maxColumns: 5)
    }
    table += "\n¹ Fraction des pixels sélectionnés où `mask × slider/100 ≥ 0.92`, uniquement pertinente pour Imperfections ; zéro pour les autres contrôles.\n"
    try table.write(to: artifactRoot.appendingPathComponent("response_metrics.md"),
                    atomically: true, encoding: .utf8)
}

private struct ResponseCorpus: Decodable {
    let cases: [ResponseEntry]
}
private struct ResponseEntry: Decodable {
    let id: String
    let source: String
    let frame: [CGFloat]
}
private struct ResponseMetric {
    var support = 0.0
    var meanMask = 0.0
    var maxMask = 0.0
    var clamped = 0.0
    var inputY = 0.0
    var mae = 0.0
    var deltaY = 0.0
    var deltaChroma = 0.0
    var changed = 0.0
    var p50 = 0.0
    var p95 = 0.0
    var nonFinite = 0
}

private func responseMetrics(original: [Float], output: [Float],
                             mask: [Float], level: Int) -> ResponseMetric {
    var metric = ResponseMetric()
    var amplitudes: [Double] = []
    var maskSum = 0.0
    var changed = 0
    var clamped = 0
    let count = original.count / 4
    for pixel in 0..<count {
        let i = pixel * 4
        let weight = Double(mask[i])
        guard weight > 0.01 else { continue }
        guard (0..<3).allSatisfy({ original[i + $0].isFinite &&
                                   output[i + $0].isFinite }) else {
            metric.nonFinite += 1
            continue
        }
        maskSum += weight
        metric.maxMask = max(metric.maxMask, weight)
        if weight * Double(level) / 100 >= 0.92 { clamped += 1 }
        let old = (Double(original[i]), Double(original[i+1]), Double(original[i+2]))
        let new = (Double(output[i]), Double(output[i+1]), Double(output[i+2]))
        let y0 = 0.2126 * old.0 + 0.7152 * old.1 + 0.0722 * old.2
        let y1 = 0.2126 * new.0 + 0.7152 * new.1 + 0.0722 * new.2
        let chroma0 = sqrt(pow(old.0-y0,2) + pow(old.1-y0,2) + pow(old.2-y0,2))
        let chroma1 = sqrt(pow(new.0-y1,2) + pow(new.1-y1,2) + pow(new.2-y1,2))
        let amplitude = (abs(new.0-old.0) + abs(new.1-old.1) + abs(new.2-old.2)) / 3
        amplitudes.append(amplitude)
        metric.mae += amplitude
        metric.inputY += y0
        metric.deltaY += y1-y0
        metric.deltaChroma += abs(chroma1-chroma0)
        if amplitude > 0.001 { changed += 1 }
    }
    metric.support = Double(amplitudes.count) / Double(max(1, count))
    guard !amplitudes.isEmpty else { return metric }
    let denominator = Double(amplitudes.count)
    metric.meanMask = maskSum / denominator
    metric.clamped = Double(clamped) / denominator
    metric.inputY /= denominator
    metric.mae /= denominator
    metric.deltaY /= denominator
    metric.deltaChroma /= denominator
    metric.changed = Double(changed) / denominator
    amplitudes.sort()
    metric.p50 = amplitudes[Int(Double(amplitudes.count - 1) * 0.50)]
    metric.p95 = amplitudes[Int(Double(amplitudes.count - 1) * 0.95)]
    return metric
}

private func responseCrop(region: String, face: CGRect?, extent: CGRect,
                          photoID: String) -> CGRect {
    let f = face ?? CGRect(x: 0.25, y: 0.2, width: 0.5, height: 0.6)
    let x: CGFloat
    let y: CGFloat
    switch region {
    case "cheek": x = f.minX + f.width * 0.31; y = f.minY + f.height * 0.45
    case "texture" where photoID == "05_older_wrinkles":
        x = f.midX; y = f.minY + f.height * 0.83
    case "texture" where photoID == "06_beard_moustache":
        x = f.midX; y = f.minY + f.height * 0.19
    case "texture": x = f.minX + f.width * 0.31; y = f.minY + f.height * 0.45
    case "blemishes": x = f.minX + f.width * 0.68; y = f.minY + f.height * 0.40
    case "under_eyes": x = f.midX; y = f.minY + f.height * 0.63
    case "eyes": x = f.midX; y = f.minY + f.height * 0.68
    case "teeth": x = f.midX; y = f.minY + f.height * 0.25
    default: x = f.midX; y = f.midY
    }
    let side: CGFloat = 320
    return CGRect(x: min(max(extent.minX, x * extent.width - side / 2),
                         extent.maxX - side),
                  y: min(max(extent.minY, y * extent.height - side / 2),
                         extent.maxY - side),
                  width: side, height: side).integral
}
