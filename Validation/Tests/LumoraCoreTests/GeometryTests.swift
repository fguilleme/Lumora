import Testing
import Foundation
import CoreGraphics
import CoreImage
import ImageIO
import UniformTypeIdentifiers
@testable import LumoraCore

private func geometryFixture(width: Int = 120, height: Int = 80) throws -> URL {
    let url = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".tiff")
    let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
    let context = try #require(CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                        bytesPerRow: width * 4, space: space,
                                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    context.setFillColor(try #require(CGColor(colorSpace: space, components: [0.1, 0.7, 0.3, 1])))
    context.fill(CGRect(x: 0, y: 0, width: width / 2, height: height))
    context.setFillColor(try #require(CGColor(colorSpace: space, components: [0.8, 0.2, 0.1, 1])))
    context.fill(CGRect(x: width / 2, y: 0, width: width - width / 2, height: height))
    let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, UTType.tiff.identifier as CFString, 1, nil))
    CGImageDestinationAddImage(destination, try #require(context.makeImage()), nil)
    #expect(CGImageDestinationFinalize(destination))
    return url
}

@Test func geometrySettingsMigrateValidateSerializeAndHistory() throws {
    var geometry = GeometrySettings()
    geometry.quarterTurns = -5
    geometry[.straighten] = 90
    geometry[.cropZoom] = .nan
    geometry[.cropX] = -400
    geometry[.perspectiveVertical] = 240
    geometry[.perspectiveScale] = .infinity
    geometry = geometry.validated
    #expect(geometry.quarterTurns == 3)
    #expect(geometry.straighten == 15 && geometry.cropZoom == 0 && geometry.cropX == -100)
    #expect(geometry.perspectiveVertical == 100 && geometry.perspectiveScale == 100)
    let old = try JSONDecoder().decode(EditState.self, from: Data(#"{"exposure":1}"#.utf8))
    #expect(old.geometry == GeometrySettings())
    var state = EditState(); state.geometry = geometry
    #expect(try JSONDecoder().decode(EditState.self, from: JSONEncoder().encode(state)) == state)
    var history = HistoryManager(); history.begin("Géométrie", state: EditState()); history.commit(state)
    #expect(history.undo() == EditState() && history.redo() == state)
}

@Test func automaticStraightenConvertsAndClampsHorizonAngle() {
    #expect(abs(GeometryAnalysis.straightenDegrees(horizonRadians: .pi / 18) + 10) < 0.0001)
    #expect(GeometryAnalysis.straightenDegrees(horizonRadians: .pi / 2) == -15)
    #expect(GeometryAnalysis.straightenDegrees(horizonRadians: -.pi / 2) == 15)
    #expect(GeometryAnalysis.straightenDegrees(horizonRadians: .nan) == 0)
}

@Test func automaticPerspectiveConvertsWeightsClampsAndRejectsWeakGeometry() throws {
    let strong = GeometryAnalysis.Quadrilateral(
        topLeft: CGPoint(x: 0.2, y: 0.9), topRight: CGPoint(x: 0.8, y: 0.9),
        bottomRight: CGPoint(x: 0.9, y: 0.1), bottomLeft: CGPoint(x: 0.1, y: 0.1), confidence: 1
    )
    let correction = try #require(GeometryAnalysis.perspectiveCorrection(from: [strong]))
    #expect(abs(correction.vertical - 45.4545) < 0.001)
    #expect(abs(correction.horizontal) < 0.001)
    let weakOpposite = GeometryAnalysis.Quadrilateral(
        topLeft: CGPoint(x: 0.1, y: 0.9), topRight: CGPoint(x: 0.9, y: 0.9),
        bottomRight: CGPoint(x: 0.8, y: 0.1), bottomLeft: CGPoint(x: 0.2, y: 0.1), confidence: 0.1
    )
    #expect(try #require(GeometryAnalysis.perspectiveCorrection(from: [strong, weakOpposite])).vertical > 30)

    let horizontal = GeometryAnalysis.Quadrilateral(
        topLeft: CGPoint(x: 0.1, y: 0.9), topRight: CGPoint(x: 0.9, y: 0.8),
        bottomRight: CGPoint(x: 0.9, y: 0.2), bottomLeft: CGPoint(x: 0.1, y: 0.1), confidence: 1
    )
    let horizontalCorrection = try #require(GeometryAnalysis.perspectiveCorrection(from: [horizontal]))
    #expect(horizontalCorrection.horizontal > 40)
    #expect(GeometryAnalysis.perspectiveCorrection(from: [
        .init(topLeft: .zero, topRight: .zero, bottomRight: .zero, bottomLeft: .zero, confidence: 1)
    ]) == nil)

    let extreme = GeometryAnalysis.Quadrilateral(
        topLeft: CGPoint(x: 0.47, y: 0.99), topRight: CGPoint(x: 0.53, y: 0.99),
        bottomRight: CGPoint(x: 1, y: 0), bottomLeft: CGPoint(x: 0, y: 0), confidence: 1
    )
    #expect(try #require(GeometryAnalysis.perspectiveCorrection(from: [extreme])).vertical == 100)
}

@Test func directGeometryHandlesMapToPerspectiveAndCropControls() {
    let topLeft = GeometryDirectManipulation.perspective(
        corner: .topLeft, normalizedPoint: CGPoint(x: 0.11, y: 0.044))
    #expect(abs(topLeft.vertical - 50) < 0.001)
    #expect(abs(topLeft.horizontal + 20) < 0.001)
    let bottomRight = GeometryDirectManipulation.perspective(
        corner: .bottomRight, normalizedPoint: CGPoint(x: 0.89, y: 0.956))
    #expect(abs(bottomRight.vertical + 50) < 0.001)
    #expect(abs(bottomRight.horizontal - 20) < 0.001)
    let crop = GeometryDirectManipulation.cropPosition(normalizedPoint: CGPoint(x: 0.75, y: 0.25))
    #expect(crop.x == 50 && crop.y == 50)
    #expect(abs(GeometryDirectManipulation.cropZoom(normalizedY: 0.86) - 40) < 0.001)
    #expect(GeometryDirectManipulation.cropZoom(normalizedY: 0) == 80)
}

@Test func perspectiveChangesPixelsAndKeepsFiniteExtent() throws {
    let url = try geometryFixture()
    defer { try? FileManager.default.removeItem(at: url) }
    let input = try #require(CIImage(contentsOf: url))
    var geometry = GeometrySettings()
    geometry.perspectiveVertical = 55
    geometry.perspectiveHorizontal = -35
    let output = GeometryRenderer.apply(input, settings: geometry)
    #expect(output.extent.minX == 0 && output.extent.minY == 0)
    #expect(output.extent.width.isFinite && output.extent.height.isFinite)
    #expect(output.extent.width > 0 && output.extent.height > 0)

    let context = CIContext(options: [.useSoftwareRenderer: true])
    let source = try #require(context.createCGImage(input, from: input.extent))
    let rendered = try #require(context.createCGImage(output, from: output.extent))
    #expect(source.width != rendered.width || source.height != rendered.height
            || source.dataProvider?.data != rendered.dataProvider?.data)
}

@Test func perspectiveAffineControlsKeepOutputCovered() throws {
    let input = CIImage(color: .red).cropped(to: CGRect(x: 0, y: 0, width: 120, height: 80))
    var geometry = GeometrySettings()
    geometry.perspectiveVertical = 45
    geometry.perspectiveHorizontal = -30
    geometry.perspectiveAspect = 40
    geometry.perspectiveScale = 115
    geometry.perspectiveOffsetX = 35
    geometry.perspectiveOffsetY = -25
    let output = GeometryRenderer.apply(input, settings: geometry)
    let context = CIContext(options: [.useSoftwareRenderer: true])
    let bitmap = try #require(context.createCGImage(output, from: output.extent))
    let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
    var bytes = [UInt8](repeating: 0, count: bitmap.width * bitmap.height * 4)
    bytes.withUnsafeMutableBytes { buffer in
        let target = CGContext(data: buffer.baseAddress, width: bitmap.width, height: bitmap.height,
                               bitsPerComponent: 8, bytesPerRow: bitmap.width * 4, space: space,
                               bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        target?.draw(bitmap, in: CGRect(x: 0, y: 0, width: bitmap.width, height: bitmap.height))
    }
    let alphas = [3, (bitmap.width - 1) * 4 + 3,
                  (bitmap.height - 1) * bitmap.width * 4 + 3, bytes.count - 1]
    #expect(output.extent.width > 0 && output.extent.height > 0)
    #expect(alphas.allSatisfy { bytes[$0] == 255 })
}

@Test func geometryRotationAndAspectProduceExpectedExtent() {
    let input = CIImage(color: .red).cropped(to: CGRect(x: 0, y: 0, width: 120, height: 80))
    var geometry = GeometrySettings(); geometry.quarterTurns = 1
    let rotated = GeometryRenderer.apply(input, settings: geometry)
    #expect(rotated.extent.width == 80 && rotated.extent.height == 120)
    geometry.aspect = .square
    let square = GeometryRenderer.apply(input, settings: geometry)
    #expect(square.extent.width == 80 && square.extent.height == 80)
}

@Test func straightenFillsEveryOutputCorner() throws {
    let input = CIImage(color: .red).cropped(to: CGRect(x: 0, y: 0, width: 120, height: 80))
    var geometry = GeometrySettings(); geometry.straighten = 15
    let output = GeometryRenderer.apply(input, settings: geometry)
    #expect(output.extent == input.extent)
    let context = CIContext(options: [.useSoftwareRenderer: true])
    let bitmap = try #require(context.createCGImage(output, from: output.extent))
    let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
    var bytes = [UInt8](repeating: 0, count: bitmap.width * bitmap.height * 4)
    bytes.withUnsafeMutableBytes { buffer in
        let target = CGContext(data: buffer.baseAddress, width: bitmap.width, height: bitmap.height,
                               bitsPerComponent: 8, bytesPerRow: bitmap.width * 4, space: space,
                               bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        target?.draw(bitmap, in: CGRect(x: 0, y: 0, width: bitmap.width, height: bitmap.height))
    }
    let alphas = [3, (bitmap.width - 1) * 4 + 3,
                  (bitmap.height - 1) * bitmap.width * 4 + 3, bytes.count - 1]
    #expect(alphas.allSatisfy { bytes[$0] == 255 })
}

@Test func geometryChangesPreviewAndFullResolutionExportDimensions() async throws {
    let url = try geometryFixture(width: 120, height: 80)
    let root = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: url); try? FileManager.default.removeItem(at: root) }
    var state = EditState()
    state.geometry.quarterTurns = 1
    state.geometry.aspect = .square
    state.geometry.cropZoom = 25
    let engine = RenderEngine()
    let preview = try await engine.render(url: url, state: state, quality: .high)
    #expect(preview.image.width == 64 && preview.image.height == 64)
    var settings = ExportSettings(); settings.format = .png
    let exported = try await engine.export(request: ExportRequest(sourceURL: url, state: state, name: "fixture"),
                                           settings: settings, directory: root)
    #expect(exported.width == 64 && exported.height == 64)
    let source = try #require(CGImageSourceCreateWithURL(exported.url as CFURL, nil))
    let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
    #expect(image.width == exported.width && image.height == exported.height)
}
