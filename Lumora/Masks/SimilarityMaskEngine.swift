import CoreGraphics
import CoreImage
import ImageIO
import UniformTypeIdentifiers
import Foundation

enum SimilarityMaskEngine {
    private final class Field: NSObject {
        let values: [UInt8]
        init(_ values: [UInt8]) { self.values = values }
    }
    // NSCache synchronizes object access; configure its budget once rather than
    // mutating it during concurrent sampling and preview renders.
    private final class FieldCache: @unchecked Sendable {
        let storage = NSCache<NSString, Field>()
        init() { storage.totalCostLimit = 16 * 1024 * 1024 }
    }
    private static let fields = FieldCache()

    static func sample(_ point: MaskPoint, image: CGImage, mask: SimilarityMask) throws -> SimilarityMask {
        guard let bitmap = MaskBitmapSource(image: image, maximumDimension: 1536) else { throw PhotoError.renderFailed }
        let point = point.validated
        let x = min(bitmap.width - 1, Int(point.x * Double(bitmap.width)))
        let y = min(bitmap.height - 1, Int(point.y * Double(bitmap.height)))
        let rgb = bitmap.rgb(x: x, y: y)
        let reference = SimilarityMaskRasterizer.lab(red: rgb.red, green: rgb.green, blue: rgb.blue)
        var values = [UInt8](repeating: 0, count: bitmap.width * bitmap.height)
        for row in 0..<bitmap.height {
            for column in 0..<bitmap.width {
                let color = bitmap.rgb(x: column, y: row)
                let difference = SimilarityMaskRasterizer.lab(red: color.red, green: color.green, blue: color.blue) - reference
                let distance = sqrt(difference.x * difference.x + difference.y * difference.y + difference.z * difference.z)
                values[row * bitmap.width + column] = UInt8(min(255, max(0, (distance * 2.55).rounded())))
            }
        }
        guard let gray = bitmap.grayImage(values),
              let data = CFDataCreateMutable(nil, 0),
              let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else {
            throw PhotoError.renderFailed
        }
        CGImageDestinationAddImage(destination, gray, nil)
        guard CGImageDestinationFinalize(destination) else { throw PhotoError.renderFailed }
        var result = mask
        result.fieldID = UUID(); result.distancePNG = data as Data
        result.width = bitmap.width; result.height = bitmap.height
        result.reference = point
        result.red = Double(rgb.red); result.green = Double(rgb.green); result.blue = Double(rgb.blue)
        // A new sample starts the search around the touched region.
        result.influence.center = point
        cache(values, for: result)
        return result.validated
    }

    static func image(_ raw: SimilarityMask, extent: CGRect) throws -> CIImage {
        let mask = raw.validated
        guard !mask.distancePNG.isEmpty else { return CIImage(color: .black).cropped(to: extent) }
        let values: [UInt8]
        if let cached = fields.storage.object(forKey: mask.fieldID.uuidString as NSString) { values = cached.values }
        else {
            guard let source = CGImageSourceCreateWithData(mask.distancePNG as CFData, nil),
                  let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
                  image.width == mask.width, image.height == mask.height,
                  image.bitsPerComponent == 8, image.bitsPerPixel == 8,
                  let bytes = image.dataProvider?.data else { throw PhotoError.renderFailed }
            let storage = bytes as Data
            guard storage.count >= image.bytesPerRow * image.height else { throw PhotoError.renderFailed }
            values = (0..<image.height).flatMap { row in
                Array(storage[(row * image.bytesPerRow)..<(row * image.bytesPerRow + image.width)])
            }
            cache(values, for: mask)
        }
        guard let coverage = SimilarityMaskRasterizer.coverage(distances: values, width: mask.width, height: mask.height,
            seedX: min(mask.width - 1, Int(mask.reference.x * Double(mask.width))),
            seedY: min(mask.height - 1, Int(mask.reference.y * Double(mask.height))),
            centerX: mask.influence.center.x, centerY: mask.influence.center.y,
            radiusX: mask.influence.radiusX, radiusY: mask.influence.radiusY,
            tolerance: mask.tolerance, feather: mask.influence.feather, connected: mask.connected),
              let provider = CGDataProvider(data: Data(coverage) as CFData),
              let space = CGColorSpace(name: CGColorSpace.linearGray),
              let gray = CGImage(width: mask.width, height: mask.height, bitsPerComponent: 8, bitsPerPixel: 8,
                bytesPerRow: mask.width, space: space, bitmapInfo: CGBitmapInfo(rawValue: 0),
                provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent) else { throw PhotoError.renderFailed }
        return CIImage(cgImage: gray).transformed(by: CGAffineTransform(scaleX: extent.width / Double(mask.width),
            y: extent.height / Double(mask.height)))
            .transformed(by: CGAffineTransform(translationX: extent.minX, y: extent.minY)).cropped(to: extent)
    }

    private static func cache(_ values: [UInt8], for mask: SimilarityMask) {
        fields.storage.setObject(Field(values), forKey: mask.fieldID.uuidString as NSString, cost: values.count)
    }
}
