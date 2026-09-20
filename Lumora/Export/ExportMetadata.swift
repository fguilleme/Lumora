import Foundation
import ImageIO

/// Copy descriptive camera metadata, never stale pixel layout, thumbnails, maker notes or source ICC.
enum ExportMetadata {
    static func properties(source: [CFString: Any], settings: ExportSettings, width: Int, height: Int) -> [CFString: Any] {
        var output: [CFString: Any] = [kCGImagePropertyOrientation: 1]
        if settings.format.supportsQuality { output[kCGImageDestinationLossyCompressionQuality] = settings.validated.quality }
        guard settings.includeMetadata else { return output }
        if var exif = source[kCGImagePropertyExifDictionary] as? [CFString: Any] {
            exif.removeValue(forKey: kCGImagePropertyExifMakerNote)
            exif[kCGImagePropertyExifPixelXDimension] = width
            exif[kCGImagePropertyExifPixelYDimension] = height
            // ImageIO writes the actual output profile; do not retain an incompatible EXIF color-space tag.
            exif[kCGImagePropertyExifColorSpace] = settings.colorSpace == .sRGB ? 1 : 65535
            output[kCGImagePropertyExifDictionary] = exif
        }
        if let tiff = source[kCGImagePropertyTIFFDictionary] as? [CFString: Any] {
            let keys: [CFString] = [kCGImagePropertyTIFFMake, kCGImagePropertyTIFFModel,
                                   kCGImagePropertyTIFFDateTime, kCGImagePropertyTIFFArtist, kCGImagePropertyTIFFCopyright]
            var clean = tiff.filter { keys.contains($0.key) }
            clean[kCGImagePropertyTIFFOrientation] = 1
            clean[kCGImagePropertyTIFFSoftware] = "Lumora"
            output[kCGImagePropertyTIFFDictionary] = clean
        }
        if !settings.removeLocation, let gps = source[kCGImagePropertyGPSDictionary] {
            output[kCGImagePropertyGPSDictionary] = gps
        }
        // XMP/IPTC are intentionally not forwarded: they may duplicate location or stale previews.
        return output
    }
}
