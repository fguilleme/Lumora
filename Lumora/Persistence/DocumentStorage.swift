import Foundation

enum DocumentStorageError: LocalizedError {
    case iCloudUnavailable

    var errorDescription: String? {
        switch self {
        case .iCloudUnavailable:
            String(localized: "iCloud Drive is unavailable. Check that iCloud Drive is enabled for this device.")
        }
    }
}

/// Resolves the user-visible Lumora library and moves it without changing the
/// document format. iCloud is deliberately opt-in and remains disabled until a
/// successful move has completed.
enum DocumentStorage {
    static let iCloudEnabledKey = "storage.iCloudEnabled"
    private static let legacyMigrationKey = "storage.documentsMigrationCompleted"
    private static let libraryName = "Lumora"

    static var localRoot: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(libraryName, isDirectory: true)
    }

    static var legacyRoot: URL {
        URL.applicationSupportDirectory.appendingPathComponent(libraryName, isDirectory: true)
    }

    static func activeRoot() -> URL {
        guard UserDefaults.standard.bool(forKey: iCloudEnabledKey),
              let root = try? iCloudRoot() else { return localRoot }
        return root
    }

    static func iCloudRoot() throws -> URL {
        guard let container = FileManager.default.url(forUbiquityContainerIdentifier: nil) else {
            throw DocumentStorageError.iCloudUnavailable
        }
        return container.appendingPathComponent("Documents", isDirectory: true)
            .appendingPathComponent(libraryName, isDirectory: true)
    }

    /// Moves the pre-1.2 library out of Application Support. Presets remain in
    /// their existing store; only photo-library entries belong in Documents.
    static func migrateLegacyLibraryIfNeeded() throws {
        let manager = FileManager.default
        if UserDefaults.standard.bool(forKey: legacyMigrationKey) {
            try manager.createDirectory(at: localRoot, withIntermediateDirectories: true)
            return
        }
        guard manager.fileExists(atPath: legacyRoot.path) else {
            try manager.createDirectory(at: localRoot, withIntermediateDirectories: true)
            UserDefaults.standard.set(true, forKey: legacyMigrationKey)
            return
        }
        try mergeLibrary(from: legacyRoot, into: localRoot)
        try removeMigratedLibraryEntries(from: legacyRoot, verifiedIn: localRoot)
        UserDefaults.standard.set(true, forKey: legacyMigrationKey)
    }

    static func moveLibrary(from source: URL, into destination: URL) throws {
        guard source.standardizedFileURL != destination.standardizedFileURL else { return }
        try mergeLibrary(from: source, into: destination)
    }

    private static func mergeLibrary(from source: URL, into destination: URL) throws {
        let manager = FileManager.default
        try manager.createDirectory(at: destination, withIntermediateDirectories: true)
        guard manager.fileExists(atPath: source.path) else { return }

        let entries = try manager.contentsOfDirectory(
            at: source,
            includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )
        for entry in entries where isLibraryEntry(entry) {
            let target = destination.appendingPathComponent(entry.lastPathComponent,
                                                             isDirectory: entry.hasDirectoryPath)
            try mergeItem(from: entry, into: target)
        }
    }

    private static func isLibraryEntry(_ url: URL) -> Bool {
        if UUID(uuidString: url.lastPathComponent) != nil { return true }
        return ["last.txt", "folders.json", "tags.json"].contains(url.lastPathComponent)
    }

    private static func removeMigratedLibraryEntries(from source: URL, verifiedIn destination: URL) throws {
        let manager = FileManager.default
        let entries = try manager.contentsOfDirectory(
            at: source,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        for entry in entries where isLibraryEntry(entry) {
            let migrated = destination.appendingPathComponent(entry.lastPathComponent,
                                                                isDirectory: entry.hasDirectoryPath)
            guard manager.fileExists(atPath: migrated.path) else { continue }
            try manager.removeItem(at: entry)
        }
    }

    private static func mergeItem(from source: URL, into destination: URL) throws {
        let manager = FileManager.default
        let sourceValues = try source.resourceValues(forKeys: [.isDirectoryKey, .contentModificationDateKey])
        if sourceValues.isDirectory == true {
            try manager.createDirectory(at: destination, withIntermediateDirectories: true)
            for child in try manager.contentsOfDirectory(
                at: source,
                includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
            ) {
                try mergeItem(from: child, into: destination.appendingPathComponent(child.lastPathComponent,
                                                                                     isDirectory: child.hasDirectoryPath))
            }
            return
        }

        guard manager.fileExists(atPath: destination.path) else {
            try manager.copyItem(at: source, to: destination)
            return
        }
        let destinationValues = try destination.resourceValues(forKeys: [.contentModificationDateKey])
        let sourceDate = sourceValues.contentModificationDate ?? .distantPast
        let destinationDate = destinationValues.contentModificationDate ?? .distantPast
        guard sourceDate > destinationDate else { return }
        let temporary = destination.deletingLastPathComponent()
            .appendingPathComponent(".lumora-merge-\(UUID().uuidString)")
        try manager.copyItem(at: source, to: temporary)
        _ = try manager.replaceItemAt(destination, withItemAt: temporary)
    }
}
