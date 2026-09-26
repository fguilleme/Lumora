import CoreGraphics
import CoreImage
import Foundation
import Testing
@testable import LumoraCore

@Test func newCreativeEffectsUseAVisibleStartingLook() {
    let toning = CreativeFXPreset.initialEffect(for: .silverToning)
    #expect(toning["toner"] != 0)
    #expect(toning["strength"] > 0)
    #expect(toning.maskID == nil)

    let center = CreativeFXPreset.initialEffect(for: .darkenLightenCenter)
    #expect(center["centerEV"] != 0 || center["borderEV"] != 0)
    #expect(center.maskID == nil)

    let cross = CreativeFXPreset.initialEffect(for: .crossProcessing)
    #expect(cross["style"] != 0)
    // The serialized neutral definitions remain available to existing edits.
    #expect(CreativeEffect(.silverToning)["toner"] == 0)
    #expect(CreativeEffect(.darkenLightenCenter)["centerEV"] == 0)

    let mask = UUID()
    var modified = CreativeEffect(.silverToning, maskID: mask)
    let originalID = modified.id
    modified["strength"] = 0
    CreativeFXPreset.resetToInitialLook(&modified)
    #expect(modified.id == originalID)
    #expect(modified.maskID == mask)
    #expect(modified["toner"] == toning["toner"])
    #expect(modified["strength"] == toning["strength"])
}

@Test func extremeColorEffectsRemainFiniteAndOrderedThroughHDR() throws {
    let width = 512
    let linear = try #require(CGColorSpace(name: CGColorSpace.extendedLinearSRGB))
    var ramp = [Float](repeating: 1, count: width * 4)
    for x in 0..<width {
        let value = Float(8 * pow(Double(x) / Double(width - 1), 2))
        for channel in 0..<3 { ramp[x * 4 + channel] = value }
    }
    let input = CIImage(bitmapData: ramp.withUnsafeBytes { Data($0) },
                        bytesPerRow: width * 16, size: CGSize(width: width, height: 1),
                        format: .RGBAf, colorSpace: linear)
    let context = CIContext()
    for kind in [CreativeEffectKind.crossProcessing, .filmEmulation] {
        for style in 0...6 {
            var effect = CreativeFXPreset.initialEffect(for: kind)
            effect["style"] = Double(style)
            effect["amount"] = 100
            let result = try CreativeStackRenderer.apply(input,
                stack: CreativeEffectStack(effects: [effect]), masks: [])
            var output = [Float](repeating: 0, count: width * 4)
            output.withUnsafeMutableBytes { bytes in
                context.render(result, toBitmap: bytes.baseAddress!, rowBytes: width * 16,
                               bounds: input.extent, format: .RGBAf, colorSpace: linear)
            }
            for x in 0..<width {
                for channel in 0..<3 {
                    let next = output[x * 4 + channel]
                    #expect(next.isFinite, "\(kind.rawValue), style \(style), x=\(x)")
                    if x > 0 {
                        #expect(next >= output[(x - 1) * 4 + channel] - 0.001,
                                "\(kind.rawValue), style \(style), x=\(x)")
                    }
                }
            }
            #expect(output[(width - 1) * 4] > 1,
                    "\(kind.rawValue), style \(style) clipped HDR")
        }
    }
}

@Test func extremeCreativeAmountAddsVisibleHeadroomWithoutChangingPresetRange() throws {
    #expect(CreativeEndpointGain.multiplier(95, atMaximum: 4) == 1)
    #expect(CreativeEndpointGain.multiplier(100, atMaximum: 4) == 4)

    let width = 128, height = 128
    var samples = [UInt8](repeating: 255, count: width * height * 4)
    for y in 0..<height {
        for x in 0..<width {
            let wave = 12 * sin(Double(x) * 0.6) * sin(Double(y) * 0.4)
            let gray = UInt8(max(0, min(255, (Double(x) / 127 * 225 + 15 + wave).rounded())))
            let i = (y * width + x) * 4
            samples[i] = gray
            samples[i + 1] = UInt8(min(255, Int(gray) + 7))
            samples[i + 2] = UInt8(max(0, Int(gray) - 8))
        }
    }
    let provider = try #require(CGDataProvider(data: Data(samples) as CFData))
    let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
    let bitmap = try #require(CGImage(width: width, height: height,
        bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
        space: space, bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
        provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent))
    let input = CIImage(cgImage: bitmap)
    let context = CIContext()
    let linear = try #require(CGColorSpace(name: CGColorSpace.extendedLinearSRGB))
    func pixels(_ image: CIImage) -> [Float] {
        var rgba = [Float](repeating: 0, count: width * height * 4)
        rgba.withUnsafeMutableBytes { bytes in
            context.render(image, toBitmap: bytes.baseAddress!, rowBytes: width * 16,
                           bounds: input.extent, format: .RGBAf, colorSpace: linear)
        }
        return rgba
    }
    let original = pixels(input)
    func difference(_ output: [Float]) -> Double {
        var sum = 0.0
        for i in stride(from: 0, to: original.count, by: 4) {
            sum += Double(abs(original[i] - output[i]))
            sum += Double(abs(original[i + 1] - output[i + 1]))
            sum += Double(abs(original[i + 2] - output[i + 2]))
        }
        return sum / Double(width * height * 3)
    }
    for kind in [CreativeEffectKind.tonalContrast, .detailExtractor, .proContrast,
                 .crossProcessing, .filmEmulation] {
        var effect = CreativeFXPreset.initialEffect(for: kind)
        let control = kind == .tonalContrast ? "globalAmount" : "amount"
        effect[control] = 95
        let before = try CreativeStackRenderer.apply(input,
            stack: CreativeEffectStack(effects: [effect]), masks: [])
        effect[control] = 100
        let after = try CreativeStackRenderer.apply(input,
            stack: CreativeEffectStack(effects: [effect]), masks: [])
        let lower = difference(pixels(before)), upper = difference(pixels(after))
        #expect(upper > lower * 1.2, "\(kind.rawValue): 95=\(lower), 100=\(upper)")
    }
    for kind in [CreativeEffectKind.silverToning, .darkenLightenCenter,
                 .crossProcessing, .filmEmulation] {
        let effect = CreativeFXPreset.initialEffect(for: kind)
        let output = try CreativeStackRenderer.apply(input,
            stack: CreativeEffectStack(effects: [effect]), masks: [])
        let change = difference(pixels(output))
        #expect(change > 0.001, "\(kind.rawValue) starts with an invisible look: \(change)")
    }
}
