import Foundation
import CoreImage
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
@testable import LumoraCore

struct RealPhotoMeasurement: Codable {
    let pixelCount: Int
    let nonFinitePixels: Int
    let meanLuminanceChange: Double
    let additionalHighlightClippingPercent: Double
    let additionalShadowClippingPercent: Double
    let additionalPerChannelClippingPercent: Double
    let additionalRedClippingPercent: Double
    let additionalGreenClippingPercent: Double
    let additionalBlueClippingPercent: Double
    let meanChromaticityDrift: Double
    let meanSaturationChange: Double
    let meanResidual: Double
    let residualSD: Double
    let chromaVariance: Double
    let spectralCentroid: Double?
}

private struct RealPhotoVariant {
    let id: String
    let title: String
    let kind: CreativeEffectKind
    let parameters: [String: Double]
}

extension LumoraVisualTestLab {
    private static let keyVariants: [RealPhotoVariant] = {
        let names = ["standard", "dynamic", "strong_dynamic", "protection", "glow"]
        let base: [[String: Double]] = [
            ["amount": 50, "dynamic": 0, "glow": 0],
            ["amount": 50, "dynamic": 50, "glow": 0],
            ["amount": 90, "dynamic": 90, "glow": 0],
            ["amount": 90, "dynamic": 50, "glow": 0],
            ["amount": 50, "dynamic": 50, "glow": 50]
        ]
        var result: [RealPhotoVariant] = []
        for kind in [CreativeEffectKind.highKey, .lowKey] {
            for index in names.indices {
                var parameters = base[index]
                if index == 3 { parameters[kind == .highKey ? "lightProtection" : "darkProtection"] = 100 }
                result.append(.init(id: "\(kind.rawValue)_\(names[index])",
                                    title: ["Standard", "Dynamic", "Strong Dynamic", kind == .highKey ? "Highlight Protection" : "Shadow Protection", "Glow"][index],
                                    kind: kind, parameters: parameters))
            }
        }
        return result
    }()

    private static let grainVariants: [RealPhotoVariant] = [
        .init(id: "grain_fine", title: "Fine", kind: .grain,
              parameters: ["amount": 50, "size": 12, "hardness": 30, "softness": 25, "clumping": 15]),
        .init(id: "grain_medium", title: "Medium", kind: .grain,
              parameters: ["amount": 50, "size": 35, "hardness": 45, "softness": 25, "clumping": 30]),
        .init(id: "grain_large", title: "Large", kind: .grain,
              parameters: ["amount": 50, "size": 75, "hardness": 45, "softness": 25, "clumping": 30]),
        .init(id: "grain_soft", title: "Soft", kind: .grain,
              parameters: ["amount": 50, "size": 35, "hardness": 25, "softness": 80, "clumping": 30]),
        .init(id: "grain_hard", title: "Hard", kind: .grain,
              parameters: ["amount": 50, "size": 35, "hardness": 85, "softness": 5, "clumping": 30]),
        .init(id: "grain_strong_clumping", title: "Strong Clumping", kind: .grain,
              parameters: ["amount": 50, "size": 35, "hardness": 45, "softness": 25, "clumping": 90])
    ]

    /// Independent manual-inspection campaign. All effects use the production
    /// CreativeStackRenderer; this method assigns no photographic PASS/WARN.
    func runRealPhotos() throws -> Int {
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let assets = URL(fileURLWithPath: ProcessInfo.processInfo.environment["LUMORA_VISUAL_ASSETS"] ?? repo.appendingPathComponent("VisualTestAssets").path)
        let files = try FileManager.default.contentsOfDirectory(at: assets, includingPropertiesForKeys: [.isRegularFileKey])
            .filter { ["png", "jpg", "jpeg", "tif", "tiff", "heic", "dng"].contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        guard !files.isEmpty else { throw NSError(domain: "LumoraVisualTestLab", code: 21,
            userInfo: [NSLocalizedDescriptionKey: "No supported photographs in \(assets.path)"]) }
        var report = """
        # Lumora — validation photographique manuelle des Creative FX

        Photographies : \(files.count). Rendu : vrai `CreativeStackRenderer` et `FXBlend` de Lumora,
        sur `CIContext` Metal en sRGB linéaire étendu / RGBA Float32. Images d'examen : PNG sRGB 16 bits.
        Aucune appréciation esthétique, aucun seuil de qualité et aucun Golden Master.

        Les variantes High/Low Key gardent les valeurs par défaut du catalogue pour tout
        paramètre non indiqué ci-dessous. Pour le grain, `amount=50` dans toutes les variantes ;
        les autres paramètres non indiqués gardent également les valeurs du catalogue.
        Les JSON de paramètres par variante contiennent **toutes** les valeurs effectives.

        `meanLuminanceChange` et `meanResidual` = moyenne(output − input) en luminance linéaire.
        `residualSD` = écart-type de cette différence sur toute la photo.
        `spectralCentroid` = fréquence spatiale du résiduel, calculée sur le crop central natif 256×256.
        `chromaVariance` = variance de (ΔR − ΔG) sur toute la photo.
        `meanChromaticityDrift` = moyenne, par pixel et par canal, de |RGB/sommeRGB après − avant|,
        sur les pixels dont les deux sommes positives dépassent 1e−8.
        Saturation = (max(R,G,B) − min(R,G,B))/max(max(R,G,B),1e−6), en RGB linéaire positif ;
        `meanSaturationChange` = moyenne(après − avant).
        Écrêtage luminance haute : Y≥1 ; noir : Y≤1e−6 ; canal : valeur≥1−1e−6.
        Les comptes « additional » sont faits pixel par pixel : l'entrée doit être sous le seuil
        correspondant. Pour chaque canal, seul l'écrêtage nouveau **de ce canal** est compté.
        L'overlay transparent code en rouge tout nouvel écrêtage haut de luminance ou de canal,
        en bleu tout nouvel écrêtage noir ; le rouge prévaut si les deux surviennent au même pixel.
        Tous les pourcentages ont pour dénominateur le nombre de pixels de la photographie.
        Les planches n'agrandissent que pour la présentation ; les crops 100 % conservent 1 pixel photo = 1 pixel planche.

        """
        for (photoIndex, file) in files.enumerated() {
            progress("Real photo \(photoIndex + 1)/\(files.count): \(file.lastPathComponent)")
            try autoreleasepool {
                let name = file.deletingPathExtension().lastPathComponent
                let folder = "RealPhotos/\(name)"
                guard var input = CIImage(contentsOf: file, options: [.applyOrientationProperty: true]) else {
                    throw NSError(domain: "LumoraVisualTestLab", code: 22,
                        userInfo: [NSLocalizedDescriptionKey: "Could not decode \(file.path)"])
                }
                input = input.transformed(by: CGAffineTransform(translationX: -input.extent.minX, y: -input.extent.minY))
                let original = "\(folder)/original.png"
                try artifacts.png(input, original)
                report += "\n## \(file.lastPathComponent) — \(Int(input.extent.width)) × \(Int(input.extent.height))\n\n"
                report += "Source : `\(file.path)` ; [Original](\(original)).\n\n"
                for kind in [CreativeEffectKind.highKey, .lowKey, .grain] {
                    let variants = (kind == .grain ? Self.grainVariants : Self.keyVariants.filter { $0.kind == kind })
                    var sheet: [(String, CIImage)] = [("Original", input)]
                    let category = kind == .highKey ? "HighKey" : kind == .lowKey ? "LowKey" : "Grain"
                    report += "### \(category)\n\n"
                    report += "| Variante | Paramètres effectifs | Δ luminance | Écrêtage haut ajouté | Noir ajouté | Canal ajouté | Dérive chromatique | Δ saturation | Moy. résidu | SD résidu | Centroïde spectral | Variance chroma | Images |\n"
                    report += "| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |\n"
                    for variant in variants {
                        try autoreleasepool {
                            let fx = effect(variant.kind, variant.parameters).validated
                            let settingsText = "enabled=\(fx.enabled), opacity=\(fx.opacity), seed=\(fx.seed), monochromatic=\(fx.monochromatic), mask=\(fx.maskID?.uuidString ?? "none"), "
                                + fx.parameters.keys.sorted().map { String(format: "%@=%g", $0, fx.parameters[$0]!) }.joined(separator: ", ")
                            let output = try render(input, [fx])
                            let prefix = "\(folder)/\(variant.id)"
                            let imagePath = "\(prefix).png"
                            try artifacts.png(output, imagePath)
                            try artifacts.json(fx, "\(prefix)_settings.json")
                            let measured = try measureRealPhoto(input, output, overlayPath: kind == .grain ? nil : "\(prefix)_clipping.png",
                                                                grain: kind == .grain)
                            try artifacts.json(measured, "\(prefix)_metrics.json")
                            let imageLink = "[rendu](\(imagePath)), [paramètres](\(prefix)_settings.json), [mesures](\(prefix)_metrics.json)"
                            let extraLinks = kind == .grain ? ", [crop 100 %](\(prefix)_crop_100percent.png)" : ", [overlay](\(prefix)_clipping.png)"
                            report += String(format: "| %@ | %@ | %+.5f | %.4f %% | %.4f %% | %.4f %% | %.6f | %+.6f | %+.5f | %.5f | %@ | %.8f | %@%@ |\n",
                                variant.title, settingsText, measured.meanLuminanceChange, measured.additionalHighlightClippingPercent,
                                measured.additionalShadowClippingPercent, measured.additionalPerChannelClippingPercent,
                                measured.meanChromaticityDrift, measured.meanSaturationChange, measured.meanResidual,
                                measured.residualSD, measured.spectralCentroid.map { String(format: "%.6f", $0) } ?? "—",
                                measured.chromaVariance, imageLink, extraLinks)
                            if kind == .grain {
                                let crop = nativeCenterCrop(output, side: 512)
                                try artifacts.png(crop, "\(prefix)_crop_100percent.png")
                            }
                            // Reload the encoded presentation PNG so the contact sheet
                            // depicts exactly the file the reviewer opens separately.
                            guard let presented = CIImage(contentsOf: try artifacts.url(imagePath)) else { throw LabError.render }
                            sheet.append((variant.title, presented))
                        }
                    }
                    let sheetPath = "\(folder)/\(category)_contact_sheet.png"
                    try artifacts.sheet(sheet, sheetPath, cell: 960, maxColumns: 3)
                    report += "\n[Planche \(category)](\(sheetPath))"
                    if kind == .grain {
                        let cropSheet = "\(folder)/Grain_crops_100percent.png"
                        try artifacts.sheet(sheet, cropSheet, nativeCrop: true, cell: 512, maxColumns: 4)
                        report += " · [Crops Grain natifs 100 %](\(cropSheet))"
                    }
                    report += "\n\n"
                }
                let overview = "\(folder)/contact_sheet.png"
                let overviewPaths = [original] + (Self.keyVariants + Self.grainVariants).map { "\(folder)/\($0.id).png" }
                let overviewItems = try overviewPaths.map { path -> (String, CIImage) in
                    guard let image = CIImage(contentsOf: try artifacts.url(path)) else { throw LabError.render }
                    return (URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent, image)
                }
                try artifacts.sheet(overviewItems, overview, cell: 768, maxColumns: 4)
                report += "[Planche complète, Original + 16 variantes](\(overview)).\n\n"
            }
        }
        let path = try artifacts.url("RealPhotosValidationReport.md")
        try report.write(to: path, atomically: true, encoding: .utf8)
        return files.count
    }

    private func nativeCenterCrop(_ image: CIImage, side: CGFloat) -> CIImage {
        let width = min(side, image.extent.width), height = min(side, image.extent.height)
        return image.cropped(to: CGRect(x: floor(image.extent.midX - width / 2),
                                      y: floor(image.extent.midY - height / 2), width: width, height: height))
    }

    private func measureRealPhoto(_ input: CIImage, _ output: CIImage, overlayPath: String?, grain: Bool) throws -> RealPhotoMeasurement {
        let bounds = input.extent.integral
        let width = Int(bounds.width), height = Int(bounds.height), pixels = width * height
        var overlay = overlayPath == nil ? [] : [UInt8](repeating: 0, count: pixels * 4)
        var luma = Moments(), residual = Moments(), chroma = Moments(), saturation = Moments()
        var drift = 0.0, driftCount = 0, nonFinite = 0
        var highlight = 0, shadow = 0, channel = 0, red = 0, green = 0, blue = 0
        for row in stride(from: 0, to: height, by: 128) {
            let bandHeight = min(128, height - row)
            let rect = CGRect(x: bounds.minX, y: bounds.minY + CGFloat(row), width: bounds.width, height: CGFloat(bandHeight))
            let before = gpu.read(input, rect), after = gpu.read(output, rect)
            for local in 0..<(width * bandHeight) {
                let p = local * 4
                guard (0..<4).allSatisfy({ before[p + $0].isFinite && after[p + $0].isFinite }) else {
                    nonFinite += 1; continue
                }
                let y0 = LabGPU.luma(before, p), y1 = LabGPU.luma(after, p)
                luma.add(y1 - y0); residual.add(y1 - y0)
                chroma.add(Double(after[p] - before[p] - after[p + 1] + before[p + 1]))
                let channelNew = (0..<3).map { c in before[p + c] < 1 - 1e-6 && after[p + c] >= 1 - 1e-6 }
                red += channelNew[0] ? 1 : 0; green += channelNew[1] ? 1 : 0; blue += channelNew[2] ? 1 : 0
                let newHigh = y0 < 1 && y1 >= 1
                let newLow = y0 > 1e-6 && y1 <= 1e-6
                let newChannel = channelNew.contains(true)
                highlight += newHigh ? 1 : 0; shadow += newLow ? 1 : 0; channel += newChannel ? 1 : 0
                if overlayPath != nil && (newHigh || newChannel || newLow) {
                    let i = (row * width + local) * 4
                    if newHigh || newChannel { overlay[i] = 204; overlay[i + 3] = 204 }
                    else { overlay[i + 2] = 204; overlay[i + 3] = 204 }
                }
                let a = (0..<3).map { max(0, Double(before[p + $0])) }
                let b = (0..<3).map { max(0, Double(after[p + $0])) }
                let sumA = a.reduce(0, +), sumB = b.reduce(0, +)
                if sumA > 1e-8 && sumB > 1e-8 {
                    for c in 0..<3 { drift += abs(a[c] / sumA - b[c] / sumB) }
                    driftCount += 3
                }
                let satA = (a.max()! - a.min()!) / max(a.max()!, 1e-6)
                let satB = (b.max()! - b.min()!) / max(b.max()!, 1e-6)
                saturation.add(satB - satA)
            }
        }
        if let overlayPath { try saveClippingOverlay(overlay, width: width, height: height, path: overlayPath) }
        let centroid: Double?
        if grain {
            let center = nativeCenterCrop(input, side: 256).extent
            centroid = gpu.structure(input, output, region: center).spectralCentroid
        } else { centroid = nil }
        let denominator = Double(max(1, pixels))
        return RealPhotoMeasurement(pixelCount: pixels, nonFinitePixels: nonFinite,
            meanLuminanceChange: luma.mean, additionalHighlightClippingPercent: Double(highlight) * 100 / denominator,
            additionalShadowClippingPercent: Double(shadow) * 100 / denominator,
            additionalPerChannelClippingPercent: Double(channel) * 100 / denominator,
            additionalRedClippingPercent: Double(red) * 100 / denominator,
            additionalGreenClippingPercent: Double(green) * 100 / denominator,
            additionalBlueClippingPercent: Double(blue) * 100 / denominator,
            meanChromaticityDrift: drift / Double(max(1, driftCount)), meanSaturationChange: saturation.mean,
            meanResidual: residual.mean, residualSD: residual.standardDeviation,
            chromaVariance: chroma.variance, spectralCentroid: centroid)
    }

    private func saveClippingOverlay(_ pixels: [UInt8], width: Int, height: Int, path: String) throws {
        let data = Data(pixels) as CFData
        guard let provider = CGDataProvider(data: data),
              let image = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                                  bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                                  provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent),
              let destination = CGImageDestinationCreateWithURL(try artifacts.url(path) as CFURL,
                                                                  UTType.png.identifier as CFString, 1, nil) else { throw LabError.render }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw LabError.render }
    }
}
