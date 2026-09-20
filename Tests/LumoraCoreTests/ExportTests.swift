import Testing
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
@testable import LumoraCore

private func exportFixture(width: Int = 128, height: Int = 64, orientation: Int = 1) throws -> URL {
    let url = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".tiff")
    let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
    let context = try #require(CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                       bytesPerRow: width * 4, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    for x in 0..<width {
        let value = 0.1 + 0.7 * Double(x) / Double(width - 1)
        context.setFillColor(try #require(CGColor(colorSpace: space, components: [value, value, value, 1])))
        context.fill(CGRect(x: x, y: 0, width: 1, height: height))
    }
    let image = try #require(context.makeImage())
    let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, UTType.tiff.identifier as CFString, 1, nil))
    let metadata: [CFString: Any] = [
        kCGImagePropertyOrientation: orientation,
        kCGImagePropertyTIFFDictionary: [kCGImagePropertyTIFFMake: "Test camera", kCGImagePropertyTIFFArtist: "Lumora test"],
        kCGImagePropertyExifDictionary: [kCGImagePropertyExifDateTimeOriginal: "2026:09:19 12:00:00", kCGImagePropertyExifExposureTime: 0.01],
        kCGImagePropertyGPSDictionary: [kCGImagePropertyGPSLatitude: 48.85, kCGImagePropertyGPSLatitudeRef: "N",
                                      kCGImagePropertyGPSLongitude: 2.35, kCGImagePropertyGPSLongitudeRef: "E"]
    ]
    CGImageDestinationAddImage(destination, image, metadata as CFDictionary)
    #expect(CGImageDestinationFinalize(destination))
    return url
}

@Test func exportDimensionCalculationNeverUpsamples() throws {
    var settings = ExportSettings()
    #expect(settings.dimensions(width: 6000, height: 4000).width == 6000)
    settings.maximumDimension = 3000
    let size = settings.dimensions(width: 6000, height: 4000)
    #expect(size.width == 3000 && size.height == 2000)
    #expect(settings.dimensions(width: 100, height: 50).width == 100)
    settings.maximumDimension = -10; settings.quality = .nan
    #expect(settings.validated.maximumDimension == 1 && settings.validated.quality == 0.95)
    settings.quality = 0.7
    #expect(try JSONDecoder().decode(ExportSettings.self, from: JSONEncoder().encode(settings)) == settings)
}

@Test func exportReallyUsesFullResolutionAndPreservesOriginal() async throws {
    let url = try exportFixture(width: 2400, height: 1200)
    let root = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: url); try? FileManager.default.removeItem(at: root) }
    let bytes = try Data(contentsOf: url)
    var settings = ExportSettings(); settings.format = .png
    let request = ExportRequest(sourceURL: url, state: EditState(), name: "fixture")
    let engine = RenderEngine()
    let preview = try await engine.render(url: url, state: EditState(), quality: .high)
    #expect(preview.image.width == 2048)
    let photo = try await engine.export(request: request, settings: settings, directory: root)
    let source = try #require(CGImageSourceCreateWithURL(photo.url as CFURL, nil))
    let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
    #expect(image.width == 2400 && image.height == 1200)
    #expect(photo.width == image.width && photo.height == image.height && photo.byteCount > 0)
    #expect(try Data(contentsOf: url) == bytes)
}

@Test func exportAllAvailableFormatsEncodeAndDecode() async throws {
    let url = try exportFixture()
    let root = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: url); try? FileManager.default.removeItem(at: root) }
    let engine = RenderEngine()
    for format in ExportFormat.available {
        var settings = ExportSettings(); settings.format = format; settings.maximumDimension = 64
        let result = try await engine.export(request: ExportRequest(sourceURL: url, state: EditState(), name: "fixture"), settings: settings, directory: root)
        let source = try #require(CGImageSourceCreateWithURL(result.url as CFURL, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        #expect(image.width == 64 && image.height == 32)
        #expect(CGImageSourceGetType(source) as String? == format.type.identifier)
    }
}

@Test func exportAppliesOrientationOnceAndWritesChosenProfile() async throws {
    let url = try exportFixture(orientation: 6)
    let root = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: url); try? FileManager.default.removeItem(at: root) }
    let engine = RenderEngine()
    for colorSpace in ExportColorSpace.allCases {
        var settings = ExportSettings(); settings.format = .png; settings.colorSpace = colorSpace; settings.maximumDimension = 64
        let result = try await engine.export(request: ExportRequest(sourceURL: url, state: EditState(), name: "fixture"), settings: settings, directory: root)
        let source = try #require(CGImageSourceCreateWithURL(result.url as CFURL, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        let metadata = try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
        #expect(image.width == 32 && image.height == 64)
        #expect((metadata[kCGImagePropertyOrientation] as? Int ?? 1) == 1)
        #expect(image.colorSpace?.name == settings.colorSpace.cgColorSpace?.name)
    }
}

@Test func exportMetadataOptionsActuallyRemoveGPSAndCameraTags() async throws {
    let url = try exportFixture()
    let root = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: url); try? FileManager.default.removeItem(at: root) }
    let engine = RenderEngine()
    for mode in 0...2 {
        var settings = ExportSettings(); settings.includeMetadata = mode != 2; settings.removeLocation = mode != 0
        let result = try await engine.export(request: ExportRequest(sourceURL: url, state: EditState(), name: "fixture"), settings: settings, directory: root)
        let source = try #require(CGImageSourceCreateWithURL(result.url as CFURL, nil))
        let metadata = try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
        let gps = metadata[kCGImagePropertyGPSDictionary] as? [CFString: Any]
        let tiff = metadata[kCGImagePropertyTIFFDictionary] as? [CFString: Any]
        let exif = metadata[kCGImagePropertyExifDictionary] as? [CFString: Any]
        #expect((gps != nil) == (mode == 0))
        #expect((tiff?[kCGImagePropertyTIFFMake] as? String == "Test camera") == (mode != 2))
        #expect((exif?[kCGImagePropertyExifDateTimeOriginal] as? String == "2026:09:19 12:00:00") == (mode != 2))
    }
}

@Test func exportMatchesPreviewAdjustments() async throws {
    let url = try exportFixture()
    let root = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: url); try? FileManager.default.removeItem(at: root) }
    var state = EditState(); state.exposure = 0.6; state.shadows = 25
    state.curves.rgb.add(x: 0.5, y: 0.6)
    state.colorGrading.midtones = GradingWheel(hue: 240, saturation: 35)
    state.detail.sharpening.amount = 35
    state.detail.sharpening.masking = 60
    state.detail.colorNoiseReduction.color = 25
    state.optics.distortion = 12
    state.optics.chromaticAberration = 15
    state.geometry.perspectiveVertical = 20
    state.geometry.perspectiveHorizontal = -15
    state.geometry.perspectiveAspect = 10
    state.geometry.perspectiveScale = 105
    state.geometry.cropZoom = 10
    var local = LocalAdjustmentState(); local.exposure = 0.5
    state.masks = [LocalMask(name: "Export", components: [MaskComponent(shape: .radial(RadialGradientMask()))],
                             adjustments: local)]
    let engine = RenderEngine()
    let preview = try await engine.render(url: url, state: state, quality: .high)
    var settings = ExportSettings(); settings.format = .png; settings.colorSpace = .displayP3
    let result = try await engine.export(request: ExportRequest(sourceURL: url, state: state, name: "fixture"), settings: settings, directory: root)
    let source = try #require(CGImageSourceCreateWithURL(result.url as CFURL, nil))
    let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
    let histogram = Histogram.compute(image)
    func mean(_ bins: [Int]) -> Double {
        Double(bins.enumerated().reduce(0) { $0 + $1.offset * $1.element }) / Double(bins.reduce(0, +))
    }
    #expect(abs(mean(histogram.red) - mean(preview.histogram.red)) < 1)
    #expect(abs(mean(histogram.blue) - mean(preview.histogram.blue)) < 1)
}

@Test func exportCancellationNeverLeavesPartialOrFinalFile() async throws {
    let url = try exportFixture()
    let root = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: url); try? FileManager.default.removeItem(at: root) }
    for stage in [ExportStage.decoding, .rendering, .encoding] {
        let task = Task {
            try await RenderEngine().export(request: ExportRequest(sourceURL: url, state: EditState(), name: "fixture"), settings: ExportSettings(), directory: root) { current in
                if current == stage { withUnsafeCurrentTask { $0?.cancel() } }
            }
        }
        do { _ = try await task.value; Issue.record("Cancelled export succeeded") }
        catch is CancellationError {} catch { Issue.record("Unexpected error: \(error)") }
        let contents = (try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? []
        #expect(contents.isEmpty)
    }
}
