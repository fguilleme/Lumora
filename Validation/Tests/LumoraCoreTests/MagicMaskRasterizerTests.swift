import Testing
@testable import LumoraCore

@Test func magicMaskInterpolatesContourBeforeThresholding() throws {
    let size = 16
    let logits = (0..<(size * size)).map { index in
        Float(index % size) + Float(index / size) * 0.37 - 8.23
    }
    let output = try #require(MagicMaskRasterizer.coverage(
        logits: logits, width: size, height: size,
        contentWidth: 16, contentHeight: 16, outputWidth: 128, outputHeight: 128))
    // A diagonal with a fractional offset must follow the signed score's zero
    // crossing, rather than the contour of a thresholded 16-pixel bitmap.
    for y in 8..<120 {
        for x in 8..<120 {
            let score = (Float(x) + 0.5) / 8 - 0.5
                + ((Float(y) + 0.5) / 8 - 0.5) * 0.37 - 8.23
            let value = output[y * 128 + x]
            if score < -0.1 { #expect(value == 0) }
            if score > 0.1 { #expect(value == 255) }
        }
    }
    #expect(output.contains { $0 > 0 && $0 < 255 })
    let higherConfidence = try #require(MagicMaskRasterizer.coverage(
        logits: logits.map { $0 * 20 }, width: size, height: size,
        contentWidth: 16, contentHeight: 16, outputWidth: 128, outputHeight: 128))
    #expect(zip(output, higherConfidence).allSatisfy { abs(Int($0) - Int($1)) <= 1 })
}

@Test func magicMaskPreservesOrientationAndCropsPadding() throws {
    let output = try #require(MagicMaskRasterizer.coverage(
        logits: [4, -3, -100, -100], width: 2, height: 2,
        contentWidth: 2, contentHeight: 1, outputWidth: 8, outputHeight: 4))
    // Top-left is selected. The padded bottom row must not flip the matte or
    // replace the top edge, and the score transition remains anti-aliased.
    #expect(output[0] == 255)
    #expect(output[7] == 0)
    #expect(output[4] > 0 && output[4] < 255)
}

@Test func magicMaskPreservesFlatRegionsAndRejectsInvalidScores() throws {
    for score: Float in [-4, 4] {
        let output = try #require(MagicMaskRasterizer.coverage(
            logits: [score, score, score, score], width: 2, height: 2,
            contentWidth: 2, contentHeight: 2, outputWidth: 20, outputHeight: 12))
        #expect(output.allSatisfy { $0 == (score > 0 ? 255 : 0) })
    }
    #expect(MagicMaskRasterizer.coverage(
        logits: [.nan], width: 1, height: 1, contentWidth: 1, contentHeight: 1,
        outputWidth: 10, outputHeight: 10) == nil)
}
