import Testing
import Foundation
import CoreGraphics
import CoreImage
import ImageIO
import UniformTypeIdentifiers
@testable import LumoraCore

private let maskExtent = CGRect(x: 0, y: 0, width: 100, height: 100)

private func maskBytes(_ image: CIImage) throws -> [UInt8] {
    let context = CIContext(options: [.useSoftwareRenderer: true])
    let bitmap = try #require(context.createCGImage(image, from: maskExtent))
    let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
    var bytes = [UInt8](repeating: 0, count: 100 * 100 * 4)
    bytes.withUnsafeMutableBytes { buffer in
        let target = CGContext(data: buffer.baseAddress, width: 100, height: 100, bitsPerComponent: 8,
                               bytesPerRow: 400, space: space,
                               bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        target?.draw(bitmap, in: maskExtent)
    }
    return bytes
}

private func red(_ bytes: [UInt8], x: Int, y: Int) -> Int { Int(bytes[(y * 100 + x) * 4]) }
private func green(_ bytes: [UInt8], x: Int, y: Int) -> Int { Int(bytes[(y * 100 + x) * 4 + 1]) }
private func alpha(_ bytes: [UInt8], x: Int, y: Int) -> Int { Int(bytes[(y * 100 + x) * 4 + 3]) }

private func halfMaskPNG() throws -> Data {
    let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
    let context = try #require(CGContext(data: nil, width: 10, height: 10, bitsPerComponent: 8,
                                        bytesPerRow: 40, space: space,
                                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    context.setFillColor(CGColor(gray: 0, alpha: 1)); context.fill(CGRect(x: 0, y: 0, width: 10, height: 10))
    context.setFillColor(CGColor(gray: 1, alpha: 1)); context.fill(CGRect(x: 0, y: 0, width: 5, height: 10))
    let data = NSMutableData()
    let destination = try #require(CGImageDestinationCreateWithData(
        data, UTType.png.identifier as CFString, 1, nil
    ))
    CGImageDestinationAddImage(destination, try #require(context.makeImage()), nil)
    #expect(CGImageDestinationFinalize(destination))
    return data as Data
}

private func rectangleMaskPNG(_ rectangle: CGRect) throws -> Data {
    let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
    let context = try #require(CGContext(data: nil, width: 100, height: 100, bitsPerComponent: 8,
                                        bytesPerRow: 400, space: space,
                                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    context.setFillColor(CGColor(gray: 0, alpha: 1)); context.fill(maskExtent)
    context.setFillColor(CGColor(gray: 1, alpha: 1)); context.fill(rectangle)
    let data = NSMutableData()
    let destination = try #require(CGImageDestinationCreateWithData(
        data, UTType.png.identifier as CFString, 1, nil
    ))
    CGImageDestinationAddImage(destination, try #require(context.makeImage()), nil)
    #expect(CGImageDestinationFinalize(destination))
    return data as Data
}

private func solidPhotoURL() throws -> URL {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let url = folder.appendingPathComponent("layer-source.png")
    let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
    let context = try #require(CGContext(data: nil, width: 100, height: 100, bitsPerComponent: 8,
                                        bytesPerRow: 400, space: space,
                                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    context.setFillColor(CGColor(gray: 0.25, alpha: 1)); context.fill(maskExtent)
    let destination = try #require(CGImageDestinationCreateWithURL(
        url as CFURL, UTType.png.identifier as CFString, 1, nil
    ))
    CGImageDestinationAddImage(destination, try #require(context.makeImage()), nil)
    #expect(CGImageDestinationFinalize(destination))
    return url
}

private func syntheticLandscape() throws -> CGImage {
    let width = 80, height = 60, rowBytes = width * 4
    var pixels = [UInt8](repeating: 255, count: rowBytes * height)
    for y in 0..<height {
        for x in 0..<width {
            let offset = y * rowBytes + x * 4
            if y < height / 2 {
                pixels[offset] = 80; pixels[offset + 1] = 155; pixels[offset + 2] = 235
            } else {
                pixels[offset] = 65; pixels[offset + 1] = 125; pixels[offset + 2] = 45
            }
        }
    }
    let provider = try #require(CGDataProvider(data: Data(pixels) as CFData))
    let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
    return try #require(CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                                bytesPerRow: rowBytes, space: space,
                                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
                                    .union(.byteOrder32Big),
                                provider: provider, decode: nil, shouldInterpolate: false,
                                intent: .defaultIntent))
}

private func syntheticPortrait() throws -> CGImage {
    let width = 80, height = 60, rowBytes = width * 4
    var pixels = [UInt8](repeating: 255, count: rowBytes * height)
    for y in 0..<height {
        for x in 0..<width {
            let offset = y * rowBytes + x * 4
            pixels[offset] = 35; pixels[offset + 1] = 80; pixels[offset + 2] = 170
            if ((20..<60).contains(x) && (8..<38).contains(y)) ||
                ((8..<18).contains(x) && (44..<56).contains(y)) {
                pixels[offset] = 180; pixels[offset + 1] = 120; pixels[offset + 2] = 90
            }
        }
    }
    let provider = try #require(CGDataProvider(data: Data(pixels) as CFData))
    let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
    return try #require(CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                                bytesPerRow: rowBytes, space: space,
                                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
                                    .union(.byteOrder32Big),
                                provider: provider, decode: nil, shouldInterpolate: false,
                                intent: .defaultIntent))
}

@Test func masksMigrateValidateSerializeAndParticipateInHistory() throws {
    var brush = BrushMask(strokes: [[MaskPoint(x: -2, y: 4)]], size: 1000, feather: .nan, flow: 0, opacity: 0)
    brush = brush.validated
    #expect(brush.strokes[0][0] == MaskPoint(x: 0, y: 1))
    #expect(brush.size == 100 && brush.feather == 70 && brush.flow == 1 && brush.opacity == 1)
    let legacyBrush = try JSONDecoder().decode(BrushMask.self, from: Data(#"{"strokes":[]}"#.utf8))
    #expect(legacyBrush.eraseStrokes.isEmpty)
    var adjustments = LocalAdjustmentState(); adjustments[.exposure] = 12; adjustments[.sharpness] = -4
    #expect(adjustments.exposure == 5 && adjustments.sharpness == 0)
    let component = MaskComponent(shape: .brush(brush))
    let mask = LocalMask(name: String(repeating: "M", count: 100), components: [component], adjustments: adjustments)
    var state = EditState(); state.masks = [mask]
    let decoded = try JSONDecoder().decode(EditState.self, from: JSONEncoder().encode(state))
    #expect(decoded.validated.masks[0].name.count == 60)
    let old = try JSONDecoder().decode(EditState.self, from: Data(#"{"exposure":1}"#.utf8))
    #expect(old.masks.isEmpty)
    var history = HistoryManager(); history.begin("Masque", state: EditState()); history.commit(state)
    #expect(history.undo() == EditState() && history.redo() == state)
}

@Test func brushEraserRemovesPaintAndRoundTrips() throws {
    let painted = MaskPoint(x: 0.3, y: 0.5)
    let retained = MaskPoint(x: 0.7, y: 0.5)
    let brush = BrushMask(strokes: [[painted], [retained]], eraseStrokes: [[painted]],
                          size: 20, feather: 10, flow: 100, opacity: 100)
    let decoded = try JSONDecoder().decode(BrushMask.self, from: JSONEncoder().encode(brush))
    #expect(decoded == brush)
    let mask = LocalMask(name: "Gomme", components: [MaskComponent(shape: .brush(brush))])
    let pixels = try maskBytes(MaskRenderer.makeMask(mask, extent: maskExtent))
    #expect(red(pixels, x: 30, y: 50) < 20)
    #expect(red(pixels, x: 70, y: 50) > 240)
}

@Test func additiveBrushEraserRemovesAnEarlierGeneratedSubject() throws {
    let subject = GeneratedMask(kind: .subject, pngData: try rectangleMaskPNG(
        CGRect(x: 10, y: 10, width: 80, height: 80)), width: 100, height: 100)
    let eraser = BrushMask(eraseStrokes: [[MaskPoint(x: 0.5, y: 0.5)]],
                           size: 24, feather: 10, flow: 100, opacity: 100)
    let mask = LocalMask(name: "Sujet affiné", components: [
        MaskComponent(operation: .add, shape: .generated(subject)),
        MaskComponent(operation: .add, shape: .brush(eraser))
    ])
    let pixels = try maskBytes(MaskRenderer.makeMask(mask, extent: maskExtent))
    #expect(red(pixels, x: 50, y: 50) < 20)
    #expect(red(pixels, x: 25, y: 50) > 240)
    #expect(red(pixels, x: 2, y: 2) < 10)
}

@Test func subjectMinusFaceMinusBodyRadialKeepsOnlyRemainingRegion() throws {
    let subject = GeneratedMask(kind: .subject, pngData: try rectangleMaskPNG(
        CGRect(x: 15, y: 10, width: 70, height: 80)), width: 100, height: 100)
    let face = GeneratedMask(kind: .face, pngData: try rectangleMaskPNG(
        CGRect(x: 35, y: 15, width: 30, height: 30)), width: 100, height: 100)
    var body = RadialGradientMask()
    body.center = MaskPoint(x: 0.5, y: 0.3)
    body.radiusX = 0.27; body.radiusY = 0.18; body.feather = 5
    let mask = LocalMask(name: "Cheveux", components: [
        MaskComponent(operation: .add, shape: .generated(subject)),
        MaskComponent(operation: .subtract, shape: .generated(face)),
        MaskComponent(operation: .subtract, shape: .radial(body))
    ])
    let pixels = try maskBytes(MaskRenderer.makeMask(mask, extent: maskExtent))
    #expect(red(pixels, x: 50, y: 70) < 20) // face
    #expect(red(pixels, x: 50, y: 30) < 20) // body
    #expect(red(pixels, x: 22, y: 70) > 240) // remaining subject
    #expect(red(pixels, x: 2, y: 50) < 10) // background
}

@Test func subtractiveBrushPaintRemovesPartOfGeneratedSubject() throws {
    let subject = GeneratedMask(kind: .subject, pngData: try rectangleMaskPNG(
        CGRect(x: 10, y: 10, width: 80, height: 80)), width: 100, height: 100)
    let lipsStroke = BrushMask(strokes: [[MaskPoint(x: 0.5, y: 0.5)]],
                               size: 24, feather: 10, flow: 100, opacity: 100)
    let mask = LocalMask(name: "Sujet sans lèvres", components: [
        MaskComponent(operation: .add, shape: .generated(subject)),
        MaskComponent(operation: .subtract, shape: .brush(lipsStroke))
    ])
    let pixels = try maskBytes(MaskRenderer.makeMask(mask, extent: maskExtent))
    #expect(red(pixels, x: 50, y: 50) < 20)
    #expect(red(pixels, x: 25, y: 50) > 240)
}

@Test func brushStoresTheEffectiveSizeOfEachZoomedStroke() throws {
    let brush = BrushMask(
        strokes: [[MaskPoint(x: 0.25, y: 0.5)], [MaskPoint(x: 0.75, y: 0.5)]],
        strokeSizes: [24, 6], size: 24, feather: 1, flow: 100, opacity: 100)
    let mask = LocalMask(name: "Tailles par trait", components: [MaskComponent(shape: .brush(brush))])
    let pixels = try maskBytes(MaskRenderer.makeMask(mask, extent: maskExtent))
    #expect(red(pixels, x: 25, y: 60) > 240)
    #expect(red(pixels, x: 75, y: 60) < 20)
    #expect(red(pixels, x: 75, y: 52) > 240)
}

@Test func layerManagementMigratesPersistsAndControlsRendering() async throws {
    let legacy = try JSONDecoder().decode(LocalMask.self, from: Data(
        #"{"name":" Ancien calque ","components":[]}"#.utf8
    ))
    #expect(legacy.name == "Ancien calque")
    #expect(legacy.isVisible)
    #expect(legacy.opacity == 100)

    let generated = GeneratedMask(kind: .subject, pngData: try halfMaskPNG(), width: 10, height: 10)
    var adjustment = LocalAdjustmentState(); adjustment.exposure = 2
    let firstID = UUID(), secondID = UUID()
    var first = LocalMask(id: firstID, name: "Éclaircir", components: [MaskComponent(shape: .generated(generated))],
                          adjustments: adjustment, opacity: 50)
    let second = LocalMask(id: secondID, name: "Second", components: [MaskComponent(shape: .generated(generated))])
    var state = EditState(); state.masks = [first, second]
    let decoded = try JSONDecoder().decode(EditState.self, from: JSONEncoder().encode(state))
    #expect(decoded.masks.map(\.id) == [firstID, secondID])
    #expect(decoded.masks[0].opacity == 50 && decoded.masks[0].isVisible)

    let url = try solidPhotoURL()
    defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
    let engine = RenderEngine()
    let half = try await engine.render(url: url, state: state, quality: .high)
    let halfPixels = try maskBytes(CIImage(cgImage: half.image))
    let halfDelta = red(halfPixels, x: 10, y: 50) - red(halfPixels, x: 90, y: 50)
    #expect(halfDelta > 20)

    first.opacity = 100; state.masks = [first]
    let full = try await engine.render(url: url, state: state, quality: .high)
    let fullPixels = try maskBytes(CIImage(cgImage: full.image))
    let fullDelta = red(fullPixels, x: 10, y: 50) - red(fullPixels, x: 90, y: 50)
    #expect(fullDelta > halfDelta + 20)

    first.isVisible = false; state.masks = [first]
    let hidden = try await engine.render(url: url, state: state, quality: .high)
    let hiddenPixels = try maskBytes(CIImage(cgImage: hidden.image))
    #expect(abs(red(hiddenPixels, x: 10, y: 50) - red(hiddenPixels, x: 90, y: 50)) < 3)

    first.opacity = .nan
    #expect(first.validated.opacity == 100)
}

@Test func radialMaskHasSoftCenterAndSupportsInversion() throws {
    let component = MaskComponent(shape: .radial(RadialGradientMask()))
    var mask = LocalMask(name: "Radial", components: [component])
    let normal = try maskBytes(MaskRenderer.makeMask(mask, extent: maskExtent))
    #expect(red(normal, x: 50, y: 50) > 245)
    #expect(red(normal, x: 2, y: 2) < 10)
    mask.inverted = true
    let inverted = try maskBytes(MaskRenderer.makeMask(mask, extent: maskExtent))
    #expect(red(inverted, x: 50, y: 50) < 10)
    #expect(red(inverted, x: 2, y: 2) > 245)
}

@Test func redMaskOverlayUsesExactMatteAlphaAndFeathering() throws {
    var radial = RadialGradientMask()
    radial.radiusX = 0.35; radial.radiusY = 0.35; radial.feather = 50
    let mask = LocalMask(name: "Overlay", components: [MaskComponent(shape: .radial(radial))])
    let bytes = try maskBytes(MaskRenderer.makeRedOverlay(mask, extent: maskExtent))
    #expect(alpha(bytes, x: 50, y: 50) > 95)
    #expect(alpha(bytes, x: 2, y: 2) < 5)
    #expect((10...95).contains(alpha(bytes, x: 75, y: 50)))
    #expect(red(bytes, x: 50, y: 50) > 95)
    #expect(green(bytes, x: 50, y: 50) < 5)
}

@Test func redMaskOverlaySupportsBrushLinearAndGeneratedMasks() throws {
    var brush = BrushMask()
    brush.size = 24; brush.feather = 35
    brush.strokes = [[MaskPoint(x: 0.2, y: 0.8), MaskPoint(x: 0.8, y: 0.2)]]
    let brushMask = LocalMask(name: "Pinceau", components: [MaskComponent(shape: .brush(brush))])
    let brushOverlay = try maskBytes(MaskRenderer.makeRedOverlay(brushMask, extent: maskExtent))
    #expect(alpha(brushOverlay, x: 20, y: 80) > 40)
    #expect(alpha(brushOverlay, x: 5, y: 95) < 5)

    var linear = LinearGradientMask(); linear.angle = 0; linear.feather = 20
    let linearMask = LocalMask(name: "Linéaire", components: [MaskComponent(shape: .linear(linear))])
    let linearOverlay = try maskBytes(MaskRenderer.makeRedOverlay(linearMask, extent: maskExtent))
    #expect(alpha(linearOverlay, x: 10, y: 50) > alpha(linearOverlay, x: 50, y: 50))
    #expect(alpha(linearOverlay, x: 50, y: 50) > alpha(linearOverlay, x: 90, y: 50))
    #expect(alpha(linearOverlay, x: 90, y: 50) < 5)

    var halfOpacityLinear = linearMask
    halfOpacityLinear.opacity = 50
    let halfOpacityOverlay = try maskBytes(
        MaskRenderer.makeRedOverlay(halfOpacityLinear, extent: maskExtent)
    )
    #expect(alpha(halfOpacityOverlay, x: 10, y: 50) < alpha(linearOverlay, x: 10, y: 50))

    let skin = GeneratedMask(kind: .skin, pngData: try halfMaskPNG(), width: 10, height: 10)
    let skinMask = LocalMask(name: "Peau", components: [MaskComponent(shape: .generated(skin))])
    let skinOverlay = try maskBytes(MaskRenderer.makeRedOverlay(skinMask, extent: maskExtent))
    #expect(alpha(skinOverlay, x: 10, y: 50) > 95)
    #expect(alpha(skinOverlay, x: 90, y: 50) < 5)
}

@Test func subtractComponentCutsARealHole() throws {
    var outer = RadialGradientMask(); outer.radiusX = 0.48; outer.radiusY = 0.48; outer.feather = 5
    var inner = RadialGradientMask(); inner.radiusX = 0.12; inner.radiusY = 0.12; inner.feather = 5
    let mask = LocalMask(name: "Anneau", components: [
        MaskComponent(operation: .add, shape: .radial(outer)),
        MaskComponent(operation: .subtract, shape: .radial(inner))
    ])
    let bytes = try maskBytes(MaskRenderer.makeMask(mask, extent: maskExtent))
    #expect(red(bytes, x: 50, y: 50) < 10)
    #expect(red(bytes, x: 70, y: 50) > 240)
    #expect(red(bytes, x: 2, y: 2) < 10)
}

@Test func brushAndLinearMasksUseNormalizedCoordinates() throws {
    var brush = BrushMask(); brush.size = 20; brush.feather = 30
    brush.strokes = [[MaskPoint(x: 0.2, y: 0.8), MaskPoint(x: 0.8, y: 0.2)]]
    let brushMask = LocalMask(name: "Pinceau", components: [MaskComponent(shape: .brush(brush))])
    let brushPixels = try maskBytes(MaskRenderer.makeMask(brushMask, extent: maskExtent))
    #expect(red(brushPixels, x: 20, y: 80) > 100)
    #expect(red(brushPixels, x: 80, y: 20) > 100)
    #expect(red(brushPixels, x: 5, y: 95) < 10)

    var linear = LinearGradientMask(); linear.angle = 0; linear.feather = 20
    let linearMask = LocalMask(name: "Linéaire", components: [MaskComponent(shape: .linear(linear))])
    let linearPixels = try maskBytes(MaskRenderer.makeMask(linearMask, extent: maskExtent))
    #expect(red(linearPixels, x: 10, y: 50) > 240)
    #expect(red(linearPixels, x: 90, y: 50) < 10)
}

@Test func localExposureOnlyChangesMaskedRegionAndKeepsExtent() throws {
    let input = CIImage(color: CIColor(red: 0.2, green: 0.2, blue: 0.2)).cropped(to: maskExtent)
    var radial = RadialGradientMask(); radial.radiusX = 0.2; radial.radiusY = 0.2; radial.feather = 10
    var adjustment = LocalAdjustmentState(); adjustment.exposure = 2
    let mask = LocalMask(name: "Centre", components: [MaskComponent(shape: .radial(radial))], adjustments: adjustment)
    let output = try MaskRenderer.apply(input, masks: [mask])
    #expect(output.extent == input.extent)
    let pixels = try maskBytes(output)
    #expect(red(pixels, x: 50, y: 50) > red(pixels, x: 2, y: 2) + 45)
}

@Test func generatedMaskSerializesScalesAndAppliesLocally() throws {
    #expect(SmartMaskKind.allCases == [.subject, .background, .person, .face, .eyes, .sky, .skin])
    let generated = GeneratedMask(kind: .subject, pngData: try halfMaskPNG(), width: 10, height: 10)
    var adjustment = LocalAdjustmentState(); adjustment.exposure = 2
    let mask = LocalMask(name: "Sujet", components: [MaskComponent(shape: .generated(generated))],
                         adjustments: adjustment)
    let decoded = try JSONDecoder().decode(LocalMask.self, from: JSONEncoder().encode(mask))
    #expect(decoded == mask)

    let matte = try maskBytes(MaskRenderer.makeMask(mask, extent: maskExtent))
    #expect(red(matte, x: 10, y: 50) > 245)
    #expect(red(matte, x: 90, y: 50) < 10)
    let input = CIImage(color: CIColor(red: 0.2, green: 0.2, blue: 0.2)).cropped(to: maskExtent)
    let rendered = try maskBytes(MaskRenderer.apply(input, masks: [mask]))
    #expect(red(rendered, x: 10, y: 50) > red(rendered, x: 90, y: 50) + 45)

    let invalid = GeneratedMask(kind: .subject, pngData: Data([1]), width: 5_000, height: 10).validated
    #expect(invalid.pngData.isEmpty && invalid.width == 0 && invalid.height == 0)
    let person = GeneratedMask(kind: .person, pngData: try halfMaskPNG(), width: 10, height: 10)
    #expect(try JSONDecoder().decode(GeneratedMask.self, from: JSONEncoder().encode(person)) == person)
    let face = GeneratedMask(kind: .face, pngData: try halfMaskPNG(), width: 10, height: 10)
    #expect(try JSONDecoder().decode(GeneratedMask.self, from: JSONEncoder().encode(face)) == face)
    let eyes = GeneratedMask(kind: .eyes, pngData: try halfMaskPNG(), width: 10, height: 10)
    #expect(try JSONDecoder().decode(GeneratedMask.self, from: JSONEncoder().encode(eyes)) == eyes)
    let sky = GeneratedMask(kind: .sky, pngData: try halfMaskPNG(), width: 10, height: 10)
    #expect(try JSONDecoder().decode(GeneratedMask.self, from: JSONEncoder().encode(sky)) == sky)
    let skin = GeneratedMask(kind: .skin, pngData: try halfMaskPNG(), width: 10, height: 10)
    #expect(try JSONDecoder().decode(GeneratedMask.self, from: JSONEncoder().encode(skin)) == skin)
}

@Test func eyeMaskCreatesTwoSeparateFeatheredRegions() throws {
    let left = [CGPoint(x: 24, y: 58), CGPoint(x: 30, y: 61),
                CGPoint(x: 36, y: 58), CGPoint(x: 30, y: 55)]
    let right = [CGPoint(x: 64, y: 58), CGPoint(x: 70, y: 61),
                 CGPoint(x: 76, y: 58), CGPoint(x: 70, y: 55)]
    let bitmap = try #require(EyeMaskGenerator.makeMask(
        imageSize: CGSize(width: 100, height: 100), eyeRegions: [left, right]
    ))
    let pixels = try maskBytes(CIImage(cgImage: bitmap))
    // The CGContext byte rows read top-down here, hence 100 - 58 for the landmark Y.
    #expect(red(pixels, x: 30, y: 42) > 245)
    #expect(red(pixels, x: 70, y: 42) > 245)
    #expect(red(pixels, x: 50, y: 42) < 10)
    #expect(red(pixels, x: 2, y: 2) < 5)
    #expect((10...240).contains(red(pixels, x: 37, y: 42)))
}

@Test func skyMaskSelectsConnectedBlueUpperRegion() throws {
    let mask = try #require(SkyMaskGenerator.makeMask(from: syntheticLandscape()))
    let data = try #require(mask.dataProvider?.data) as Data
    #expect(data[10 * mask.bytesPerRow + 40] > 180)
    #expect(data[50 * mask.bytesPerRow + 40] < 10)
}

@Test func skinMaskCalibratesFromFaceAndSelectsMatchingRegion() throws {
    let face = CGRect(x: 0.25, y: 0.13, width: 0.5, height: 0.5)
    let mask = try #require(SkinMaskGenerator.makeMask(from: syntheticPortrait(), faceRegions: [face]))
    let data = try #require(mask.dataProvider?.data) as Data
    #expect(data[20 * mask.bytesPerRow + 40] > 180)
    #expect(data[50 * mask.bytesPerRow + 12] > 180)
    #expect(data[50 * mask.bytesPerRow + 70] < 10)
}

@Test func maskedLayerCarriesFullDevelopmentAndMigratesLegacyValues() async throws {
    var adjustments = LocalAdjustmentState()
    adjustments.curves.rgb = ToneCurve(points: [
        CurvePoint(x: 0, y: 0), CurvePoint(x: 0.25, y: 0.85), CurvePoint(x: 1, y: 1)
    ])
    adjustments.effects.texture = 22
    adjustments.detail.sharpening.amount = 35
    let generated = GeneratedMask(kind: .subject, pngData: try halfMaskPNG(), width: 10, height: 10)
    let layer = LocalMask(name: "Courbe locale", components: [MaskComponent(shape: .generated(generated))],
                          adjustments: adjustments)
    var state = EditState(); state.masks = [layer]

    let decoded = try JSONDecoder().decode(EditState.self, from: JSONEncoder().encode(state))
    #expect(decoded.masks[0].adjustments.curves == adjustments.curves)
    #expect(decoded.masks[0].adjustments.effects.texture == 22)
    #expect(decoded.masks[0].adjustments.detail.sharpening.amount == 35)

    let url = try solidPhotoURL()
    defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
    let result = try await RenderEngine().render(url: url, state: state, quality: .high)
    let pixels = try maskBytes(CIImage(cgImage: result.image))
    #expect(red(pixels, x: 10, y: 50) > red(pixels, x: 90, y: 50) + 45)

    let legacy = try JSONDecoder().decode(LocalAdjustmentState.self, from: Data(
        #"{"exposure":1.25,"clarity":18,"sharpness":42}"#.utf8
    ))
    #expect(legacy.exposure == 1.25)
    #expect(legacy.effects.clarity == 18)
    #expect(legacy.detail.sharpening.amount == 42)
}
