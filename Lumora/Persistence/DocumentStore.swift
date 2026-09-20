import Foundation

/// Owns one private, immutable original per import, plus a small atomic JSON sidecar.
actor DocumentStore {
    private let root: URL
    private var revisions: [UUID: Int] = [:]
    private var deleted: Set<UUID> = []
    init(root: URL = URL.applicationSupportDirectory.appendingPathComponent("Lumora", isDirectory: true)) {
        self.root = root
    }
    func originalURL(for document: PhotoDocument) -> URL {
        root.appendingPathComponent(document.id.uuidString).appendingPathComponent(document.originalFilename)
    }
    func importPhoto(at source: URL) throws -> PhotoDocument {
        let scoped = source.startAccessingSecurityScopedResource()
        defer { if scoped { source.stopAccessingSecurityScopedResource() } }
        let id = UUID()
        let filename = "original." + (source.pathExtension.isEmpty ? "image" : source.pathExtension)
        let document = PhotoDocument(id: id, originalName: source.lastPathComponent, originalFilename: filename, createdAt: Date())
        let directory = root.appendingPathComponent(id.uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        do {
            try FileManager.default.copyItem(at: source, to: originalURL(for: document))
            try save(document, revision: 0)
        } catch {
            try? FileManager.default.removeItem(at: directory)
            throw error
        }
        return document
    }
    func save(_ document: PhotoDocument, revision: Int) throws {
        guard !deleted.contains(document.id) else { return }
        guard revision >= (revisions[document.id] ?? 0) else { return }
        let url = root.appendingPathComponent(document.id.uuidString).appendingPathComponent("edits.json")
        try JSONEncoder().encode(document).write(to: url, options: .atomic)
        revisions[document.id] = revision
    }
    func select(_ document: PhotoDocument) throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data(document.id.uuidString.utf8).write(to: root.appendingPathComponent("last.txt"), options: .atomic)
    }
    func list() throws -> [PhotoDocument] {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let urls = try FileManager.default.contentsOfDirectory(
            at: root, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
        return urls.compactMap { directory in
            guard (try? directory.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true,
                  let id = UUID(uuidString: directory.lastPathComponent),
                  let document = try? load(id),
                  FileManager.default.fileExists(atPath: originalURL(for: document).path)
            else { return nil }
            return document
        }.sorted { lhs, rhs in
            if lhs.createdAt == rhs.createdAt { return lhs.id.uuidString < rhs.id.uuidString }
            return lhs.createdAt > rhs.createdAt
        }
    }
    func load(_ id: UUID) throws -> PhotoDocument {
        let url = root.appendingPathComponent(id.uuidString).appendingPathComponent("edits.json")
        var document = try JSONDecoder().decode(PhotoDocument.self, from: Data(contentsOf: url))
        guard document.id == id, document.schemaVersion == 1 else { throw PhotoError.incompatibleDocument }
        document.state = document.state.validated
        return document
    }
    func isFavorite(_ id: UUID) -> Bool {
        FileManager.default.fileExists(atPath: favoriteURL(for: id).path)
    }
    func setFavorite(_ favorite: Bool, for id: UUID) throws {
        let directory = root.appendingPathComponent(id.uuidString)
        guard FileManager.default.fileExists(atPath: directory.path) else {
            throw CocoaError(.fileNoSuchFile)
        }
        let url = favoriteURL(for: id)
        if favorite { try Data().write(to: url, options: .atomic) }
        else if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
    }
    func setFavorites(_ favorite: Bool, for ids: Set<UUID>) throws {
        try validateDocuments(ids)
        for id in sorted(ids) { try setFavorite(favorite, for: id) }
    }
    func folders() throws -> [LibraryFolder] {
        let url = foldersURL
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        return try JSONDecoder().decode([LibraryFolder].self, from: Data(contentsOf: url))
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
    func createFolder(named proposedName: String) throws -> LibraryFolder {
        let name = proposedName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw LibraryError.invalidFolderName }
        var existing = try folders()
        guard !existing.contains(where: { $0.name.compare(name, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame })
        else { throw LibraryError.duplicateFolderName }
        let folder = LibraryFolder(id: UUID(), name: name)
        existing.append(folder)
        try saveFolders(existing)
        return folder
    }
    func deleteFolder(_ id: UUID) throws {
        var existing = try folders()
        existing.removeAll { $0.id == id }
        try saveFolders(existing)
        for document in try list() where folderID(for: document.id) == id {
            try setFolder(nil, for: document.id)
        }
    }
    func folderID(for id: UUID) -> UUID? {
        guard let data = try? Data(contentsOf: folderURL(for: id)),
              let text = String(data: data, encoding: .utf8)
        else { return nil }
        return UUID(uuidString: text.trimmingCharacters(in: .whitespacesAndNewlines))
    }
    func setFolder(_ folderID: UUID?, for id: UUID) throws {
        let directory = root.appendingPathComponent(id.uuidString)
        guard FileManager.default.fileExists(atPath: directory.path) else {
            throw CocoaError(.fileNoSuchFile)
        }
        let url = folderURL(for: id)
        if let folderID {
            guard try folders().contains(where: { $0.id == folderID }) else { throw LibraryError.unknownFolder }
            try Data(folderID.uuidString.utf8).write(to: url, options: .atomic)
        } else if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }
    func setFolder(_ folderID: UUID?, for ids: Set<UUID>) throws {
        try validateDocuments(ids)
        if let folderID {
            guard try folders().contains(where: { $0.id == folderID }) else { throw LibraryError.unknownFolder }
        }
        for id in sorted(ids) { try setFolder(folderID, for: id) }
    }
    func tags() throws -> [LibraryTag] {
        guard FileManager.default.fileExists(atPath: tagsURL.path) else { return [] }
        return try JSONDecoder().decode([LibraryTag].self, from: Data(contentsOf: tagsURL))
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
    func createTag(named proposedName: String) throws -> LibraryTag {
        let name = proposedName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw LibraryError.invalidTagName }
        var existing = try tags()
        guard !existing.contains(where: { $0.name.compare(name, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame })
        else { throw LibraryError.duplicateTagName }
        let tag = LibraryTag(id: UUID(), name: name)
        existing.append(tag)
        try saveTags(existing)
        return tag
    }
    func deleteTag(_ id: UUID) throws {
        var existing = try tags()
        existing.removeAll { $0.id == id }
        try saveTags(existing)
        for document in try list() where tagIDs(for: document.id).contains(id) {
            try setTag(id, enabled: false, for: document.id)
        }
    }
    func tagIDs(for id: UUID) -> Set<UUID> {
        guard let data = try? Data(contentsOf: documentTagsURL(for: id)),
              let ids = try? JSONDecoder().decode([UUID].self, from: data)
        else { return [] }
        return Set(ids)
    }
    func setTag(_ tagID: UUID, enabled: Bool, for id: UUID) throws {
        let directory = root.appendingPathComponent(id.uuidString)
        guard FileManager.default.fileExists(atPath: directory.path) else {
            throw CocoaError(.fileNoSuchFile)
        }
        var assigned = tagIDs(for: id)
        if enabled {
            guard try tags().contains(where: { $0.id == tagID }) else { throw LibraryError.unknownTag }
            assigned.insert(tagID)
        } else {
            assigned.remove(tagID)
        }
        let url = documentTagsURL(for: id)
        if assigned.isEmpty {
            if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
        } else {
            try JSONEncoder().encode(assigned.sorted { $0.uuidString < $1.uuidString }).write(to: url, options: .atomic)
        }
    }
    func setTag(_ tagID: UUID, enabled: Bool, for ids: Set<UUID>) throws {
        try validateDocuments(ids)
        if enabled {
            guard try tags().contains(where: { $0.id == tagID }) else { throw LibraryError.unknownTag }
        }
        for id in sorted(ids) { try setTag(tagID, enabled: enabled, for: id) }
    }
    func delete(_ id: UUID) throws {
        deleted.insert(id)
        let directory = root.appendingPathComponent(id.uuidString)
        if FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.removeItem(at: directory)
        }
        revisions.removeValue(forKey: id)
        let last = root.appendingPathComponent("last.txt")
        if let selected = try? String(contentsOf: last, encoding: .utf8),
           selected.trimmingCharacters(in: .whitespacesAndNewlines) == id.uuidString {
            try? FileManager.default.removeItem(at: last)
        }
    }
    func delete(_ ids: Set<UUID>) throws {
        for id in sorted(ids) { try delete(id) }
    }
    func restore() throws -> PhotoDocument? {
        let last = root.appendingPathComponent("last.txt")
        guard FileManager.default.fileExists(atPath: last.path) else { return nil }
        let text = try String(contentsOf: last, encoding: .utf8)
        guard let id = UUID(uuidString: text) else { throw PhotoError.incompatibleDocument }
        return try load(id)
    }
    private func favoriteURL(for id: UUID) -> URL {
        root.appendingPathComponent(id.uuidString).appendingPathComponent("favorite")
    }
    private var foldersURL: URL { root.appendingPathComponent("folders.json") }
    private var tagsURL: URL { root.appendingPathComponent("tags.json") }
    private func folderURL(for id: UUID) -> URL {
        root.appendingPathComponent(id.uuidString).appendingPathComponent("folder.txt")
    }
    private func saveFolders(_ folders: [LibraryFolder]) throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try JSONEncoder().encode(folders).write(to: foldersURL, options: .atomic)
    }
    private func documentTagsURL(for id: UUID) -> URL {
        root.appendingPathComponent(id.uuidString).appendingPathComponent("tags.json")
    }
    private func saveTags(_ tags: [LibraryTag]) throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try JSONEncoder().encode(tags).write(to: tagsURL, options: .atomic)
    }
    private func validateDocuments(_ ids: Set<UUID>) throws {
        for id in ids where !FileManager.default.fileExists(atPath: root.appendingPathComponent(id.uuidString).path) {
            throw CocoaError(.fileNoSuchFile)
        }
    }
    private func sorted(_ ids: Set<UUID>) -> [UUID] {
        ids.sorted { $0.uuidString < $1.uuidString }
    }
}
