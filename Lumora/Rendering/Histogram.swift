import CoreGraphics
import Foundation

struct Histogram: Sendable {
    /// Display histogram: 256 sRGB 8-bit bins after the preview has been rendered
    /// to SDR. Bin 255 includes display white and any brighter values compressed
    /// or clipped by the upstream rendering path; it does not prove RAW clipping.
    static let endpointBin = 255
    static let shadowEndpoint = 1
    static let highlightEndpoint = 254
    var red = [Int](repeating: 0, count: 256)
    var green = [Int](repeating: 0, count: 256)
    var blue = [Int](repeating: 0, count: 256)
    var luminance = [Int](repeating: 0, count: 256)
    var shadows = 0
    var highlights = 0
    var samples = 0

    /// Occupancy of near-black / near-white display endpoints, not sensor clipping.
    var shadowFraction: Double { samples == 0 ? 0 : Double(shadows) / Double(samples) }
    var highlightFraction: Double { samples == 0 ? 0 : Double(highlights) / Double(samples) }

    /// Square-root scaling retains small peaks when a single bin dominates.
    static func displayedHeight(_ count: Int, peak: Int) -> Double {
        sqrt(Double(max(0, count)) / Double(max(1, peak)))
    }

    static func compute(_ image: CGImage) -> Self {
        let width = 160, height = 160
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let success = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let space = CGColorSpace(name: CGColorSpace.sRGB),
                  let context = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                                          bytesPerRow: width * 4, space: space,
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        var result = Self()
        guard success else { return result }
        for i in stride(from: 0, to: bytes.count, by: 4) where bytes[i + 3] > 0 {
            let r = Int(bytes[i]), g = Int(bytes[i + 1]), b = Int(bytes[i + 2])
            result.red[r] += 1; result.green[g] += 1; result.blue[b] += 1
            let redLuma = 0.2126 * Double(r)
            let greenLuma = 0.7152 * Double(g)
            let blueLuma = 0.0722 * Double(b)
            let bin = Int(redLuma + greenLuma + blueLuma)
            result.luminance[bin] += 1
            if max(r, g, b) <= shadowEndpoint { result.shadows += 1 }
            if max(r, g, b) >= highlightEndpoint { result.highlights += 1 }
            result.samples += 1
        }
        return result
    }
}
