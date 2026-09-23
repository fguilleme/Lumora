import Foundation

struct FXParameter: Sendable, Identifiable {
    let id: String
    let title: String
    let range: ClosedRange<Double>
    let defaultValue: Double
    init(_ id: String, _ title: String, _ range: ClosedRange<Double> = 0...100, _ value: Double = 0) {
        self.id = id; self.title = title; self.range = range; defaultValue = value
    }
}

enum CreativeEffectKind: String, Codable, CaseIterable, Sendable, Identifiable {
    case highKey, lowKey, grain, tonalContrast, detailExtractor, glamourGlow, bleachBypass, proContrast, crossProcessing, filmEmulation, silverBW, silverToning, darkenLightenCenter
    var id: String { rawValue }
    var descriptor: CreativeEffectDescriptor { CreativeEffectCatalog.descriptors[self]! }
}

struct CreativeEffectDescriptor: Sendable {
    let title: String
    let category: String
    let symbol: String
    let parameters: [FXParameter]
}

enum CreativeEffectCatalog {
    static let descriptors: [CreativeEffectKind: CreativeEffectDescriptor] = [
        .highKey: .init(title: "High Key", category: "Key", symbol: "sun.max", parameters: keyParameters(high: true)),
        .lowKey: .init(title: "Low Key", category: "Key", symbol: "moon", parameters: keyParameters(high: false)),
        .glamourGlow: .init(title: "Glamour Glow", category: "Film", symbol: "sparkles", parameters: [
            .init("amount", "Amount", 0...100, 50),
            .init("glow", "Glow", 0...100, 45),
            .init("softness", "Softness", 0...100, 40),
            .init("warmth", "Warmth", -100...100),
            .init("threshold", "Highlight threshold", 0...100, 40),
            .init("highlightProtection", "Protect highlights", 0...100, 55),
            .init("shadowProtection", "Protect shadows", 0...100, 70)
        ]),
        .bleachBypass: .init(title: "Bleach Bypass", category: "Film", symbol: "circle.lefthalf.filled", parameters: [
            .init("amount", "Amount", 0...100, 55),
            .init("bleach", "Bleach", 0...100, 55),
            .init("contrast", "Contrast", 0...100, 55),
            .init("saturation", "Saturation", -100...100),
            .init("blackDensity", "Black density", 0...100, 50),
            .init("highlightRollOff", "Highlight roll-off", 0...100, 55),
            .init("shadowProtection", "Protect shadows", 0...100, 40)
        ]),
        .proContrast: .init(title: "Pro Contrast", category: "Film", symbol: "slider.horizontal.3", parameters: [
            .init("amount", "Amount", 0...100, 60),
            .init("correctColorCast", "Correct color cast", 0...100, 25),
            .init("correctContrast", "Correct contrast", 0...100, 60),
            .init("dynamicContrast", "Dynamic contrast", 0...100, 35),
            .init("shadowProtection", "Protect shadows", 0...100, 65),
            .init("highlightProtection", "Protect highlights", 0...100, 70)
        ]),
        .crossProcessing: .init(title: "Cross Processing", category: "Film", symbol: "circle.hexagongrid.fill", parameters: [
            .init("amount", "Amount", 0...100, 65),
            .init("styleStrength", "Style strength", 0...100, 75),
            .init("contrast", "Contrast", -100...100, 20),
            .init("saturation", "Saturation", -100...100, 0),
            .init("shadowHue", "Shadow color", 0...360, 195),
            .init("shadowStrength", "Shadow strength", 0...100, 30),
            .init("highlightHue", "Highlight color", 0...360, 35),
            .init("highlightStrength", "Highlight strength", 0...100, 25),
            .init("blackLift", "Lift blacks", 0...100, 0),
            .init("style", "Internal style", 0...6, 0)
        ]),
        .filmEmulation: .init(title: "Film Emulation", category: "Film", symbol: "film.stack", parameters: [
            .init("amount", "Amount", 0...100, 75),
            .init("filmStrength", "Film strength", 0...100, 80),
            .init("exposure", "Exposure (EV)", -2...2, 0),
            .init("contrast", "Contrast", -100...100, 0),
            .init("saturation", "Saturation", -100...100, 0),
            .init("highlightRollOff", "Highlight roll-off", -100...100, 0),
            .init("shadowDensity", "Shadow density", -100...100, 0),
            .init("colorResponse", "Color response", 0...100, 75),
            .init("style", "Internal type", 0...6, 0)
        ]),
        .darkenLightenCenter: .init(title: "Darken / Lighten Center", category: "Key", symbol: "scope", parameters: [
            .init("amount", "Amount", 0...100, 100),
            .init("centerEV", "Center (EV)", -2...2),
            .init("borderEV", "Outer (EV)", -2...2),
            .init("size", "Size", 5...150, 45),
            .init("shape", "Shape (tall / wide)", -100...100),
            .init("feather", "Feather", 0...100, 75),
            .init("rotation", "Rotation (°)", -180...180),
            .init("centerX", "Center X", 0...1, 0.5),
            .init("centerY", "Center Y", 0...1, 0.5)
        ]),
        .silverToning: .init(title: "Silver Toning", category: "Film", symbol: "drop.halffull", parameters: [
            .init("amount", "Amount", 0...100, 100),
            .init("toner", "Toner", 0...8),
            .init("strength", "Strength", 0...100, 50),
            .init("balance", "Balance", -100...100),
            .init("shadowStrength", "Shadow strength", 0...100, 100),
            .init("highlightStrength", "Highlight strength", 0...100, 100),
            .init("paperTone", "Paper (cool / warm)", -100...100),
            .init("silverTone", "Silver tone", 0...100, 100),
            .init("shadowHue", "Shadow hue", 0...360, 220),
            .init("highlightHue", "Highlight hue", 0...360, 40)
        ]),
        .silverBW: .init(title: "Silver B&W", category: "Film", symbol: "circle.lefthalf.filled", parameters: [
            .init("amount", "Amount", 0...100, 100),
            .init("brightness", "Brightness", -100...100),
            .init("contrast", "Contrast", -100...100),
            .init("structure", "Structure", 0...100),
            .init("filmResponse", "Film response", 0...6),
            .init("filterHue", "Filter color", 0...360, 60),
            .init("filterStrength", "Filter strength", 0...100),
            .init("dynamicBrightness", "Dynamic brightness", -100...100),
            .init("softContrast", "Soft contrast", -100...100),
            .init("blacks", "Black density", -100...100),
            .init("whites", "White presence", -100...100)
        ]),
        .tonalContrast: .init(title: "Tonal Contrast", category: "Detail", symbol: "circle.hexagongrid", parameters: [
            .init("globalAmount", "Global", 0...100, 60),
            .init("highlights", "Highlights", -100...100, 25),
            .init("midtones", "Midtones", -100...100, 30),
            .init("shadows", "Shadows", -100...100, 20),
            // Radius is mapped logarithmically to 1.2...24 photographic px on a 3000 px long edge.
            .init("radius", "Radius", 0...100, 45),
            .init("saturation", "Saturation", -100...100),
            .init("protectHighlights", "Protect highlights", 0...100, 50),
            .init("protectShadows", "Protect shadows", 0...100, 55)
        ]),
        .detailExtractor: .init(title: "Detail Extractor", category: "Detail", symbol: "viewfinder", parameters: [
            .init("amount", "Amount", -100...100, 45),
            .init("fine", "Fine detail", 0...100, 40),
            .init("medium", "Medium detail", 0...100, 60),
            .init("large", "Large detail", 0...100, 20),
            .init("protectShadows", "Protect shadows", 0...100, 70),
            .init("protectHighlights", "Protect highlights", 0...100, 65)
        ]),
        .grain: .init(title: "Grain", category: "Film", symbol: "camera.filters", parameters: [
            .init("amount", "Amount", 0...100, 35), .init("size", "Size", 1...100, 35),
            .init("hardness", "Hardness", 0...100, 45), .init("irregularity", "Irregularity", 0...100, 50),
            .init("clumping", "Clumping", 0...100, 30), .init("softness", "Softness", 0...100, 25),
            .init("shadowAmount", "Shadows", 0...200, 80), .init("midtoneAmount", "Midtones", 0...200, 100),
            .init("highlightAmount", "Highlights", 0...200, 45),
            .init("chromaAmount", "Color grain", 0...100, 15)
        ])
    ]
    private static func keyParameters(high: Bool) -> [FXParameter] {
        [.init("amount", "Amount", 0...100, 50), .init("dynamic", "Dynamic", 0...100, 50),
         .init("glow", "Glow"), .init("glowRadius", "Glow radius", 1...100, 30),
         .init("glowThreshold", "Glow threshold", 0...100, 70), .init("contrast", "Contrast", -100...100),
         .init("saturation", "Saturation", -100...100),
         .init("darkProtection", high ? "Preserve blacks" : "Protect shadows", 0...100, 65),
         .init("lightProtection", high ? "Protect whites" : "Preserve highlights", 0...100, 70)]
    }
}

/// A color layer and a luminance-derived silver-density layer in linear light.
/// The full parameter snapshot is serializable through CreativeEffect.
struct BleachBypassSettings: Codable, Sendable, Equatable {
    var amount = 55.0, bleach = 55.0, contrast = 55.0, saturation = 0.0
    var blackDensity = 50.0, highlightRollOff = 55.0, shadowProtection = 40.0
    init() {}
    init(effect: CreativeEffect) {
        amount = effect["amount"]; bleach = effect["bleach"]
        contrast = effect["contrast"]; saturation = effect["saturation"]
        blackDensity = effect["blackDensity"]; highlightRollOff = effect["highlightRollOff"]
        shadowProtection = effect["shadowProtection"]
    }
    var validated: Self {
        var effect = CreativeEffect(.bleachBypass)
        for (key, value) in [("amount", amount), ("bleach", bleach), ("contrast", contrast),
                             ("saturation", saturation), ("blackDensity", blackDensity),
                             ("highlightRollOff", highlightRollOff), ("shadowProtection", shadowProtection)] {
            effect[key] = value
        }
        return Self(effect: effect)
    }
}

/// Global scene-aware correction; analysis is shared across slider changes.
struct ProContrastSettings: Codable, Sendable, Equatable {
    var amount = 60.0, correctColorCast = 25.0, correctContrast = 60.0
    var dynamicContrast = 35.0, shadowProtection = 65.0, highlightProtection = 70.0
    init() {}
    init(effect: CreativeEffect) {
        amount = effect["amount"]; correctColorCast = effect["correctColorCast"]
        correctContrast = effect["correctContrast"]; dynamicContrast = effect["dynamicContrast"]
        shadowProtection = effect["shadowProtection"]; highlightProtection = effect["highlightProtection"]
    }
    var validated: Self {
        var effect = CreativeEffect(.proContrast)
        for (key, value) in [("amount", amount), ("correctColorCast", correctColorCast),
                             ("correctContrast", correctContrast), ("dynamicContrast", dynamicContrast),
                             ("shadowProtection", shadowProtection), ("highlightProtection", highlightProtection)] {
            effect[key] = value
        }
        return Self(effect: effect)
    }
}

/// Seven original analytic RGB curve families. Hue values are circular degrees;
/// the final Amount blend is applied by the renderer before stack opacity/masks.
struct CrossProcessingSettings: Codable, Sendable, Equatable {
    var amount = 65.0, styleStrength = 75.0, contrast = 20.0, saturation = 0.0
    var shadowHue = 195.0, shadowStrength = 30.0
    var highlightHue = 35.0, highlightStrength = 25.0, blackLift = 0.0, style = 0.0
    init() {}
    init(effect: CreativeEffect) {
        amount = effect["amount"]; styleStrength = effect["styleStrength"]
        contrast = effect["contrast"]; saturation = effect["saturation"]
        shadowHue = effect["shadowHue"]; shadowStrength = effect["shadowStrength"]
        highlightHue = effect["highlightHue"]; highlightStrength = effect["highlightStrength"]
        blackLift = effect["blackLift"]; style = effect["style"]
    }
    var validated: Self {
        var result = CreativeEffect(.crossProcessing)
        for (key, value) in [("amount", amount), ("styleStrength", styleStrength),
                             ("contrast", contrast), ("saturation", saturation),
                             ("shadowHue", shadowHue), ("shadowStrength", shadowStrength),
                             ("highlightHue", highlightHue), ("highlightStrength", highlightStrength),
                             ("blackLift", blackLift), ("style", style)] { result[key] = value }
        return Self(effect: result)
    }
}

/// A complete, serializable film-control snapshot. The style index selects a
/// fixed parametric response; there is no external LUT or proprietary profile.
struct FilmEmulationSettings: Codable, Sendable, Equatable {
    var amount = 75.0, filmStrength = 80.0, exposure = 0.0, contrast = 0.0
    var saturation = 0.0, highlightRollOff = 0.0, shadowDensity = 0.0
    var colorResponse = 75.0, style = 0.0
    init() {}
    init(effect: CreativeEffect) {
        amount=effect["amount"];filmStrength=effect["filmStrength"]
        exposure=effect["exposure"];contrast=effect["contrast"]
        saturation=effect["saturation"];highlightRollOff=effect["highlightRollOff"]
        shadowDensity=effect["shadowDensity"];colorResponse=effect["colorResponse"]
        style=effect["style"]
    }
    var validated: Self {
        var result=CreativeEffect(.filmEmulation)
        for (key,value) in [("amount",amount),("filmStrength",filmStrength),
                            ("exposure",exposure),("contrast",contrast),
                            ("saturation",saturation),("highlightRollOff",highlightRollOff),
                            ("shadowDensity",shadowDensity),("colorResponse",colorResponse),
                            ("style",style)] {result[key]=value}
        return Self(effect:result)
    }
}

/// Controls for content-gated, multi-scale optical diffusion in linear light.
/// Zero amount or zero glow is an exact identity.
struct GlamourGlowSettings: Codable, Sendable, Equatable {
    var amount = 50.0, glow = 45.0, softness = 40.0, warmth = 0.0
    var threshold = 40.0, highlightProtection = 55.0, shadowProtection = 70.0
    init() {}
    init(effect: CreativeEffect) {
        amount = effect["amount"]; glow = effect["glow"]
        softness = effect["softness"]; warmth = effect["warmth"]
        threshold = effect["threshold"]
        highlightProtection = effect["highlightProtection"]
        shadowProtection = effect["shadowProtection"]
    }
    var validated: Self {
        var effect = CreativeEffect(.glamourGlow)
        for (key, value) in [("amount", amount), ("glow", glow), ("softness", softness),
                             ("warmth", warmth), ("threshold", threshold),
                             ("highlightProtection", highlightProtection),
                             ("shadowProtection", shadowProtection)] { effect[key] = value }
        return Self(effect: effect)
    }
}

/// Amount -100...100 (zero is exact identity); band and protection controls
/// 0...100. A negative amount selectively softens existing spatial detail.
struct DetailExtractorSettings: Codable, Sendable, Equatable {
    var amount = 45.0, fine = 40.0, medium = 60.0, large = 20.0
    var protectShadows = 70.0, protectHighlights = 65.0
    init() {}
    init(effect: CreativeEffect) {
        amount = effect["amount"]; fine = effect["fine"]; medium = effect["medium"]; large = effect["large"]
        protectShadows = effect["protectShadows"]; protectHighlights = effect["protectHighlights"]
    }
    var validated: Self {
        var effect = CreativeEffect(.detailExtractor)
        for (key, value) in [("amount", amount), ("fine", fine), ("medium", medium),
                             ("large", large), ("protectShadows", protectShadows),
                             ("protectHighlights", protectHighlights)] { effect[key] = value }
        return Self(effect: effect)
    }
}

enum DetailExtractorProfile: String, CaseIterable, Identifiable {
    case subtleDetail = "Subtle Detail", fineTexture = "Fine Texture"
    case naturalDetail = "Natural Detail", architecture = "Architecture"
    case landscapeDetail = "Landscape Detail", extremeDetail = "Extreme Detail"
    var id: String { rawValue }
    func applying(to effect: CreativeEffect) -> CreativeEffect {
        var result = effect
        let values: [String: Double]
        switch self {
        case .subtleDetail: values = ["amount": 25, "fine": 30, "medium": 35, "large": 10]
        case .fineTexture: values = ["amount": 55, "fine": 85, "medium": 20, "large": 0]
        case .naturalDetail: values = ["amount": 50, "fine": 40, "medium": 65, "large": 20]
        case .architecture: values = ["amount": 65, "fine": 40, "medium": 75, "large": 50]
        case .landscapeDetail: values = ["amount": 65, "fine": 35, "medium": 75, "large": 40]
        case .extremeDetail: values = ["amount": 95, "fine": 90, "medium": 95, "large": 75]
        }
        for (key, value) in values { result[key] = value }
        return result
    }
}

/// Public, serializable view of the catalogue parameters. Amounts are -100...100,
/// global/radius/protection 0...100, saturation -100...100. Zero tonal amounts
/// or zero global amount are exact identities; radius and protection then have no effect.
struct TonalContrastSettings: Codable, Sendable, Equatable {
    var highlights = 25.0, midtones = 30.0, shadows = 20.0
    var globalAmount = 60.0, radius = 45.0, saturation = 0.0
    var protectHighlights = 50.0, protectShadows = 55.0
    init() {}
    init(effect: CreativeEffect) {
        highlights = effect["highlights"]; midtones = effect["midtones"]; shadows = effect["shadows"]
        globalAmount = effect["globalAmount"]; radius = effect["radius"]; saturation = effect["saturation"]
        protectHighlights = effect["protectHighlights"]; protectShadows = effect["protectShadows"]
    }
    var validated: Self {
        var effect = CreativeEffect(.tonalContrast)
        for (key, value) in [("highlights", highlights), ("midtones", midtones), ("shadows", shadows),
                             ("globalAmount", globalAmount), ("radius", radius), ("saturation", saturation),
                             ("protectHighlights", protectHighlights), ("protectShadows", protectShadows)] { effect[key] = value }
        return Self(effect: effect)
    }
}

enum TonalContrastProfile: String, CaseIterable, Identifiable {
    case subtleDetail = "Subtle Detail", naturalTexture = "Natural Texture"
    case landscapeDefinition = "Landscape Definition", softStructure = "Soft Structure"
    case strongStructure = "Strong Structure"
    var id: String { rawValue }
    func applying(to effect: CreativeEffect) -> CreativeEffect {
        var result = effect
        let settings: [String: Double]
        switch self {
        case .subtleDetail: settings = ["globalAmount": 40, "highlights": 12, "midtones": 18, "shadows": 10, "radius": 25]
        case .naturalTexture: settings = ["globalAmount": 60, "highlights": 22, "midtones": 32, "shadows": 18, "radius": 45]
        case .landscapeDefinition: settings = ["globalAmount": 75, "highlights": 38, "midtones": 42, "shadows": 28, "radius": 60]
        case .softStructure: settings = ["globalAmount": 55, "highlights": -22, "midtones": -30, "shadows": -18, "radius": 55]
        case .strongStructure: settings = ["globalAmount": 90, "highlights": 65, "midtones": 75, "shadows": 55, "radius": 70]
        }
        for (key, value) in settings { result[key] = value }
        return result
    }
}

/// Ordered instructions; maskID references an existing AdjustmentLayer, never a second mask model.
struct CreativeEffect: Codable, Sendable, Equatable, Identifiable {
    var id = UUID()
    var kind: CreativeEffectKind
    var enabled = true
    var opacity = 100.0
    var maskID: UUID?
    var parameters: [String: Double] = [:]
    var monochromatic = true
    var seed: UInt32 = 137

    init(_ kind: CreativeEffectKind, maskID: UUID? = nil) { self.kind = kind; self.maskID = maskID }
    private enum CodingKeys: String, CodingKey {
        case id, kind, enabled, opacity, maskID, parameters, monochromatic, seed
    }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        kind = try values.decode(CreativeEffectKind.self, forKey: .kind)
        id = try values.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        enabled = try values.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        opacity = try values.decodeIfPresent(Double.self, forKey: .opacity) ?? 100
        maskID = try values.decodeIfPresent(UUID.self, forKey: .maskID)
        parameters = try values.decodeIfPresent([String: Double].self, forKey: .parameters) ?? [:]
        monochromatic = try values.decodeIfPresent(Bool.self, forKey: .monochromatic) ?? true
        seed = try values.decodeIfPresent(UInt32.self, forKey: .seed) ?? 137
        self = validated
    }
    subscript(_ key: String) -> Double {
        get { parameters[key] ?? kind.descriptor.parameters.first { $0.id == key }?.defaultValue ?? 0 }
        set {
            guard let spec = kind.descriptor.parameters.first(where: { $0.id == key }) else { return }
            parameters[key] = newValue.isFinite ? min(spec.range.upperBound, max(spec.range.lowerBound, newValue)) : spec.defaultValue
        }
    }
    var validated: Self {
        var value = self
        value.opacity = opacity.isFinite ? min(100, max(0, opacity)) : 100
        value.parameters = [:]
        for spec in kind.descriptor.parameters { value[spec.id] = self[spec.id] }
        return value
    }
    mutating func reset() { parameters = [:]; opacity = 100; monochromatic = true; seed = 137 }
}

struct CreativeEffectStack: Codable, Sendable, Equatable {
    var effects: [CreativeEffect] = []
    var validated: Self {
        var seen = Set<UUID>()
        return Self(effects: effects.prefix(32).map { effect in
            var value = effect.validated
            if !seen.insert(value.id).inserted { value.id = UUID() }
            return value
        })
    }
    mutating func duplicate(_ id: UUID) {
        guard effects.count < 32, let index = effects.firstIndex(where: { $0.id == id }) else { return }
        var copy = effects[index]; copy.id = UUID()
        effects.insert(copy, at: index + 1)
    }
    mutating func move(_ id: UUID, by offset: Int) {
        guard let index = effects.firstIndex(where: { $0.id == id }) else { return }
        let target = min(effects.count - 1, max(0, index + offset))
        guard target != index else { return }
        effects.insert(effects.remove(at: index), at: target)
    }
}

/// Shared public grain settings for Creative, legacy Effects and future monochrome/film modules.
struct FilmGrainSettings: Sendable, Codable, Equatable {
    var amount = 35.0, size = 35.0, hardness = 45.0
    var irregularity = 50.0, clumping = 30.0, softness = 25.0
    var shadowAmount = 80.0, midtoneAmount = 100.0, highlightAmount = 45.0
    var monochromatic = true
    var chromaAmount = 15.0
    var seed: UInt32 = 137
    init() {}
    init(effect: CreativeEffect) {
        amount = effect["amount"]; size = effect["size"]; hardness = effect["hardness"]
        irregularity = effect["irregularity"]; clumping = effect["clumping"]; softness = effect["softness"]
        shadowAmount = effect["shadowAmount"]; midtoneAmount = effect["midtoneAmount"]; highlightAmount = effect["highlightAmount"]
        monochromatic = effect.monochromatic; chromaAmount = effect["chromaAmount"]; seed = effect.seed
    }
    var validated: Self {
        var effect = CreativeEffect(.grain)
        for (key, value) in [("amount", amount), ("size", size), ("hardness", hardness),
                             ("irregularity", irregularity), ("clumping", clumping), ("softness", softness),
                             ("shadowAmount", shadowAmount), ("midtoneAmount", midtoneAmount),
                             ("highlightAmount", highlightAmount), ("chromaAmount", chromaAmount)] { effect[key] = value }
        effect.monochromatic = monochromatic; effect.seed = seed
        return Self(effect: effect)
    }
}

enum FilmGrainProfile: String, CaseIterable, Identifiable {
    case fine50 = "Fine 50", classic100 = "Classic 100", classic400 = "Classic 400"
    case reportage800 = "Documentary 800", push1600 = "Push 1600", rough3200 = "Rough 3200"
    var id: String { rawValue }
    func applying(to effect: CreativeEffect) -> CreativeEffect {
        var value = effect
        let index = Double(Self.allCases.firstIndex(of: self)!)
        value["size"] = 12 + index * 15; value["hardness"] = 25 + index * 11
        value["irregularity"] = 25 + index * 12; value["clumping"] = 10 + index * 14
        value["softness"] = 35 - index * 5
        value["shadowAmount"] = 65 + index * 10; value["midtoneAmount"] = 100
        value["highlightAmount"] = 25 + index * 8
        return value
    }
}

/// Built-in Creative presets are complete parameter snapshots. Applying one to an
/// existing effect keeps its identity, mask, opacity and position in the stack.
struct CreativeFXPreset: Identifiable {
    let kind: CreativeEffectKind
    let title: String
    let parameters: [String: Double]
    let monochromatic: Bool
    var id: String { "\(kind.rawValue):\(title)" }

    func applying(to effect: CreativeEffect) -> CreativeEffect {
        guard effect.kind == kind else { return effect }
        var result = effect
        result.parameters = parameters
        result.monochromatic = monochromatic
        return result.validated
    }

    func makeEffect(maskID: UUID? = nil) -> CreativeEffect {
        applying(to: CreativeEffect(kind, maskID: maskID))
    }

    func matches(_ effect: CreativeEffect) -> Bool {
        guard effect.kind == kind else { return false }
        let candidate = effect.validated
        return candidate.monochromatic == monochromatic &&
            kind.descriptor.parameters.allSatisfy { spec in
                abs(candidate[spec.id] - (parameters[spec.id] ?? spec.defaultValue)) <= 0.000001
            }
    }

    static func matching(_ effect: CreativeEffect) -> Self? {
        all(for: effect.kind).first { $0.matches(effect) }
    }

    static func all(for kind: CreativeEffectKind) -> [Self] {
        func snapshot(_ title: String, _ configure: (CreativeEffect) -> CreativeEffect) -> Self {
            let effect = configure(CreativeEffect(kind)).validated
            return Self(kind: kind, title: title, parameters: effect.parameters,
                        monochromatic: effect.monochromatic)
        }
        func values(_ title: String, _ settings: [String: Double]) -> Self {
            snapshot(title) { initial in
                var effect = initial
                for (key, value) in settings { effect[key] = value }
                return effect
            }
        }
        switch kind {
        case .highKey:
            return [
                values("Soft High Key", ["amount": 30, "dynamic": 0]),
                values("Dynamic High Key", ["amount": 55, "dynamic": 65]),
                values("Protected highlights", ["amount": 70, "dynamic": 50, "lightProtection": 100]),
                values("Bright High Key", ["amount": 55, "dynamic": 45, "glow": 30])
            ]
        case .lowKey:
            return [
                values("Soft Low Key", ["amount": 30, "dynamic": 0]),
                values("Dynamic Low Key", ["amount": 55, "dynamic": 65]),
                values("Deep blacks", ["amount": 75, "dynamic": 30, "darkProtection": 30]),
                values("Protected shadows", ["amount": 70, "dynamic": 60, "darkProtection": 100]),
                values("Bright Low Key", ["amount": 55, "dynamic": 45, "glow": 25])
            ]
        case .grain:
            return FilmGrainProfile.allCases.map { profile in
                snapshot(profile.rawValue) { profile.applying(to: $0) }
            }
        case .tonalContrast:
            return TonalContrastProfile.allCases.map { profile in
                snapshot(profile.rawValue) { profile.applying(to: $0) }
            }
        case .detailExtractor:
            return DetailExtractorProfile.allCases.map { profile in
                snapshot(profile.rawValue) { profile.applying(to: $0) }
            }
        case .glamourGlow:
            return [
                values("Subtle Glow", ["amount": 28, "glow": 28, "softness": 28]),
                values("Portrait Glow", ["amount": 48, "glow": 42, "softness": 42, "shadowProtection": 85]),
                values("Warm Glow", ["amount": 52, "glow": 48, "softness": 48, "warmth": 40]),
                values("Cool Glow", ["amount": 52, "glow": 48, "softness": 48, "warmth": -40]),
                values("Dreamy", ["amount": 72, "glow": 68, "softness": 76, "threshold": 28]),
                values("Strong Glow", ["amount": 88, "glow": 86, "softness": 65, "threshold": 30,
                                        "highlightProtection": 70])
            ]
        case .bleachBypass:
            return [
                values("Subtle Bypass", ["amount": 32, "bleach": 32, "contrast": 35, "blackDensity": 25,
                                          "highlightRollOff": 50, "shadowProtection": 65]),
                values("Classic Bypass", ["amount": 65, "bleach": 60, "contrast": 60, "blackDensity": 55,
                                           "highlightRollOff": 60, "shadowProtection": 40]),
                values("Soft Silver", ["amount": 55, "bleach": 72, "contrast": 35, "blackDensity": 35,
                                       "highlightRollOff": 75, "shadowProtection": 75]),
                values("Hard Silver", ["amount": 78, "bleach": 82, "contrast": 85, "blackDensity": 80,
                                       "highlightRollOff": 65, "shadowProtection": 22]),
                values("Cinematic", ["amount": 68, "bleach": 55, "contrast": 70, "saturation": 12,
                                     "blackDensity": 65, "highlightRollOff": 78, "shadowProtection": 45]),
                values("Extreme Bypass", ["amount": 95, "bleach": 95, "contrast": 95,
                                          "blackDensity": 90, "highlightRollOff": 85, "shadowProtection": 15])
            ]
        case .proContrast:
            return [
                values("Subtle Correction", ["amount": 35, "correctColorCast": 20,
                                             "correctContrast": 35, "dynamicContrast": 15]),
                values("Natural Contrast", ["amount": 60, "correctColorCast": 25,
                                            "correctContrast": 60, "dynamicContrast": 35]),
                values("Flat Recovery", ["amount": 75, "correctColorCast": 20,
                                        "correctContrast": 90, "dynamicContrast": 65]),
                values("Punch", ["amount": 85, "correctColorCast": 10,
                                "correctContrast": 85, "dynamicContrast": 80,
                                "shadowProtection": 40, "highlightProtection": 45]),
                values("Color Neutralize", ["amount": 65, "correctColorCast": 95,
                                           "correctContrast": 25, "dynamicContrast": 10]),
                values("Strong Correction", ["amount": 95, "correctColorCast": 50,
                                            "correctContrast": 95, "dynamicContrast": 80,
                                            "shadowProtection": 45, "highlightProtection": 50])
            ]
        case .crossProcessing:
            return [
                values("Subtle Cross", ["style": 0, "amount": 55, "styleStrength": 42, "contrast": 8,
                                        "shadowHue": 205, "shadowStrength": 12, "highlightHue": 32, "highlightStrength": 10]),
                values("Warm Process", ["style": 1, "amount": 75, "styleStrength": 78, "contrast": 18,
                                        "shadowHue": 205, "shadowStrength": 12, "highlightHue": 32, "highlightStrength": 30]),
                values("Cool Process", ["style": 2, "amount": 75, "styleStrength": 78, "contrast": 18,
                                        "shadowHue": 225, "shadowStrength": 25, "highlightHue": 188, "highlightStrength": 18]),
                values("Cyan Shadows", ["style": 3, "amount": 78, "styleStrength": 85, "contrast": 22,
                                        "shadowHue": 190, "shadowStrength": 55, "highlightHue": 36, "highlightStrength": 13]),
                values("Green-Magenta", ["style": 4, "amount": 80, "styleStrength": 86, "contrast": 24,
                                         "shadowHue": 135, "shadowStrength": 43, "highlightHue": 310, "highlightStrength": 38]),
                values("Vintage Process", ["style": 5, "amount": 70, "styleStrength": 72, "contrast": 5,
                                           "saturation": -12, "shadowHue": 180, "shadowStrength": 15,
                                           "highlightHue": 40, "highlightStrength": 21, "blackLift": 18]),
                values("Strong Cross", ["style": 6, "amount": 90, "styleStrength": 100, "contrast": 40,
                                       "saturation": 12, "shadowHue": 190, "shadowStrength": 65,
                                       "highlightHue": 25, "highlightStrength": 55, "blackLift": 7])
            ]
        case .darkenLightenCenter:
            return [
                values("Subtle Focus", ["centerEV":0.12,"borderEV":-0.18,"size":70,"feather":100]),
                values("Portrait Focus", ["centerEV":0.30,"borderEV":-0.45,"size":48,"shape":-30,"feather":85]),
                values("Dark Surround", ["centerEV":0,"borderEV":-0.85,"size":60,"feather":90]),
                values("Light Center", ["centerEV":0.55,"borderEV":0,"size":48,"feather":90]),
                values("Wide Focus", ["centerEV":0.18,"borderEV":-0.30,"size":75,"shape":45,"feather":100]),
                values("Narrow Focus", ["centerEV":0.45,"borderEV":-0.55,"size":30,"shape":-25,"feather":90]),
                values("Off-Center Drama", ["centerX":0.32,"centerY":0.38,"centerEV":0.40,"borderEV":-0.80,"size":55,"shape":-20,"rotation":-20,"feather":90]),
                values("Reverse Focus", ["centerEV":-0.40,"borderEV":0.25,"size":55,"feather":90])
            ]
        case .silverToning:
            return [
                values("Neutral Print", [:]),
                values("Subtle Selenium", ["toner":1,"strength":28]),
                values("Deep Selenium", ["toner":1,"strength":90,"balance":20]),
                values("Classic Sepia", ["toner":2,"strength":75,"paperTone":40]),
                values("Soft Sepia", ["toner":2,"strength":32,"paperTone":25,"balance":20]),
                values("Copper Print", ["toner":3,"strength":78,"balance":10,"paperTone":12]),
                values("Cool Gold", ["toner":4,"strength":80,"paperTone":-15]),
                values("Platinum Print", ["toner":5,"strength":45,"paperTone":8]),
                values("Warm Silver", ["toner":7,"strength":65,"paperTone":20]),
                values("Cool Silver", ["toner":6,"strength":65,"paperTone":-8]),
                values("Split Warm/Cool", ["toner":8,"strength":65,"shadowHue":220,"highlightHue":40,"paperTone":15])
            ]
        case .silverBW:
            return [
                values("Neutral Silver", [:]),
                values("Soft Portrait", ["filmResponse":2,"brightness":8,"softContrast":28,"structure":8,"filterHue":35,"filterStrength":12]),
                values("Fine Art", ["filmResponse":1,"contrast":28,"blacks":25,"whites":-18,"structure":20,"filterHue":45,"filterStrength":28]),
                values("Classic Film", ["filmResponse":3,"contrast":12,"structure":18,"filterHue":60,"filterStrength":18]),
                values("High Structure", ["filmResponse":6,"structure":80,"contrast":18,"dynamicBrightness":12]),
                values("Dark Drama", ["filmResponse":4,"brightness":-12,"blacks":42,"whites":-20,"filterHue":0,"filterStrength":42,"structure":35]),
                values("Soft Silver", ["filmResponse":5,"softContrast":55,"contrast":-18,"blacks":-20,"brightness":7]),
                values("Hard Documentary", ["filmResponse":6,"contrast":48,"blacks":38,"structure":65,"filterHue":120,"filterStrength":20])
            ]
        case .filmEmulation:
            return [
                values("Neutral Negative", ["style":0,"amount":75,"filmStrength":78,"colorResponse":55]),
                values("Warm Portrait", ["style":1,"amount":75,"filmStrength":82,"colorResponse":72]),
                values("Vivid Chrome", ["style":2,"amount":80,"filmStrength":90,"colorResponse":85]),
                values("Muted Cinema", ["style":3,"amount":78,"filmStrength":84,"colorResponse":70]),
                values("Faded Negative", ["style":4,"amount":77,"filmStrength":90,"colorResponse":68]),
                values("Vintage Color", ["style":5,"amount":82,"filmStrength":88,"colorResponse":88]),
                values("Dense Slide", ["style":6,"amount":85,"filmStrength":95,"colorResponse":82,
                                       "shadowDensity":-80,"contrast":-10,"highlightRollOff":85,"saturation":-12])
            ]
        }
    }
}
