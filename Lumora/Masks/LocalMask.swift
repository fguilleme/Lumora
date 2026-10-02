import Foundation

struct MaskPoint: Codable, Sendable, Equatable {
    var x: Double
    var y: Double
    var validated: Self {
        Self(x: x.isFinite ? min(1, max(0, x)) : 0.5,
             y: y.isFinite ? min(1, max(0, y)) : 0.5)
    }
}

struct BrushMask: Codable, Sendable, Equatable {
    var strokes: [[MaskPoint]] = []
    var eraseStrokes: [[MaskPoint]] = []
    /// Effective image-relative size captured when each stroke begins. Empty arrays
    /// preserve legacy documents, where every stroke uses `size`.
    var strokeSizes: [Double] = []
    var eraseStrokeSizes: [Double] = []
    var size = 18.0
    var feather = 70.0
    var flow = 80.0
    var opacity = 100.0

    private enum CodingKeys: String, CodingKey {
        case strokes, eraseStrokes, strokeSizes, eraseStrokeSizes, size, feather, flow, opacity
    }

    init(strokes: [[MaskPoint]] = [], eraseStrokes: [[MaskPoint]] = [],
         strokeSizes: [Double] = [], eraseStrokeSizes: [Double] = [], size: Double = 18,
         feather: Double = 70, flow: Double = 80, opacity: Double = 100) {
        self.strokes = strokes
        self.eraseStrokes = eraseStrokes
        self.strokeSizes = strokeSizes
        self.eraseStrokeSizes = eraseStrokeSizes
        self.size = size
        self.feather = feather
        self.flow = flow
        self.opacity = opacity
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        strokes = try values.decodeIfPresent([[MaskPoint]].self, forKey: .strokes) ?? []
        eraseStrokes = try values.decodeIfPresent([[MaskPoint]].self, forKey: .eraseStrokes) ?? []
        strokeSizes = try values.decodeIfPresent([Double].self, forKey: .strokeSizes) ?? []
        eraseStrokeSizes = try values.decodeIfPresent([Double].self, forKey: .eraseStrokeSizes) ?? []
        size = try values.decodeIfPresent(Double.self, forKey: .size) ?? 18
        feather = try values.decodeIfPresent(Double.self, forKey: .feather) ?? 70
        flow = try values.decodeIfPresent(Double.self, forKey: .flow) ?? 80
        opacity = try values.decodeIfPresent(Double.self, forKey: .opacity) ?? 100
        self = validated
    }

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(strokes, forKey: .strokes)
        try values.encode(eraseStrokes, forKey: .eraseStrokes)
        try values.encode(strokeSizes, forKey: .strokeSizes)
        try values.encode(eraseStrokeSizes, forKey: .eraseStrokeSizes)
        try values.encode(size, forKey: .size)
        try values.encode(feather, forKey: .feather)
        try values.encode(flow, forKey: .flow)
        try values.encode(opacity, forKey: .opacity)
    }

    var validated: Self {
        var value = self
        value.strokes = strokes.prefix(128).map { $0.prefix(4096).map(\.validated) }
        let remaining = max(0, 128 - value.strokes.count)
        value.eraseStrokes = eraseStrokes.prefix(remaining).map { $0.prefix(4096).map(\.validated) }
        value.size = Self.clamp(size, 1...100, fallback: 18)
        value.strokeSizes = strokeSizes.prefix(value.strokes.count).map {
            Self.clamp($0, 0.1...100, fallback: value.size)
        }
        value.eraseStrokeSizes = eraseStrokeSizes.prefix(value.eraseStrokes.count).map {
            Self.clamp($0, 0.1...100, fallback: value.size)
        }
        value.feather = Self.clamp(feather, 0...100, fallback: 70)
        value.flow = Self.clamp(flow, 1...100, fallback: 80)
        value.opacity = Self.clamp(opacity, 1...100, fallback: 100)
        return value
    }
    private static func clamp(_ value: Double, _ range: ClosedRange<Double>, fallback: Double) -> Double {
        value.isFinite ? min(range.upperBound, max(range.lowerBound, value)) : fallback
    }
}

enum BrushMode: String, CaseIterable, Sendable {
    case paint, erase, pan

    var title: String { switch self { case .paint: String(localized: "Paint"); case .erase: String(localized: "Erase"); case .pan: String(localized: "Pan") } }
}

struct LinearGradientMask: Codable, Sendable, Equatable {
    var center = MaskPoint(x: 0.5, y: 0.5)
    var angle = 0.0
    var feather = 40.0
    var validated: Self {
        var value = self; value.center = center.validated
        value.angle = angle.isFinite ? min(180, max(-180, angle)) : 0
        value.feather = feather.isFinite ? min(100, max(1, feather)) : 40
        return value
    }
}

struct RadialGradientMask: Codable, Sendable, Equatable {
    var center = MaskPoint(x: 0.5, y: 0.5)
    var radiusX = 0.35
    var radiusY = 0.25
    var feather = 50.0
    var validated: Self {
        var value = self; value.center = center.validated
        value.radiusX = Self.clamp(radiusX, fallback: 0.35)
        value.radiusY = Self.clamp(radiusY, fallback: 0.25)
        value.feather = feather.isFinite ? min(100, max(1, feather)) : 50
        return value
    }
    private static func clamp(_ value: Double, fallback: Double) -> Double {
        value.isFinite ? min(1, max(0.02, value)) : fallback
    }
}

enum SmartMaskKind: String, CaseIterable, Codable, Sendable, Identifiable {
    case subject, background, person, face, eyes, sky, skin

    var id: String { rawValue }
    var title: String {
        switch self {
        case .subject: String(localized: "Subject")
        case .background: String(localized: "Background")
        case .person: String(localized: "Person")
        case .face: String(localized: "Face")
        case .eyes: String(localized: "Eyes")
        case .sky: String(localized: "Sky")
        case .skin: String(localized: "Skin")
        }
    }
    var symbol: String {
        switch self {
        case .subject: "person.crop.rectangle"
        case .background: "rectangle.dashed"
        case .person: "figure.stand"
        case .face: "face.smiling"
        case .eyes: "eye"
        case .sky: "cloud.sun"
        case .skin: "hand.raised"
        }
    }
}

struct GeneratedMask: Codable, Sendable, Equatable {
    var kind: SmartMaskKind
    var pngData: Data
    var width: Int
    var height: Int

    var validated: Self {
        guard (1...4096).contains(width), (1...4096).contains(height),
              !pngData.isEmpty, pngData.count <= 8 * 1_024 * 1_024 else {
            return Self(kind: kind, pngData: Data(), width: 0, height: 0)
        }
        return self
    }
}

enum MaskShape: Codable, Sendable, Equatable {
    case brush(BrushMask)
    case linear(LinearGradientMask)
    case radial(RadialGradientMask)
    case generated(GeneratedMask)

    var title: String {
        switch self {
        case .brush: String(localized: "Brush")
        case .linear: String(localized: "Linear")
        case .radial: "Radial"
        case .generated(let mask): mask.kind.title
        }
    }
}

enum MaskOperation: String, Codable, Sendable, CaseIterable { case add, subtract }

struct MaskComponent: Codable, Sendable, Equatable, Identifiable {
    var id = UUID()
    var operation = MaskOperation.add
    var shape: MaskShape
    var validated: Self {
        var value = self
        switch shape {
        case .brush(let brush): value.shape = .brush(brush.validated)
        case .linear(let linear): value.shape = .linear(linear.validated)
        case .radial(let radial): value.shape = .radial(radial.validated)
        case .generated(let mask): value.shape = .generated(mask.validated)
        }
        return value
    }
}

struct LocalAdjustmentState: Codable, Sendable, Equatable {
    var exposure = 0.0, contrast = 0.0, highlights = 0.0, shadows = 0.0
    var whites = 0.0, blacks = 0.0
    var temperature = 0.0, tint = 0.0, vibrance = 0.0, saturation = 0.0
    var curves = ToneCurves()
    var colorMixer = ColorMixer()
    var colorGrading = ColorGrading()
    var effects = EffectsSettings()
    var detail = DetailSettings()

    init() {}

    init(editState: EditState) {
        for adjustment in Adjustment.allCases { set(adjustment, to: editState[adjustment]) }
        curves = editState.curves
        colorMixer = editState.colorMixer
        colorGrading = editState.colorGrading
        effects = editState.effects
        detail = editState.detail
    }

    private enum CodingKeys: String, CodingKey {
        case exposure, contrast, highlights, shadows, whites, blacks
        case temperature, tint, vibrance, saturation, clarity, sharpness
        case curves, colorMixer, colorGrading, effects, detail
    }

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
        effects.clarity = try values.decodeIfPresent(Double.self, forKey: .clarity) ?? effects.clarity
        detail.sharpening.amount = try values.decodeIfPresent(Double.self, forKey: .sharpness) ?? detail.sharpening.amount
        self = validated
    }

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(exposure, forKey: .exposure)
        try values.encode(contrast, forKey: .contrast)
        try values.encode(highlights, forKey: .highlights)
        try values.encode(shadows, forKey: .shadows)
        try values.encode(whites, forKey: .whites)
        try values.encode(blacks, forKey: .blacks)
        try values.encode(temperature, forKey: .temperature)
        try values.encode(tint, forKey: .tint)
        try values.encode(vibrance, forKey: .vibrance)
        try values.encode(saturation, forKey: .saturation)
        try values.encode(curves, forKey: .curves)
        try values.encode(colorMixer, forKey: .colorMixer)
        try values.encode(colorGrading, forKey: .colorGrading)
        try values.encode(effects, forKey: .effects)
        try values.encode(detail, forKey: .detail)
    }

    var editState: EditState {
        var state = EditState()
        for adjustment in Adjustment.allCases { state[adjustment] = value(for: adjustment) }
        state.curves = curves
        state.colorMixer = colorMixer
        state.colorGrading = colorGrading
        state.effects = effects
        state.detail = detail
        return state.validated
    }

    var isIdentity: Bool {
        Adjustment.allCases.allSatisfy { value(for: $0) == 0 }
            && curves.isIdentity && colorMixer.isIdentity && colorGrading.isIdentity
            && effects.isIdentity && detail.isIdentity
    }

    var validated: Self {
        var value = self
        for adjustment in Adjustment.allCases { value.set(adjustment, to: self.value(for: adjustment)) }
        value.colorGrading = colorGrading.validated
        value.effects = effects.validated
        value.detail = detail.validated
        return value
    }

    func value(for adjustment: Adjustment) -> Double {
        switch adjustment {
        case .exposure: exposure; case .contrast: contrast
        case .highlights: highlights; case .shadows: shadows
        case .whites: whites; case .blacks: blacks
        case .temperature: temperature; case .tint: tint
        case .vibrance: vibrance; case .saturation: saturation
        }
    }

    mutating func set(_ adjustment: Adjustment, to newValue: Double) {
        let value = newValue.isFinite
            ? min(adjustment.range.upperBound, max(adjustment.range.lowerBound, newValue)) : 0
        switch adjustment {
        case .exposure: exposure = value; case .contrast: contrast = value
        case .highlights: highlights = value; case .shadows: shadows = value
        case .whites: whites = value; case .blacks: blacks = value
        case .temperature: temperature = value; case .tint: tint = value
        case .vibrance: vibrance = value; case .saturation: saturation = value
        }
    }

    var clarity: Double {
        get { effects.clarity }
        set { effects.clarity = newValue }
    }
    var sharpness: Double {
        get { detail.sharpening.amount }
        set { detail.sharpening.amount = newValue }
    }

    subscript(_ adjustment: LocalAdjustment) -> Double {
        get {
            switch adjustment {
            case .exposure: exposure; case .contrast: contrast
            case .highlights: highlights; case .shadows: shadows
            case .temperature: temperature; case .tint: tint
            case .saturation: saturation; case .clarity: effects.clarity
            case .sharpness: detail.sharpening.amount
            }
        }
        set {
            let value = newValue.isFinite
                ? min(adjustment.range.upperBound, max(adjustment.range.lowerBound, newValue)) : 0
            switch adjustment {
            case .exposure: exposure = value; case .contrast: contrast = value
            case .highlights: highlights = value; case .shadows: shadows = value
            case .temperature: temperature = value; case .tint: tint = value
            case .saturation: saturation = value; case .clarity: effects.clarity = value
            case .sharpness: detail.sharpening.amount = value
            }
        }
    }
}

enum LocalAdjustment: String, CaseIterable, Codable, Sendable, Identifiable {
    case exposure, contrast, highlights, shadows, temperature, tint, saturation, clarity, sharpness
    var id: String { rawValue }
    var title: String {
        switch self {
        case .exposure: String(localized: "Exposure")
        case .contrast: String(localized: "Contrast")
        case .highlights: String(localized: "Highlights")
        case .shadows: String(localized: "Shadows")
        case .temperature: String(localized: "Temperature")
        case .tint: String(localized: "Tint")
        case .saturation: "Saturation"
        case .clarity: String(localized: "Clarity")
        case .sharpness: String(localized: "Sharpening")
        }
    }
    var range: ClosedRange<Double> { self == .exposure ? -5...5 : (self == .sharpness ? 0...100 : -100...100) }
}

struct AdjustmentLayer: Codable, Sendable, Equatable, Identifiable {
    var id = UUID()
    var name: String
    var components: [MaskComponent]
    var adjustments = LocalAdjustmentState()
    var inverted = false
    var isVisible = true
    var opacity = 100.0

    init(id: UUID = UUID(), name: String, components: [MaskComponent],
         adjustments: LocalAdjustmentState = LocalAdjustmentState(), inverted: Bool = false,
         isVisible: Bool = true, opacity: Double = 100) {
        self.id = id
        self.name = name
        self.components = components
        self.adjustments = adjustments
        self.inverted = inverted
        self.isVisible = isVisible
        self.opacity = opacity
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, components, adjustments, inverted, isVisible, opacity
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try values.decodeIfPresent(String.self, forKey: .name) ?? "Layer"
        components = try values.decodeIfPresent([MaskComponent].self, forKey: .components) ?? []
        adjustments = try values.decodeIfPresent(LocalAdjustmentState.self, forKey: .adjustments) ?? LocalAdjustmentState()
        inverted = try values.decodeIfPresent(Bool.self, forKey: .inverted) ?? false
        isVisible = try values.decodeIfPresent(Bool.self, forKey: .isVisible) ?? true
        opacity = try values.decodeIfPresent(Double.self, forKey: .opacity) ?? 100
        self = validated
    }

    var validated: Self {
        var value = self
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        value.name = cleanName.isEmpty ? "Layer" : String(cleanName.prefix(60))
        value.components = components.prefix(32).map(\.validated)
        value.adjustments = adjustments.validated
        value.opacity = opacity.isFinite ? min(100, max(0, opacity)) : 100
        return value
    }
}

/// Source-compatible name for sidecars and call sites created before masks became
/// full adjustment layers. The serialized `masks` key remains intentionally stable.
typealias LocalMask = AdjustmentLayer

enum MaskKind: String, CaseIterable, Sendable, Identifiable {
    case brush, linear, radial
    var id: String { rawValue }
    var title: String { switch self { case .brush: String(localized: "Brush"); case .linear: String(localized: "Linear"); case .radial: "Radial" } }
    func shape() -> MaskShape {
        switch self {
        case .brush: .brush(BrushMask())
        case .linear: .linear(LinearGradientMask())
        case .radial: .radial(RadialGradientMask())
        }
    }
}

enum MaskParameter: String, CaseIterable, Sendable, Identifiable {
    case size, feather, flow, opacity, angle, centerX, centerY, radiusX, radiusY
    var id: String { rawValue }
    var title: String {
        switch self {
        case .size: String(localized: "Size"); case .feather: String(localized: "Feather"); case .flow: String(localized: "Flow")
        case .opacity: String(localized: "Opacity"); case .angle: "Angle"; case .centerX: String(localized: "Horizontal center")
        case .centerY: String(localized: "Vertical center"); case .radiusX: String(localized: "Width"); case .radiusY: String(localized: "Height")
        }
    }
    var range: ClosedRange<Double> {
        switch self {
        case .angle: -180...180
        case .centerX, .centerY: 0...100
        case .radiusX, .radiusY: 2...100
        default: 1...100
        }
    }
}
