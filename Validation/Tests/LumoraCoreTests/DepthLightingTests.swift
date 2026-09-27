import Testing
import Foundation
import CoreImage
import Metal
@testable import LumoraCore

@Test func depthLightingMigrationAndHistory() throws {
    let original = try JSONDecoder().decode(EditState.self, from: Data("{}".utf8))
    #expect(original.depthLighting == nil)
    #expect(!DepthLightingSettings().enabled)
    var changed = original
    changed.depthLighting = DepthLightingSettings(enabled: true, intensity: 82, targetX: 0.3, targetY: 0.7)
    #expect(try JSONDecoder().decode(EditState.self, from: JSONEncoder().encode(changed)) == changed)
    var history = HistoryManager()
    history.begin("Lighting", state: original); history.commit(changed)
    #expect(history.undo() == original)
    #expect(history.redo() == changed)
    let sanitized = DepthLightingSettings(intensity: .nan, distance: 0, warmth: 200, lightX: .infinity).validated
    #expect(sanitized.intensity == 65 && sanitized.distance == 15 && sanitized.warmth == 100 && sanitized.lightX == 0.25)
}

private func lightingPixels(_ image: CIImage) -> [Float] {
    let space = CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!
    let context = CIContext(options: [.workingColorSpace: space, .workingFormat: CIFormat.RGBAf])
    var pixels = [Float](repeating: 0, count: Int(image.extent.width*image.extent.height)*4)
    pixels.withUnsafeMutableBytes {
        context.render(image, toBitmap: $0.baseAddress!, rowBytes: Int(image.extent.width)*16,
                       bounds: image.extent, format: .RGBAf, colorSpace: space)
    }
    return pixels
}

@Test func depthLightingBypassHeadroomAndDistantBackground() throws {
    let rect = CGRect(x: 0, y: 0, width: 64, height: 96)
    let source = CIImage(color: CIColor(red: 0.25, green: 0.18, blue: 0.12)).cropped(to: rect)
    // CI y increases upwards: distant sky in upper half, subject below.
    let sky = CIImage(color: CIColor(red: 0, green: 0, blue: 0)).cropped(to: rect)
    let depth = CIImage(color: CIColor(red: 1, green: 1, blue: 1))
        .cropped(to: CGRect(x: 0, y: 0, width: 64, height: 48)).composited(over: sky)
    let baseline = lightingPixels(source)
    for settings in [DepthLightingSettings(), DepthLightingSettings(enabled: true, intensity: 0)] {
        let result = try DepthLightingRenderer.apply(source, depth: depth, low: 0, high: 1, settings: settings)
        #expect(result === source)
    }
    let settings = DepthLightingSettings(enabled: true, intensity: 100, lightX: 0.5, lightY: 0.75, targetX: 0.5, targetY: 0.75)
    let output = lightingPixels(try DepthLightingRenderer.apply(source, depth: depth, low: 0, high: 1, settings: settings))
    #expect(output.allSatisfy { $0.isFinite })
    #expect(output.max()! <= 1)
    // Row order is immaterial: count exact unchanged and illuminated pixels.
    let unchanged = stride(from: 0, to: output.count, by: 4).filter { abs(output[$0]-baseline[$0]) < 0.00001 }.count
    let brightened = stride(from: 0, to: output.count, by: 4).filter { output[$0] > baseline[$0]+0.01 }.count
    #expect(unchanged >= 64*40)
    #expect(brightened > 500)
    for i in stride(from: 3, to: output.count, by: 4) { #expect(output[i] == baseline[i]) }
    let hdr = CIImage(color: CIColor(red: 2, green: 1.3, blue: 0.6)).cropped(to: rect)
    let originalHDR = lightingPixels(hdr)
    let outputHDR = lightingPixels(try DepthLightingRenderer.apply(hdr, depth: depth, low: 0, high: 1, settings: settings))
    #expect(zip(originalHDR, outputHDR).allSatisfy { abs($0-$1) < 0.00001 })
}

@Test func depthLightingResolutionAndOriginConsistency() throws {
    let source = CIImage(color: CIColor(red: 0.2, green: 0.2, blue: 0.2))
    let depth = CIImage(color: CIColor(red: 0.8, green: 0.8, blue: 0.8)).cropped(to: CGRect(x: 0, y: 0, width: 64, height: 96))
    let settings = DepthLightingSettings(enabled: true)
    let small = try DepthLightingRenderer.apply(source.cropped(to: depth.extent), depth: depth, low: 0, high: 1, settings: settings)
    let largeRect = CGRect(x: 24, y: 32, width: 256, height: 384)
    let large = try DepthLightingRenderer.apply(source.cropped(to: largeRect), depth: depth, low: 0, high: 1, settings: settings)
        .transformed(by: CGAffineTransform(translationX: -24, y: -32))
        .transformed(by: CGAffineTransform(scaleX: 0.25, y: 0.25))
    let a = lightingPixels(small), b = lightingPixels(large)
    #expect(zip(a,b).map { abs($0-$1) }.max()! < 0.002)
}

@Test func depthLightingMatchesMetalPrototypeAt960() throws {
    let device = try #require(MTLCreateSystemDefaultDevice())
    let queue = try #require(device.makeCommandQueue())
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let shader = try String(contentsOf: root.appendingPathComponent("DepthLighting/Sources/Lighting.metal"), encoding: .utf8)
    let library = try device.makeLibrary(source: shader, options: nil)
    let function = try #require(library.makeFunction(name: "relight"))
    let pipeline = try device.makeComputePipelineState(function: function)
    let space = CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!
    let context = CIContext(mtlDevice: device, options: [.workingColorSpace: space, .workingFormat: CIFormat.RGBAf])
    let w = 640, h = 960
    let rect = CGRect(x: 0, y: 0, width: w, height: h)
    let source = CIImage(color: CIColor(red: 0.24, green: 0.18, blue: 0.12)).cropped(to: rect)
    var raw = [Float](repeating: 1, count: 64*96*4)
    for y in 0..<96 { for x in 0..<64 {
        let value: Float = y < 24 ? 0 : 0.55 + Float(x)/200 + Float(y)/800
        for c in 0..<3 { raw[(y*64+x)*4+c] = value }
    } }
    let rawImage = CIImage(bitmapData: raw.withUnsafeBytes { Data($0) }, bytesPerRow: 64*16,
        size: CGSize(width: 64, height: 96), format: .RGBAf, colorSpace: nil)
    let depth = rawImage.clampedToExtent().applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 2]).cropped(to: rawImage.extent)
    func texture() throws -> MTLTexture {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba32Float, width: w, height: h, mipmapped: false)
        descriptor.storageMode = .shared; descriptor.usage = [.shaderRead, .shaderWrite]
        return try #require(device.makeTexture(descriptor: descriptor))
    }
    func flipped(_ image: CIImage) -> CIImage {
        image.transformed(by: CGAffineTransform(scaleX: 1, y: -1)).transformed(by: CGAffineTransform(translationX: 0, y: CGFloat(h)))
    }
    let sourceTexture = try texture(), depthTexture = try texture(), outputTexture = try texture(), actualTexture = try texture()
    let command = try #require(queue.makeCommandBuffer())
    context.render(flipped(source), to: sourceTexture, commandBuffer: command, bounds: rect, colorSpace: space)
    context.render(flipped(depth.transformed(by: CGAffineTransform(scaleX: 10, y: 10))), to: depthTexture, commandBuffer: command, bounds: rect, colorSpace: space)
    let settings = DepthLightingSettings(enabled: true, lightX: 0.4, lightY: 0.4, targetX: 0.5, targetY: 0.6)
    var params = [SIMD4<Float>(0.4,0.4,0.65,0.55), SIMD4<Float>(0,0.8,0,0.48), SIMD4<Float>(0,1,0.5,0.6)]
    let encoder = try #require(command.makeComputeCommandEncoder())
    encoder.setComputePipelineState(pipeline)
    encoder.setTexture(sourceTexture, index: 0); encoder.setTexture(depthTexture, index: 1); encoder.setTexture(outputTexture, index: 2)
    params.withUnsafeMutableBytes { encoder.setBytes($0.baseAddress!, length: $0.count, index: 0) }
    encoder.dispatchThreads(MTLSize(width: w, height: h, depth: 1), threadsPerThreadgroup: MTLSize(width: 16, height: 16, depth: 1))
    encoder.endEncoding()
    let actual = try DepthLightingRenderer.apply(source, depth: depth, low: 0, high: 1, settings: settings)
    context.render(flipped(actual), to: actualTexture, commandBuffer: command, bounds: rect, colorSpace: space)
    command.commit(); command.waitUntilCompleted()
    #expect(command.error == nil)
    func values(_ texture: MTLTexture) -> [Float] {
        var values = [Float](repeating: 0, count: w*h*4)
        values.withUnsafeMutableBytes { texture.getBytes($0.baseAddress!, bytesPerRow: w*16, from: MTLRegionMake2D(0, 0, w, h), mipmapLevel: 0) }
        return values
    }
    let expected = values(outputTexture), observed = values(actualTexture)
    let differences = zip(expected, observed).map { abs($0-$1) }
    let mean = differences.reduce(0,+)/Float(differences.count), peak = differences.max()!
    print("Depth lighting prototype comparison: mean=\(mean), peak=\(peak)")
    #expect(mean < 0.001)
    #expect(peak < 0.01)
}
