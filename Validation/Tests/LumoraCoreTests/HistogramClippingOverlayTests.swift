import CoreGraphics
import CoreImage
import Foundation
import Testing
@testable import LumoraCore

private func clippingFixture(_ pixel: (Int, Int) -> (UInt8, UInt8, UInt8)) -> CGImage {
    let side = 160
    var bytes = [UInt8](repeating: 255, count: side * side * 4)
    for y in 0..<side { for x in 0..<side {
        let (r, g, b) = pixel(x, y)
        let index = (y * side + x) * 4
        bytes[index] = r; bytes[index + 1] = g; bytes[index + 2] = b
    } }
    return bytes.withUnsafeMutableBytes { buffer in
        let context = CGContext(data: buffer.baseAddress, width: side, height: side,
                                bitsPerComponent: 8, bytesPerRow: side * 4,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        return context.makeImage()!
    }
}

private func clippingBytes(_ image: CGImage) -> [UInt8] {
    var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
    bytes.withUnsafeMutableBytes { buffer in
        let context = CGContext(data: buffer.baseAddress, width: image.width, height: image.height,
                                bitsPerComponent: 8, bytesPerRow: image.width * 4,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.interpolationQuality = .none
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    }
    return bytes
}

@Test func clippingMaskUsesHistogramSDREndpointsWithoutGlobalOccupancyGate() throws {
    let source = clippingFixture { x, y in
        if x == 0 && y == 0 { return (255, 80, 80) } // one pixel < 0.2%
        if x < 40 { return (0, 0, 0) }
        if x < 80 { return (1, 1, 1) }
        if x < 120 { return (254, 254, 254) }
        return (80, 80, 80)
    }
    let before = Histogram.compute(source)
    let mask = try #require(HistogramClippingOverlay.make(from: source))
    #expect(mask.width == source.width && mask.height == source.height)
    let sourceBytes = clippingBytes(source), maskBytes = clippingBytes(mask)
    for offset in stride(from: 0, to: sourceBytes.count, by: 4) {
        let r = sourceBytes[offset], g = sourceBytes[offset + 1], b = sourceBytes[offset + 2]
        let alpha = maskBytes[offset + 3]
        if max(r, g, b) >= Histogram.highlightEndpoint {
            #expect(alpha > 0)
            #expect(maskBytes[offset] > maskBytes[offset + 2]) // red highlight
        } else if max(r, g, b) <= Histogram.shadowEndpoint {
            #expect(alpha > 0)
            #expect(maskBytes[offset + 2] > maskBytes[offset]) // blue shadow
        } else {
            #expect(alpha == 0)
        }
    }
    #expect(before.red == Histogram.compute(source).red)
    #expect(before.highlights == Histogram.compute(source).highlights)
}

@Test func clippingMaskSingleChannelHighlightsAndUniformExtremes() throws {
    for (r, g, b) in [(UInt8(255), UInt8(80), UInt8(80)), (80, 255, 80), (80, 80, 255)] {
        let mask = try #require(HistogramClippingOverlay.make(from: clippingFixture { _, _ in (r, g, b) }))
        let bytes = clippingBytes(mask)
        #expect(bytes[3] > 0 && bytes[0] > bytes[2])
    }
    let black = try #require(HistogramClippingOverlay.make(from: clippingFixture { _, _ in (0, 0, 0) }))
    let blackBytes = clippingBytes(black)
    #expect(blackBytes[3] > 0 && blackBytes[2] > blackBytes[0])
    let gray = try #require(HistogramClippingOverlay.make(from: clippingFixture { _, _ in (118, 118, 118) }))
    #expect(clippingBytes(gray).allSatisfy { $0 == 0 })
}

@Test func clippingMaskTracksRenderedCropRotationAndMirror() throws {
    let source = clippingFixture { x, y in
        if x < 32 && y < 40 { return (0, 0, 0) }
        if x > 125 && y > 100 { return (255, 140, 140) }
        return (100, 100, 100)
    }
    let context = CIContext(options: [.workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!])
    let cropped = CIImage(cgImage: source).cropped(to: CGRect(x: 10, y: 20, width: 140, height: 120))
    let variants = [cropped, cropped.oriented(.right), cropped.oriented(.down),
                    cropped.oriented(.left), cropped.oriented(.upMirrored)]
    for variant in variants {
        let extent = variant.extent.integral
        let rendered = try #require(context.createCGImage(variant, from: extent))
        let mask = try #require(HistogramClippingOverlay.make(from: rendered))
        #expect(mask.width == rendered.width && mask.height == rendered.height)
        let input = clippingBytes(rendered), output = clippingBytes(mask)
        for offset in stride(from: 0, to: input.count, by: 4) {
            let r = input[offset], g = input[offset + 1], b = input[offset + 2]
            let expected = max(r, g, b) >= Histogram.highlightEndpoint ||
                max(r, g, b) <= Histogram.shadowEndpoint
            #expect((output[offset + 3] > 0) == expected)
        }
    }
}
