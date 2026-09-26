import Foundation
import Testing
@testable import LumoraCore

@Test func hslRoundTripsRGBAndPreservesNeutralAxis() {
    var mixer = ColorMixer()
    for channel in MixerChannel.allCases { mixer[channel] = MixerAdjustment(hue: 80, saturation: -60, luminance: 75) }
    for r in 0...10 {
        for g in 0...10 {
            for b in 0...10 {
                let red = Double(r) / 10, green = Double(g) / 10, blue = Double(b) / 10
                let output = HSLColor(red: red, green: green, blue: blue).rgb
                #expect(abs(output.0 - red) < 1e-10 && abs(output.1 - green) < 1e-10 && abs(output.2 - blue) < 1e-10)
            }
        }
        let gray = Double(r) / 10
        let output = HSLMixer.apply(gray, gray, gray, mixer: mixer)
        #expect(output.0 == gray && output.1 == gray && output.2 == gray)
    }
}

@Test func mixerCentersTargetOnlyTheSelectedBand() {
    for channel in MixerChannel.allCases {
        let weights = HSLMixer.weights(hue: channel.center)
        #expect(weights.lower == channel && weights.upperWeight == 0)
        var mixer = ColorMixer()
        mixer[channel] = MixerAdjustment(saturation: -100)
        for other in MixerChannel.allCases {
            let input = HSLColor(hue: other.center, saturation: 1, lightness: 0.5).rgb
            let output = HSLMixer.apply(input.0, input.1, input.2, mixer: mixer)
            if channel == other {
                #expect(abs(output.0 - 0.5) < 1e-9 && abs(output.1 - 0.5) < 1e-9 && abs(output.2 - 0.5) < 1e-9)
            } else {
                #expect(abs(output.0 - input.0) < 1e-9 && abs(output.1 - input.1) < 1e-9 && abs(output.2 - input.2) < 1e-9)
            }
        }
    }
}

@Test func mixerTransitionsAreSmoothAndCyclic() {
    var mixer = ColorMixer()
    for (index, channel) in MixerChannel.allCases.enumerated() {
        mixer[channel] = MixerAdjustment(hue: index.isMultiple(of: 2) ? 100 : -100,
                                         saturation: index.isMultiple(of: 2) ? -90 : 70,
                                         luminance: index.isMultiple(of: 2) ? -70 : 90)
    }
    func sample(_ hue: Double) -> (Double, Double, Double) {
        let input = HSLColor(hue: hue, saturation: 0.8, lightness: 0.5).rgb
        return HSLMixer.apply(input.0, input.1, input.2, mixer: mixer)
    }
    for channel in MixerChannel.allCases {
        let before = sample(channel.center - 0.0001), after = sample(channel.center + 0.0001)
        #expect(abs(before.0 - after.0) < 0.0001)
        #expect(abs(before.1 - after.1) < 0.0001)
        #expect(abs(before.2 - after.2) < 0.0001)
    }
    for hue in stride(from: -360.0, through: 720, by: 0.5) {
        let weights = HSLMixer.weights(hue: hue)
        #expect((0...1).contains(weights.upperWeight))
    }
    let negative = sample(-1), positive = sample(359)
    #expect(abs(negative.0 - positive.0) < 1e-10)
    #expect(abs(negative.1 - positive.1) < 1e-10)
    #expect(abs(negative.2 - positive.2) < 1e-10)
}

@Test func hslControlsHaveIndependentNumericalEffects() {
    var mixer = ColorMixer()
    mixer[.red] = MixerAdjustment(hue: 100)
    var result = HSLMixer.apply(1, 0, 0, mixer: mixer)
    #expect(abs(result.0 - 1) < 1e-9 && abs(result.1 - 0.5) < 1e-9 && result.2 == 0)
    mixer[.red] = MixerAdjustment(luminance: -100)
    result = HSLMixer.apply(1, 0, 0, mixer: mixer)
    #expect(abs(result.0 - 0.5) < 1e-9 && result.1 == 0 && result.2 == 0)
    mixer[.red] = MixerAdjustment(luminance: 100)
    result = HSLMixer.apply(1, 0, 0, mixer: mixer)
    #expect(abs(result.0 - 1) < 1e-9 && abs(result.1 - 0.5) < 1e-9 && abs(result.2 - 0.5) < 1e-9)
}

@Test func extremeMixerOutputStaysFiniteAndInGamut() {
    for sign in [-1.0, 1.0] {
        var mixer = ColorMixer()
        for channel in MixerChannel.allCases { mixer[channel] = MixerAdjustment(hue: 100 * sign, saturation: 100 * sign, luminance: 100 * sign) }
        for hue in stride(from: 0.0, to: 360, by: 3) {
            for lightness in [0.0, 0.01, 0.25, 0.5, 0.75, 0.99, 1] {
                let input = HSLColor(hue: hue, saturation: 0.8, lightness: lightness).rgb
                let output = HSLMixer.apply(input.0, input.1, input.2, mixer: mixer)
                for value in [output.0, output.1, output.2] {
                    #expect(value.isFinite && value >= -1e-12 && value <= 1 + 1e-12)
                }
            }
        }
    }
}

@Test func mixerSerializationMigrationAndRangeValidation() throws {
    let legacy = try JSONDecoder().decode(EditState.self, from: Data(#"{"exposure":0.7}"#.utf8))
    #expect(legacy.colorMixer.isIdentity && legacy.exposure == 0.7)
    let data = Data(#"{"blue":{"hue":999,"saturation":-999,"luminance":42}}"#.utf8)
    let mixer = try JSONDecoder().decode(ColorMixer.self, from: data)
    #expect(mixer[.blue] == MixerAdjustment(hue: 100, saturation: -100, luminance: 42))
    #expect(mixer[.red] == MixerAdjustment())
    var state = legacy; state.colorMixer = mixer
    #expect(try JSONDecoder().decode(EditState.self, from: JSONEncoder().encode(state)) == state)
    var invalid = MixerAdjustment(); invalid[.hue] = .infinity
    #expect(invalid.hue == 0)
}

@Test func mixerHistoryGroupsChangesAndRestoresOtherAdjustments() {
    var state = EditState(), history = HistoryManager()
    state.exposure = 1.1
    state.curves.rgb.add(x: 0.5, y: 0.7)
    let before = state
    history.begin("Vert saturation", state: state)
    for i in 1...100 { state.colorMixer[.green] = MixerAdjustment(saturation: Double(-i)) }
    history.commit(state)
    #expect(history.undoStack.count == 1)
    #expect(history.undo() == before)
    #expect(history.redo() == state)
}
