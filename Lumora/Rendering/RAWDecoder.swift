import CoreImage
import ImageIO
import UniformTypeIdentifiers

/// Identifies camera originals before constructing CIRAWFilter. CIRAWFilter's
/// initializer is intentionally permissive and can also accept developed files,
/// so a non-nil filter is not proof that the source is RAW.
enum RAWDecoder {
    private static let cameraExtensions: Set<String> = [
        "3fr", "arw", "cr2", "cr3", "crw", "dcr", "dng", "erf", "fff",
        "iiq", "kdc", "mef", "mos", "mrw", "nef", "nrw", "orf", "pef",
        "raf", "raw", "rw2", "rwl", "sr2", "srf", "srw", "x3f"
    ]

    static func recognizes(_ url: URL) -> Bool {
        if let source = CGImageSourceCreateWithURL(url as CFURL, nil),
           let identifier = CGImageSourceGetType(source),
           let type = UTType(identifier as String), type.conforms(to: .rawImage) {
            return true
        }
        let fileExtension = url.pathExtension.lowercased()
        if let type = UTType(filenameExtension: fileExtension), type.conforms(to: .rawImage) {
            return true
        }
        return cameraExtensions.contains(fileExtension)
    }

    static func filter(_ url: URL) -> CIRAWFilter? {
        recognizes(url) ? CIRAWFilter(imageURL: url) : nil
    }
}
