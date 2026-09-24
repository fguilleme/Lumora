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
        case .newest: String(localized: "Newest first")
        case .oldest: String(localized: "Oldest first")
        case .name: String(localized: "Name")
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
        case .invalidFolderName: "The folder name cannot be empty."
        case .duplicateFolderName: "A folder already has that name."
        case .unknownFolder: "This folder no longer exists."
        case .invalidTagName: "The tag name cannot be empty."
        case .duplicateTagName: "A tag already has that name."
        case .unknownTag: "This tag no longer exists."
        }
    }
}

enum PhotoError: LocalizedError {
    case unreadable, renderFailed, incompatibleDocument
    var errorDescription: String? {
        switch self {
        case .unreadable: "This image cannot be decoded. Check its format and local availability."
        case .renderFailed: "The renderer could not produce the image."
        case .incompatibleDocument: "This edit was created by an unsupported version."
        }
    }
}
