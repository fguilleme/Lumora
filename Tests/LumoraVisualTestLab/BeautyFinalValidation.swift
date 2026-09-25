import CoreGraphics
import CoreImage
import Foundation
import ImageIO
import Testing
@testable import LumoraCore

@Test func beautyFinalRenderPathConsistency() async throws {
    let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
    let output = repo.appendingPathComponent("BeautyValidation/FinalV1Run")
    try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
    let gpu = try LabGPU()
    let engine = RenderEngine()
    var rows = """
    # Beauty V1 — production render paths

    RenderEngine interactive/HQ previews and PNG export use identical persisted
    Beauty settings. Comparisons resample each result to 256×256 and read it in
    extended-linear sRGB; measured MAE includes resampling and PNG conversion.
    Timings are macOS wall time, not iPhone interaction latency.

    | Case | Preset | Preview/HQ MAE | HQ/export MAE | Nonfinite | Preview ms | HQ ms | Export ms |
    |---|---|---:|---:|---:|---:|---:|---:|

    """
    let cases: [(String, BeautyPreset)] = [
        ("01_light_skin_pores", .natural),
        ("01_light_skin_pores", .portrait),
        ("01_light_skin_pores", .beauty),
        ("09_pronounced_dark_circles", .portrait)
    ]
    func normalized(_ image: CGImage) -> CIImage {
        CIImage(cgImage: image).transformed(by: CGAffineTransform(
            scaleX: 256 / CGFloat(image.width), y: 256 / CGFloat(image.height)))
            .cropped(to: CGRect(x: 0, y: 0, width: 256, height: 256))
    }
    for (id, preset) in cases {
        let file = repo.appendingPathComponent("BeautyValidation/Sources/\(id).jpg")
        var state = EditState()
        state.beauty = preset.settings
        let preview = try await engine.render(url: file, state: state, quality: .interactive)
        let high = try await engine.render(url: file, state: state, quality: .high)
        var settings = ExportSettings()
        settings.format = .png
        settings.colorSpace = .displayP3
        settings.maximumDimension = 2048
        let started = ContinuousClock.now
        let exported = try await engine.export(
            request: ExportRequest(sourceURL: file, state: state, name: id),
            settings: settings, directory: FileManager.default.temporaryDirectory)
        let duration = started.duration(to: .now)
        let exportMS = Double(duration.components.seconds) * 1000
            + Double(duration.components.attoseconds) / 1_000_000_000_000_000
        defer { try? FileManager.default.removeItem(at: exported.url.deletingLastPathComponent()) }
        let source = try #require(CGImageSourceCreateWithURL(exported.url as CFURL, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        let previewHigh = gpu.compare(normalized(preview.image), normalized(high.image))
        let highExport = gpu.compare(normalized(high.image), normalized(image))
        #expect(previewHigh.nonFinite == 0 && highExport.nonFinite == 0)
        #expect(previewHigh.mae < 0.03, "Preview/HQ diverged for \(id) \(preset.rawValue)")
        #expect(highExport.mae < 0.03, "HQ/export diverged for \(id) \(preset.rawValue)")
        rows += String(format: "| %@ | %@ | %.6f | %.6f | %d | %.1f | %.1f | %.1f |\n",
            id, preset.rawValue, previewHigh.mae, highExport.mae,
            previewHigh.nonFinite + highExport.nonFinite,
            preview.milliseconds, high.milliseconds, exportMS)
    }
    try rows.write(to: output.appendingPathComponent("render_path_consistency.md"),
        atomically: true, encoding: .utf8)
}
