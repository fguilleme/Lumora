import Foundation
import Photos
import os

enum PhotosExportError: LocalizedError {
    case accessDenied, albumAccessRequired, ambiguousAlbum, albumUnavailable, saveFailed

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            String(localized: "Allow Lumora to add photos in Settings, or use Share or save.")
        case .albumAccessRequired:
            String(localized: "Saving to an album requires Full Access to Photos in Settings. You can leave the album name empty to save to the library.")
        case .ambiguousAlbum:
            String(localized: "Several albums have this name. Enter a unique album name to choose the destination safely.")
        case .albumUnavailable:
            String(localized: "This album cannot be modified. Choose another album name.")
        case .saveFailed:
            String(localized: "The photo could not be saved to Photos. Your exported file is still available.")
        }
    }
}

enum PhotosExporter {
    static func albumTitle(_ name: String) -> String? {
        let title = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? nil : title
    }

    /// Add the encoded file unchanged. Album membership and asset creation share
    /// one Photos transaction; the export remains available for sharing/retry.
    static func save(_ url: URL, albumName: String) async throws {
        let title = albumTitle(albumName)
        let level: PHAccessLevel = title == nil ? .addOnly : .readWrite
        let status = await PHPhotoLibrary.requestAuthorization(for: level)
        if title != nil {
            guard status == .authorized else { throw PhotosExportError.albumAccessRequired }
        } else {
            guard status == .authorized || status == .limited else { throw PhotosExportError.accessDenied }
        }
        try Task.checkCancellation()

        let existing: PHAssetCollection?
        if let title {
            let options = PHFetchOptions()
            options.predicate = NSPredicate(format: "title == %@", title)
            let matches = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumRegular, options: options)
            guard matches.count <= 1 else { throw PhotosExportError.ambiguousAlbum }
            existing = matches.firstObject
            if let existing, !existing.canPerform(.addContent) { throw PhotosExportError.albumUnavailable }
        } else { existing = nil }

        let writeError = OSAllocatedUnfairLock<PhotosExportError?>(initialState: nil)
        try await PHPhotoLibrary.shared().performChanges {
            let album: PHAssetCollectionChangeRequest?
            if let existing {
                guard let request = PHAssetCollectionChangeRequest(for: existing) else {
                    writeError.withLock { $0 = .albumUnavailable }
                    return
                }
                album = request
            } else if let title {
                album = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: title)
            } else { album = nil }

            let asset = PHAssetCreationRequest.forAsset()
            let options = PHAssetResourceCreationOptions()
            options.shouldMoveFile = false
            asset.addResource(with: .photo, fileURL: url, options: options)
            if let album, let placeholder = asset.placeholderForCreatedAsset {
                album.addAssets([placeholder] as NSArray)
            } else if album != nil {
                writeError.withLock { $0 = .saveFailed }
            }
        }
        if let error = writeError.withLock({ $0 }) { throw error }
    }
}
