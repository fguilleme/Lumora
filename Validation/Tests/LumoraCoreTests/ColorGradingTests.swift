import Testing
import Foundation
@testable import LumoraCore

@Test func gradingWeightsAreNormalizedAndTargetTonality() {
    for blending in [0.0, 50, 100] {
        for balance in [-100.0, 0, 100] {
            for i in 0...1000 {
                let w = GradingTransform.weights(luminance: Double(i) / 1000, blending: blending, balance: balance)
                #expect(abs(w.x + w.y + w.z - 1) < 1e-10)
                #expect(w.x >= 0 && w.y >= 0 && w.z >= 0)
            }
        }
    }
    #expect(GradingTransform.weights(luminance: 0.1, blending: 0, balance: 0).x == 1)
    #expect(GradingTransform.weights(luminance: 0.5, blending: 0, balance: 0).y == 1)
    #expect(GradingTransform.weights(luminance: 0.9, blending: 0, balance: 0).z == 1)
    let positive = GradingTransform.weights(luminance: 0.5, blending: 50, balance: 100)
    let negative = GradingTransform.weights(luminance: 0.5, blending: 50, balance: -100)
    #expect(positive.z > negative.z && positive.x < negative.x)
    #expect(GradingTransform.weights(luminance: 0.5, blending: 100, balance: 0).x > 0)
}

@Test func neutralGradingIsIdentityAndTintPreservesLuma() {
    let identity = GradingTransform(ColorGrading())
    for i in 0...100 {
        let r = Double(i) / 100, g = 0.3, b = 0.7
        let output = identity.apply(r, g, b)
        #expect(output.0 == r && output.1 == g && output.2 == b)
    }
    var settings = ColorGrading()
    settings.midtones = GradingWheel(hue: 240, saturation: 100)
    let transform = GradingTransform(settings)
    let tinted = transform.apply(0.5, 0.5, 0.5)
    #expect(tinted.2 > tinted.0 && tinted.2 > tinted.1)
    #expect(abs(tinted.0 * 0.2126 + tinted.1 * 0.7152 + tinted.2 * 0.0722 - 0.5) < 1e-10)
    let black = transform.apply(0, 0, 0), white = transform.apply(1, 1, 1)
    #expect(black.0 == 0 && black.1 == 0 && black.2 == 0)
    #expect(white.0 == 1 && white.1 == 1 && white.2 == 1)
}

@Test func gradingTargetsShadowsAndLuminanceIndependently() {
    var settings = ColorGrading(); settings.blending = 0
    settings.shadows = GradingWheel(hue: 0, saturation: 100)
    var transform = GradingTransform(settings)
    let dark = transform.apply(0.1, 0.1, 0.1), bright = transform.apply(0.9, 0.9, 0.9)
    #expect(dark.0 > dark.1 && dark.0 > dark.2)
    #expect(bright.0 == 0.9 && bright.1 == 0.9 && bright.2 == 0.9)
    settings.shadows = GradingWheel(luminance: 100)
    transform = GradingTransform(settings)
    let lifted = transform.apply(0.1, 0.1, 0.1)
    #expect(lifted.0 > 0.1 && lifted.0 == lifted.1 && lifted.1 == lifted.2)
}

@Test func gradingGamutCompressionIsBounded() {
    var settings = ColorGrading()
    settings.shadows = GradingWheel(hue: 180, saturation: 100, luminance: -100)
    settings.midtones = GradingWheel(hue: 300, saturation: 100, luminance: 100)
    settings.highlights = GradingWheel(hue: 60, saturation: 100, luminance: 100)
    let transform = GradingTransform(settings)
    for r in 0...8 { for g in 0...8 { for b in 0...8 {
        let output = transform.apply(Double(r) / 8, Double(g) / 8, Double(b) / 8)
        for value in [output.0, output.1, output.2] { #expect(value.isFinite && value >= -1e-10 && value <= 1 + 1e-10) }
    } } }
}

@Test func wheelCoordinatesRoundTripAndClamp() {
    for hue in stride(from: 0.0, to: 360, by: 10) {
        let position = ColorWheelCoordinates.position(hue: hue, saturation: 70)
        let result = ColorWheelCoordinates.value(x: position.x, y: position.y, previousHue: 0)
        #expect(abs(result.hue - hue) < 1e-9)
        #expect(abs(result.saturation - 70) < 1e-9)
    }
    #expect(ColorWheelCoordinates.value(x: 0, y: 0, previousHue: 240).hue == 240)
    #expect(ColorWheelCoordinates.value(x: 4, y: 3, previousHue: 0).saturation == 100)
}

@Test func gradingMigrationValidationAndHistory() throws {
    var state = try JSONDecoder().decode(EditState.self, from: Data(#"{"exposure":1}"#.utf8))
    #expect(state.colorGrading.isIdentity && state.colorGrading.blending == 50)
    let before = state
    var history = HistoryManager(); history.begin("Roue", state: state)
    for i in 0...100 { state.colorGrading.shadows = GradingWheel(hue: 210, saturation: Double(i)) }
    history.commit(state)
    #expect(history.undoStack.count == 1)
    #expect(history.undo() == before)
    #expect(history.redo() == state)
    #expect(try JSONDecoder().decode(EditState.self, from: JSONEncoder().encode(state)) == state)
    let decoded = try JSONDecoder().decode(ColorGrading.self, from: Data(#"{"balance":1000,"blending":-8,"shadows":{"hue":-30,"saturation":150}}"#.utf8))
    #expect(decoded.balance == 100 && decoded.blending == 0)
    #expect(decoded.shadows.hue == 330 && decoded.shadows.saturation == 100)
}
