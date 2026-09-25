import Foundation

/// A document value: no detected landmarks or generated mattes are persisted.
struct BeautyState: Codable, Sendable, Equatable {
    static let version = 1
    var version = Self.version
    var amount: Double = 100
    var uniformity: Double = 0
    var texture: Double = 0
    var blemishes: Double = 0
    var darkCircles: Double = 0
    var eyeBrightness: Double = 0
    var eyeDetail: Double = 0
    var teeth: Double = 0

    var isIdentity: Bool {
        amount == 0 || (uniformity == 0 && texture == 0 && blemishes == 0 &&
                        darkCircles == 0 && eyeBrightness == 0 && eyeDetail == 0 && teeth == 0)
    }

    var validated: Self {
        var value = self
        value.version = Self.version
        for control in BeautyControl.allCases { value[control] = self[control] }
        return value
    }

    subscript(_ control: BeautyControl) -> Double {
        get {
            switch control {
            case .amount: amount
            case .uniformity: uniformity
            case .texture: texture
            case .blemishes: blemishes
            case .darkCircles: darkCircles
            case .eyeBrightness: eyeBrightness
            case .eyeDetail: eyeDetail
            case .teeth: teeth
            }
        }
        set {
            let range = control == .texture ? -100.0...100.0 : 0.0...100.0
            let value = newValue.isFinite ? min(range.upperBound, max(range.lowerBound, newValue)) : 0
            switch control {
            case .amount: amount = value
            case .uniformity: uniformity = value
            case .texture: texture = value
            case .blemishes: blemishes = value
            case .darkCircles: darkCircles = value
            case .eyeBrightness: eyeBrightness = value
            case .eyeDetail: eyeDetail = value
            case .teeth: teeth = value
            }
        }
    }
}

enum BeautyControl: String, CaseIterable, Sendable, Identifiable {
    case amount, uniformity, texture, blemishes, darkCircles, eyeBrightness, eyeDetail, teeth
    var id: String { rawValue }
    var range: ClosedRange<Double> { self == .texture ? -100...100 : 0...100 }
    var title: String {
        switch self {
        case .amount: String(localized: "Beauty Amount")
        case .uniformity: String(localized: "Uniformity")
        case .texture: String(localized: "Texture")
        case .blemishes: String(localized: "Blemishes")
        case .darkCircles: String(localized: "Dark Circles")
        case .eyeBrightness: String(localized: "Eye Brightness")
        case .eyeDetail: String(localized: "Eye Detail")
        case .teeth: String(localized: "Teeth")
        }
    }
}

enum BeautyPreset: String, CaseIterable, Sendable, Identifiable {
    case natural, portrait, beauty
    var id: String { rawValue }
    var title: String {
        switch self {
        case .natural: String(localized: "Natural")
        case .portrait: String(localized: "Portrait")
        case .beauty: String(localized: "Beauty")
        }
    }
    var settings: BeautyState {
        var state = BeautyState()
        switch self {
        case .natural:
            state.uniformity = 12; state.texture = -4; state.blemishes = 10
            state.darkCircles = 8; state.eyeBrightness = 7; state.eyeDetail = 5; state.teeth = 6
        case .portrait:
            state.uniformity = 42; state.texture = -8; state.blemishes = 44
            state.darkCircles = 40; state.eyeBrightness = 25; state.eyeDetail = 16; state.teeth = 18
        case .beauty:
            state.uniformity = 70; state.texture = -15; state.blemishes = 70
            state.darkCircles = 65; state.eyeBrightness = 42; state.eyeDetail = 28; state.teeth = 32
        }
        return state
    }

    static func matching(_ state: BeautyState) -> Self? {
        allCases.first { $0.settings == state.validated }
    }
}
