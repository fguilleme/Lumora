import Foundation
import Observation

@MainActor @Observable
final class ExportController {
    var settings = ExportSettings()
    private(set) var result: ExportedPhoto?
    private(set) var stage: ExportStage = .decoding
    private(set) var isExporting = false
    private(set) var isCancelling = false
    var error: String?
    @ObservationIgnored private let engine = RenderEngine()
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var generation = 0
    static let directory = URL.temporaryDirectory.appendingPathComponent("LumoraExports", isDirectory: true)

    func start(_ request: ExportRequest) {
        guard !isExporting else { return }
        generation += 1
        let token = generation, snapshot = settings
        isExporting = true; isCancelling = false; error = nil; stage = .decoding
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
                } else { result = photo; stage = .finished }
            } catch is CancellationError {
                // Cancellation is an expected outcome, not an export failure.
            } catch { self.error = error.localizedDescription }
            isExporting = false; isCancelling = false
        }
    }
    func cancel() {
        guard isExporting else { return }
        isCancelling = true; task?.cancel()
    }
    /// Called when the export sheet is actually dismissed, after any sharing sheet closes.
    func close() {
        cancel()
        discardResult()
    }
    func discardResult() {
        guard !isExporting else { return }
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
