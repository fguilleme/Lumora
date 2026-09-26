import Testing
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
@testable import LumoraCore

private func opticsFixture(uniform: Bool = false, metadata: Bool = false) throws -> URL {
    let size = 128
    let url = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".tiff")
    let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
    let context = try #require(CGContext(data: nil, width: size, height: size, bitsPerComponent: 8,
                                        bytesPerRow: size * 4, space: space,
                                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    context.setFillColor(try #require(CGColor(colorSpace: space, components: [0.5, 0.5, 0.5, 1])))
    context.fill(CGRect(x: 0, y: 0, width: size, height: size))
    if !uniform {
        context.setFillColor(try #require(CGColor(colorSpace: space, components: [0.95, 0.95, 0.95, 1])))
        context.fill(CGRect(x: 24, y: 24, width: 80, height: 80))
        context.setFillColor(try #require(CGColor(colorSpace: space, components: [0.05, 0.05, 0.05, 1])))
        context.fill(CGRect(x: 43, y: 43, width: 42, height: 42))
    }
    let image = try #require(context.makeImage())
    let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, UTType.tiff.identifier as CFString, 1, nil))
    var properties: [CFString: Any] = [:]
    if metadata {
        properties[kCGImagePropertyTIFFDictionary] = [
            kCGImagePropertyTIFFMake: "Lumora Test", kCGImagePropertyTIFFModel: "Camera 1"
        ]
        properties[kCGImagePropertyExifDictionary] = [kCGImagePropertyExifLensModel: "Prime 35 mm"]
    }
    CGImageDestinationAddImage(destination, image, properties as CFDictionary)
    #expect(CGImageDestinationFinalize(destination))
    return url
}

private func opticsPixels(_ image: CGImage) throws -> [[Double]] {
    let width = image.width, height = image.height
    let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
    var bytes = [UInt8](repeating: 0, count: width * height * 4)
    try bytes.withUnsafeMutableBytes { buffer in
        let context = try #require(CGContext(data: buffer.baseAddress, width: width, height: height,
                                            bitsPerComponent: 8, bytesPerRow: width * 4, space: space,
                                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    }
    return stride(from: 0, to: bytes.count, by: 4).map {
        [Double(bytes[$0]) / 255, Double(bytes[$0 + 1]) / 255, Double(bytes[$0 + 2]) / 255]
    }
}

@Test func opticsSettingsMigrateValidateSerializeAndHistory() throws {
    var settings = OpticsSettings()
    settings[.distortion] = 1000; settings[.chromaticAberration] = -.infinity
    settings[.lensVignette] = -80
    #expect(settings.distortion == 100 && settings.chromaticAberration == 0 && settings.lensVignette == 0)
    let old = try JSONDecoder().decode(EditState.self, from: Data(#"{"exposure":1}"#.utf8))
    #expect(old.optics.profileCorrection && !old.optics.hasManualCorrections)
    let partial = try JSONDecoder().decode(OpticsSettings.self, from: Data(#"{"profileCorrection":false,"distortion":25}"#.utf8))
    #expect(!partial.profileCorrection && partial.distortion == 25)
    var state = EditState(); state.optics = partial
    #expect(try JSONDecoder().decode(EditState.self, from: JSONEncoder().encode(state)) == state)
    var history = HistoryManager(); history.begin("Optique", state: EditState()); history.commit(state)
    #expect(history.undo() == EditState() && history.redo() == state)
}

@Test func developedImageReportsMetadataWithoutPretendingToHaveProfile() async throws {
    let url = try opticsFixture(metadata: true)
    defer { try? FileManager.default.removeItem(at: url) }
    let result = try await RenderEngine().render(url: url, state: EditState(), quality: .high)
    #expect(!result.isRAW && !result.optics.profileSupported)
    #expect(result.optics.camera == "Lumora Test Camera 1")
    #expect(result.optics.lens == "Prime 35 mm")
}

@Test func manualDistortionAndChromaticCorrectionChangePixelsAndKeepExtent() async throws {
    let url = try opticsFixture()
    defer { try? FileManager.default.removeItem(at: url) }
    let engine = RenderEngine()
    let neutral = try await engine.render(url: url, state: EditState(), quality: .high)
    var distortionState = EditState(); distortionState.optics.distortion = 80
    let distorted = try await engine.render(url: url, state: distortionState, quality: .high)
    #expect(distorted.image.width == 128 && distorted.image.height == 128)
    #expect(distorted.histogram.luminance != neutral.histogram.luminance)

    var chromaticState = EditState(); chromaticState.optics.chromaticAberration = 100
    let chromatic = try await engine.render(url: url, state: chromaticState, quality: .high)
    let pixels = try opticsPixels(chromatic.image)
    #expect(chromatic.histogram.red != chromatic.histogram.blue)
    #expect(pixels.filter { abs($0[0] - $0[2]) > 0.002 }.count > 20)
    let reset = try await engine.render(url: url, state: EditState(), quality: .high)
    #expect(reset.histogram.red == neutral.histogram.red)
}

@Test func lensVignetteCorrectionBrightensCornersMoreThanCenter() async throws {
    let url = try opticsFixture(uniform: true)
    defer { try? FileManager.default.removeItem(at: url) }
    var state = EditState(); state.optics.lensVignette = 100
    let result = try await RenderEngine().render(url: url, state: state, quality: .high)
    let pixels = try opticsPixels(result.image)
    func luma(_ index: Int) -> Double {
        let p = pixels[index]; return p[0] * 0.2126 + p[1] * 0.7152 + p[2] * 0.0722
    }
    let corner = luma(2 * 128 + 2), center = luma(64 * 128 + 64)
    #expect(corner > center + 0.04)
}
