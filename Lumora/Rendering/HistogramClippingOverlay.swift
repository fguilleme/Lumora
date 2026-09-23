import CoreGraphics
import Foundation

/// Display-only diagnostic derived from the same SDR/sRGB 8-bit representation
/// and endpoint constants as Histogram. It never enters EditState or export.
enum HistogramClippingOverlay {
    static func make(from preview: CGImage) -> CGImage? {
        let width = preview.width, height = preview.height
        guard width > 0, height > 0 else { return nil }
        let rowBytes = width * 4
        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        var input = [UInt8](repeating: 0, count: rowBytes * height)
        let drawn = input.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: width, height: height,
                                          bitsPerComponent: 8, bytesPerRow: rowBytes, space: space,
                                          bitmapInfo: bitmapInfo) else { return false }
            context.interpolationQuality = .none
            context.draw(preview, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return nil }

        var output = [UInt8](repeating: 0, count: input.count)
        for index in stride(from: 0, to: input.count, by: 4) where input[index + 3] > 0 {
            let red = input[index], green = input[index + 1], blue = input[index + 2]
            // All values below are premultiplied by alpha 145/255. Highlight
            // wins explicitly if a future threshold change makes both true.
            if max(red, green, blue) >= Histogram.highlightEndpoint {
                output[index] = 145; output[index + 1] = 24
                output[index + 2] = 24; output[index + 3] = 145
            } else if max(red, green, blue) <= Histogram.shadowEndpoint {
                output[index] = 20; output[index + 1] = 63
                output[index + 2] = 145; output[index + 3] = 145
            }
        }
        return output.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(data: buffer.baseAddress, width: width, height: height,
                                          bitsPerComponent: 8, bytesPerRow: rowBytes, space: space,
                                          bitmapInfo: bitmapInfo) else { return nil }
            return context.makeImage()
        }
    }
}
