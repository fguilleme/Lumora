import Foundation
import CoreImage
import CoreImage.CIFilterBuiltins

struct SharpeningSettings: Codable, Sendable, Equatable {
    var amount = 0.0
    var radius = 1.0
    var detail = 25.0
    var masking = 0.0
    private enum CodingKeys: String, CodingKey { case amount, radius, detail, masking }
    init() {}
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        amount = try values.decodeIfPresent(Double.self, forKey: .amount) ?? 0
        radius = try values.decodeIfPresent(Double.self, forKey: .radius) ?? 1
        detail = try values.decodeIfPresent(Double.self, forKey: .detail) ?? 25
        masking = try values.decodeIfPresent(Double.self, forKey: .masking) ?? 0
    }
}

struct NoiseReductionSettings: Codable, Sendable, Equatable {
    var luminance = 0.0
    var detail = 50.0
    var contrast = 0.0
    private enum CodingKeys: String, CodingKey { case luminance, detail, contrast }
    init() {}
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        luminance = try values.decodeIfPresent(Double.self, forKey: .luminance) ?? 0
        detail = try values.decodeIfPresent(Double.self, forKey: .detail) ?? 50
        contrast = try values.decodeIfPresent(Double.self, forKey: .contrast) ?? 0
    }
}

struct ColorNoiseReductionSettings: Codable, Sendable, Equatable {
    var color = 0.0
    var detail = 50.0
    var smoothness = 50.0
    private enum CodingKeys: String, CodingKey { case color, detail, smoothness }
    init() {}
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        color = try values.decodeIfPresent(Double.self, forKey: .color) ?? 0
        detail = try values.decodeIfPresent(Double.self, forKey: .detail) ?? 50
        smoothness = try values.decodeIfPresent(Double.self, forKey: .smoothness) ?? 50
    }
}

struct DetailSettings: Codable, Sendable, Equatable {
    var sharpening = SharpeningSettings()
    var noiseReduction = NoiseReductionSettings()
    var colorNoiseReduction = ColorNoiseReductionSettings()
    private enum CodingKeys: String, CodingKey { case sharpening, noiseReduction, colorNoiseReduction }
    init() {}
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        sharpening = try values.decodeIfPresent(SharpeningSettings.self, forKey: .sharpening) ?? SharpeningSettings()
        noiseReduction = try values.decodeIfPresent(NoiseReductionSettings.self, forKey: .noiseReduction) ?? NoiseReductionSettings()
        colorNoiseReduction = try values.decodeIfPresent(ColorNoiseReductionSettings.self, forKey: .colorNoiseReduction) ?? ColorNoiseReductionSettings()
        self = validated
    }
    var isIdentity: Bool {
        sharpening.amount == 0 && noiseReduction.luminance == 0 && colorNoiseReduction.color == 0
    }
    var validated: Self {
        var value = self
        for adjustment in DetailAdjustment.allCases { value[adjustment] = self[adjustment] }
        return value
    }
    subscript(_ adjustment: DetailAdjustment) -> Double {
        get { self[keyPath: adjustment.keyPath] }
        set {
            self[keyPath: adjustment.keyPath] = newValue.isFinite
                ? min(adjustment.range.upperBound, max(adjustment.range.lowerBound, newValue))
                : adjustment.defaultValue
        }
    }
}

enum DetailAdjustment: String, CaseIterable, Sendable, Identifiable {
    case sharpeningAmount, sharpeningRadius, sharpeningDetail, sharpeningMasking
    case luminanceNoise, luminanceDetail, luminanceContrast
    case colorNoise, colorDetail, colorSmoothness
    var id: String { rawValue }
    var title: String {
        switch self {
        case .sharpeningAmount: "Gain"
        case .sharpeningRadius: "Rayon"
        case .sharpeningDetail: "Détail"
        case .sharpeningMasking: "Masquage"
        case .luminanceNoise: "Luminance"
        case .luminanceDetail: "Détail"
        case .luminanceContrast: "Contraste"
        case .colorNoise: "Couleur"
        case .colorDetail: "Détail"
        case .colorSmoothness: "Lissage"
        }
    }
    var range: ClosedRange<Double> {
        switch self {
        case .sharpeningAmount: 0...150
        case .sharpeningRadius: 0.5...3
        default: 0...100
        }
    }
    var step: Double { self == .sharpeningRadius ? 0.1 : 1 }
    var precision: Int { self == .sharpeningRadius ? 1 : 0 }
    var defaultValue: Double {
        switch self {
        case .sharpeningRadius: 1
        case .sharpeningDetail: 25
        case .luminanceDetail, .colorDetail, .colorSmoothness: 50
        default: 0
        }
    }
    var group: Int {
        switch self {
        case .sharpeningAmount, .sharpeningRadius, .sharpeningDetail, .sharpeningMasking: 0
        case .luminanceNoise, .luminanceDetail, .luminanceContrast: 1
        default: 2
        }
    }
    var keyPath: WritableKeyPath<DetailSettings, Double> {
        switch self {
        case .sharpeningAmount: \.sharpening.amount
        case .sharpeningRadius: \.sharpening.radius
        case .sharpeningDetail: \.sharpening.detail
        case .sharpeningMasking: \.sharpening.masking
        case .luminanceNoise: \.noiseReduction.luminance
        case .luminanceDetail: \.noiseReduction.detail
        case .luminanceContrast: \.noiseReduction.contrast
        case .colorNoise: \.colorNoiseReduction.color
        case .colorDetail: \.colorNoiseReduction.detail
        case .colorSmoothness: \.colorNoiseReduction.smoothness
        }
    }
    static let groups: [(String, [Self])] = [
        ("Netteté", allCases.filter { $0.group == 0 }),
        ("Réduction du bruit", allCases.filter { $0.group == 1 }),
        ("Bruit coloré", allCases.filter { $0.group == 2 })
    ]
}

enum DetailRenderer {
    static func apply(_ input: CIImage, settings: DetailSettings) throws -> CIImage {
        let settings = settings.validated
        guard !settings.isIdentity else { return input }
        let extent = input.extent
        var image = input

        if settings.colorNoiseReduction.color > 0 {
            image = try reduceColorNoise(image, settings: settings.colorNoiseReduction, extent: extent)
        }
        if settings.noiseReduction.luminance > 0 {
            let values = settings.noiseReduction
            let filter = CIFilter.noiseReduction()
            filter.inputImage = image
            filter.noiseLevel = Float(0.005 + values.luminance / 100 * 0.075)
            filter.sharpness = Float(values.detail / 100 * 0.45)
            guard let reduced = filter.outputImage else { throw PhotoError.renderFailed }
            image = reduced.cropped(to: extent)
            if values.contrast > 0 {
                let contrast = CIFilter.unsharpMask()
                contrast.inputImage = image
                contrast.radius = 2
                contrast.intensity = Float(values.contrast / 100 * 0.45)
                guard let output = contrast.outputImage else { throw PhotoError.renderFailed }
                image = output.cropped(to: extent)
            }
        }
        if settings.sharpening.amount > 0 {
            image = try sharpen(image, settings: settings.sharpening, extent: extent)
        }
        return image
    }

    private static func sharpen(_ input: CIImage, settings: SharpeningSettings, extent: CGRect) throws -> CIImage {
        let base = CIFilter.sharpenLuminance()
        base.inputImage = input
        base.radius = Float(settings.radius)
        base.sharpness = Float(settings.amount / 100 * 0.8)
        guard var sharpened = base.outputImage?.cropped(to: extent) else { throw PhotoError.renderFailed }
        if settings.detail > 0 {
            let fine = CIFilter.sharpenLuminance()
            fine.inputImage = sharpened
            fine.radius = Float(max(0.5, settings.radius * 0.45))
            fine.sharpness = Float(settings.amount / 100 * settings.detail / 100 * 0.45)
            guard let output = fine.outputImage else { throw PhotoError.renderFailed }
            sharpened = output.cropped(to: extent)
        }
        guard settings.masking > 0 else { return sharpened }
        let edges = CIFilter.edges()
        edges.inputImage = input
        edges.intensity = Float(1 + settings.detail / 100 * 2)
        guard let edgeImage = edges.outputImage?.cropped(to: extent) else { throw PhotoError.renderFailed }
        let threshold = CIFilter.colorControls()
        threshold.inputImage = edgeImage
        threshold.saturation = 0
        threshold.contrast = Float(1 + settings.masking / 100 * 5)
        threshold.brightness = Float(-settings.masking / 100 * 0.45)
        guard let mask = threshold.outputImage else { throw PhotoError.renderFailed }
        let blend = CIFilter.blendWithMask()
        blend.inputImage = sharpened
        blend.backgroundImage = input
        blend.maskImage = mask
        guard let output = blend.outputImage else { throw PhotoError.renderFailed }
        return output.cropped(to: extent)
    }

    private static func reduceColorNoise(_ input: CIImage, settings: ColorNoiseReductionSettings,
                                         extent: CGRect) throws -> CIImage {
        let blur = CIFilter.gaussianBlur()
        blur.inputImage = input.clampedToExtent()
        blur.radius = Float(0.6 + settings.smoothness / 100 * 3.4)
        guard let blurred = blur.outputImage?.cropped(to: extent) else { throw PhotoError.renderFailed }

        let luma = CIFilter.colorMatrix()
        luma.inputImage = input
        let y = CIVector(x: 0.2126, y: 0.7152, z: 0.0722, w: 0)
        luma.rVector = y; luma.gVector = y; luma.bVector = y
        luma.aVector = CIVector(x: 0, y: 0, z: 0, w: 1)

        let chroma = CIFilter.colorMatrix()
        chroma.inputImage = blurred
        chroma.rVector = CIVector(x: 0.7874, y: -0.7152, z: -0.0722, w: 0)
        chroma.gVector = CIVector(x: -0.2126, y: 0.2848, z: -0.0722, w: 0)
        chroma.bVector = CIVector(x: -0.2126, y: -0.7152, z: 0.9278, w: 0)
        chroma.aVector = CIVector(x: 0, y: 0, z: 0, w: 0)
        guard let lumaImage = luma.outputImage, let chromaImage = chroma.outputImage else { throw PhotoError.renderFailed }

        let addition = CIFilter.additionCompositing()
        addition.inputImage = chromaImage
        addition.backgroundImage = lumaImage
        guard let reconstructed = addition.outputImage?.cropped(to: extent) else { throw PhotoError.renderFailed }
        let blend = CIFilter.dissolveTransition()
        blend.inputImage = input
        blend.targetImage = reconstructed
        blend.time = Float(settings.color / 100 * (1 - settings.detail / 100 * 0.75))
        guard let output = blend.outputImage else { throw PhotoError.renderFailed }
        return output.cropped(to: extent)
    }
}
