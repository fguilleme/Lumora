import Testing
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
@testable import LumoraCore

private enum DetailFixtureKind { case luminanceNoise, colorNoise, edge }

private func detailFixture(_ kind: DetailFixtureKind) throws -> URL {
    let size = 128
    let url = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".png")
    let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
    let context = try #require(CGContext(data: nil, width: size, height: size, bitsPerComponent: 8,
                                        bytesPerRow: size * 4, space: space,
                                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    for y in 0..<size { for x in 0..<size {
        let components: [CGFloat]
        switch kind {
        case .luminanceNoise:
            let value = CGFloat(0.46 + Double((x * 17 + y * 31) % 9) / 100)
            components = [value, value, value, 1]
        case .colorNoise:
            components = (x + y).isMultiple(of: 2) ? [0.62, 0.47, 0.50, 1] : [0.38, 0.53, 0.50, 1]
        case .edge:
            let value: CGFloat = x < size / 2 ? 0.35 : 0.65
            components = [value, value, value, 1]
        }
        context.setFillColor(try #require(CGColor(colorSpace: space, components: components)))
        context.fill(CGRect(x: x, y: y, width: 1, height: 1))
    } }
    let image = try #require(context.makeImage())
    let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil))
    CGImageDestinationAddImage(destination, image, nil)
    #expect(CGImageDestinationFinalize(destination))
    return url
}

private struct DetailStatistics {
    var lumaVariance: Double
    var chromaVariance: Double
    var pixels: [[Double]]
}

private func detailStatistics(_ image: CGImage) throws -> DetailStatistics {
    let width = image.width, height = image.height
    let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
    var bytes = [UInt8](repeating: 0, count: width * height * 4)
    try bytes.withUnsafeMutableBytes { buffer in
        let context = try #require(CGContext(data: buffer.baseAddress, width: width, height: height,
                                            bitsPerComponent: 8, bytesPerRow: width * 4, space: space,
                                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    }
    var pixels = [[Double]](); pixels.reserveCapacity(width * height)
    for index in stride(from: 0, to: bytes.count, by: 4) {
        pixels.append([Double(bytes[index]) / 255, Double(bytes[index + 1]) / 255, Double(bytes[index + 2]) / 255])
    }
    let lumas = pixels.map { $0[0] * 0.2126 + $0[1] * 0.7152 + $0[2] * 0.0722 }
    let chromas = pixels.map { abs($0[0] - $0[1]) + abs($0[2] - $0[1]) }
    func variance(_ values: [Double]) -> Double {
        let mean = values.reduce(0, +) / Double(values.count)
        return values.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(values.count)
    }
    return DetailStatistics(lumaVariance: variance(lumas), chromaVariance: variance(chromas), pixels: pixels)
}

@Test func detailSettingsValidateMigrateSerializeAndHistory() throws {
    var settings = DetailSettings()
    settings[.sharpeningAmount] = 500
    settings[.sharpeningRadius] = .nan
    settings[.luminanceDetail] = -10
    settings[.colorSmoothness] = 200
    #expect(settings.sharpening.amount == 150 && settings.sharpening.radius == 1)
    #expect(settings.noiseReduction.detail == 0 && settings.colorNoiseReduction.smoothness == 100)
    let old = try JSONDecoder().decode(EditState.self, from: Data(#"{"contrast":12}"#.utf8))
    #expect(old.detail.isIdentity && old.detail.sharpening.radius == 1)
    let partial = try JSONDecoder().decode(DetailSettings.self, from: Data(#"{"sharpening":{"amount":40}}"#.utf8))
    #expect(partial.sharpening.amount == 40 && partial.sharpening.detail == 25)
    var state = EditState(); state.detail = settings
    #expect(try JSONDecoder().decode(EditState.self, from: JSONEncoder().encode(state)) == state)
    var history = HistoryManager(); history.begin("Détail", state: EditState()); history.commit(state)
    #expect(history.undo() == EditState() && history.redo() == state)
}

@Test func luminanceNoiseReductionReducesFineLumaVariance() async throws {
    let url = try detailFixture(.luminanceNoise)
    defer { try? FileManager.default.removeItem(at: url) }
    let engine = RenderEngine()
    let neutral = try await engine.render(url: url, state: EditState(), quality: .high)
    var state = EditState(); state.detail.noiseReduction.luminance = 100
    state.detail.noiseReduction.detail = 0
    let reduced = try await engine.render(url: url, state: state, quality: .high)
    let before = try detailStatistics(neutral.image), after = try detailStatistics(reduced.image)
    #expect(after.lumaVariance < before.lumaVariance * 0.8)
    #expect(reduced.image.width == neutral.image.width && reduced.image.height == neutral.image.height)
}

@Test func colorNoiseReductionSuppressesChromaAndPreservesLuma() async throws {
    let url = try detailFixture(.colorNoise)
    defer { try? FileManager.default.removeItem(at: url) }
    let engine = RenderEngine()
    let neutral = try await engine.render(url: url, state: EditState(), quality: .high)
    var state = EditState(); state.detail.colorNoiseReduction.color = 100
    state.detail.colorNoiseReduction.detail = 0; state.detail.colorNoiseReduction.smoothness = 100
    let reduced = try await engine.render(url: url, state: state, quality: .high)
    let before = try detailStatistics(neutral.image), after = try detailStatistics(reduced.image)
    #expect(after.chromaVariance < before.chromaVariance * 0.25)
    #expect(abs(after.lumaVariance - before.lumaVariance) < 0.0002)
}

@Test func sharpeningChangesEdgesAndMaskingProtectsFlatAreas() async throws {
    let url = try detailFixture(.edge)
    defer { try? FileManager.default.removeItem(at: url) }
    let engine = RenderEngine()
    let neutral = try await engine.render(url: url, state: EditState(), quality: .high)
    var state = EditState(); state.detail.sharpening.amount = 120
    state.detail.sharpening.detail = 80; state.detail.sharpening.masking = 100
    let sharpened = try await engine.render(url: url, state: state, quality: .high)
    let before = try detailStatistics(neutral.image), after = try detailStatistics(sharpened.image)
    #expect(sharpened.histogram.luminance != neutral.histogram.luminance)
    let flatIndex = 20 * neutral.image.width + 20
    #expect(abs(after.pixels[flatIndex][0] - before.pixels[flatIndex][0]) < 0.02)
    #expect(sharpened.original === neutral.original)
}
