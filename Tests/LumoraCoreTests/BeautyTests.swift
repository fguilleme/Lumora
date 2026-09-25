import CoreGraphics
import CoreImage
import Foundation
import Testing
@testable import LumoraCore

@Test func beautyStateMigrationAndPresets() throws {
    let legacy = try JSONDecoder().decode(EditState.self, from: Data("{}".utf8))
    #expect(legacy.beauty == BeautyState())
    #expect(legacy.beauty.isIdentity)
    for preset in BeautyPreset.allCases {
        let settings = preset.settings
        #expect(BeautyPreset.matching(settings) == preset)
        #expect(!settings.isIdentity)
        let data = try JSONEncoder().encode(settings)
        #expect(try JSONDecoder().decode(BeautyState.self, from: data) == settings)
    }
    var custom = BeautyPreset.portrait.settings
    custom.texture -= 1
    #expect(BeautyPreset.matching(custom) == nil)
    custom.amount = 0
    #expect(custom.isIdentity)
    custom.amount = 100
    #expect(!custom.isIdentity)
}

@Test func beautyUndoRedoAndDocumentReload() throws {
    var before = EditState()
    var history = HistoryManager()
    history.begin("Beauty preset", state: before)
    before.beauty = BeautyPreset.portrait.settings
    history.commit(before)
    #expect(history.canUndo)
    let undoValue = history.undo()
    let restored = try #require(undoValue)
    #expect(restored.beauty.isIdentity)
    let redoValue = history.redo()
    let redone = try #require(redoValue)
    #expect(redone.beauty == BeautyPreset.portrait.settings)
    let encoded = try JSONEncoder().encode(redone)
    #expect(try JSONDecoder().decode(EditState.self, from: encoded).beauty == redone.beauty)
}

@Test func beautyVisionHonorsCancellation() async throws {
    let input = CIImage(color: CIColor(red: 0.4, green: 0.4, blue: 0.4))
        .cropped(to: CGRect(x: 0, y: 0, width: 64, height: 64))
    let bitmap = try #require(CIContext().createCGImage(input, from: input.extent))
    let task = Task {
        withUnsafeCurrentTask { $0?.cancel() }
        return try BeautyFaceAnalysis.analyze(bitmap)
    }
    await #expect(throws: CancellationError.self) { try await task.value }
}

@Test func beautyNeutralReconstructionAndHDR() throws {
    let width = 256
    let space = try #require(CGColorSpace(name: CGColorSpace.extendedLinearSRGB))
    var values = [Float](repeating: 1, count: width * 4)
    for x in 0..<width {
        let luminance = Float(8 * Double(x) / Double(width - 1))
        for channel in 0..<3 { values[x * 4 + channel] = luminance }
    }
    let input = CIImage(bitmapData: values.withUnsafeBytes { Data($0) },
        bytesPerRow: width * 16, size: CGSize(width: width, height: 1),
        format: .RGBAf, colorSpace: space)
    let empty = BeautyMasks.empty
    let neutral = try BeautyRenderer.apply(input, settings: BeautyState(), masks: empty)
    #expect(neutral === input)
    let rebuilt = try BeautyRenderer.reconstructed(input, radius: 5)
    let context = CIContext()
    var output = [Float](repeating: 0, count: values.count)
    output.withUnsafeMutableBytes { data in
        context.render(rebuilt, toBitmap: data.baseAddress!, rowBytes: width * 16,
                       bounds: input.extent, format: .RGBAf, colorSpace: space)
    }
    var maximum: Float = 0
    for index in values.indices {
        #expect(output[index].isFinite)
        maximum = max(maximum, abs(output[index] - values[index]))
    }
    #expect(maximum < 0.003, "Frequency reconstruction error: \(maximum)")
    #expect(output[(width - 1) * 4] > 7.9)
}

@Test func beautyNoFaceIsIdentity() throws {
    let input = CIImage(color: CIColor(red: 0.4, green: 0.4, blue: 0.4)).cropped(to:
        CGRect(x: 0, y: 0, width: 64, height: 64))
    let bitmap = try #require(CIContext().createCGImage(input, from: input.extent))
    let masks = try BeautyFaceAnalysis.analyze(bitmap)
    #expect(masks.faceCount == 0)
    let output = try BeautyRenderer.apply(input, settings: BeautyPreset.beauty.settings, masks: masks)
    #expect(output === input)
}

@Test func beautyMaskedRenderStaysFiniteAndLocal() throws {
    let width = 64, height = 64
    let space = try #require(CGColorSpace(name: CGColorSpace.extendedLinearSRGB))
    let input = CIImage(color: CIColor(red: 0.5, green: 0.4, blue: 0.3, alpha: 1))
        .cropped(to: CGRect(x: 0, y: 0, width: width, height: height))
    var matte = [UInt8](repeating: 0, count: width * height)
    for y in 16..<48 { for x in 16..<48 { matte[y * width + x] = 255 } }
    let mask = try #require(CGImage(width: width, height: height,
        bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: width,
        space: CGColorSpace(name: CGColorSpace.linearGray)!,
        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
        provider: CGDataProvider(data: Data(matte) as CFData)!, decode: nil,
        shouldInterpolate: false, intent: .defaultIntent))
    let masks = BeautyMasks(faceCount: 1, faceWidthFraction: 0.5, faceRects: [],
        skin: mask, eyes: mask, underEyes: mask, teeth: mask, blemishes: mask)
    var disabled = BeautyPreset.beauty.settings
    disabled.amount = 0
    let bypassed = try BeautyRenderer.apply(input, settings: disabled, masks: masks)
    #expect(bypassed === input)
    var sourcePixels = [Float](repeating: 0, count: width * height * 4)
    sourcePixels.withUnsafeMutableBytes { data in
        CIContext().render(input, toBitmap: data.baseAddress!, rowBytes: width * 16,
                           bounds: input.extent, format: .RGBAf, colorSpace: space)
    }
    let output = try BeautyRenderer.apply(input, settings: BeautyPreset.beauty.settings, masks: masks)
    var pixels = [Float](repeating: 0, count: width * height * 4)
    pixels.withUnsafeMutableBytes { data in
        CIContext().render(output, toBitmap: data.baseAddress!, rowBytes: width * 16,
                           bounds: input.extent, format: .RGBAf, colorSpace: space)
    }
    #expect(pixels.allSatisfy { $0.isFinite })
    #expect(abs(pixels[0] - sourcePixels[0]) < 0.01)
    #expect(abs(pixels[(32 * width + 32) * 4] - sourcePixels[(32 * width + 32) * 4]) > 0.001)
}
