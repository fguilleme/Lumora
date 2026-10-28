import Testing
import Foundation
import CoreImage
import CoreImage.CIFilterBuiltins
import ImageIO
import UniformTypeIdentifiers
@testable import LumoraCore

struct MaskGeometryTests {
    private let source = CGRect(x: 0, y: 0, width: 240, height: 180)

    private func bytes(_ image: CIImage, extent: CGRect) -> [UInt8] {
        let width = Int(extent.width), height = Int(extent.height)
        var data = [UInt8](repeating: 0, count: width * height * 4)
        data.withUnsafeMutableBytes {
            CIContext().render(image, toBitmap: $0.baseAddress!, rowBytes: width * 4,
                               bounds: extent, format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!)
        }
        return data
    }

    private func png(_ image: CIImage) throws -> Data {
        let bitmap = try #require(CIContext().createCGImage(image, from: source))
        let data = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, bitmap, nil)
        #expect(CGImageDestinationFinalize(destination))
        return data as Data
    }

    private func shapes() throws -> [MaskShape] {
        var brush = BrushMask()
        brush.strokes = [[.init(x: 0.3, y: 0.3), .init(x: 0.6, y: 0.7)]]
        brush.eraseStrokes = [[.init(x: 0.4, y: 0.4)]]
        brush.size = 24; brush.feather = 35
        var radial = RadialGradientMask()
        radial.center = .init(x: 0.35, y: 0.4); radial.radiusX = 0.2; radial.radiusY = 0.3
        var linear = LinearGradientMask()
        linear.angle = 40; linear.center = .init(x: 0.4, y: 0.3)
        let rectangle = CIImage(color: .white).cropped(to: CGRect(x: 40, y: 30, width: 60, height: 100))
            .composited(over: CIImage(color: .black).cropped(to: source))
        let generated = GeneratedMask(kind: .magic, pngData: try png(rectangle), width: 240, height: 180)
        var similarity = SimilarityMask()
        let sampleImage = try #require(CIContext().createCGImage(rectangle, from: source))
        similarity = try SimilarityMaskEngine.sample(.init(x: 0.25, y: 0.5), image: sampleImage, mask: similarity)
        return [.brush(brush), .radial(radial), .linear(linear), .generated(generated), .similarity(similarity)]
    }

    @Test(arguments: ["rotation", "mirror", "crop", "straighten", "perspective", "combined"])
    func masksFollowPhotoPixels(_ kind: String) throws {
        var geometry = GeometrySettings()
        switch kind {
        case "rotation": geometry.quarterTurns = 1
        case "mirror": geometry.flipHorizontal = true; geometry.flipVertical = true
        case "crop": geometry.aspect = .fourFive; geometry.cropZoom = 30; geometry.cropX = -25; geometry.cropY = 20
        case "straighten": geometry.straighten = 9
        case "perspective": geometry.perspectiveVertical = 35; geometry.perspectiveHorizontal = -25
        default:
            geometry.quarterTurns = 3; geometry.flipHorizontal = true; geometry.straighten = -7
            geometry.perspectiveVertical = -25; geometry.perspectiveAspect = 20; geometry.perspectiveScale = 115
            geometry.perspectiveOffsetX = 15; geometry.aspect = .square; geometry.cropZoom = 10
        }
        for shape in try shapes() {
            let component = MaskComponent(shape: shape, geometry: GeometrySettings())
            let layer = LocalMask(name: "Fixture", components: [component])
            let original = try MaskRenderer.makeMask(layer, extent: source)
            let expected = GeometryRenderer.apply(original, settings: geometry)
            let extent = expected.extent.integral
            let rendered = try MaskRenderer.makeMask(layer, extent: extent,
                geometry: MaskRenderGeometry(sourceSize: source.size, current: geometry))
            let a = bytes(expected, extent: extent), b = bytes(rendered, extent: extent)
            let errors = stride(from: 0, to: a.count, by: 4).map { abs(Int(a[$0]) - Int(b[$0])) }
            let mean = Double(errors.reduce(0, +)) / Double(errors.count)
            #expect(mean < 2.5, "\(kind) / \(shape.title): mean pixel error \(mean)")
        }
    }

    @Test func componentsCreatedInDifferentFramesStayAligned() throws {
        var mirror = GeometrySettings(); mirror.flipHorizontal = true
        var first = RadialGradientMask(); first.center = .init(x: 0.2, y: 0.5)
        first.radiusX = 0.1; first.radiusY = 0.15; first.feather = 10
        var second = first; second.center.x = 0.2
        let layer = LocalMask(name: "Mixed frames", components: [
            MaskComponent(shape: .radial(first), geometry: GeometrySettings()),
            MaskComponent(shape: .radial(second), geometry: mirror)
        ])
        let rendered = try MaskRenderer.makeMask(layer, extent: source,
            geometry: MaskRenderGeometry(sourceSize: source.size, current: mirror))
        let data = bytes(rendered, extent: source)
        #expect(data[(90 * 240 + 48) * 4] > 240)
        #expect(data[(90 * 240 + 192) * 4] > 240)
        #expect(data[(90 * 240 + 120) * 4] < 10)
        let subtract = LocalMask(name: "Subtract", components: [layer.components[0],
            MaskComponent(operation: .subtract, shape: .radial(first), geometry: GeometrySettings())])
        let empty = try MaskRenderer.makeMask(subtract, extent: source,
            geometry: MaskRenderGeometry(sourceSize: source.size, current: mirror))
        #expect(bytes(empty, extent: source)[(90 * 240 + 192) * 4] < 10)
    }

    @Test func creationFrameSurvivesSavingAndUndoRedo() throws {
        var creation = GeometrySettings(); creation.quarterTurns = 1; creation.aspect = .square; creation.cropZoom = 20
        let layer = LocalMask(name: "Saved", components: [MaskComponent(shape: .radial(.init()), geometry: creation)])
        var state = EditState(); state.geometry = creation; state.masks = [layer]
        let saved = try JSONDecoder().decode(EditState.self, from: JSONEncoder().encode(state))
        #expect(saved == state)
        var history = HistoryManager(); history.begin("Geometry", state: saved)
        state.geometry.flipHorizontal = true; state.geometry.cropZoom = 35
        history.commit(state)
        #expect(history.undo() == saved)
        #expect(history.redo() == state)
        #expect(state.masks[0].components[0].geometry == creation)
        let map = MaskRenderGeometry(sourceSize: source.size, current: state.geometry).mapping(layer.components[0])
        for point in [MaskPoint(x: 0.2, y: 0.3), .init(x: 0.7, y: 0.6)] {
            let roundTrip = map.stored(map.display(point))
            #expect(abs(roundTrip.x - point.x) < 0.000_001)
            #expect(abs(roundTrip.y - point.y) < 0.000_001)
        }
    }

    @Test func previewAndExportKeepLocalAdjustmentsOnTheSamePixels() async throws {
        let directory = URL.temporaryDirectory.appendingPathComponent("MaskGeometry-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("fixture.png")
        try png(CIImage(color: CIColor(red: 0.2, green: 0.25, blue: 0.3)).cropped(to: source)).write(to: url)
        var radial = RadialGradientMask(); radial.center = .init(x: 0.3, y: 0.4)
        radial.radiusX = 0.12; radial.radiusY = 0.18; radial.feather = 20
        var layer = LocalMask(name: "Exposure", components: [MaskComponent(shape: .radial(radial), geometry: GeometrySettings())])
        layer.adjustments.exposure = 1
        var state = EditState(); state.masks = [layer]
        let engine = RenderEngine()
        let before = try await engine.render(url: url, state: state, quality: .high)
        state.geometry.quarterTurns = 1; state.geometry.flipHorizontal = true; state.geometry.cropZoom = 20
        let after = try await engine.render(url: url, state: state, quality: .high)
        let expected = GeometryRenderer.apply(CIImage(cgImage: before.image), settings: state.geometry)
        let extent = expected.extent.integral
        let a = bytes(expected, extent: extent), b = bytes(CIImage(cgImage: after.image), extent: extent)
        let mean = zip(a, b).reduce(0.0) { $0 + Double(abs(Int($1.0) - Int($1.1))) } / Double(a.count)
        #expect(mean < 1.5, "Transformed preview must move the adjustment with the photograph")
        var settings = ExportSettings(); settings.format = .png; settings.colorSpace = .sRGB; settings.includeMetadata = false
        let exported = try await engine.export(request: ExportRequest(sourceURL: url, state: state, name: "Mask geometry"),
                                               settings: settings, directory: directory)
        let exportImage = try #require(CIImage(contentsOf: exported.url))
        let c = bytes(exportImage, extent: extent)
        let exportError = zip(b, c).reduce(0.0) { $0 + Double(abs(Int($1.0) - Int($1.1))) } / Double(b.count)
        #expect(exportError < 1.5, "Preview and PNG export must use the same projected matte")
    }

    @Test func legacyComponentsKeepTheirExistingAppearanceUntilAnchored() throws {
        let legacy = MaskComponent(shape: .radial(.init()))
        let decoded = try JSONDecoder().decode(MaskComponent.self, from: JSONEncoder().encode(legacy))
        #expect(decoded.geometry == nil)
        var geometry = GeometrySettings(); geometry.quarterTurns = 1; geometry.cropZoom = 20
        let layer = LocalMask(name: "Legacy", components: [decoded])
        let expected = try MaskRenderer.makeMask(layer, extent: source)
        let actual = try MaskRenderer.makeMask(layer, extent: source,
            geometry: MaskRenderGeometry(sourceSize: source.size, current: geometry))
        #expect(bytes(expected, extent: source) == bytes(actual, extent: source))
    }
}
