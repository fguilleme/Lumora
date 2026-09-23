import SwiftUI

struct ColorGradingView: View {
    let grading: ColorGrading
    let onBegin: (String) -> Void
    let onChange: (ColorGrading) -> Void
    let onEnd: () -> Void
    @State private var selected: GradingRange = .shadows
    @State private var precise = false

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

            HStack(spacing: 10) {
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
                VStack(alignment: .leading, spacing: 2) {
                    Text(selected.title).font(.subheadline.weight(.semibold))
                    Text("Hue \(Int(grading[selected].hue))°")
                    Text("Saturation \(Int(grading[selected].saturation))")
                }
                .font(.caption).foregroundStyle(.secondary)
                .dimsDuringAdjustment()
                Spacer()
                Button {
                    onEnd(); var updated = grading; updated[selected] = GradingWheel(); onChange(updated)
                } label: { Image(systemName: "arrow.counterclockwise").frame(width: 44, height: 44) }
                    .accessibilityLabel("Reset grading for \(selected.title)")
                    .dimsDuringAdjustment()
            }
            AdjustmentSlider(title: "Luminance", accessibilityID: "grading-luminance", value: grading[selected].luminance,
                             onBegin: { onBegin("Grading luminance") }, onChange: { value in
                                 var updated = grading; updated[selected].luminance = value; onChange(updated)
                             }, onEnd: onEnd, onReset: {
                                 onEnd(); var updated = grading; updated[selected].luminance = 0; onChange(updated)
                             }).id(selected)
            DisclosureGroup("Precise hue and saturation", isExpanded: $precise) {
                AdjustmentSlider(title: "Hue", range: 0...360, accessibilityID: "grading-hue", value: grading[selected].hue,
                                 onBegin: { onBegin("Grading hue") }, onChange: { value in
                                     var updated = grading; updated[selected].hue = value; onChange(updated)
                                 }, onEnd: onEnd, onReset: {
                                     onEnd(); var updated = grading; updated[selected].hue = 0; onChange(updated)
                                 }).id(selected)
                AdjustmentSlider(title: "Saturation", range: 0...100, accessibilityID: "grading-saturation", value: grading[selected].saturation,
                                 onBegin: { onBegin("Grading saturation") }, onChange: { value in
                                     var updated = grading; updated[selected].saturation = value; onChange(updated)
                                 }, onEnd: onEnd, onReset: {
                                     onEnd(); var updated = grading; updated[selected].saturation = 0; onChange(updated)
                                 }).id(selected)
            }.font(.caption).padding(.vertical, 3)
            AdjustmentSlider(title: "Blending", range: 0...100, accessibilityID: "grading-blending", value: grading.blending,
                             onBegin: { onBegin("Grading blending") }, onChange: { value in
                                 var updated = grading; updated.blending = value; onChange(updated)
                             }, onEnd: onEnd, onReset: {
                                 onEnd(); var updated = grading; updated.blending = 50; onChange(updated)
                             })
            AdjustmentSlider(title: "Balance", accessibilityID: "grading-balance", value: grading.balance,
                             onBegin: { onBegin("Grading balance") }, onChange: { value in
                                 var updated = grading; updated.balance = value; onChange(updated)
                             }, onEnd: onEnd, onReset: {
                                 onEnd(); var updated = grading; updated.balance = 0; onChange(updated)
                             })
        }.padding(.horizontal, 14).padding(.bottom, 8).onDisappear(perform: onEnd)
    }
}
