import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins

/// A bounded, one-time read of the input to the curve stage. Sampling a finger
/// position only reads this CPU buffer; it never starts a render.
struct CurveSamplingBuffer {
    let width: Int
    let height: Int
    private let pixels: [Float]
    private let tonalState: EditState

    static func prepare(original: CGImage, state: EditState) throws -> Self {
        var image = try OpticsRenderer.apply(CIImage(cgImage: original), settings: state.optics)
        if state.temperature != 0 || state.tint != 0 {
            let filter = CIFilter.temperatureAndTint()
            filter.inputImage = image
            filter.neutral = CIVector(x: 6500, y: 0)
            filter.targetNeutral = CIVector(x: 6500 + state.temperature * 35, y: state.tint * 0.6)
            guard let output = filter.outputImage else { throw PhotoError.renderFailed }
            image = output
        }
        if state.exposure != 0 {
            let filter = CIFilter.exposureAdjust()
            filter.inputImage = image
            filter.ev = Float(state.exposure)
            guard let output = filter.outputImage else { throw PhotoError.renderFailed }
            image = output
        }
        image = GeometryRenderer.apply(image, settings: state.geometry)
        let context = CIContext(options: [.cacheIntermediates: false])
        let maximum = 512
        let scale = min(1, Double(maximum) / max(image.extent.width, image.extent.height))
        let width = max(1, Int((image.extent.width * scale).rounded()))
        let height = max(1, Int((image.extent.height * scale).rounded()))
        let pixels = AutoAnalysisInput.pixels(image, context: context, maximum: maximum)
        var tonal = state
        tonal.curves = ToneCurves()
        return Self(width: width, height: height, pixels: pixels, tonalState: tonal)
    }

    func sample(at point: MaskPoint) -> CurveSample? {
        guard (0...1).contains(point.x), (0...1).contains(point.y) else { return nil }
        let column = min(width - 1, max(0, Int(point.x * Double(width))))
        let row = min(height - 1, max(0, Int((1 - point.y) * Double(height))))
        var total = SIMD3<Double>(repeating: 0)
        var count = 0.0
        for y in max(0, row - 1)...min(height - 1, row + 1) {
            for x in max(0, column - 1)...min(width - 1, column + 1) {
                let index = (y * width + x) * 4
                guard pixels[index + 3] > 0 else { continue }
                total += SIMD3(Double(pixels[index]), Double(pixels[index + 1]), Double(pixels[index + 2]))
                count += 1
            }
        }
        guard count > 0 else { return nil }
        let rgb = total / count
        let red = encode(rgb.x), green = encode(rgb.y), blue = encode(rgb.z)
        let luminance = red * 0.2126 + green * 0.7152 + blue * 0.0722
        let delta = TonalResponse.map(luminance, state: tonalState) - luminance
        let mapped = SIMD3(clamp(red + delta), clamp(green + delta), clamp(blue + delta))
        return CurveSample(red: mapped.x, green: mapped.y, blue: mapped.z, location: point)
    }

    private func clamp(_ value: Double) -> Double { min(1, max(0, value)) }
    private func encode(_ linear: Double) -> Double {
        let value = max(0, linear)
        return value <= 0.0031308 ? 12.92 * value : 1.055 * pow(value, 1 / 2.4) - 0.055
    }
}

struct CurveSample {
    let red: Double
    let green: Double
    let blue: Double
    let location: MaskPoint
    func value(for channel: CurveChannel) -> Double {
        switch channel {
        case .rgb: red * 0.2126 + green * 0.7152 + blue * 0.0722
        case .red: red
        case .green: green
        case .blue: blue
        }
    }
}
