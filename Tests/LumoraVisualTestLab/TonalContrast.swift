import Foundation
import CoreImage
import ImageIO
@testable import LumoraCore

/// Deterministic linear-light chart. Frequencies are expressed on a logical
/// 3000-pixel long edge, independent of the generated bitmap resolution.
struct TonalContrastTestChart {
    let image: CIImage
    let regions: [ChartRegion]
    static func generate(size: Int) -> Self {
        let names = ["smooth-gradient", "fine-texture", "medium-texture", "coarse-texture",
                     "dark-texture", "midtone-texture", "bright-texture", "hard-edge",
                     "soft-edge", "skin-like", "sky-gradient", "dark-noise"]
        let cell = size / 4
        let image = SyntheticCharts.make(size: size) { x, y in
            let col = min(3, Int(x * 4)), row = min(2, Int(y * 3))
            let u = x * 4 - Double(col), v = y * 3 - Double(row)
            let wave: (Double) -> Double = { period in
                sin(2 * .pi * x * 3000 / period) * sin(2 * .pi * y * 3000 / period)
            }
            let value: Double
            switch row * 4 + col {
            case 0: value = u
            case 1: value = 0.48 + 0.045 * wave(4)
            case 2: value = 0.48 + 0.06 * wave(16)
            case 3: value = 0.48 + 0.08 * wave(64)
            case 4: value = 0.08 + 0.025 * wave(16)
            case 5: value = 0.45 + 0.055 * wave(16)
            case 6: value = 0.82 + 0.045 * wave(16)
            case 7: value = u < 0.5 ? 0.07 : 0.90
            case 8: value = 0.07 + 0.83 / (1 + exp(-(u - 0.5) * 18))
            case 9:
                let texture = 0.02 * wave(24)
                return SIMD3(Float(0.60 + texture), Float(0.35 + texture), Float(0.24 + texture))
            case 10:
                let base = 0.36 + 0.36 * v
                return SIMD3(Float(base * 0.55), Float(base * 0.77), Float(base))
            default:
                let ix = UInt32(x * 3000), iy = UInt32(y * 3000)
                var hash = ix &* 374761393 &+ iy &* 668265263 &+ 137
                hash = (hash ^ (hash >> 13)) &* 1274126177
                value = 0.035 + (Double(hash & 65535) / 65535 - 0.5) * 0.012
            }
            return SIMD3(repeating: Float(value))
        }
        let regions: [ChartRegion] = names.enumerated().map { index, name in
            let column = index % 4
            let row = index / 4
            let originX = column * cell + cell / 8
            let originY = size - (row + 1) * (size / 3) + size / 24
            return ChartRegion(name: name, x: originX, y: originY,
                               width: cell * 3 / 4, height: size / 4, ramp: index == 0)
        }
        return Self(image: image, regions: regions)
    }
    func region(_ name: String) -> CGRect { regions.first { $0.name == name }!.rect }
}

extension LumoraVisualTestLab {
    /// All outputs below use the production CreativeStackRenderer and RenderEngine.
    func runTonalContrast() async throws {
        let chart = TonalContrastTestChart.generate(size: full ? 4096 : 1024)
        try artifacts.json(chart.regions, "TonalContrast/chart_regions.json")
        try artifacts.png(chart.image, "TonalContrast/TonalContrastTestChart.png")
        try tonalSynthetic(chart)
        try tonalRadius(chart)
        try tonalMasksAndOrder(chart)
        try tonalResolutionAndPerformance()
        try await tonalPipeline()
        try tonalPhotographs()
        try tonalReport()
    }

    private func tonalSynthetic(_ chart: TonalContrastTestChart) throws {
        var zero = effect(.tonalContrast)
        for parameter in zero.kind.descriptor.parameters { zero[parameter.id] = 0 }
        let unchanged = try render(chart.image, [zero])
        let neutral = gpu.compare(chart.image, unchanged)
        var identity = LabCase(name: "TC_neutrality")
        identity.metrics = ["maxRGBError": neutral.maxError, "meanLuminanceChange": neutral.residual.mean,
                            "chromaticityDrift": neutral.chromaticityMAE, "nonFinitePixels": Double(neutral.nonFinite)]
        identity.check("Exact neutral identity", neutral.maxError < 2e-6, hard: true,
                       "All zero amounts return the source CIImage without reconstruction.")
        identity.check("Finite output", neutral.nonFinite == 0, hard: true, "No NaN/Inf RGBA samples.")
        cases.append(identity)

        let variants: [(String, [String: Double])] = [
            ("shadows", ["globalAmount": 85, "shadows": 80, "midtones": 0, "highlights": 0]),
            ("midtones", ["globalAmount": 85, "shadows": 0, "midtones": 80, "highlights": 0]),
            ("highlights", ["globalAmount": 85, "shadows": 0, "midtones": 0, "highlights": 80]),
            ("strong", ["globalAmount": 90, "shadows": 55, "midtones": 75, "highlights": 65]),
            ("soft", ["globalAmount": 65, "shadows": -30, "midtones": -45, "highlights": -30])]
        var sheet: [(String, CIImage)] = [("Original", chart.image)]
        for (name, parameters) in variants {
            let fx = effect(.tonalContrast, parameters).validated
            let output = try render(chart.image, [fx])
            let prefix = "TonalContrast/Synthetic/\(name)"
            try artifacts.png(output, prefix + ".png")
            try artifacts.png(artifacts.difference(chart.image, output, gain: 6), prefix + "_difference_x6.png")
            try artifacts.json(fx, prefix + "_settings.json")
            let whole = gpu.compare(chart.image, output)
            var c = LabCase(name: "TC_\(name)")
            c.metrics = ["meanLuminanceChange": whole.residual.mean, "nonFinitePixels": Double(whole.nonFinite),
                         "chromaticityDrift": whole.chromaticityMAE, "maxChromaticityDrift": whole.maxChromaticityError]
            c.check("Finite output", whole.nonFinite == 0, hard: true, "Full synthetic chart in RGBA float.")
            c.check("Mean brightness stable", abs(whole.residual.mean) < 0.025,
                    "Quality heuristic: |mean luminance change| < .025 linear on a chart with transitions.")
            for zone in ["dark-texture", "midtone-texture", "bright-texture",
                         "fine-texture", "medium-texture", "coarse-texture"] {
                let roi = centered(chart.region(zone), side: 192)
                let before = localRMS(chart.image, region: roi)
                let after = localRMS(output, region: roi)
                c.metrics[zone + "-localRMSBefore"] = before
                c.metrics[zone + "-localRMSAfter"] = after
                c.metrics[zone + "-localRMSRatio"] = after / max(before, 1e-9)
            }
            if ["shadows", "midtones", "highlights"].contains(name) {
                let target = ["shadows": "dark-texture", "midtones": "midtone-texture", "highlights": "bright-texture"][name]!
                let gain = abs(c.metrics[target + "-localRMSRatio"]! - 1)
                let others = ["dark-texture", "midtone-texture", "bright-texture"].filter { $0 != target }
                c.check("Tonal selectivity", gain >= others.map { abs(c.metrics[$0 + "-localRMSRatio"]! - 1) }.max()! - 0.005,
                        "Target zone should have the strongest local RMS response; .005 allows measurement noise.")
            }
            if name == "strong" {
                let skin = gpu.compare(chart.image, output, region: chart.region("skin-like"))
                c.metrics["skinChromaticityDrift"] = skin.chromaticityMAE
                c.check("Neutral-saturation hue preservation", skin.chromaticityMAE < 0.002,
                        "Mean RGB/sum(RGB) drift < .002 on the skin-like patch.")
                let ramp = gpu.compare(chart.image, output, region: chart.region("smooth-gradient"), ramp: true)
                c.metrics["gradientReversals"] = Double(ramp.monotonicityViolations)
                c.check("Smooth-gradient ordering", ramp.monotonicityViolations == 0,
                        "Quality heuristic: no derivative reversal on a smooth grayscale gradient.")
                let edge = centered(chart.region("hard-edge"), side: 256)
                let a = edgeProfile(chart.image, region: edge), b = edgeProfile(output, region: edge)
                let overshoot = max(0, (b.max() ?? 0) - (a.max() ?? 0))
                let undershoot = max(0, (a.min() ?? 0) - (b.min() ?? 0))
                c.metrics["hardEdgeOvershoot"] = overshoot
                c.metrics["hardEdgeUndershoot"] = undershoot
                c.check("Hard-edge halo", max(overshoot, undershoot) < 0.03,
                        "Quality heuristic: overshoot/undershoot should stay below .03 linear; inspect profile.")
                try artifacts.plot([("Input", a), ("Output", b)], "TonalContrast/edge_profile.png",
                                   title: "Dark / bright hard edge — linear luminance")
                c.images.append("TonalContrast/edge_profile.png")
            }
            c.images += [prefix + ".png", prefix + "_difference_x6.png"]
            cases.append(c)
            sheet.append((name.capitalized, output))
        }
        try artifacts.sheet(sheet, "TonalContrast/Synthetic/contact_sheet.png", cell: 768, maxColumns: 3)
    }

    private func centered(_ rect: CGRect, side: Int) -> CGRect {
        let s = min(CGFloat(side), rect.width, rect.height)
        return CGRect(x: floor(rect.midX - s / 2), y: floor(rect.midY - s / 2), width: s, height: s)
    }

    /// RMS of the 3×3 high-pass response, not whole-image standard deviation.
    private func localRMS(_ image: CIImage, region: CGRect) -> Double {
        let pixels = gpu.read(image, region), width = Int(region.width), height = Int(region.height)
        let y = (0..<(width * height)).map { LabGPU.luma(pixels, $0 * 4) }
        var sum = 0.0, count = 0
        for row in 1..<(height - 1) { for col in 1..<(width - 1) {
            var mean = 0.0
            for dy in -1...1 { for dx in -1...1 { mean += y[(row + dy) * width + col + dx] } }
            let delta = y[row * width + col] - mean / 9
            sum += delta * delta; count += 1
        } }
        return sqrt(sum / Double(max(1, count)))
    }

    private func edgeProfile(_ image: CIImage, region: CGRect) -> [Double] {
        let line = CGRect(x: region.minX, y: floor(region.midY), width: region.width, height: 1)
        let pixels = gpu.read(image, line)
        return (0..<Int(region.width)).map { LabGPU.luma(pixels, $0 * 4) }
    }

    private func tonalRadius(_ chart: TonalContrastTestChart) throws {
        let zones = ["fine-texture", "medium-texture", "coarse-texture"]
        var series: [(String, [Double])] = zones.map { ($0, []) }
        var c = LabCase(name: "TC_radius_frequency_response")
        for radius in [0.0, 50, 100] {
            let fx = effect(.tonalContrast, ["globalAmount": 85, "highlights": 0,
                                               "midtones": 75, "shadows": 0, "radius": radius])
            let output = try render(chart.image, [fx])
            for (index, zone) in zones.enumerated() {
                let response = gpu.compare(chart.image, output,
                                           region: centered(chart.region(zone), side: 192)).residualStd
                let key = "radius-\(Int(radius))-\(zone)-residualSD"
                c.metrics[key] = response
                series[index].1.append(response)
            }
        }
        let smallCoarse = c.metrics["radius-0-coarse-texture-residualSD"]!
        let largeCoarse = c.metrics["radius-100-coarse-texture-residualSD"]!
        c.check("Large radius reaches coarse structure", largeCoarse > smallCoarse,
                "Quality heuristic: coarse-band residual SD at radius 100 should exceed radius 0.")
        c.notes = ["Residual SD is the standard deviation of output−input linear luminance in each isolated texture patch; radius values are 0, 50, 100."]
        try artifacts.plot(series, "TonalContrast/frequency_response.png",
                           title: "Local residual SD by radius (0 / 50 / 100)", xMaximum: 100)
        c.images = ["TonalContrast/frequency_response.png"]
        cases.append(c)
    }

    private func tonalMasksAndOrder(_ chart: TonalContrastTestChart) throws {
        let input = normalized(chart.image, to: 1024)
        let fx = TonalContrastProfile.strongStructure.applying(to: effect(.tonalContrast))
        let global = try render(input, [fx])
        var radial = RadialGradientMask()
        radial.center = MaskPoint(x: 0.375, y: 0.5)
        radial.radiusX = 0.20; radial.radiusY = 0.20; radial.feather = 5
        let mask = LocalMask(name: "Tonal test", components: [MaskComponent(shape: .radial(radial))])
        var targeted = fx; targeted.maskID = mask.id
        let masked = try render(input, [targeted], masks: [mask])
        var inverse = mask; inverse.inverted = true
        let inverted = try render(input, [targeted], masks: [inverse])
        var radial2 = radial; radial2.center = MaskPoint(x: 0.78, y: 0.5)
        let mask2 = LocalMask(name: "Second zone", components: [MaskComponent(shape: .radial(radial2))])
        var targeted2 = fx; targeted2.maskID = mask2.id
        let stacked = try render(input, [targeted, targeted2], masks: [mask, mask2])
        let inside = CGRect(x: 342, y: 464, width: 64, height: 64)
        let outside = CGRect(x: 10, y: 10, width: 64, height: 64)
        let second = CGRect(x: 766, y: 464, width: 64, height: 64)
        let outsideError = gpu.compare(input, masked, region: outside)
        let inverseCenter = gpu.compare(input, inverted, region: inside)
        let stackOutside = gpu.compare(input, stacked, region: outside)
        var c = LabCase(name: "TC_mask_isolation")
        c.metrics = ["unmaskedCenterMAE": gpu.compare(input, global, region: inside).mae,
                     "maskedCenterMAE": gpu.compare(input, masked, region: inside).mae,
                     "maskedOutsideMaxError": outsideError.maxError,
                     "invertedCenterMaxError": inverseCenter.maxError,
                     "stackedSecondMAE": gpu.compare(input, stacked, region: second).mae,
                     "stackedOutsideMaxError": stackOutside.maxError]
        c.check("Outside mask identity", outsideError.maxError < 2e-6, hard: true,
                "The production mask compositor must leave distant pixels unchanged.")
        c.check("Inverted mask exclusion", inverseCenter.maxError < 2e-6, hard: true,
                "The centre excluded by the inverted mask must remain unchanged.")
        c.check("Stacked masks isolate outside", stackOutside.maxError < 2e-6, hard: true,
                "Two referenced masks must not broaden their effects globally.")
        c.check("Masked and stacked interiors respond", c.metrics["maskedCenterMAE"]! > 1e-5 && c.metrics["stackedSecondMAE"]! > 1e-5,
                hard: true, "Both selected mask interiors must change measurably.")
        try artifacts.sheet([("Original", input), ("Unmasked", global), ("Masked", masked),
                             ("Inverted", inverted), ("Stacked masks", stacked)],
                            "TonalContrast/mask_comparison.png", cell: 512)
        c.images = ["TonalContrast/mask_comparison.png"]
        cases.append(c)

        let texture = SyntheticCharts.make(size: 512) { x, y in
            SIMD3(repeating: Float(0.38 + 0.08 * sin(2 * .pi * x * 24) * sin(2 * .pi * y * 18)))
        }
        var grain = effect(.grain, ["amount": 65, "size": 45])
        grain.seed = 137
        let beforeGrain = try render(texture, [fx, grain])
        let afterGrain = try render(texture, [grain, fx])
        let order = gpu.compare(beforeGrain, afterGrain)
        var stackCase = LabCase(name: "TC_effect_stack_order")
        stackCase.metrics = ["forwardReverseMAE": order.mae, "nonFinitePixels": Double(order.nonFinite)]
        stackCase.check("Order changes result", order.mae > 1e-6, hard: true,
                        "Tonal Contrast → Grain and Grain → Tonal Contrast must be ordered operations.")
        stackCase.check("Finite stack", order.nonFinite == 0, hard: true, "Both stack permutations remain finite.")
        try artifacts.sheet([("Tonal → Grain", beforeGrain), ("Grain → Tonal", afterGrain),
                             ("Difference ×10", artifacts.difference(beforeGrain, afterGrain, gain: 10))],
                            "TonalContrast/stack_order.png", cell: 512)
        stackCase.images = ["TonalContrast/stack_order.png"]
        cases.append(stackCase)
    }

    private func tonalResolutionAndPerformance() throws {
        let dimensions = full ? [1024, 2048, 4096] : [512, 1024]
        let fx = TonalContrastProfile.naturalTexture.applying(to: effect(.tonalContrast))
        var reference: CIImage?
        var c = LabCase(name: "TC_resolution_performance")
        c.notes = ["Wall time includes GPU graph evaluation and RGBA8 readback; machine-dependent, never a hard speed gate.",
                   "The radius is normalized by the image long edge / 3000. No full-resolution texture cache is retained by the effect."]
        for dimension in dimensions {
            try autoreleasepool {
                let source = SyntheticCharts.make(size: dimension) { x, y in
                    let value = 0.45 + 0.05 * sin(2 * .pi * x * 3000 / 16) * sin(2 * .pi * y * 3000 / 16)
                        + 0.04 * sin(2 * .pi * x * 3000 / 64)
                    return SIMD3(repeating: Float(value))
                }
                let start = ContinuousClock.now
                let output = try render(source, [fx])
                guard let bitmap = gpu.context.createCGImage(output, from: output.extent,
                                                              format: .RGBA8, colorSpace: gpu.linear) else { throw LabError.render }
                let elapsed = start.duration(to: .now)
                c.metrics["\(dimension)-millisecondsIncludingReadback"] = Double(elapsed.components.seconds) * 1000
                    + Double(elapsed.components.attoseconds) / 1e15
                c.metrics["\(dimension)-bitmapBytes"] = Double(bitmap.width * bitmap.height * 4)
                let center = centered(output.extent, side: min(256, dimension / 2))
                c.metrics["\(dimension)-localRMSRatio"] = localRMS(output, region: center)
                    / max(1e-9, localRMS(source, region: center))
                let normalizedOutput = normalized(output, to: 512)
                if let reference {
                    let m = gpu.compare(reference, normalizedOutput)
                    c.metrics["\(dimension)-normalizedRMSE"] = m.rmse
                    c.check("Resolution agreement \(dimension)", m.rmse < 0.03,
                            "Quality heuristic: equal logical image fields, normalized to 512 px; RMSE < .03 linear.")
                } else { reference = normalizedOutput }
                try artifacts.png(normalizedOutput, "TonalContrast/resolution_\(dimension).png")
            }
        }
        cases.append(c)
    }

    private func tonalPipeline() async throws {
        let sourceImage = SyntheticCharts.make(size: 2048) { x, y in
            SIMD3(repeating: Float(0.45 + 0.06 * sin(2 * .pi * x * 80) * sin(2 * .pi * y * 60)))
        }
        let source = try artifacts.url("TonalContrast/Pipeline/source.png")
        try artifacts.png(sourceImage, "TonalContrast/Pipeline/source.png")
        let engine = RenderEngine()
        var state = EditState()
        state.creative.effects = [TonalContrastProfile.naturalTexture.applying(to: effect(.tonalContrast))]
        var c = LabCase(name: "TC_preview_HQ_export")
        var images: [(String, CIImage)] = []
        for quality in [PreviewQuality.interactive, .high] {
            let result = try await engine.render(url: source, state: state, quality: quality)
            let name = quality == .interactive ? "interactive" : "HQ"
            c.metrics[name + "-milliseconds"] = result.milliseconds
            c.metrics[name + "-width"] = Double(result.image.width)
            images.append((name, CIImage(cgImage: result.image)))
        }
        let repeated = try await engine.render(url: source, state: state, quality: .interactive)
        c.check("Preview source cache reused", repeated.cacheHit, hard: true,
                "The existing source decode cache remains active for repeat renders.")
        state.creative.effects[0]["midtones"] = 50
        let changed = try await engine.render(url: source, state: state, quality: .interactive)
        let invalidation = gpu.compare(images[0].1, CIImage(cgImage: changed.image))
        c.metrics["changedParameterMAE"] = invalidation.mae
        c.check("Parameter invalidates output", invalidation.mae > 1e-6, hard: true,
                "Changing one Creative parameter must update the preview while reusing source decode.")
        var settings = ExportSettings()
        settings.format = .png; settings.colorSpace = .displayP3; settings.includeMetadata = false
        let exported = try await engine.export(request: ExportRequest(sourceURL: source, state: state, name: "tonal-lab"),
                                               settings: settings, directory: artifacts.url("TonalContrast/Pipeline/Export"))
        guard let exportImage = CIImage(contentsOf: exported.url) else { throw LabError.render }
        c.metrics["exportWidth"] = Double(exported.width)
        let previewChanged = normalized(CIImage(cgImage: changed.image), to: 512)
        let exportedComparable = normalized(exportImage, to: 512)
        let agreement = gpu.compare(previewChanged, exportedComparable)
        c.metrics["previewExportSSIM"] = agreement.ssim
        c.check("Preview/export perceptual consistency", agreement.ssim > 0.9,
                "Quality heuristic after color conversion and resizing; not byte equality.")
        images += [("changed preview", CIImage(cgImage: changed.image)), ("export", exportImage)]
        try artifacts.sheet(images, "TonalContrast/Pipeline/comparison.png", cell: 512)
        c.images = ["TonalContrast/Pipeline/comparison.png"]
        cases.append(c)
    }

    private func tonalPhotographs() throws {
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let folder = URL(fileURLWithPath: ProcessInfo.processInfo.environment["LUMORA_VISUAL_ASSETS"]
            ?? repo.appendingPathComponent("VisualTestAssets").path)
        let files = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
            .filter { ["png", "jpg", "jpeg", "tif", "tiff", "heic"].contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        guard files.count == 8 else { throw NSError(domain: "TonalContrastLab", code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Expected eight photographs in \(folder.path), found \(files.count)"]) }
        let variants: [(String, (CreativeEffect) -> CreativeEffect)] = [
            ("Subtle", { TonalContrastProfile.subtleDetail.applying(to: $0) }),
            ("Shadows", { var fx = $0; fx["shadows"] = 75; fx["midtones"] = 0; fx["highlights"] = 0; fx["globalAmount"] = 80; return fx }),
            ("Midtones", { var fx = $0; fx["shadows"] = 0; fx["midtones"] = 75; fx["highlights"] = 0; fx["globalAmount"] = 80; return fx }),
            ("Highlights", { var fx = $0; fx["shadows"] = 0; fx["midtones"] = 0; fx["highlights"] = 75; fx["globalAmount"] = 80; return fx }),
            ("Natural", { TonalContrastProfile.naturalTexture.applying(to: $0) }),
            ("Strong", { TonalContrastProfile.strongStructure.applying(to: $0) }),
            ("Soft", { TonalContrastProfile.softStructure.applying(to: $0) })]
        for (index, file) in files.enumerated() {
            progress("Tonal Contrast photo \(index + 1)/8: \(file.lastPathComponent)")
            try autoreleasepool {
                guard var input = CIImage(contentsOf: file, options: [.applyOrientationProperty: true]) else { throw LabError.render }
                input = input.transformed(by: CGAffineTransform(translationX: -input.extent.minX, y: -input.extent.minY))
                let name = file.deletingPathExtension().lastPathComponent
                let root = "TonalContrast/RealPhotos/\(name)"
                try artifacts.png(input, root + "/Original.png")
                var sheet: [(String, CIImage)] = [("Original", input)]
                var crops: [(String, CIImage)] = []
                let centers = priorityCrops(index: index)
                for (label, x, y) in centers { crops.append(("Original · \(label)", crop(input, x: x, y: y))) }
                var c = LabCase(name: "TC_photo_\(name)")
                c.notes = ["Manual photographic review only. No aesthetic PASS/FAIL or Golden Master.",
                           "Crop centres: \(centers.map { "\($0.0)=(\($0.1),\($0.2))" }.joined(separator: ", ")). Native 512×512 pixels."]
                for (title, configure) in variants {
                    let fx = configure(effect(.tonalContrast)).validated
                    let output = try render(input, [fx])
                    let variant = title.lowercased()
                    let path = root + "/\(variant)"
                    try artifacts.png(output, path + ".png")
                    try artifacts.png(artifacts.difference(input, output, gain: 6), path + "_difference_x6.png")
                    try artifacts.json(fx, path + "_settings.json")
                    let sample = centered(input.extent, side: 256)
                    let m = gpu.compare(input, output, region: sample)
                    c.metrics[variant + "-centerMeanLuminanceChange"] = m.residual.mean
                    c.metrics[variant + "-centerChromaticityDrift"] = m.chromaticityMAE
                    c.metrics[variant + "-centerLocalRMSRatio"] = localRMS(output, region: sample)
                        / max(1e-9, localRMS(input, region: sample))
                    c.metrics[variant + "-nonFiniteCenterPixels"] = Double(m.nonFinite)
                    c.check("Finite \(title) crop", m.nonFinite == 0, hard: true,
                            "Central 256×256 RGBA float crop; full-image finiteness is checked on synthetic charts.")
                    sheet.append((title, output))
                    for (label, x, y) in centers { crops.append(("\(title) · \(label)", crop(output, x: x, y: y))) }
                    c.images += [path + ".png", path + "_difference_x6.png", path + "_settings.json"]
                }
                let sheetPath = root + "/TonalContrast_contact_sheet.png"
                let cropPath = root + "/TonalContrast_crops_100percent.png"
                try artifacts.sheet(sheet, sheetPath, cell: 960, maxColumns: 3)
                try artifacts.sheet(crops, cropPath, nativeCrop: true, cell: 512, maxColumns: 4)
                c.images += [sheetPath, cropPath]
                cases.append(c)
            }
        }
    }

    private func crop(_ image: CIImage, x: Double, y: Double) -> CIImage {
        let side = min(512, Int(image.extent.width), Int(image.extent.height))
        let originX = min(image.extent.maxX - CGFloat(side), max(image.extent.minX, image.extent.minX + image.extent.width * x - CGFloat(side) / 2))
        let originY = min(image.extent.maxY - CGFloat(side), max(image.extent.minY, image.extent.minY + image.extent.height * y - CGFloat(side) / 2))
        return image.cropped(to: CGRect(x: floor(originX), y: floor(originY), width: CGFloat(side), height: CGFloat(side)))
    }

    private func priorityCrops(index: Int) -> [(String, Double, Double)] {
        switch index {
        case 0, 1: [("skin", 0.50, 0.50), ("hair", 0.50, 0.77)]
        case 2: [("clouds", 0.50, 0.28), ("ridge", 0.50, 0.57)]
        case 3: [("hair", 0.48, 0.57), ("sky", 0.50, 0.28)]
        case 4: [("stone", 0.50, 0.68), ("dark", 0.30, 0.45)]
        case 5: [("wall", 0.50, 0.30), ("table-shadow", 0.50, 0.70)]
        case 6: [("dress", 0.50, 0.68), ("wall", 0.26, 0.43)]
        default: [("fabric", 0.50, 0.58), ("water", 0.50, 0.25)]
        }
    }

    private func tonalReport() throws {
        let tonalCases = cases.filter { $0.name.hasPrefix("TC_") }
        try artifacts.json(tonalCases, "TonalContrast/metrics.json")
        var report = """
        # Lumora — Tonal Contrast Validation

        Generated: \(ISO8601DateFormatter().string(from: Date())). Device: \(gpu.deviceName).
        All rendered outputs use the production `CreativeStackRenderer` or `RenderEngine`,
        in extended linear sRGB, measured as RGBA Float32. PNG contact sheets are sRGB
        presentation files. No Golden Master was created.

        ## Architecture and mathematical contract

        The effect extracts linear Rec.709 luminance Y, blurs it at 0.5r, 1.8r and 5r,
        and forms three Laplacian bands: Y−B₁, B₁−B₂, B₂−B₃. Radius r maps logarithmically
        from 1.2 to 24 photographic pixels on a 3000-pixel long edge. Shadow/midtone/highlight
        weights are continuous smoothstep functions of √B₂. The signed zone gain, multiplied
        by Global, modulates 0.60 fine + 0.30 medium + 0.10 coarse detail. Edge and black-level
        gates, highlight/shadow protection and a bounded luminance delta suppress halos,
        noise and clipping. RGB is scaled by Y′/Y at neutral Saturation to preserve chromaticity;
        Saturation then mixes around the new luminance. All Gaussian and reconstruction stages
        stay in the existing Metal-backed Core Image graph. There is no per-frame CPU readback
        or full-resolution intermediate cache.

        PASS/FAIL below apply only to hard invariants; WARN flags a quality heuristic for
        photographic review. The eight photographs are intentionally **not** judged
        aesthetically. Runtime timings depend on the test machine and include readback.

        ## Summary

        | Case | Status |
        | --- | --- |
        """
        for c in tonalCases { report += "\n| \(c.name) | \(c.status) |" }
        report += "\n\n## Synthetic and pipeline artifacts\n\n"
        for path in ["TonalContrast/TonalContrastTestChart.png", "TonalContrast/Synthetic/contact_sheet.png",
                     "TonalContrast/edge_profile.png", "TonalContrast/frequency_response.png",
                     "TonalContrast/mask_comparison.png",
                     "TonalContrast/stack_order.png", "TonalContrast/Pipeline/comparison.png"] {
            report += "- [\(path)](\(path))\n"
        }
        for c in tonalCases {
            report += "\n## \(c.name) — \(c.status)\n\n"
            for key in c.metrics.keys.sorted() {
                report += String(format: "- `%@`: %.8g\n", key, c.metrics[key]!)
            }
            for check in c.checks {
                report += "- **\(check.status)** \(check.name) [\(check.hard ? "hard invariant" : "quality heuristic")]: \(check.detail)\n"
            }
            for note in c.notes { report += "- \(note)\n" }
            for path in c.images { report += "- [\(path)](\(path))\n" }
        }
        try report.write(to: artifacts.url("TonalContrastValidationReport.md"), atomically: true, encoding: .utf8)
    }
}
