import Foundation
import CoreImage
import CoreImage.CIFilterBuiltins

struct EffectsSettings: Codable, Sendable, Equatable {
    var texture = 0.0
    var clarity = 0.0
    var dehaze = 0.0
    var vignette = 0.0
    var grain = 0.0

    var validated: Self {
        var value = self
        for adjustment in EffectAdjustment.allCases { value[adjustment] = self[adjustment] }
        return value
    }
    var isIdentity: Bool { self == EffectsSettings() }
    subscript(_ adjustment: EffectAdjustment) -> Double {
        get { self[keyPath: adjustment.keyPath] }
        set {
            self[keyPath: adjustment.keyPath] = newValue.isFinite
                ? min(adjustment.range.upperBound, max(adjustment.range.lowerBound, newValue)) : 0
        }
    }
}

enum EffectAdjustment: String, CaseIterable, Sendable, Identifiable {
    case texture, clarity, dehaze, vignette, grain
    var id: String { rawValue }
    var title: String {
        switch self {
        case .texture: "Texture"
        case .clarity: "Clarity"
        case .dehaze: "Dehaze"
        case .vignette: "Vignette"
        case .grain: "Grain"
        }
    }
    var range: ClosedRange<Double> { self == .grain ? 0...100 : -100...100 }
    var keyPath: WritableKeyPath<EffectsSettings, Double> {
        switch self {
        case .texture: \.texture
        case .clarity: \.clarity
        case .dehaze: \.dehaze
        case .vignette: \.vignette
        case .grain: \.grain
        }
    }
}

/// Spatial effects applied after color grading. Every filter keeps the input extent.
enum EffectsRenderer {
    static func apply(_ input: CIImage, settings: EffectsSettings) throws -> CIImage {
        let detailed = try applyBeforeDetail(input, settings: settings)
        return try applyFinishing(detailed, settings: settings)
    }

    static func applyBeforeDetail(_ input: CIImage, settings: EffectsSettings) throws -> CIImage {
        let settings = settings.validated
        guard settings.texture != 0 || settings.clarity != 0 || settings.dehaze != 0 else { return input }
        let extent = input.extent
        var image = input

        // Texture works on fine detail; clarity uses a much wider local mean.
        if settings.texture > 0 {
            let filter = CIFilter.unsharpMask()
            filter.inputImage = image
            filter.radius = 1.25
            filter.intensity = Float(settings.texture / 100 * 1.4)
            guard let output = filter.outputImage else { throw PhotoError.renderFailed }
            image = output.cropped(to: extent)
        } else if settings.texture < 0 {
            image = try softened(image, radius: 1.25, amount: -settings.texture / 100 * 0.8, extent: extent)
        }

        if settings.clarity > 0 {
            let radius = min(28, max(7, max(extent.width, extent.height) * 0.012))
            image = try sharpened(image, radius: radius, intensity: settings.clarity / 100 * 1.1, extent: extent)
        } else if settings.clarity < 0 {
            let radius = min(28, max(7, max(extent.width, extent.height) * 0.012))
            image = try softened(image, radius: radius, amount: -settings.clarity / 100 * 0.55, extent: extent)
        }

        if settings.dehaze != 0 {
            // A broad unsharp pass estimates local atmospheric contrast before a restrained
            // global black-point/saturation correction. This avoids making Dehaze an alias
            // of the Contrast slider.
            let amount = settings.dehaze / 100
            let radius = min(70, max(18, max(extent.width, extent.height) * 0.035))
            if amount > 0 {
                image = try sharpened(image, radius: radius, intensity: amount * 0.75, extent: extent)
            } else {
                image = try softened(image, radius: radius, amount: -amount * 0.25, extent: extent)
            }
            let controls = CIFilter.colorControls()
            controls.inputImage = image
            controls.contrast = Float(1 + amount * 0.16)
            controls.saturation = Float(1 + amount * 0.18)
            controls.brightness = Float(-amount * 0.018)
            guard let output = controls.outputImage else { throw PhotoError.renderFailed }
            image = output.cropped(to: extent)
        }

        return image
    }

    static func applyFinishing(_ input: CIImage, settings: EffectsSettings) throws -> CIImage {
        let settings = settings.validated
        guard settings.vignette != 0 || settings.grain != 0 else { return input }
        let extent = input.extent
        var image = input
        if settings.vignette != 0 {
            let filter = CIFilter.vignette()
            filter.inputImage = image
            filter.intensity = Float(-settings.vignette / 100 * 1.7)
            filter.radius = Float(max(extent.width, extent.height) * 0.65)
            guard let output = filter.outputImage else { throw PhotoError.renderFailed }
            image = output.cropped(to: extent)
        }
        if settings.grain > 0 {
            var grain = FilmGrainSettings()
            grain.amount = settings.grain
            image = try FilmGrainEngine.apply(image, settings: grain)
        }
        return image
    }

    private static func softened(_ image: CIImage, radius: Double, amount: Double, extent: CGRect) throws -> CIImage {
        let blur = CIFilter.gaussianBlur()
        blur.inputImage = image.clampedToExtent()
        blur.radius = Float(radius)
        guard let blurred = blur.outputImage?.cropped(to: extent) else { throw PhotoError.renderFailed }
        let blend = CIFilter.dissolveTransition()
        blend.inputImage = image
        blend.targetImage = blurred
        blend.time = Float(amount)
        guard let output = blend.outputImage else { throw PhotoError.renderFailed }
        return output.cropped(to: extent)
    }

    private static func sharpened(_ image: CIImage, radius: Double, intensity: Double, extent: CGRect) throws -> CIImage {
        let filter = CIFilter.unsharpMask()
        filter.inputImage = image
        filter.radius = Float(radius)
        filter.intensity = Float(intensity)
        guard let output = filter.outputImage else { throw PhotoError.renderFailed }
        return output.cropped(to: extent)
    }
}
