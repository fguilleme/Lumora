import SwiftUI

struct ColorGradingView: View {
    let grading: ColorGrading
    let onBegin: (String) -> Void
    let onChange: (ColorGrading) -> Void
    let onEnd: () -> Void
    @State private var selected: GradingRange = .shadows
    @State private var selectedID = "luminance"

    var body: some View {
        VStack(spacing: 6) {
            GradingPresetSelector(grading: grading) { preset in
                onEnd(); onBegin("Grading · " + preset.title); onChange(preset.settings); onEnd()
            }
            Picker("Tonal range", selection: $selected) {
                ForEach(GradingRange.allCases) { range in
                    Text(range.title).tag(range)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("grading-range-picker")
            .onChange(of: selected) { _, _ in onEnd() }
            .dimsDuringAdjustment()

            HStack {
                Spacer(minLength: 0)
                ColorWheel(hue: grading[selected].hue, saturation: grading[selected].saturation,
                           title: selected.title, identifier: "grading-wheel", selected: true,
                           onBegin: { onBegin("Grading · \(selected.title)") },
                           onChange: { hue, saturation in
                               var updated = grading
                               var wheel = updated[selected]; wheel.hue = hue; wheel.saturation = saturation
                               updated[selected] = wheel; onChange(updated)
                           }, onEnd: onEnd)
                    .frame(width: 128, height: 128)
                    .dimsDuringAdjustment()
                Spacer(minLength: 0)
            }
            HStack(spacing: 0) {
                Color.clear.frame(width: 44, height: 44).allowsHitTesting(false)
                VStack(spacing: 2) {
                    Text(selected.title).font(.subheadline.weight(.semibold))
                    Text(String(format: NSLocalizedString("Hue %d°", comment: "Color grading"), Int(grading[selected].hue)))
                    Text(String(format: NSLocalizedString("Saturation %d", comment: "Color grading"), Int(grading[selected].saturation)))
                }
                .font(.caption).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("grading-wheel-info")
                .dimsDuringAdjustment()
                Button {
                    onEnd(); var updated = grading; updated[selected] = GradingWheel(); onChange(updated)
                } label: { Image(systemName: "arrow.counterclockwise").frame(width: 44, height: 44) }
                    .accessibilityLabel(String(format: NSLocalizedString("Reset grading for %@", comment: "Color grading"), selected.title))
                    .dimsDuringAdjustment()
            }
            LinearAdjustmentControl(parameters: parameters, selectedID: $selectedID,
                onBegin: { onBegin("Grading · \($0.title)") },
                onChange: { parameter, value in update(parameter.id, value) },
                onEnd: onEnd,
                onReset: { parameter in update(parameter.id, parameter.resetValue) })
                .id(selected)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 14).padding(.bottom, 8)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("grading-content")
        .onDisappear(perform: onEnd)
    }
    private var parameters: [LinearAdjustmentParameter] {
        [
            .init(id: "luminance", title: String(localized: "Luminance"), value: grading[selected].luminance, range: -100...100, step: 1, precision: 0, resetValue: 0),
            .init(id: "hue", title: String(localized: "Hue"), value: grading[selected].hue, range: 0...360, step: 1, precision: 0, unit: "°", resetValue: 0),
            .init(id: "saturation", title: String(localized: "Saturation"), value: grading[selected].saturation, range: 0...100, step: 1, precision: 0, resetValue: 0),
            .init(id: "blending", title: String(localized: "Blending"), value: grading.blending, range: 0...100, step: 1, precision: 0, resetValue: 50),
            .init(id: "balance", title: String(localized: "Balance"), value: grading.balance, range: -100...100, step: 1, precision: 0, resetValue: 0)
        ]
    }
    private func update(_ id: String, _ value: Double) {
        var updated = grading
        switch id {
        case "luminance": updated[selected].luminance = value
        case "hue": updated[selected].hue = value
        case "saturation": updated[selected].saturation = value
        case "blending": updated.blending = value
        case "balance": updated.balance = value
        default: return
        }
        onChange(updated)
    }
}
