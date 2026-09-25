import Accelerate
import CoreGraphics
import CoreVideo
import Foundation

/// Copies Vision's small instance mask into owned grayscale memory before scaling.
/// This avoids the Metal texture view created by `generateScaledMask`, which can
/// assert when Vision's IOSurface and requested resource options disagree on macOS.
enum InstanceMaskRasterizer {
    enum Failure: Error { case invalidSize, unsupportedPixelFormat, unreadableBuffer, scalingFailed, bitmapCreation }

    static func scaledImage(from buffer: CVPixelBuffer, width: Int, height: Int) throws -> CGImage {
        guard (1...4096).contains(width), (1...4096).contains(height),
              !CVPixelBufferIsPlanar(buffer) else { throw Failure.invalidSize }
        let sourceWidth = CVPixelBufferGetWidth(buffer)
        let sourceHeight = CVPixelBufferGetHeight(buffer)
        guard sourceWidth > 0, sourceHeight > 0 else { throw Failure.invalidSize }
        let format = CVPixelBufferGetPixelFormatType(buffer)
        let bytesPerPixel: Int
        switch format {
        case kCVPixelFormatType_OneComponent8: bytesPerPixel = 1
        case kCVPixelFormatType_OneComponent16Half: bytesPerPixel = 2
        case kCVPixelFormatType_OneComponent32Float: bytesPerPixel = 4
        default: throw Failure.unsupportedPixelFormat
        }
        guard CVPixelBufferGetBytesPerRow(buffer) >= sourceWidth * bytesPerPixel,
              CVPixelBufferLockBaseAddress(buffer, .readOnly) == kCVReturnSuccess else {
            throw Failure.unreadableBuffer
        }
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(buffer) else { throw Failure.unreadableBuffer }

        let rowBytes = CVPixelBufferGetBytesPerRow(buffer)
        var pixels = [UInt8](repeating: 0, count: sourceWidth * sourceHeight)
        for y in 0..<sourceHeight {
            let row = base.advanced(by: y * rowBytes)
            for x in 0..<sourceWidth {
                let value: Float
                switch format {
                case kCVPixelFormatType_OneComponent8:
                    value = Float(row.load(fromByteOffset: x, as: UInt8.self)) / 255
                case kCVPixelFormatType_OneComponent16Half:
                    value = Float(Float16(bitPattern: row.load(fromByteOffset: x * 2, as: UInt16.self)))
                default:
                    value = row.load(fromByteOffset: x * 4, as: Float.self)
                }
                pixels[y * sourceWidth + x] = UInt8((max(0, min(1, value.isFinite ? value : 0)) * 255).rounded())
            }
        }
        var scaled = [UInt8](repeating: 0, count: width * height)
        let scaleResult = pixels.withUnsafeMutableBytes { sourceBytes in
            scaled.withUnsafeMutableBytes { targetBytes in
                var source = vImage_Buffer(data: sourceBytes.baseAddress,
                                           height: vImagePixelCount(sourceHeight),
                                           width: vImagePixelCount(sourceWidth), rowBytes: sourceWidth)
                var target = vImage_Buffer(data: targetBytes.baseAddress,
                                           height: vImagePixelCount(height),
                                           width: vImagePixelCount(width), rowBytes: width)
                return vImageScale_Planar8(&source, &target, nil,
                                           vImage_Flags(kvImageHighQualityResampling))
            }
        }
        guard scaleResult == kvImageNoError else { throw Failure.scalingFailed }
        let gray = CGColorSpaceCreateDeviceGray()
        guard let provider = CGDataProvider(data: Data(scaled) as CFData),
              let result = CGImage(width: width, height: height,
                                   bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: width,
                                   space: gray, bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                                   provider: provider, decode: nil, shouldInterpolate: false,
                                   intent: .defaultIntent)
        else { throw Failure.bitmapCreation }
        return result
    }
}
