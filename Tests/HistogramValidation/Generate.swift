// Run from the repository root:
// swiftc -parse-as-library Lumora/Rendering/Histogram.swift Lumora/UI/HistogramView.swift \
//   Tests/HistogramValidation/Generate.swift -o /tmp/lumora-histogram-artifacts
// /tmp/lumora-histogram-artifacts
// This renders the production SwiftUI histogram view around diagnostic photos;
// it does not run the photo development renderer.
import AppKit
import CoreImage
import ImageIO
import SwiftUI

@main struct HistogramArtifactGenerator {
    @MainActor static func main() throws {
        _ = NSApplication.shared
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let destination = root.appendingPathComponent("HistogramValidation")
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

        let portrait = try load(root, "AutoStressCorpus/01_dark_indoor_portrait.png")
        let landscapeSource = try load(root, "AutoStressCorpus/07_flat_foggy_landscape.png")
        // The stress-corpus file named "landscape" is actually portrait 2:3.
        // A centered 3:2 crop supplies a genuine horizontal photo for layout checks.
        let landscapeHeight = landscapeSource.width * 2 / 3
        let landscape = landscapeSource.cropping(to: CGRect(x: 0,
            y: (landscapeSource.height - landscapeHeight) / 2,
            width: landscapeSource.width, height: landscapeHeight))!
        let portraitHistogram = Histogram.compute(portrait)
        let landscapeHistogram = Histogram.compute(landscape)
        try png(render(portrait, portraitHistogram, expanded: false, size: CGSize(width: 390, height: 600)),
                at: destination.appendingPathComponent("compact_portrait.png"))
        try png(render(portrait, portraitHistogram, expanded: true, size: CGSize(width: 390, height: 600)),
                at: destination.appendingPathComponent("expanded_portrait.png"))
        try png(render(landscape, landscapeHistogram, expanded: false, size: CGSize(width: 390, height: 400)),
                at: destination.appendingPathComponent("compact_landscape.png"))
        try png(render(landscape, landscapeHistogram, expanded: true, size: CGSize(width: 390, height: 400)),
                at: destination.appendingPathComponent("expanded_landscape.png"))

        let synthetic: [(String, CGImage)] = [
            ("Black", make8 { _, _ in (0, 0, 0) }),
            ("White", make8 { _, _ in (255, 255, 255) }),
            ("18% gray", make8 { _, _ in (118, 118, 118) }),
            ("Gradient 0–1", make8 { x, _ in let v = UInt8(x * 255 / 159); return (v, v, v) }),
            ("Extended 0–4 → SDR", make8 { x, _ in
                let v = UInt8(min(255, x * 4 * 255 / 159)); return (v, v, v)
            }),
            ("R endpoint", make8 { _, _ in (255, 80, 80) }),
            ("G endpoint", make8 { _, _ in (80, 255, 80) }),
            ("B endpoint", make8 { _, _ in (80, 80, 255) }),
            ("Sparse highlight", make8 { x, y in x == 0 && y == 0 ? (255, 80, 80) : (80, 80, 80) }),
            ("Broad highlight", make8 { x, _ in x < 80 ? (255, 80, 80) : (80, 80, 80) })
        ]
        let clippingTiles = synthetic.map { name, image in
            (name, render(image, Histogram.compute(image), expanded: true,
                          size: CGSize(width: 360, height: 240)))
        }
        try png(sheet(clippingTiles, columns: 2, tile: CGSize(width: 380, height: 280)),
                at: destination.appendingPathComponent("clipping_cases.png"))

        let photoPaths = [
            "01_dark_indoor_portrait", "02_overexposed_beach_portrait",
            "08_high_iso_rainy_night", "07_flat_foggy_landscape"
        ]
        var photoTiles = try photoPaths.map { name in
            let image = try load(root, "AutoStressCorpus/\(name).png")
            return (name, render(image, Histogram.compute(image), expanded: true,
                                 size: CGSize(width: 360, height: 270)))
        }
        photoTiles.append(("07_flat_foggy_landscape — horizontal crop",
                           render(landscape, landscapeHistogram, expanded: true,
                                  size: CGSize(width: 360, height: 270))))
        try png(sheet(photoTiles, columns: 2, tile: CGSize(width: 380, height: 310)),
                at: destination.appendingPathComponent("photo_histograms.png"))

        var diagnostics = [[String: Any]]()
        for (name, image) in synthetic {
            diagnostics.append(diagnostic(name, Histogram.compute(image)))
        }
        for name in photoPaths {
            let image = try load(root, "AutoStressCorpus/\(name).png")
            diagnostics.append(diagnostic(name, Histogram.compute(image)))
        }
        diagnostics.append(diagnostic("07_flat_foggy_landscape — horizontal crop", landscapeHistogram))
        try JSONSerialization.data(withJSONObject: diagnostics, options: [.prettyPrinted, .sortedKeys])
            .write(to: destination.appendingPathComponent("clipping_diagnostics.json"))

        let update = timings(iterations: 40) { _ = Histogram.compute(portrait) }
        let compact = timings(iterations: 8) {
            _ = render(portrait, portraitHistogram, expanded: false,
                       size: CGSize(width: 390, height: 600))
        }
        let expanded = timings(iterations: 8) {
            _ = render(portrait, portraitHistogram, expanded: true,
                       size: CGSize(width: 390, height: 600))
        }
        let metrics: [String: Any] = ["platform": "macOS AppKit/SwiftUI, Apple M2 Pro",
                                       "sampleSize": 160 * 160,
                                       "histogramUpdateMedianMs": update,
                                       "compactSnapshotMedianMs": compact,
                                       "expandedSnapshotMedianMs": expanded,
                                       "expandedAdditionalHistogramComputations": 0]
        let data = try JSONSerialization.data(withJSONObject: metrics, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: destination.appendingPathComponent("measurements.json"))
        print(String(data: data, encoding: .utf8) ?? "")
    }

    private static func load(_ root: URL, _ path: String) throws -> CGImage {
        let url = root.appendingPathComponent(path)
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw NSError(domain: "HistogramValidation", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Cannot load \(url.path)"])
        }
        return image
    }

    @MainActor private static func render(_ image: CGImage, _ histogram: Histogram,
                                          expanded: Bool, size: CGSize) -> NSImage {
        let view = Image(decorative: image, scale: 1).resizable().aspectRatio(contentMode: .fit)
            .frame(width: size.width, height: size.height).background(Color.black)
            .overlay {
                HistogramView(histogram: histogram,
                              imageSize: CGSize(width: image.width, height: image.height),
                              initiallyExpanded: expanded)
            }
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        return renderer.nsImage!
    }

    private static func make8(_ pixel: (Int, Int) -> (UInt8, UInt8, UInt8)) -> CGImage {
        let side = 160
        var bytes = [UInt8](repeating: 255, count: side * side * 4)
        for y in 0..<side { for x in 0..<side {
            let (r, g, b) = pixel(x, y)
            let offset = (y * side + x) * 4
            bytes[offset] = r; bytes[offset + 1] = g; bytes[offset + 2] = b
        } }
        return bytes.withUnsafeMutableBytes { buffer in
            let context = CGContext(data: buffer.baseAddress, width: side, height: side,
                                    bitsPerComponent: 8, bytesPerRow: side * 4,
                                    space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            return context.makeImage()!
        }
    }

    private static func sheet(_ tiles: [(String, NSImage)], columns: Int, tile: CGSize) -> NSImage {
        let rows = (tiles.count + columns - 1) / columns
        let result = NSImage(size: CGSize(width: tile.width * CGFloat(columns),
                                          height: tile.height * CGFloat(rows)))
        result.lockFocus()
        NSColor(calibratedWhite: 0.08, alpha: 1).setFill()
        NSRect(origin: .zero, size: result.size).fill()
        for (index, item) in tiles.enumerated() {
            let col = index % columns, row = index / columns
            let x = CGFloat(col) * tile.width
            let y = CGFloat(rows - row - 1) * tile.height
            item.1.draw(in: CGRect(x: x + 10, y: y + 10, width: tile.width - 20, height: tile.height - 40))
            (item.0 as NSString).draw(in: CGRect(x: x + 10, y: y + tile.height - 27,
                                                 width: tile.width - 20, height: 20),
                                      withAttributes: [.font: NSFont.systemFont(ofSize: 13, weight: .semibold),
                                                       .foregroundColor: NSColor.white])
        }
        result.unlockFocus()
        return result
    }

    private static func png(_ image: NSImage, at url: URL) throws {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let bytes = bitmap.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "HistogramValidation", code: 2)
        }
        try bytes.write(to: url)
    }

    private static func timings(iterations: Int, work: () -> Void) -> Double {
        var values = [Double]()
        for _ in 0..<iterations {
            let start = ContinuousClock.now
            work()
            let duration = start.duration(to: .now)
            values.append(Double(duration.components.seconds) * 1_000
                          + Double(duration.components.attoseconds) / 1e15)
        }
        return values.sorted()[iterations / 2]
    }

    private static func diagnostic(_ name: String, _ histogram: Histogram) -> [String: Any] {
        ["case": name, "samples": histogram.samples,
         "shadowEndpointPixels": histogram.shadows,
         "highlightEndpointPixels": histogram.highlights,
         "shadowFraction": histogram.shadowFraction,
         "highlightFraction": histogram.highlightFraction,
         "redBin255": histogram.red[255],
         "greenBin255": histogram.green[255],
         "blueBin255": histogram.blue[255]]
    }
}
