import Testing
import Foundation
import CoreGraphics
import CoreImage
import ImageIO
import UniformTypeIdentifiers
@testable import LumoraCore

private func feedbackBitmap(width: Int = 256, height: Int = 192) throws -> CGImage {
    let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
    let ctx = try #require(CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
        bytesPerRow: width * 4, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    for x in 0..<width {
        let v: CGFloat = x.isMultiple(of: 2) ? 0.2 : 0.8
        ctx.setFillColor(CGColor(gray: v, alpha: 1))
        ctx.fill(CGRect(x: x, y: 0, width: 1, height: height))
    }
    return try #require(ctx.makeImage())
}

private func feedbackPixels(_ image: CGImage) throws -> [UInt8] {
    var data = [UInt8](repeating: 0, count: image.width * image.height * 4)
    let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
    try data.withUnsafeMutableBytes { bytes in
        let ctx = try #require(CGContext(data: bytes.baseAddress, width: image.width, height: image.height,
            bitsPerComponent: 8, bytesPerRow: image.width * 4,
            space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    }
    return data
}

private func feedbackWrite(_ image: CGImage, at url: URL) throws {
    let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil))
    CGImageDestinationAddImage(destination, image, nil)
    #expect(CGImageDestinationFinalize(destination))
}

@Test func detailBlurMigratesPersistsClampsAndUndoesPerLayer() throws {
    let old = try JSONDecoder().decode(DetailSettings.self, from: Data("{}".utf8))
    #expect(old.blur == 0 && old.isIdentity)
    var state = EditState()
    var layer = AdjustmentLayer(name: "Local blur", components: [.init(shape: .radial(.init()))])
    layer.adjustments.detail[.blur] = 200
    #expect(layer.adjustments.detail.blur == 100)
    state.masks = [layer]
    #expect(state.detail.blur == 0 && !state.masks[0].adjustments.isIdentity)
    #expect(try JSONDecoder().decode(EditState.self, from: JSONEncoder().encode(state)) == state)
    var previous = state; previous.masks[0].adjustments.detail.blur = 0
    var history = HistoryManager()
    history.begin("Blur", state: previous); history.commit(state)
    #expect(history.undo() == previous); #expect(history.redo() == state)
    state.detail[.blur] = .nan
    #expect(state.detail.blur == 0)
}

@Test func adjustmentIndicatorsAndSummariesFollowStoredValuesWithoutMutating() {
    let neutral = EditState()
    #expect(AdjustmentSection.allCases.allSatisfy { !neutral.hasAdjustments(in: $0, includingMasks: true) })
    var state = neutral
    var layer = AdjustmentLayer(name: "Soft area", components: [.init(shape: .radial(.init()))])
    layer.adjustments.exposure = 0.5
    layer.adjustments.detail.blur = 20
    state.masks = [layer]
    #expect(state.hasAdjustments(in: .effects, includingMasks: true))
    #expect(!state.hasAdjustments(in: .detail, includingMasks: true))
    #expect(!state.hasAdjustments(in: .effects))
    #expect(state.hasAdjustments(in: .light, includingMasks: true))
    #expect(!state.hasAdjustments(in: .color, includingMasks: true))
    #expect(state.hasAdjustments(in: .masks))
    let snapshot = state
    let summary = state.masks[0].adjustments.editState.adjustmentSummary
    #expect(summary.contains("20") && summary.contains("EV"))
    #expect(state == snapshot)
    state.masks[0].adjustments = LocalAdjustmentState()
    #expect(!state.hasAdjustments(in: .effects, includingMasks: true))
    #expect(!state.hasAdjustments(in: .light, includingMasks: true))
    state.geometry.quarterTurns = 1
    #expect(state.hasAdjustments(in: .geometry))
}

@Test func maskedDetailBlurSmoothsOnlyCoveredPixelsAndKeepsDimensions() async throws {
    let url = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".png")
    defer { try? FileManager.default.removeItem(at: url) }
    let source = try feedbackBitmap()
    try feedbackWrite(source, at: url)
    let engine = RenderEngine()
    let baseline = try await engine.render(url: url, state: EditState(), quality: .high)
    let maskImage = CIImage(color: .white).cropped(to: CGRect(x: 0, y: 0, width: source.width / 2, height: source.height))
        .composited(over: CIImage(color: .black).cropped(to: CGRect(x: 0, y: 0, width: source.width, height: source.height)))
    let context = CIContext()
    let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
    let png = try #require(context.pngRepresentation(of: maskImage, format: .RGBA8, colorSpace: space))
    var state = EditState()
    var layer = AdjustmentLayer(name: "Blur", components: [.init(shape: .generated(.init(kind: .magic, pngData: png, width: source.width, height: source.height)))])
    layer.adjustments.detail.blur = 60
    state.masks = [layer]
    let result = try await engine.render(url: url, state: state, quality: .high)
    #expect(result.image.width == baseline.image.width && result.image.height == baseline.image.height)
    let before = try feedbackPixels(baseline.image), after = try feedbackPixels(result.image)
    let left = (50 * source.width + 50) * 4, right = (50 * source.width + 200) * 4
    #expect(abs(Int(after[left]) - Int(before[left])) > 20)
    #expect(abs(Int(after[right]) - Int(before[right])) <= 1)
    #expect(result.original === baseline.original)
}

@Test func geometryTightCropKeepsAvailablePreviewAndNativeExportDetail() async throws {
    let directory = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("original.png")
    let source = try feedbackBitmap(width: 3200, height: 2400)
    try feedbackWrite(source, at: url)
    let originalBytes = try Data(contentsOf: url)
    var state = EditState(); state.geometry.cropZoom = 80
    let expected = GeometryRenderer.apply(CIImage(cgImage: source), settings: state.geometry).extent
    let engine = RenderEngine()
    let preview = try await engine.render(url: url, state: state, quality: .high)
    #expect(preview.image.width >= min(2048, Int(expected.width)) - 2)
    print("Tight crop HQ preview: \(preview.image.width) × \(preview.image.height); native crop \(Int(expected.width)) × \(Int(expected.height))")
    var settings = ExportSettings(); settings.format = .png; settings.maximumDimension = 2048
    let cropped = try await engine.export(request: .init(sourceURL: url, state: state, name: "crop"), settings: settings, directory: directory)
    #expect(cropped.width == Int(expected.width) && cropped.height == Int(expected.height))
    let identity = try await engine.export(request: .init(sourceURL: url, state: EditState(), name: "base"), settings: {
        var value = settings; value.maximumDimension = nil; return value
    }(), directory: directory)
    let image = try #require(CGImageSourceCreateWithURL(cropped.url as CFURL, nil).flatMap { CGImageSourceCreateImageAtIndex($0, 0, nil) })
    let base = try #require(CGImageSourceCreateWithURL(identity.url as CFURL, nil).flatMap { CGImageSourceCreateImageAtIndex($0, 0, nil) })
    let target = try #require(base.cropping(to: CGRect(x: floor((3200 - expected.width) / 2), y: floor((2400 - expected.height) / 2), width: expected.width, height: expected.height)))
    let actualPixels = try feedbackPixels(image), expectedPixels = try feedbackPixels(target)
    let maximumError = zip(actualPixels, expectedPixels).map { abs(Int($0) - Int($1)) }.max() ?? 0
    #expect(maximumError <= 1)
    #expect(try Data(contentsOf: url) == originalBytes)
}

@Test(.enabled(if: ProcessInfo.processInfo.environment["LUMORA_RAW_FIXTURE"] != nil))
func geometryRAWExportResizesAfterCrop() async throws {
    let url = URL(fileURLWithPath: try #require(ProcessInfo.processInfo.environment["LUMORA_RAW_FIXTURE"]))
    let directory = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let decoder = try #require(RAWDecoder.filter(url))
    #expect(max(decoder.nativeSize.width, decoder.nativeSize.height) > 4000)
    var state = EditState(); state.geometry.cropZoom = 60; state.geometry.aspect = .fourFive
    var settings = ExportSettings(); settings.format = .png; settings.maximumDimension = 1600
    let exported = try await RenderEngine().export(request: .init(sourceURL: url, state: state, name: "RAW crop"), settings: settings, directory: directory)
    #expect(max(exported.width, exported.height) == 1600)
    #expect(abs(Double(exported.width) - Double(exported.height) * 0.8) <= 1)
    print("RAW cropped export: \(exported.width) × \(exported.height), requested longest side 1600")
}

@Test func cropPreviewDecodeBudgetIsBoundedAndNeutralIsUnchanged() {
    #expect(GeometryRenderer.previewSourceMaximum(sourceSize: .init(width: 6000, height: 4000), settings: .init(), outputMaximum: 2048) == 2048)
    var crop = GeometrySettings(); crop.cropZoom = 80
    #expect(GeometryRenderer.previewSourceMaximum(sourceSize: .init(width: 3200, height: 2400), settings: crop, outputMaximum: 2048) == 3200)
    #expect(GeometryRenderer.previewSourceMaximum(sourceSize: .init(width: 12000, height: 8000), settings: crop, outputMaximum: 2048) == 4096)
}

@Test func expensivePreviewKeepsEstablishedInputBudget() {
    var state = EditState(); state.geometry.aspect = .fourFive
    #expect(PreviewMemoryBudget.sourceLimit(for: state) == 4096)
    state.beauty.uniformity = 70
    #expect(PreviewMemoryBudget.sourceLimit(for: state) == 2048)
    state.beauty = BeautyState()
    var lighting = DepthLightingSettings(); lighting.enabled = true; lighting.surfaceNormals = true
    state.depthLighting = lighting
    #expect(PreviewMemoryBudget.sourceLimit(for: state) == 2048)
    state.depthLighting = nil
    state.masks = [.init(name: "Blur", components: [.init(shape: .radial(.init()))])]
    state.masks[0].adjustments.detail.blur = 30
    #expect(PreviewMemoryBudget.sourceLimit(for: state) == 2048)
    state.masks[0].adjustments.detail.blur = 0
    #expect(PreviewMemoryBudget.sourceLimit(for: state) == 4096)
    let chosen = GeometryRenderer.previewSourceMaximum(sourceSize: .init(width: 4032, height: 6048),
        settings: state.geometry, outputMaximum: 2048, sourceLimit: 2048)
    #expect(chosen == 2048)
}
