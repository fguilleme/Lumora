import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import LumoraCore

@Test func developedPNGIsNotReportedAsRAW() throws {
    let url = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".png")
    defer { try? FileManager.default.removeItem(at: url) }
    let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
    let context = try #require(CGContext(data: nil, width: 2, height: 3, bitsPerComponent: 8,
                                        bytesPerRow: 8, space: space,
                                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    let image = try #require(context.makeImage())
    let destination = try #require(CGImageDestinationCreateWithURL(
        url as CFURL, UTType.png.identifier as CFString, 1, nil))
    CGImageDestinationAddImage(destination, image, nil)
    #expect(CGImageDestinationFinalize(destination))

    #expect(!RAWDecoder.recognizes(url))
    #expect(RAWDecoder.filter(url) == nil)
}

@Test func canonDNGIsRecognizedAsRAWWhenFixtureIsAvailable() {
    let url = URL(fileURLWithPath: "/Volumes/XTRA/Downloads/a0014-WP_CRW_6320.dng")
    guard FileManager.default.fileExists(atPath: url.path) else { return }
    #expect(RAWDecoder.recognizes(url))
    #expect(RAWDecoder.filter(url) != nil)
}
