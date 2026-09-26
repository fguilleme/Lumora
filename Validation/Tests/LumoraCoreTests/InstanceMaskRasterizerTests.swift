import CoreGraphics
import CoreVideo
import Testing
@testable import LumoraCore

@Test func instanceMaskRasterizerPreservesGeometryAndSoftValues() throws {
    var created: CVPixelBuffer?
    #expect(CVPixelBufferCreate(kCFAllocatorDefault, 2, 2,
                                kCVPixelFormatType_OneComponent32Float,
                                nil, &created) == kCVReturnSuccess)
    let buffer = try #require(created)
    #expect(CVPixelBufferLockBaseAddress(buffer, []) == kCVReturnSuccess)
    let base = try #require(CVPixelBufferGetBaseAddress(buffer))
    let stride = CVPixelBufferGetBytesPerRow(buffer)
    // A top-left subject with a feathered bottom-right edge. The source is
    // intentionally non-symmetric so a flipped or transposed mask is visible.
    base.storeBytes(of: Float(1), toByteOffset: 0, as: Float.self)
    base.storeBytes(of: Float(0), toByteOffset: 4, as: Float.self)
    base.storeBytes(of: Float(0), toByteOffset: stride, as: Float.self)
    base.storeBytes(of: Float(0.5), toByteOffset: stride + 4, as: Float.self)
    CVPixelBufferUnlockBaseAddress(buffer, [])

    let image = try InstanceMaskRasterizer.scaledImage(from: buffer, width: 4, height: 4)
    #expect(image.width == 4 && image.height == 4)
    let bytes = try #require(image.dataProvider?.data as Data?)
    #expect(bytes.count >= image.bytesPerRow * image.height)
    #expect(bytes[0] > 200)
    #expect(bytes[3] < 80)
    #expect(bytes[3 * image.bytesPerRow] < 80)
    #expect((80...180).contains(bytes[3 * image.bytesPerRow + 3]))
}

@Test func instanceMaskRasterizerRejectsInvalidDimensions() throws {
    var created: CVPixelBuffer?
    #expect(CVPixelBufferCreate(kCFAllocatorDefault, 2, 2,
                                kCVPixelFormatType_OneComponent8,
                                nil, &created) == kCVReturnSuccess)
    let buffer = try #require(created)
    #expect(throws: InstanceMaskRasterizer.Failure.self) {
        try InstanceMaskRasterizer.scaledImage(from: buffer, width: 0, height: 4)
    }
    #expect(throws: InstanceMaskRasterizer.Failure.self) {
        try InstanceMaskRasterizer.scaledImage(from: buffer, width: 4, height: 4097)
    }
}
