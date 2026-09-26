import Foundation

enum GradingRange: String, Codable, CaseIterable, Sendable, Identifiable {
    case shadows, midtones, highlights, global
    var id: String { rawValue }
    var title: String {
        switch self { case .shadows: String(localized: "Shadows"); case .midtones: String(localized: "Midtones"); case .highlights: String(localized: "Highlights"); case .global: String(localized: "Global") }
    }
}

struct GradingWheel: Codable, Sendable, Equatable {
    var hue: Double = 0
    var saturation: Double = 0
    var luminance: Double = 0
    init(hue: Double = 0, saturation: Double = 0, luminance: Double = 0) {
        self.hue = HSLColor.wrap(hue)
        self.saturation = Self.clamp(saturation, 0...100)
        self.luminance = Self.clamp(luminance, -100...100)
    }
    var validated: Self { Self(hue: hue, saturation: saturation, luminance: luminance) }
    static func clamp(_ value: Double, _ range: ClosedRange<Double>) -> Double {
        value.isFinite ? min(range.upperBound, max(range.lowerBound, value)) : 0
    }
    private enum CodingKeys: String, CodingKey { case hue, saturation, luminance }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(hue: try values.decodeIfPresent(Double.self, forKey: .hue) ?? 0,
                  saturation: try values.decodeIfPresent(Double.self, forKey: .saturation) ?? 0,
                  luminance: try values.decodeIfPresent(Double.self, forKey: .luminance) ?? 0)
    }
}

struct ColorGrading: Codable, Sendable, Equatable {
    var shadows = GradingWheel(), midtones = GradingWheel(), highlights = GradingWheel(), global = GradingWheel()
    var blending: Double = 50
    var balance: Double = 0
    init() {}
    var isIdentity: Bool {
        GradingRange.allCases.allSatisfy { self[$0].saturation == 0 && self[$0].luminance == 0 }
    }
    subscript(_ range: GradingRange) -> GradingWheel {
        get { switch range { case .shadows: shadows; case .midtones: midtones; case .highlights: highlights; case .global: global } }
        set { switch range { case .shadows: shadows = newValue.validated; case .midtones: midtones = newValue.validated; case .highlights: highlights = newValue.validated; case .global: global = newValue.validated } }
    }
    var validated: Self {
        var result = self
        for range in GradingRange.allCases { result[range] = self[range] }
        result.blending = GradingWheel.clamp(blending, 0...100)
        result.balance = GradingWheel.clamp(balance, -100...100)
        return result
    }
    private enum CodingKeys: String, CodingKey { case shadows, midtones, highlights, global, blending, balance }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        shadows = try values.decodeIfPresent(GradingWheel.self, forKey: .shadows) ?? GradingWheel()
        midtones = try values.decodeIfPresent(GradingWheel.self, forKey: .midtones) ?? GradingWheel()
        highlights = try values.decodeIfPresent(GradingWheel.self, forKey: .highlights) ?? GradingWheel()
        global = try values.decodeIfPresent(GradingWheel.self, forKey: .global) ?? GradingWheel()
        blending = try values.decodeIfPresent(Double.self, forKey: .blending) ?? 50
        balance = try values.decodeIfPresent(Double.self, forKey: .balance) ?? 0
        self = validated
    }
}

/// UI-independent wheel coordinates. Zero hue points right; hue increases clockwise.
enum ColorWheelCoordinates {
    static func position(hue: Double, saturation: Double) -> (x: Double, y: Double) {
        let angle = HSLColor.wrap(hue) * .pi / 180
        let radius = GradingWheel.clamp(saturation, 0...100) / 100
        return (cos(angle) * radius, sin(angle) * radius)
    }
    static func value(x: Double, y: Double, previousHue: Double) -> (hue: Double, saturation: Double) {
        guard x.isFinite, y.isFinite else { return (HSLColor.wrap(previousHue), 0) }
        let radius = hypot(x, y)
        return (radius < 0.001 ? HSLColor.wrap(previousHue) : HSLColor.wrap(atan2(y, x) * 180 / .pi), min(1, radius) * 100)
    }
}

/// Prepared once per LUT; hue vectors are never recomputed per pixel.
struct GradingTransform: Sendable {
    private let settings: ColorGrading
    private let vectors: [SIMD3<Double>]
    init(_ settings: ColorGrading) {
        self.settings = settings.validated
        vectors = GradingRange.allCases.map { range in
            let wheel = settings[range].validated
            let color = HSLColor(hue: wheel.hue, saturation: 1, lightness: 0.5).rgb
            let luma = color.0 * 0.2126 + color.1 * 0.7152 + color.2 * 0.0722
            return (SIMD3(color.0, color.1, color.2) - SIMD3(repeating: luma)) * (wheel.saturation / 100)
        }
    }
    static func weights(luminance: Double, blending: Double, balance: Double) -> SIMD3<Double> {
        let value = GradingWheel.clamp(luminance + GradingWheel.clamp(balance, -100...100) * 0.0025, 0...1)
        let width = 0.15 + GradingWheel.clamp(blending, 0...100) * 0.003
        let shadows = 1 - TonalResponse.smoothstep(0.3 - width, 0.3 + width, value)
        let highlights = TonalResponse.smoothstep(0.7 - width, 0.7 + width, value)
        return SIMD3(shadows, max(0, 1 - shadows - highlights), highlights)
    }
    func apply(_ r: Double, _ g: Double, _ b: Double) -> (Double, Double, Double) {
        let y = r * 0.2126 + g * 0.7152 + b * 0.0722
        let weights = Self.weights(luminance: y, blending: settings.blending, balance: settings.balance)
        let envelope = 4 * y * (1 - y)
        let luminance = settings.shadows.luminance * weights.x + settings.midtones.luminance * weights.y + settings.highlights.luminance * weights.z + settings.global.luminance
        let delta = luminance * 0.0025 * envelope
        let base = SIMD3(min(1, max(0, r + delta)), min(1, max(0, g + delta)), min(1, max(0, b + delta)))
        let tint = (vectors[0] * weights.x + vectors[1] * weights.y + vectors[2] * weights.z + vectors[3]) * (0.35 * envelope)
        // Compress the tint uniformly to the available gamut, preserving its direction.
        var scale = 1.0
        for i in 0..<3 {
            if tint[i] > 0 { scale = min(scale, (1 - base[i]) / tint[i]) }
            else if tint[i] < 0 { scale = min(scale, -base[i] / tint[i]) }
        }
        let output = base + tint * max(0, scale)
        return (output.x, output.y, output.z)
    }
}
