import Testing
@testable import LumoraCore

private func coverage(_ field: [UInt8], connected: Bool = true, radiusX: Double = 1,
                      radiusY: Double = 1, tolerance: Double = 10, feather: Double = 0) throws -> [UInt8] {
    try #require(SimilarityMaskRasterizer.coverage(distances: field, width: 7, height: 5,
        seedX: 1, seedY: 2, centerX: 0.5, centerY: 0.5, radiusX: radiusX, radiusY: radiusY,
        tolerance: tolerance, feather: feather, connected: connected))
}

@Test func similarityConnectedRegionRejectsSeparateIslands() throws {
    var field = [UInt8](repeating: 0, count: 35)
    for y in 0..<5 { field[y * 7 + 3] = 255 }
    let connected = try coverage(field)
    let all = try coverage(field, connected: false)
    #expect(connected[2 * 7 + 1] == 255)
    #expect(connected[2 * 7 + 5] == 0)
    #expect(all[2 * 7 + 5] == 255)
    #expect(all[2 * 7 + 3] == 0)
}

@Test func similarityCannotPropagateOutsideInfluenceArea() throws {
    var field = [UInt8](repeating: 0, count: 35)
    for y in 1..<4 { field[y * 7 + 3] = 255 }
    // The only path around the barrier is above/below the ellipse.
    let clipped = try coverage(field, radiusY: 0.3)
    #expect(clipped[2 * 7 + 1] == 255)
    #expect(clipped[2 * 7 + 5] == 0)
    #expect(clipped[1] == 0)
    #expect(try coverage(field)[2 * 7 + 5] == 255)
}

@Test func similarityToleranceAndFeatherRemainIndependent() throws {
    var field = [UInt8](repeating: 0, count: 35)
    field[2 * 7 + 2] = 50
    #expect(try coverage(field, connected: false)[2 * 7 + 2] == 0)
    #expect(try coverage(field, connected: false, tolerance: 50)[2 * 7 + 2] == 255)
    let soft = try coverage(field, connected: false, feather: 100)
    #expect(soft[0] > 0 && soft[0] < 255)
    #expect(soft[2 * 7 + 2] == 0)
}

@Test func similaritySeedOutsideEllipseAndDiagonalGapDoNotLeak() throws {
    #expect(try coverage([UInt8](repeating: 0, count: 35), radiusX: 0.1).allSatisfy { $0 == 0 })
    var field = [UInt8](repeating: 255, count: 35)
    field[2 * 7 + 1] = 0; field[3 * 7 + 2] = 0
    #expect(try coverage(field)[3 * 7 + 2] == 0)
}

@Test func similarityPerceptualColorsAndInvalidInput() {
    let white = SimilarityMaskRasterizer.lab(red: 1, green: 1, blue: 1)
    let black = SimilarityMaskRasterizer.lab(red: 0, green: 0, blue: 0)
    #expect(abs(white.x - 100) < 0.01 && abs(white.y) < 0.01 && abs(white.z) < 0.01)
    #expect(abs(black.x) < 0.01)
    #expect(SimilarityMaskRasterizer.coverage(distances: [], width: 7, height: 5,
        seedX: 1, seedY: 2, centerX: 0.5, centerY: 0.5, radiusX: 1, radiusY: 1,
        tolerance: .nan, feather: 0, connected: true) == nil)
}
