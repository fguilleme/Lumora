import Testing
import CoreImage
import Foundation
@testable import LumoraCore

struct HighlightRecoveryTests {
    private let linear = CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!
    private func pixels(_ image: CIImage) -> [Float] {
        let context = CIContext(options: [.workingColorSpace: linear, .workingFormat: CIFormat.RGBAf])
        var values = [Float](repeating: 0, count: Int(image.extent.width*image.extent.height)*4)
        values.withUnsafeMutableBytes { context.render(image, toBitmap: $0.baseAddress!, rowBytes: Int(image.extent.width)*16,
            bounds: image.extent, format: .RGBAf, colorSpace: linear) }
        return values
    }
    private func image(_ values: [Float]) -> CIImage {
        CIImage(bitmapData: values.withUnsafeBytes { Data($0) }, bytesPerRow: values.count*4,
            size: CGSize(width: values.count/4, height: 1), format: .RGBAf, colorSpace: linear)
    }
    @Test func zeroBypassAndLowTones() throws {
        let input = image([0.05,0.1,0.2,1, 2,1,0.5,1])
        #expect(try HighlightRecoveryRenderer.recover(input, highlights: 0) === input)
        let actual = pixels(try HighlightRecoveryRenderer.recover(input, highlights: -70))
        for c in 0..<3 { #expect(abs(actual[c]-[Float(0.05),0.1,0.2][c]) < 0.00001) }
        var state = EditState(); state.depthLighting = DepthLightingSettings(enabled: true)
        var called = false
        _ = try DevelopmentRenderer.apply(input, state: state) { _ in called = true; return Data() }
        #expect(!called)
    }
    @Test func preservesColorRatiosAlphaAndHDRContinuity() throws {
        // Premultiplied HDR red/green/blue = 4/2/1 with alpha 0.5.
        let input = image([2,1,0.5,0.5, 0,0,0,0])
        let actual = pixels(try HighlightRecoveryRenderer.recover(input, highlights: -70))
        #expect(abs(actual[0]/actual[1]-2) < 0.0001)
        #expect(abs(actual[1]/actual[2]-2) < 0.0001)
        #expect(actual[3] == 0.5 && actual[7] == 0)
        #expect(actual.allSatisfy { $0.isFinite })
        let tiny = pixels(try HighlightRecoveryRenderer.recover(input, highlights: -0.001))
        #expect(abs(tiny[0]-2) < 0.001)
        let restored = pixels(try HighlightRecoveryRenderer.restoring(HighlightRecoveryRenderer.bounded(input), from: input))
        for (a,b) in zip(pixels(input),restored) { #expect(abs(a-b) < 0.00001) }
    }
    @Test func exposureAndNegativeHighlightsRetainUpperRamp() throws {
        var ramp = [Float]()
        for x in 0..<512 { let v = Float(x)/511; ramp += [v,v,v,1] }
        var state = EditState(); state.exposure = 1.64; state.highlights = -70
        state.shadows = 62; state.whites = -13; state.blacks = -50; state.contrast = 7
        let output = pixels(try DevelopmentRenderer.apply(image(ramp), state: state, cube: RenderEngine.makeCube))
        let differences = (350..<511).map { output[($0+1)*4]-output[$0*4] }
        print("Recovery ramp differences min=\(differences.min()!), max=\(differences.max()!), first=\(output[350*4]), last=\(output[511*4])")
        // GPU color-space conversion can quantize adjacent float samples. Check
        // ordering with tolerance and distinguish samples separated by four steps.
        for x in 350..<511 { #expect(output[(x+1)*4] >= output[x*4]-0.00005) }
        for x in stride(from: 350, to: 507, by: 4) { #expect(output[(x+4)*4] > output[x*4]+0.0001) }
        #expect(output.allSatisfy { $0.isFinite })
        #expect(output[511*4] < 1)
    }
    @Test func colorLUTDoesNotClipHDRAndExposureOnlyRemainsExact() throws {
        let input = image([0.3,0.2,0.1,1, 1,0.7,0.4,1])
        var exposure = EditState(); exposure.exposure = 2
        let only = pixels(try DevelopmentRenderer.apply(input, state: exposure, cube: RenderEngine.makeCube))
        let before = pixels(input)
        for i in [0,1,2,4,5,6] { #expect(abs(only[i]-before[i]*4) < 0.0001) }
        var graded = exposure; graded.saturation = -5
        let actual = pixels(try DevelopmentRenderer.apply(input, state: graded, cube: RenderEngine.makeCube))
        #expect(actual[4] > 1 && actual[4] > actual[0])
        #expect(actual.allSatisfy { $0.isFinite })
    }
}
