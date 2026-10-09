import Testing
import Foundation
import CoreGraphics
import CoreImage
@testable import LumoraCore

private func similarityFixture() throws -> CGImage {
    var rgba = [UInt8](repeating: 0, count: 100 * 60 * 4)
    for y in 0..<60 {
        for x in 0..<100 {
            let i = (y * 100 + x) * 4
            let red = y < 25 && (x < 25 || x > 75)
            rgba[i] = red ? 255 : 0
            rgba[i + 2] = red ? 0 : 255
            rgba[i + 3] = 255
        }
    }
    let provider = try #require(CGDataProvider(data: Data(rgba) as CFData))
    return try #require(CGImage(width: 100, height: 60, bitsPerComponent: 8, bitsPerPixel: 32,
        bytesPerRow: 400, space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
        provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent))
}

private func sampledSimilarity() throws -> SimilarityMask {
    var sampled = try SimilarityMaskEngine.sample(MaskPoint(x: 0.1, y: 0.1),
        image: similarityFixture(), mask: SimilarityMask())
    sampled.influence = RadialGradientMask(center: MaskPoint(x: 0.5, y: 0.5), radiusX: 1, radiusY: 1, feather: 1)
    return sampled
}

private func renderedSimilarity(_ shape: SimilarityMask) throws -> MaskBitmapSource {
    let context = CIContext(options: [.useSoftwareRenderer: true])
    let extent = CGRect(x: 0, y: 0, width: 100, height: 60)
    let rendered = try SimilarityMaskEngine.image(shape, extent: extent)
    let image = try #require(context.createCGImage(rendered, from: extent))
    return try #require(MaskBitmapSource(image: image, maximumDimension: 100))
}

@Test func similaritySamplingPersistenceAndOrientation() throws {
    let sampled = try sampledSimilarity()
    #expect(sampled.red > 0.99 && sampled.blue < 0.01)
    let connected = try renderedSimilarity(sampled)
    #expect(connected.rgb(x: 10, y: 10).red > 0.99)
    #expect(connected.rgb(x: 90, y: 10).red < 0.01)
    #expect(connected.rgb(x: 10, y: 50).red < 0.01)
    var decoded = try JSONDecoder().decode(SimilarityMask.self, from: JSONEncoder().encode(sampled))
    #expect(decoded == sampled)
    decoded.fieldID = UUID() // force PNG decoding, rather than the sampling cache
    decoded.connected = false
    let all = try renderedSimilarity(decoded)
    #expect(all.rgb(x: 10, y: 10).red > 0.99)
    #expect(all.rgb(x: 90, y: 10).red > 0.99)
    #expect(all.rgb(x: 10, y: 50).red < 0.01)
    decoded.influence.center = MaskPoint(x: 0.8, y: 0.3)
    #expect(decoded.reference == sampled.reference)
    #expect(decoded.distancePNG == sampled.distancePNG)
}

@Test func similaritySubtractionUsesSameMatteAndHistoryRestoresField() throws {
    let sampled = try sampledSimilarity()
    let full = RadialGradientMask(center: MaskPoint(x: 0.5, y: 0.5), radiusX: 1, radiusY: 1, feather: 1)
    let layer = LocalMask(name: "Color", components: [MaskComponent(shape: .radial(full)),
        MaskComponent(operation: .subtract, shape: .similarity(sampled))])
    let extent = CGRect(x: 0, y: 0, width: 100, height: 60)
    let context = CIContext(options: [.useSoftwareRenderer: true])
    let image = try #require(context.createCGImage(MaskRenderer.makeMask(layer, extent: extent), from: extent))
    let pixels = try #require(MaskBitmapSource(image: image, maximumDimension: 100))
    #expect(pixels.rgb(x: 10, y: 10).red < 0.01)
    #expect(pixels.rgb(x: 50, y: 40).red > 0.99)
    var state = EditState(); state.masks = [layer]
    var history = HistoryManager(); history.begin("Tolerance", state: state)
    var changed = sampled; changed.tolerance = 90
    state.masks[0].components[1].shape = .similarity(changed)
    history.commit(state)
    let undone = history.undo()
    let restored = try #require(undone)
    #expect(restored.masks[0].components[1].shape == .similarity(sampled))
    #expect(try JSONDecoder().decode(EditState.self, from: JSONEncoder().encode(restored)) == restored)
}
