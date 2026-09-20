import SwiftUI

struct AdjustmentSlider: View {
    let title: String
    let range: ClosedRange<Double>
    let step: Double
    let precision: Int
    let accessibilityID: String
    let value: Double
    let onBegin: () -> Void
    let onChange: (Double) -> Void
    let onEnd: () -> Void
    let onReset: () -> Void
    init(adjustment: Adjustment, value: Double, onBegin: @escaping () -> Void,
         onChange: @escaping (Double) -> Void, onEnd: @escaping () -> Void, onReset: @escaping () -> Void) {
        self.init(title: adjustment.title, range: adjustment.range, step: adjustment.step,
                  precision: adjustment == .exposure ? 2 : 0, accessibilityID: adjustment.rawValue,
                  value: value, onBegin: onBegin, onChange: onChange, onEnd: onEnd, onReset: onReset)
    }
    init(title: String, range: ClosedRange<Double> = -100...100, step: Double = 1,
         precision: Int = 0, accessibilityID: String, value: Double, onBegin: @escaping () -> Void,
         onChange: @escaping (Double) -> Void, onEnd: @escaping () -> Void, onReset: @escaping () -> Void) {
        self.title = title; self.range = range; self.step = step; self.precision = precision
        self.accessibilityID = accessibilityID; self.value = value
        self.onBegin = onBegin; self.onChange = onChange; self.onEnd = onEnd; self.onReset = onReset
    }
    @State private var fine = false
    @State private var zeroFeedback = 0
    @State private var fineOrigin = 0.0

    private var activeRange: ClosedRange<Double> {
        guard fine else { return range }
        let radius = (range.upperBound - range.lowerBound) / 20
        return max(range.lowerBound, fineOrigin - radius)...min(range.upperBound, fineOrigin + radius)
    }
    var body: some View {
        VStack(spacing: 2) {
            HStack {
                Text(title).font(.subheadline)
                Spacer()
                Button {
                    fine.toggle(); fineOrigin = value
                } label: {
                    Text(value, format: .number.precision(.fractionLength(fine ? precision + 1 : precision)))
                        .font(.system(.subheadline, design: .monospaced)).monospacedDigit()
                        .foregroundStyle(fine ? Color.mint : Color.secondary)
                        .frame(minWidth: 54, minHeight: 44)
                }
                .accessibilityLabel("\(title), réglage fin")
                .accessibilityValue(fine ? "Activé" : "Désactivé")
                Button(action: onReset) { Image(systemName: "arrow.counterclockwise").frame(width: 44, height: 44) }
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Réinitialiser \(title)")
            }
            Slider(value: Binding(get: { value }, set: { next in
                if (value < 0 && next >= 0) || (value > 0 && next <= 0) { zeroFeedback += 1 }
                onChange(next)
            }), in: activeRange, step: fine ? step / 10 : step, onEditingChanged: { editing in
                if editing { onBegin() } else { onEnd() }
            })
            .overlay(alignment: .center) {
                if !fine && range.lowerBound == -range.upperBound { Rectangle().fill(.white.opacity(0.55)).frame(width: 1, height: 9).allowsHitTesting(false) }
            }
            .frame(minHeight: 32)
            .onTapGesture(count: 2, perform: onReset)
            .accessibilityLabel(title)
            .accessibilityIdentifier(accessibilityID)
            .accessibilityValue(String(format: "%.2f", value))
            .sensoryFeedback(.selection, trigger: zeroFeedback)
        }
        .onChange(of: value) { _, next in
            // Undo/reset can move the value outside the currently magnified interval.
            if fine && !activeRange.contains(next) { fineOrigin = next }
        }
    }
}
