import Foundation

/// Development instructions, never rendered pixels. Versioned independently of the original.
struct EditState: Codable, Sendable, Equatable {
    var exposure: Double = 0
    var contrast: Double = 0
    var highlights: Double = 0
    var shadows: Double = 0
    var whites: Double = 0
    var blacks: Double = 0
    /// Relative temperature offset; zero preserves the embedded/as-shot white balance.
    var temperature: Double = 0
    var tint: Double = 0
    var vibrance: Double = 0
    var saturation: Double = 0
    var curves = ToneCurves()
    var colorMixer = ColorMixer()
    var colorGrading = ColorGrading()
    var effects = EffectsSettings()
    var detail = DetailSettings()
    var beauty = BeautyState()
    var depthLens: DepthLensSettings?
    var depthLighting: DepthLightingSettings?
    var optics = OpticsSettings()
    var geometry = GeometrySettings()
    /// Frozen Core Image Auto baseline, applied before manual development controls.
    var coreImageAuto: CoreImageAutoState?
    var creative = CreativeEffectStack()
    /// Ordered masked adjustment layers. The legacy key name is preserved on disk.
    var masks: [AdjustmentLayer] = []

    init() {}

    private enum CodingKeys: String, CodingKey {
        case exposure, contrast, highlights, shadows, whites, blacks
        case temperature, tint, vibrance, saturation, curves, colorMixer, colorGrading, effects, detail, beauty, optics, geometry, masks, creative, coreImageAuto, depthLens, depthLighting
    }

    /// Additive migration: older documents have no curve or mixer keys.
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        exposure = try values.decodeIfPresent(Double.self, forKey: .exposure) ?? 0
        contrast = try values.decodeIfPresent(Double.self, forKey: .contrast) ?? 0
        highlights = try values.decodeIfPresent(Double.self, forKey: .highlights) ?? 0
        shadows = try values.decodeIfPresent(Double.self, forKey: .shadows) ?? 0
        whites = try values.decodeIfPresent(Double.self, forKey: .whites) ?? 0
        blacks = try values.decodeIfPresent(Double.self, forKey: .blacks) ?? 0
        temperature = try values.decodeIfPresent(Double.self, forKey: .temperature) ?? 0
        tint = try values.decodeIfPresent(Double.self, forKey: .tint) ?? 0
        vibrance = try values.decodeIfPresent(Double.self, forKey: .vibrance) ?? 0
        saturation = try values.decodeIfPresent(Double.self, forKey: .saturation) ?? 0
        curves = try values.decodeIfPresent(ToneCurves.self, forKey: .curves) ?? ToneCurves()
        colorMixer = try values.decodeIfPresent(ColorMixer.self, forKey: .colorMixer) ?? ColorMixer()
        colorGrading = try values.decodeIfPresent(ColorGrading.self, forKey: .colorGrading) ?? ColorGrading()
        effects = try values.decodeIfPresent(EffectsSettings.self, forKey: .effects) ?? EffectsSettings()
        detail = try values.decodeIfPresent(DetailSettings.self, forKey: .detail) ?? DetailSettings()
        beauty = try values.decodeIfPresent(BeautyState.self, forKey: .beauty) ?? BeautyState()
        optics = try values.decodeIfPresent(OpticsSettings.self, forKey: .optics) ?? OpticsSettings()
        geometry = try values.decodeIfPresent(GeometrySettings.self, forKey: .geometry) ?? GeometrySettings()
        coreImageAuto = try values.decodeIfPresent(CoreImageAutoState.self, forKey: .coreImageAuto)
        masks = try values.decodeIfPresent([LocalMask].self, forKey: .masks) ?? []
        creative = try values.decodeIfPresent(CreativeEffectStack.self, forKey: .creative) ?? CreativeEffectStack()
        depthLens = try values.decodeIfPresent(DepthLensSettings.self, forKey: .depthLens)
        depthLighting = try values.decodeIfPresent(DepthLightingSettings.self, forKey: .depthLighting)
        self = validated
    }

    subscript(_ adjustment: Adjustment) -> Double {
        get { self[keyPath: adjustment.keyPath] }
        set { self[keyPath: adjustment.keyPath] = newValue.isFinite ? min(adjustment.range.upperBound, max(adjustment.range.lowerBound, newValue)) : 0 }
    }

    var validated: EditState {
        var result = self
        for adjustment in Adjustment.allCases { result[adjustment] = self[adjustment] }
        result.colorGrading = colorGrading.validated
        result.effects = effects.validated
        result.detail = detail.validated
        result.beauty = beauty.validated
        result.depthLens = depthLens?.validated
        result.depthLighting = depthLighting?.validated
        result.optics = optics.validated
        result.geometry = geometry.validated
        result.creative = creative.validated
        result.masks = masks.prefix(16).map(\.validated)
        return result
    }
}

enum Adjustment: String, CaseIterable, Codable, Sendable, Identifiable {
    case exposure, contrast, highlights, shadows, whites, blacks
    case temperature, tint, vibrance, saturation
    var id: String { rawValue }
    var title: String {
        switch self {
        case .exposure: String(localized: "Exposure")
        case .contrast: String(localized: "Contrast")
        case .highlights: String(localized: "Highlights")
        case .shadows: String(localized: "Shadows")
        case .whites: String(localized: "Whites")
        case .blacks: String(localized: "Blacks")
        case .temperature: String(localized: "Temperature")
        case .tint: String(localized: "Tint")
        case .vibrance: "Vibrance"
        case .saturation: "Saturation"
        }
    }
    var range: ClosedRange<Double> { self == .exposure ? -5...5 : -100...100 }
    var step: Double { self == .exposure ? 0.01 : 1 }
    var keyPath: WritableKeyPath<EditState, Double> {
        switch self {
        case .exposure: \.exposure
        case .contrast: \.contrast
        case .highlights: \.highlights
        case .shadows: \.shadows
        case .whites: \.whites
        case .blacks: \.blacks
        case .temperature: \.temperature
        case .tint: \.tint
        case .vibrance: \.vibrance
        case .saturation: \.saturation
        }
    }
    static let light: [Self] = [.exposure, .contrast, .highlights, .shadows, .whites, .blacks]
    static let color: [Self] = [.temperature, .tint, .vibrance, .saturation]
}
