import SwiftUI

struct ColorGradingView: View {
    let grading: ColorGrading
    let onBegin: (String) -> Void
    let onChange: (ColorGrading) -> Void
    let onEnd: () -> Void
    @State private var selected: GradingRange = .shadows
    @State private var precise = false

    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .top, spacing: 0) {
                ForEach(GradingRange.allCases) { range in
                    VStack(spacing: 0) {
                        ColorWheel(hue: grading[range].hue, saturation: grading[range].saturation,
                                   title: range.title, identifier: "grading-wheel-\(range.rawValue)", selected: range == selected,
                                   onBegin: { selected = range; onBegin("Grading · \(range.title)") },
                                   onChange: { hue, saturation in
                                       var updated = grading
                                       var wheel = updated[range]; wheel.hue = hue; wheel.saturation = saturation
                                       updated[range] = wheel; onChange(updated)
                                   }, onEnd: onEnd)
                        .frame(height: 100)
                        Button { onEnd(); selected = range } label: {
                            Text(range.title).font(.caption).multilineTextAlignment(.center).frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .accessibilityIdentifier("grading-range-\(range.rawValue)")
                        .accessibilityAddTraits(range == selected ? .isSelected : [])
                    }
                }
            }
            HStack {
                Text(selected.title).font(.subheadline.weight(.medium))
                Spacer()
                Button {
                    onEnd(); var updated = grading; updated[selected] = GradingWheel(); onChange(updated)
                } label: { Image(systemName: "arrow.counterclockwise").frame(width: 44, height: 44) }
                    .accessibilityLabel("Réinitialiser grading \(selected.title)")
            }
            AdjustmentSlider(title: "Luminance", accessibilityID: "grading-luminance", value: grading[selected].luminance,
                             onBegin: { onBegin("Grading luminance") }, onChange: { value in
                                 var updated = grading; updated[selected].luminance = value; onChange(updated)
                             }, onEnd: onEnd, onReset: {
                                 onEnd(); var updated = grading; updated[selected].luminance = 0; onChange(updated)
                             }).id(selected)
            DisclosureGroup("Teinte et saturation précises", isExpanded: $precise) {
                AdjustmentSlider(title: "Teinte", range: 0...360, accessibilityID: "grading-hue", value: grading[selected].hue,
                                 onBegin: { onBegin("Grading teinte") }, onChange: { value in
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
            }.font(.subheadline).padding(.vertical, 8)
            AdjustmentSlider(title: "Mélange", range: 0...100, accessibilityID: "grading-blending", value: grading.blending,
                             onBegin: { onBegin("Grading mélange") }, onChange: { value in
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
        }.padding(.horizontal, 16).padding(.bottom, 12).onDisappear(perform: onEnd)
    }
}
