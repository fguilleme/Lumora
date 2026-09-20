import SwiftUI

struct ColorToolsView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case mixer = "Mélangeur"
        case grading = "Grading"
        var id: String { rawValue }
    }

    let mixer: ColorMixer
    let grading: ColorGrading
    let onBegin: (String) -> Void
    let onMixerChange: (MixerChannel, MixerAdjustment) -> Void
    let onGradingChange: (ColorGrading) -> Void
    let onEnd: () -> Void
    @State private var mode = Mode.mixer

    var body: some View {
        VStack(spacing: 6) {
            Picker("Outil couleur", selection: $mode) {
                ForEach(Mode.allCases) { mode in Text(mode.rawValue).tag(mode) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 14)
            .accessibilityIdentifier("color-tools-tabs")
            .onChange(of: mode) { _, _ in onEnd() }
            .dimsDuringAdjustment()

            ScrollView {
                if mode == .mixer {
                    ColorMixerView(mixer: mixer, onBegin: onBegin,
                                   onChange: onMixerChange, onEnd: onEnd)
                } else {
                    ColorGradingView(grading: grading, onBegin: onBegin,
                                     onChange: onGradingChange, onEnd: onEnd)
                }
            }
            .accessibilityIdentifier(mode == .mixer ? "mixer-controls" : "grading-controls")
        }
        .accessibilityIdentifier("color-tools-controls")
        .onDisappear(perform: onEnd)
    }
}
