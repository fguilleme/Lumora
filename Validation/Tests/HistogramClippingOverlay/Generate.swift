// Compile with -O and Histogram.swift, HistogramClippingOverlay.swift and HistogramView.swift.
// Rendered photos are diagnostic inputs, not exported Lumora documents.
import AppKit
import ImageIO
import SwiftUI
import Darwin.Mach

@main struct HistogramClippingArtifacts {
    @MainActor static func main() throws {
        _ = NSApplication.shared
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let target = root.appendingPathComponent("Validation/HistogramClippingOverlay")
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)

        let photos = [
            ("01_shadows", "Validation/AutoStressCorpus/01_dark_indoor_portrait.png"),
            ("02_highlights", "Validation/AutoStressCorpus/02_overexposed_beach_portrait.png"),
            ("08_night", "Validation/AutoStressCorpus/08_high_iso_rainy_night.png")
        ]
        for (name, path) in photos {
            let image = try load(root.appendingPathComponent(path))
            let pair = [("Normal", render(image, showMask: false, expanded: true)),
                        ("Appui long — clipping SDR", render(image, showMask: true, expanded: true))]
            try save(sheet(pair, columns: 2, tile: CGSize(width: 390, height: 570)),
                     to: target.appendingPathComponent("\(name).png"))
        }
        let portrait = try load(root.appendingPathComponent("Validation/AutoStressCorpus/01_dark_indoor_portrait.png"))
        try save(render(portrait, showMask: true, expanded: false),
                 to: target.appendingPathComponent("compact_overlay.png"))
        try save(render(portrait, showMask: true, expanded: true),
                 to: target.appendingPathComponent("expanded_overlay.png"))

        let synthetic: [(String, CGImage)] = [
            ("Noir", make8 { _, _ in (0, 0, 0) }),
            ("Blanc", make8 { _, _ in (255, 255, 255) }),
            ("Gradient", make8 { x, _ in let v = UInt8(x * 255 / 159); return (v, v, v) }),
            ("Patch noir", make8 { x, y in x < 30 && y < 30 ? (0, 0, 0) : (90, 90, 90) }),
            ("Un pixel blanc", make8 { x, y in x == 25 && y == 25 ? (255, 255, 255) : (90, 90, 90) }),
            ("R seulement", make8 { _, _ in (255, 80, 80) }),
            ("G seulement", make8 { _, _ in (80, 255, 80) }),
            ("B seulement", make8 { _, _ in (80, 80, 255) })
        ]
        let syntheticTiles = synthetic.map { name, image in
            (name, render(image, showMask: true, expanded: false,
                          canvas: CGSize(width: 320, height: 260)))
        }
        try save(sheet(syntheticTiles, columns: 2, tile: CGSize(width: 340, height: 300)),
                 to: target.appendingPathComponent("synthetic_cases.png"))

        let medium = scaled(portrait, longSide: 960)
        let high = scaled(portrait, longSide: 2048)
        let mediumTimes = times(12) { _ = HistogramClippingOverlay.make(from: medium) }
        let highTimes = times(12) { _ = HistogramClippingOverlay.make(from: high) }
        let readyMask = HistogramClippingOverlay.make(from: medium)
        let plainFrameTimes = times(6) {
            autoreleasepool { _ = render(medium, showMask: false, expanded: false).tiffRepresentation }
        }
        let overlayFrameTimes = times(6) {
            autoreleasepool { _ = render(medium, showMask: true, expanded: false,
                                         precomputedMask: readyMask).tiffRepresentation }
        }
        let before = residentBytes()
        for _ in 0..<35 { autoreleasepool { _ = HistogramClippingOverlay.make(from: medium) } }
        let after = residentBytes()
        let metrics: [String: Any] = [
            "platform": "Apple M2 Pro, macOS; CPU sRGB8 preview diagnostic",
            "activationMask960MedianMs": mediumTimes.sorted()[mediumTimes.count / 2],
            "activationMask2048MedianMs": highTimes.sorted()[highTimes.count / 2],
            "plainFrame960MedianMs": plainFrameTimes.sorted()[plainFrameTimes.count / 2],
            "overlayFrame960MedianMs": overlayFrameTimes.sorted()[overlayFrameTimes.count / 2],
            "activationLongPressThresholdMs": 350,
            "releaseStateUpdate": "synchronous on gesture release; next SwiftUI frame",
            "storedMaskBytes960": medium.width * medium.height * 4,
            "storedMaskBytes2048": high.width * high.height * 4,
            "rssBefore35CyclesBytes": before,
            "rssAfter35CyclesBytes": after,
            "rssDelta35CyclesBytes": after - before
        ]
        let data = try JSONSerialization.data(withJSONObject: metrics, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: target.appendingPathComponent("measurements.json"))
        print(String(data: data, encoding: .utf8) ?? "")
    }

    private static func load(_ url: URL) throws -> CGImage {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw NSError(domain: "HistogramClippingArtifacts", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Cannot load \(url.path)"])
        }
        return image
    }

    @MainActor private static func render(_ image: CGImage, showMask: Bool,
                                          expanded: Bool, canvas: CGSize = CGSize(width: 360, height: 520),
                                          precomputedMask: CGImage? = nil) -> NSImage {
        let mask = showMask ? (precomputedMask ?? HistogramClippingOverlay.make(from: image)) : nil
        let photo = Image(decorative: image, scale: 1).resizable().aspectRatio(contentMode: .fit)
            .frame(width: canvas.width, height: canvas.height)
            .overlay {
                if let mask {
                    Image(decorative: mask, scale: 1).resizable().aspectRatio(contentMode: .fit)
                        .frame(width: canvas.width, height: canvas.height)
                }
            }
            .background(Color.black)
            .overlay {
                HistogramView(histogram: Histogram.compute(image),
                              imageSize: CGSize(width: image.width, height: image.height),
                              initiallyExpanded: expanded)
            }
        let renderer = ImageRenderer(content: photo)
        renderer.scale = 2
        return renderer.nsImage!
    }

    private static func make8(_ pixel: (Int, Int) -> (UInt8, UInt8, UInt8)) -> CGImage {
        let side = 160
        var bytes = [UInt8](repeating: 255, count: side * side * 4)
        for y in 0..<side { for x in 0..<side {
            let (r, g, b) = pixel(x, y)
            let index = (y * side + x) * 4
            bytes[index] = r; bytes[index + 1] = g; bytes[index + 2] = b
        } }
        return bytes.withUnsafeMutableBytes { buffer in
            let context = CGContext(data: buffer.baseAddress, width: side, height: side,
                                    bitsPerComponent: 8, bytesPerRow: side * 4,
                                    space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            return context.makeImage()!
        }
    }

    private static func scaled(_ image: CGImage, longSide: Int) -> CGImage {
        let factor = Double(longSide) / Double(max(image.width, image.height))
        let width = Int((Double(image.width) * factor).rounded())
        let height = Int((Double(image.height) * factor).rounded())
        let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()!
    }

    private static func sheet(_ items: [(String, NSImage)], columns: Int, tile: CGSize) -> NSImage {
        let rows = (items.count + columns - 1) / columns
        let image = NSImage(size: CGSize(width: tile.width * CGFloat(columns),
                                         height: tile.height * CGFloat(rows)))
        image.lockFocus()
        NSColor(calibratedWhite: 0.08, alpha: 1).setFill()
        NSRect(origin: .zero, size: image.size).fill()
        for (index, item) in items.enumerated() {
            let x = CGFloat(index % columns) * tile.width
            let y = CGFloat(rows - index / columns - 1) * tile.height
            item.1.draw(in: CGRect(x: x + 10, y: y + 10, width: tile.width - 20, height: tile.height - 40))
            (item.0 as NSString).draw(in: CGRect(x: x + 10, y: y + tile.height - 27,
                                                 width: tile.width - 20, height: 20),
                                      withAttributes: [.font: NSFont.systemFont(ofSize: 13, weight: .semibold),
                                                       .foregroundColor: NSColor.white])
        }
        image.unlockFocus()
        return image
    }

    private static func save(_ image: NSImage, to url: URL) throws {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "HistogramClippingArtifacts", code: 2)
        }
        try png.write(to: url)
    }

    private static func times(_ count: Int, work: () -> Void) -> [Double] {
        (0..<count).map { _ in
            let start = ContinuousClock.now
            work()
            let duration = start.duration(to: .now)
            return Double(duration.components.seconds) * 1_000
                + Double(duration.components.attoseconds) / 1e15
        }
    }

    private static func residentBytes() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size)
        let status = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        return status == KERN_SUCCESS ? Int64(info.resident_size) : -1
    }
}
