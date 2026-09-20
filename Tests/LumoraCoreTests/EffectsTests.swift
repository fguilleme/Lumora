import Testing
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
@testable import LumoraCore

private func effectsFixture(uniform: Bool = false) throws -> URL {
    let url = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".png")
    let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
    let context = try #require(CGContext(data: nil, width: 128, height: 128, bitsPerComponent: 8,
                                        bytesPerRow: 512, space: space,
                                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    for y in stride(from: 0, to: 128, by: 4) {
        for x in stride(from: 0, to: 128, by: 4) {
            let value = uniform ? 0.55 : 0.40 + Double((x / 4 + y / 4) % 2) * 0.18
            context.setFillColor(try #require(CGColor(colorSpace: space, components: [value, value, value, 1])))
            context.fill(CGRect(x: x, y: y, width: 4, height: 4))
        }
    }
    let image = try #require(context.makeImage())
    let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil))
    CGImageDestinationAddImage(destination, image, nil)
    #expect(CGImageDestinationFinalize(destination))
    return url
}

private func pixelLuma(_ image: CGImage, x: Int, y: Int) throws -> Double {
    let crop = try #require(image.cropping(to: CGRect(x: x, y: y, width: 1, height: 1)))
    let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
    var bytes = [UInt8](repeating: 0, count: 4)
    try bytes.withUnsafeMutableBytes { buffer in
        let context = try #require(CGContext(data: buffer.baseAddress, width: 1, height: 1, bitsPerComponent: 8,
                                            bytesPerRow: 4, space: space,
                                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(crop, in: CGRect(x: 0, y: 0, width: 1, height: 1))
    }
    return (Double(bytes[0]) * 0.2126 + Double(bytes[1]) * 0.7152 + Double(bytes[2]) * 0.0722) / 255
}

@Test func effectsSettingsValidateMigrateSerializeAndHistory() throws {
    var settings = EffectsSettings(texture: 400, clarity: -.infinity, dehaze: -140, vignette: 35, grain: -20)
    settings = settings.validated
    #expect(settings.texture == 100 && settings.clarity == 0 && settings.dehaze == -100)
    #expect(settings.vignette == 35 && settings.grain == 0)
    var state = try JSONDecoder().decode(EditState.self, from: Data(#"{"exposure":1}"#.utf8))
    #expect(state.effects.isIdentity)
    state.effects = settings
    #expect(try JSONDecoder().decode(EditState.self, from: JSONEncoder().encode(state)) == state)
    var history = HistoryManager()
    history.begin("Effets", state: EditState())
    history.commit(state)
    #expect(history.undo() == EditState())
    #expect(history.redo() == state)
}

@Test func effectsIdentityAndTextureClarityUseDistinctScales() async throws {
    let url = try effectsFixture()
    defer { try? FileManager.default.removeItem(at: url) }
    let engine = RenderEngine()
    let neutral = try await engine.render(url: url, state: EditState(), quality: .high)
    var textureState = EditState(); textureState.effects.texture = 80
    let texture = try await engine.render(url: url, state: textureState, quality: .high)
    var clarityState = EditState(); clarityState.effects.clarity = 80
    let clarity = try await engine.render(url: url, state: clarityState, quality: .high)
    #expect(texture.histogram.luminance != neutral.histogram.luminance)
    #expect(clarity.histogram.luminance != neutral.histogram.luminance)
    #expect(texture.histogram.luminance != clarity.histogram.luminance)
    let reset = try await engine.render(url: url, state: EditState(), quality: .high)
    #expect(reset.histogram.luminance == neutral.histogram.luminance)
}

@Test func dehazeChangesHazyToneAndVignetteTargetsEdges() async throws {
    let url = try effectsFixture(uniform: true)
    defer { try? FileManager.default.removeItem(at: url) }
    let engine = RenderEngine()
    let neutral = try await engine.render(url: url, state: EditState(), quality: .high)
    var vignetteState = EditState(); vignetteState.effects.vignette = -80
    let vignette = try await engine.render(url: url, state: vignetteState, quality: .high)
    let center = try pixelLuma(vignette.image, x: 64, y: 64)
    let corner = try pixelLuma(vignette.image, x: 2, y: 2)
    #expect(center > corner + 0.08)
    #expect(abs(center - (try pixelLuma(neutral.image, x: 64, y: 64))) < 0.08)

    var dehazeState = EditState(); dehazeState.effects.dehaze = 70
    let dehazed = try await engine.render(url: url, state: dehazeState, quality: .high)
    #expect(dehazed.histogram.luminance != neutral.histogram.luminance)
}

@Test func grainChangesUniformImageWithoutChangingExtent() async throws {
    let url = try effectsFixture(uniform: true)
    defer { try? FileManager.default.removeItem(at: url) }
    let engine = RenderEngine()
    var state = EditState(); state.effects.grain = 75
    let result = try await engine.render(url: url, state: state, quality: .high)
    #expect(result.image.width == 128 && result.image.height == 128)
    #expect(result.histogram.luminance.filter { $0 > 0 }.count > 5)
}
