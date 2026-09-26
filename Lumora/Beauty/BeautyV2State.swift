import Foundation

/// Additive portrait-finishing values. Absent from V1 documents and presets.
struct BeautyV2Settings: Codable, Sendable, Equatable {
    // Legacy value retained for decoding; no production effect or control.
    var lipColor = 0.0
    var lipSaturation = 0.0
    var lipBrightness = 0.0
    var lipDetail = 0.0
    var skinShine = 0.0
    var faceBalance = 0.0
    // Retained for experimental-document compatibility; ignored by production.
    var hairLight = 0.0
    var hairShine = 0.0
    var hairDetail = 0.0

    var isIdentity: Bool { BeautyV2Control.productionCases.allSatisfy { self[$0] == 0 } }

    var hasStoredValues: Bool { BeautyV2Control.allCases.contains { self[$0] != 0 } }

    init() {}
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: BeautyV2Control.self)
        for control in BeautyV2Control.allCases {
            self[control] = try values.decodeIfPresent(Double.self, forKey: control) ?? 0
        }
    }

    var validated: Self {
        var result = self
        for control in BeautyV2Control.allCases { result[control] = self[control] }
        return result
    }

    subscript(_ control: BeautyV2Control) -> Double {
        get {
            switch control {
            case .lipColor: lipColor
            case .lipSaturation: lipSaturation
            case .lipBrightness: lipBrightness
            case .lipDetail: lipDetail
            case .skinShine: skinShine
            case .faceBalance: faceBalance
            case .hairLight: hairLight
            case .hairShine: hairShine
            case .hairDetail: hairDetail
            }
        }
        set {
            let number = newValue.isFinite ? newValue : 0
            let clamped = min(control.range.upperBound, max(control.range.lowerBound, number))
            switch control {
            case .lipColor: lipColor = clamped
            case .lipSaturation: lipSaturation = clamped
            case .lipBrightness: lipBrightness = clamped
            case .lipDetail: lipDetail = clamped
            case .skinShine: skinShine = clamped
            case .faceBalance: faceBalance = clamped
            case .hairLight: hairLight = clamped
            case .hairShine: hairShine = clamped
            case .hairDetail: hairDetail = clamped
            }
        }
    }
}

enum BeautyV2Control: String, Codable, CaseIterable, Sendable, Identifiable, CodingKey {
    case lipColor, lipSaturation, lipBrightness, lipDetail
    case skinShine, faceBalance, hairLight, hairShine, hairDetail
    static let productionCases: [Self] = [.lipSaturation, .lipBrightness,
        .lipDetail, .skinShine, .faceBalance]
    var id: String { rawValue }
    var range: ClosedRange<Double> {
        switch self {
        case .skinShine, .hairShine: 0...100
        default: -100...100
        }
    }
    var title: String {
        switch self {
        case .lipColor: String(localized: "Lip Color")
        case .lipSaturation: String(localized: "Lip Saturation")
        case .lipBrightness: String(localized: "Lip Brightness")
        case .lipDetail: String(localized: "Lip Detail")
        case .skinShine: String(localized: "Skin Shine")
        case .faceBalance: String(localized: "Face Balance")
        case .hairLight: String(localized: "Hair Light")
        case .hairShine: String(localized: "Hair Shine")
        case .hairDetail: String(localized: "Hair Detail")
        }
    }
}
