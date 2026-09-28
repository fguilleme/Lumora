import CoreTransferable
import Foundation
import UniformTypeIdentifiers

struct ImportedPhoto: Transferable, Sendable {
    let url: URL
    static var transferRepresentation: some TransferRepresentation {
        // Ask Photos for the original RAW resource before accepting a developed
        // image representation. This preserves third-party camera files instead
        // of silently receiving a JPEG rendered by the photo library.
        FileRepresentation(importedContentType: .rawImage) { received in
            try copy(received.file)
        }
        FileRepresentation(importedContentType: .image) { received in
            try copy(received.file)
        }
    }

    private static func copy(_ source: URL) throws -> ImportedPhoto {
        let directory = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let destination = directory.appendingPathComponent(source.lastPathComponent)
        try FileManager.default.copyItem(at: source, to: destination)
        return ImportedPhoto(url: destination)
    }
}
