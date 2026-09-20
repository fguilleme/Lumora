import Foundation

struct PhotoDocument: Codable, Sendable, Identifiable {
    var id: UUID
    var originalName: String
    var originalFilename: String
    var createdAt: Date
    var schemaVersion = 1
    var state = EditState()
}

struct LibraryDocument: Sendable, Identifiable {
    var document: PhotoDocument
    var originalURL: URL
    var isFavorite = false
    var folderID: UUID?
    var tagIDs: Set<UUID> = []
    var id: UUID { document.id }
}

struct LibraryFolder: Codable, Sendable, Identifiable, Hashable {
    var id: UUID
    var name: String
}

struct LibraryTag: Codable, Sendable, Identifiable, Hashable {
    var id: UUID
    var name: String
}

enum LibraryScope: Hashable, Sendable {
    case all, favorites, folder(UUID), tag(UUID)
}

enum LibrarySortOrder: String, CaseIterable, Sendable, Identifiable {
    case newest, oldest, name
    var id: String { rawValue }
    var title: String {
        switch self {
        case .newest: "Plus récentes"
        case .oldest: "Plus anciennes"
        case .name: "Nom"
        }
    }
}

enum LibraryQuery {
    static func results(_ documents: [LibraryDocument], search: String,
                        sort: LibrarySortOrder, scope: LibraryScope = .all) -> [LibraryDocument] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        let scoped = documents.filter { document in
            switch scope {
            case .all: true
            case .favorites: document.isFavorite
            case let .folder(id): document.folderID == id
            case let .tag(id): document.tagIDs.contains(id)
            }
        }
        let filtered = query.isEmpty ? scoped : scoped.filter {
            $0.document.originalName.localizedCaseInsensitiveContains(query)
        }
        return filtered.sorted { lhs, rhs in
            switch sort {
            case .newest:
                if lhs.document.createdAt == rhs.document.createdAt { return lhs.id.uuidString < rhs.id.uuidString }
                return lhs.document.createdAt > rhs.document.createdAt
            case .oldest:
                if lhs.document.createdAt == rhs.document.createdAt { return lhs.id.uuidString < rhs.id.uuidString }
                return lhs.document.createdAt < rhs.document.createdAt
            case .name:
                let comparison = lhs.document.originalName.localizedStandardCompare(rhs.document.originalName)
                return comparison == .orderedSame ? lhs.id.uuidString < rhs.id.uuidString : comparison == .orderedAscending
            }
        }
    }
}

enum LibraryError: LocalizedError {
    case invalidFolderName, duplicateFolderName, unknownFolder
    case invalidTagName, duplicateTagName, unknownTag
    var errorDescription: String? {
        switch self {
        case .invalidFolderName: "Le nom du dossier ne peut pas être vide."
        case .duplicateFolderName: "Un dossier porte déjà ce nom."
        case .unknownFolder: "Ce dossier n’existe plus."
        case .invalidTagName: "Le nom de l’étiquette ne peut pas être vide."
        case .duplicateTagName: "Une étiquette porte déjà ce nom."
        case .unknownTag: "Cette étiquette n’existe plus."
        }
    }
}

enum PhotoError: LocalizedError {
    case unreadable, renderFailed, incompatibleDocument
    var errorDescription: String? {
        switch self {
        case .unreadable: "Cette image ne peut pas être décodée. Vérifiez son format et sa disponibilité locale."
        case .renderFailed: "Le moteur n’a pas pu produire l’image."
        case .incompatibleDocument: "Ce développement provient d’une version non prise en charge."
        }
    }
}
