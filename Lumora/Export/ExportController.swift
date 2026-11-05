import Foundation
import Observation

@MainActor @Observable
final class ExportController {
    var settings = ExportController.lastSettings() ?? ExportSettings()
    private(set) var result: ExportedPhoto?
    private(set) var stage: ExportStage = .decoding
    private(set) var isExporting = false
    private(set) var isCancelling = false
    private(set) var isSavingToPhotos = false
    private(set) var photosSaveMessage: String?
    private(set) var suggestedMaximumDimension: Int?
    var photosError: String?
    var isBusy: Bool { isExporting || isSavingToPhotos }
    var error: String?
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var generation = 0
    static let directory = URL.temporaryDirectory.appendingPathComponent("LumoraExports", isDirectory: true)
    private static let lastSettingsKey = "export.lastNormalSettings"

    func start(_ request: ExportRequest, using engine: RenderEngine) {
        start(request, using: engine, settings: settings, photosAlbum: nil)
    }

    func startToPhotos(_ request: ExportRequest, using engine: RenderEngine, albumName: String,
                       includeMetadataByDefault: Bool, maximumDimension: Int? = nil) {
        var saved = Self.lastSettings() ?? ExportSettings(includeMetadata: includeMetadataByDefault)
        if let maximumDimension { saved.maximumDimension = maximumDimension }
        start(request, using: engine, settings: saved, photosAlbum: albumName)
    }

    private static func lastSettings() -> ExportSettings? {
        guard let data = UserDefaults.standard.data(forKey: lastSettingsKey) else { return nil }
        return try? JSONDecoder().decode(ExportSettings.self, from: data).validated
    }

    private func start(_ request: ExportRequest, using engine: RenderEngine, settings: ExportSettings, photosAlbum: String?) {
        guard !isBusy else { return }
        generation += 1
        let token = generation, snapshot = settings.validated
        isExporting = true; isCancelling = false; error = nil; stage = .decoding
        suggestedMaximumDimension = nil
        photosSaveMessage = nil; photosError = nil
        let previous = result
        result = nil
        task = Task {
            if let previous { await Self.remove(previous.url) }
            do {
                let photo = try await engine.export(request: request, settings: snapshot, directory: Self.directory) { [weak self] stage in
                    Task { @MainActor in
                        guard let self, self.generation == token, self.isExporting, stage.rawValue >= self.stage.rawValue else { return }
                        self.stage = stage
                    }
                }
                if Task.isCancelled {
                    await Self.remove(photo.url)
                } else {
                    result = photo
                    stage = .finished
                    if let photosAlbum {
                        isExporting = false
                        isCancelling = false
                        await saveToPhotos(albumName: photosAlbum)
                        return
                    }
                    if let data = try? JSONEncoder().encode(snapshot) {
                        UserDefaults.standard.set(data, forKey: Self.lastSettingsKey)
                    }
                }
            } catch is CancellationError {
                // Cancellation is an expected outcome, not an export failure.
            } catch {
                suggestedMaximumDimension = (error as? ExportError)?.suggestedMaximum
                self.error = error.localizedDescription
            }
            isExporting = false; isCancelling = false
        }
    }
    func cancel() {
        guard isExporting else { return }
        isCancelling = true; task?.cancel()
    }
    func saveToPhotos(albumName: String) async {
        guard !isBusy, photosSaveMessage == nil, let result else { return }
        isSavingToPhotos = true
        photosError = nil
        defer { isSavingToPhotos = false }
        do {
            try await PhotosExporter.save(result.url, albumName: albumName)
            if let title = PhotosExporter.albumTitle(albumName) {
                photosSaveMessage = String(format: String(localized: "Saved to album “%@”."), title)
            } else { photosSaveMessage = String(localized: "Saved to Photos") }
        } catch { photosError = error.localizedDescription }
    }
    /// Called when the export sheet is actually dismissed, after any sharing sheet closes.
    func close() {
        cancel()
        discardResult()
    }
    func discardResult() {
        guard !isBusy else { return }
        photosSaveMessage = nil; photosError = nil
        if let result {
            self.result = nil
            Task { await Self.remove(result.url) }
        }
    }
    private static func remove(_ url: URL) async {
        await ExportFileCleanup.shared.remove(url)
    }
}

private actor ExportFileCleanup {
    static let shared = ExportFileCleanup()
    func remove(_ url: URL) {
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }
}
