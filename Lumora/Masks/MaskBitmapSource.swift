import Foundation
import CoreGraphics

struct MaskBitmapSource {
    let width: Int
    let height: Int
    let rowBytes: Int
    let rgba: [UInt8]

    init?(image: CGImage, maximumDimension: Int) {
        guard image.width > 0, image.height > 0, maximumDimension > 0 else { return nil }
        let scale = min(1, CGFloat(maximumDimension) / CGFloat(max(image.width, image.height)))
        let targetWidth = max(1, Int((CGFloat(image.width) * scale).rounded()))
        let targetHeight = max(1, Int((CGFloat(image.height) * scale).rounded()))
        let targetRowBytes = targetWidth * 4
        var pixels = [UInt8](repeating: 0, count: targetRowBytes * targetHeight)
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
            | CGBitmapInfo.byteOrder32Big.rawValue
        let success = pixels.withUnsafeMutableBytes { storage -> Bool in
            guard let context = CGContext(data: storage.baseAddress,
                                          width: targetWidth, height: targetHeight,
                                          bitsPerComponent: 8, bytesPerRow: targetRowBytes,
                                          space: colorSpace, bitmapInfo: bitmapInfo) else { return false }
            context.interpolationQuality = .high
            context.draw(image, in: CGRect(x: 0, y: 0,
                                           width: targetWidth, height: targetHeight))
            return true
        }
        guard success else { return nil }
        width = targetWidth
        height = targetHeight
        rowBytes = targetRowBytes
        rgba = pixels
    }

    func rgb(x: Int, y: Int) -> (red: Float, green: Float, blue: Float) {
        let offset = y * rowBytes + x * 4
        return (Float(rgba[offset]) / 255,
                Float(rgba[offset + 1]) / 255,
                Float(rgba[offset + 2]) / 255)
    }

    func grayImage(_ values: [UInt8]) -> CGImage? {
        guard values.count == width * height,
              let provider = CGDataProvider(data: Data(values) as CFData),
              let gray = CGColorSpace(name: CGColorSpace.linearGray) else { return nil }
        return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 8,
                       bytesPerRow: width, space: gray,
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: true,
                       intent: .defaultIntent)
    }
}
