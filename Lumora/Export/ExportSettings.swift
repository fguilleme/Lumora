import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

enum ExportFormat: String, CaseIterable, Codable, Sendable, Identifiable {
    case jpeg, heic, png, tiff
    var id: String { rawValue }
    var title: String { rawValue.uppercased() }
    var type: UTType {
        switch self { case .jpeg: .jpeg; case .heic: .heic; case .png: .png; case .tiff: .tiff }
    }
    var filenameExtension: String { self == .jpeg ? "jpg" : rawValue }
    var supportsQuality: Bool { self == .jpeg || self == .heic }
    static var available: [Self] {
        let types = CGImageDestinationCopyTypeIdentifiers() as? [String] ?? []
        return allCases.filter { types.contains($0.type.identifier) }
    }
}

enum ExportColorSpace: String, CaseIterable, Codable, Sendable, Identifiable {
    case sRGB, displayP3
    var id: String { rawValue }
    var title: String { self == .sRGB ? "sRGB" : "Display P3" }
    var cgColorSpace: CGColorSpace? {
        CGColorSpace(name: self == .sRGB ? CGColorSpace.sRGB : CGColorSpace.displayP3)
    }
}

struct ExportSettings: Codable, Sendable, Equatable {
    var format: ExportFormat = .jpeg
    var quality: Double = 0.95
    /// Nil retains oriented source dimensions; resizing never upsamples.
    var maximumDimension: Int?
    var colorSpace: ExportColorSpace = .sRGB
    var includeMetadata = true
    var removeLocation = true
    var validated: Self {
        var result = self
        result.quality = quality.isFinite ? min(1, max(0.1, quality)) : 0.95
        if let maximumDimension { result.maximumDimension = min(20000, max(1, maximumDimension)) }
        return result
    }
    func dimensions(width: Int, height: Int) -> (width: Int, height: Int) {
        guard width > 0, height > 0 else { return (1, 1) }
        guard let limit = validated.maximumDimension else { return (width, height) }
        let scale = min(1, Double(limit) / Double(max(width, height)))
        return (max(1, Int((Double(width) * scale).rounded())), max(1, Int((Double(height) * scale).rounded())))
    }
}

struct ExportRequest: Identifiable, Sendable {
    let id = UUID()
    let sourceURL: URL
    let state: EditState
    let name: String
}

struct ExportedPhoto: Sendable {
    let url: URL
    let width: Int
    let height: Int
    let byteCount: Int
}

enum ExportStage: Int, Sendable {
    case decoding, rendering, encoding, finished
    var fraction: Double {
        switch self { case .decoding: 0; case .rendering: 0.2; case .encoding: 0.75; case .finished: 1 }
    }
    var title: String {
        switch self {
        case .decoding: "Lecture de l’original…"
        case .rendering: "Développement haute résolution…"
        case .encoding: "Écriture du fichier…"
        case .finished: "Export terminé"
        }
    }
}

enum ExportError: LocalizedError {
    case unsupportedFormat, encodingFailed
    var errorDescription: String? {
        switch self {
        case .unsupportedFormat: "Ce format n’est pas disponible sur cet appareil."
        case .encodingFailed: "Impossible d’encoder l’image exportée. Essayez un autre format ou des dimensions réduites."
        }
    }
}
