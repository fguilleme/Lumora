import Foundation

enum MixerChannel: String, Codable, CaseIterable, Sendable, Identifiable {
    case red, orange, yellow, green, aqua, blue, purple, magenta
    var id: String { rawValue }
    var title: String {
        switch self {
        case .red: String(localized: "Red"); case .orange: "Orange"; case .yellow: String(localized: "Yellow"); case .green: String(localized: "Green")
        case .aqua: String(localized: "Aqua"); case .blue: String(localized: "Blue"); case .purple: String(localized: "Purple"); case .magenta: "Magenta"
        }
    }
    /// Centers in perceptual sRGB hue, in degrees around the circle.
    var center: Double {
        switch self {
        case .red: 0; case .orange: 30; case .yellow: 60; case .green: 120
        case .aqua: 180; case .blue: 240; case .purple: 270; case .magenta: 300
        }
    }
}

enum MixerComponent: String, CaseIterable, Sendable, Identifiable {
    case hue, saturation, luminance
    var id: String { rawValue }
    var title: String {
        switch self { case .hue: String(localized: "Hue"); case .saturation: "Saturation"; case .luminance: "Luminance" }
    }
    var keyPath: WritableKeyPath<MixerAdjustment, Double> {
        switch self { case .hue: \.hue; case .saturation: \.saturation; case .luminance: \.luminance }
    }
}

struct MixerAdjustment: Codable, Sendable, Equatable {
    var hue: Double = 0
    var saturation: Double = 0
    var luminance: Double = 0
    init(hue: Double = 0, saturation: Double = 0, luminance: Double = 0) {
        self.hue = Self.clamp(hue); self.saturation = Self.clamp(saturation); self.luminance = Self.clamp(luminance)
    }
    subscript(_ component: MixerComponent) -> Double {
        get { self[keyPath: component.keyPath] }
        set { self[keyPath: component.keyPath] = Self.clamp(newValue) }
    }
    var validated: Self { Self(hue: hue, saturation: saturation, luminance: luminance) }
    private static func clamp(_ value: Double) -> Double { value.isFinite ? min(100, max(-100, value)) : 0 }
    private enum CodingKeys: String, CodingKey { case hue, saturation, luminance }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(hue: try values.decodeIfPresent(Double.self, forKey: .hue) ?? 0,
                  saturation: try values.decodeIfPresent(Double.self, forKey: .saturation) ?? 0,
                  luminance: try values.decodeIfPresent(Double.self, forKey: .luminance) ?? 0)
    }
}

/// Named, independently serializable bands; absent bands decode as neutral.
struct ColorMixer: Codable, Sendable, Equatable {
    private var red = MixerAdjustment(), orange = MixerAdjustment(), yellow = MixerAdjustment(), green = MixerAdjustment()
    private var aqua = MixerAdjustment(), blue = MixerAdjustment(), purple = MixerAdjustment(), magenta = MixerAdjustment()
    init() {}
    var isIdentity: Bool { MixerChannel.allCases.allSatisfy { self[$0] == MixerAdjustment() } }
    subscript(_ channel: MixerChannel) -> MixerAdjustment {
        get {
            switch channel {
            case .red: red; case .orange: orange; case .yellow: yellow; case .green: green
            case .aqua: aqua; case .blue: blue; case .purple: purple; case .magenta: magenta
            }
        }
        set {
            let value = newValue.validated
            switch channel {
            case .red: red = value; case .orange: orange = value; case .yellow: yellow = value; case .green: green = value
            case .aqua: aqua = value; case .blue: blue = value; case .purple: purple = value; case .magenta: magenta = value
            }
        }
    }
    private enum CodingKeys: String, CodingKey { case red, orange, yellow, green, aqua, blue, purple, magenta }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        red = try values.decodeIfPresent(MixerAdjustment.self, forKey: .red) ?? MixerAdjustment()
        orange = try values.decodeIfPresent(MixerAdjustment.self, forKey: .orange) ?? MixerAdjustment()
        yellow = try values.decodeIfPresent(MixerAdjustment.self, forKey: .yellow) ?? MixerAdjustment()
        green = try values.decodeIfPresent(MixerAdjustment.self, forKey: .green) ?? MixerAdjustment()
        aqua = try values.decodeIfPresent(MixerAdjustment.self, forKey: .aqua) ?? MixerAdjustment()
        blue = try values.decodeIfPresent(MixerAdjustment.self, forKey: .blue) ?? MixerAdjustment()
        purple = try values.decodeIfPresent(MixerAdjustment.self, forKey: .purple) ?? MixerAdjustment()
        magenta = try values.decodeIfPresent(MixerAdjustment.self, forKey: .magenta) ?? MixerAdjustment()
    }
}

struct HSLColor: Sendable {
    var hue: Double // degrees, [0, 360)
    var saturation: Double
    var lightness: Double
    init(hue: Double, saturation: Double, lightness: Double) {
        self.hue = Self.wrap(hue); self.saturation = saturation; self.lightness = lightness
    }
    init(red: Double, green: Double, blue: Double) {
        let maximum = max(red, green, blue), minimum = min(red, green, blue)
        let chroma = maximum - minimum
        lightness = (maximum + minimum) / 2
        guard chroma > 1e-12 else { hue = 0; saturation = 0; return }
        saturation = chroma / max(1e-12, 1 - abs(2 * lightness - 1))
        if maximum == red { hue = Self.wrap(60 * (green - blue) / chroma) }
        else if maximum == green { hue = Self.wrap(60 * ((blue - red) / chroma + 2)) }
        else { hue = Self.wrap(60 * ((red - green) / chroma + 4)) }
    }
    static func wrap(_ hue: Double) -> Double {
        guard hue.isFinite else { return 0 }
        let value = hue.truncatingRemainder(dividingBy: 360)
        return value < 0 ? value + 360 : value
    }
    var rgb: (Double, Double, Double) {
        let chroma = (1 - abs(2 * lightness - 1)) * saturation
        let sector = Self.wrap(hue) / 60
        let x = chroma * (1 - abs(sector.truncatingRemainder(dividingBy: 2) - 1))
        let offset = lightness - chroma / 2
        let components: (Double, Double, Double)
        switch sector {
        case ..<1: components = (chroma, x, 0)
        case ..<2: components = (x, chroma, 0)
        case ..<3: components = (0, chroma, x)
        case ..<4: components = (0, x, chroma)
        case ..<5: components = (x, 0, chroma)
        default: components = (chroma, 0, x)
        }
        return (components.0 + offset, components.1 + offset, components.2 + offset)
    }
}

enum HSLMixer {
    /// Cyclic partition of unity: exactly two neighboring bands with smooth C1 transitions.
    /// 360° and 0° share the same red center, avoiding a seam in the red range.
    static func weights(hue: Double) -> (lower: MixerChannel, upper: MixerChannel, upperWeight: Double) {
        let hue = HSLColor.wrap(hue)
        let channels = MixerChannel.allCases
        let index = channels.lastIndex { $0.center <= hue } ?? 0
        let lower = channels[index], upper = channels[(index + 1) % channels.count]
        let high = upper == .red ? 360 : upper.center
        let t = (hue - lower.center) / (high - lower.center)
        return (lower, upper, t * t * (3 - 2 * t))
    }
    static func apply(_ red: Double, _ green: Double, _ blue: Double, mixer: ColorMixer) -> (Double, Double, Double) {
        var color = HSLColor(red: red, green: green, blue: blue)
        // Hue is undefined for neutral pixels. Fade hue/lightness edits near the neutral axis.
        let chroma = max(red, green, blue) - min(red, green, blue)
        guard chroma > 1e-12 else { return (red, green, blue) }
        let bands = weights(hue: color.hue)
        let a = mixer[bands.lower], b = mixer[bands.upper], w = bands.upperWeight
        let hue = a.hue * (1 - w) + b.hue * w
        let saturation = a.saturation * (1 - w) + b.saturation * w
        let luminance = a.luminance * (1 - w) + b.luminance * w
        let protection = TonalResponse.smoothstep(0.015, 0.12, chroma)
        color.hue = HSLColor.wrap(color.hue + hue * 0.3 * protection)
        color.saturation = min(1, max(0, color.saturation * (1 + saturation / 100)))
        let amount = luminance / 100 * 0.5 * protection
        color.lightness += amount * (amount >= 0 ? 1 - color.lightness : color.lightness)
        return color.rgb
    }
}
