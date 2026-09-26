import CoreGraphics
import CoreImage
import Foundation
import Testing
@testable import LumoraCore

private func histogramPixels(_ pixel: (Int, Int) -> (UInt8, UInt8, UInt8)) -> Histogram {
    let side = 160
    var bytes = [UInt8](repeating: 255, count: side * side * 4)
    for y in 0..<side { for x in 0..<side {
        let (r, g, b) = pixel(x, y)
        let offset = (y * side + x) * 4
        bytes[offset] = r; bytes[offset + 1] = g; bytes[offset + 2] = b
    } }
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let image = bytes.withUnsafeMutableBytes { buffer in
        let context = CGContext(data: buffer.baseAddress, width: side, height: side,
                                bitsPerComponent: 8, bytesPerRow: side * 4,
                                space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        return context.makeImage()!
    }
    return Histogram.compute(image)
}

@Test func histogramDisplayBinsAndNearEndpoints() {
    let black = histogramPixels { _, _ in (0, 0, 0) }
    #expect(black.samples == 25_600)
    #expect(black.red[0] == black.samples)
    #expect(black.shadows == black.samples)
    #expect(black.highlights == 0)

    let white = histogramPixels { _, _ in (255, 255, 255) }
    #expect(white.red[Histogram.endpointBin] == white.samples)
    #expect(white.highlights == white.samples)
    #expect(white.shadows == 0)

    let gray = histogramPixels { _, _ in (118, 118, 118) }
    #expect(gray.red[118] == gray.samples)
    #expect(gray.shadows == 0 && gray.highlights == 0)

    let nearBlack = histogramPixels { _, _ in (1, 1, 1) }
    #expect(nearBlack.red[1] == nearBlack.samples)
    #expect(nearBlack.shadows == nearBlack.samples)
    let nearWhite = histogramPixels { _, _ in (254, 254, 254) }
    #expect(nearWhite.red[254] == nearWhite.samples)
    #expect(nearWhite.highlights == nearWhite.samples)
    let belowWhiteWarning = histogramPixels { _, _ in (253, 253, 253) }
    #expect(belowWhiteWarning.highlights == 0)

    for channel in 0..<3 {
        let single = histogramPixels { _, _ in
            let values: [UInt8] = (0..<3).map { $0 == channel ? 255 : 80 }
            return (values[0], values[1], values[2])
        }
        #expect(single.highlights == single.samples)
        #expect(single.shadows == 0)
    }
}

@Test func histogramGradientAndSparseEndpointOccupancy() {
    let ramp = histogramPixels { x, _ in
        let value = UInt8((Double(x) / 159 * 255).rounded())
        return (value, value, value)
    }
    #expect(ramp.samples == 25_600)
    #expect(ramp.red[0] > 0 && ramp.red[255] > 0)
    #expect(ramp.red.filter { $0 > 0 }.count >= 150)

    let sparse = histogramPixels { x, y in x == 0 && y == 0 ? (255, 80, 80) : (80, 80, 80) }
    #expect(sparse.highlights == 1)
    #expect(sparse.highlightFraction < 0.002)
    let broad = histogramPixels { x, _ in x < 80 ? (255, 80, 80) : (80, 80, 80) }
    #expect(broad.highlightFraction == 0.5)
    #expect(Histogram.displayedHeight(1, peak: 100) == 0.1)
    #expect(Histogram.displayedHeight(100, peak: 100) == 1)
}

@Test func histogramHDRValuesAreDisplayBinnedNotSourceClipping() throws {
    let side = 160
    let space = try #require(CGColorSpace(name: CGColorSpace.extendedLinearSRGB))
    var floats = [Float](repeating: 1, count: side * side * 4)
    for y in 0..<side { for x in 0..<side {
        let value: Float = x < 40 ? 0 : x < 80 ? 0.01 : x < 120 ? 1 : 4
        let offset = (y * side + x) * 4
        floats[offset] = value; floats[offset + 1] = value; floats[offset + 2] = value
    } }
    let data = floats.withUnsafeBytes { Data($0) }
    let ci = CIImage(bitmapData: data, bytesPerRow: side * 16,
                     size: CGSize(width: side, height: side), format: .RGBAf, colorSpace: space)
    let context = CIContext(options: [.workingColorSpace: space])
    let source = try #require(context.createCGImage(ci, from: ci.extent, format: .RGBAf, colorSpace: space))
    let display = Histogram.compute(source)
    #expect(display.samples == side * side)
    #expect(display.red[0] > 0)
    #expect(display.red[255] >= side * 80)
    #expect(display.highlights >= side * 80)
    // Both linear 1 and linear 4 are indistinguishable in this SDR histogram.
    // The right-edge count is not an unrecoverable-sensor-clipping measurement.
}
