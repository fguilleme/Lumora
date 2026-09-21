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
    case highKey, lowKey, grain, tonalContrast, detailExtractor
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
        .tonalContrast: .init(title: "Tonal Contrast", category: "Detail", symbol: "circle.hexagongrid", parameters: [
            .init("globalAmount", "Global", 0...100, 60),
            .init("highlights", "Hautes lumières", -100...100, 25),
            .init("midtones", "Tons moyens", -100...100, 30),
            .init("shadows", "Ombres", -100...100, 20),
            // Radius is mapped logarithmically to 1.2...24 photographic px on a 3000 px long edge.
            .init("radius", "Rayon", 0...100, 45),
            .init("saturation", "Saturation", -100...100),
            .init("protectHighlights", "Protéger les hautes lumières", 0...100, 50),
            .init("protectShadows", "Protéger les ombres", 0...100, 55)
        ]),
        .detailExtractor: .init(title: "Detail Extractor", category: "Detail", symbol: "viewfinder", parameters: [
            .init("amount", "Quantité", -100...100, 45),
            .init("fine", "Détails fins", 0...100, 40),
            .init("medium", "Détails moyens", 0...100, 60),
            .init("large", "Grands détails", 0...100, 20),
            .init("protectShadows", "Protéger les ombres", 0...100, 70),
            .init("protectHighlights", "Protéger les hautes lumières", 0...100, 65)
        ]),
        .grain: .init(title: "Grain", category: "Film", symbol: "camera.filters", parameters: [
            .init("amount", "Quantité", 0...100, 35), .init("size", "Taille", 1...100, 35),
            .init("hardness", "Dureté", 0...100, 45), .init("irregularity", "Irrégularité", 0...100, 50),
            .init("clumping", "Agrégation", 0...100, 30), .init("softness", "Douceur", 0...100, 25),
            .init("shadowAmount", "Ombres", 0...200, 80), .init("midtoneAmount", "Tons moyens", 0...200, 100),
            .init("highlightAmount", "Hautes lumières", 0...200, 45),
            .init("chromaAmount", "Grain couleur", 0...100, 15)
        ])
    ]
    private static func keyParameters(high: Bool) -> [FXParameter] {
        [.init("amount", "Quantité", 0...100, 50), .init("dynamic", "Dynamique", 0...100, 50),
         .init("glow", "Glow"), .init("glowRadius", "Rayon glow", 1...100, 30),
         .init("glowThreshold", "Seuil glow", 0...100, 70), .init("contrast", "Contraste", -100...100),
         .init("saturation", "Saturation", -100...100),
         .init("darkProtection", high ? "Préserver noirs" : "Protéger ombres", 0...100, 65),
         .init("lightProtection", high ? "Protéger blancs" : "Préserver lumières", 0...100, 70)]
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
    case reportage800 = "Reportage 800", push1600 = "Push 1600", rough3200 = "Rough 3200"
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
                values("High Key doux", ["amount": 30, "dynamic": 0]),
                values("High Key dynamique", ["amount": 55, "dynamic": 65]),
                values("Lumières protégées", ["amount": 70, "dynamic": 50, "lightProtection": 100]),
                values("High Key lumineux", ["amount": 55, "dynamic": 45, "glow": 30])
            ]
        case .lowKey:
            return [
                values("Low Key doux", ["amount": 30, "dynamic": 0]),
                values("Low Key dynamique", ["amount": 55, "dynamic": 65]),
                values("Noirs profonds", ["amount": 75, "dynamic": 30, "darkProtection": 30]),
                values("Ombres protégées", ["amount": 70, "dynamic": 60, "darkProtection": 100]),
                values("Low Key lumineux", ["amount": 55, "dynamic": 45, "glow": 25])
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
        }
    }
}
