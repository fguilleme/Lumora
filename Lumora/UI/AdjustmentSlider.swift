import SwiftUI

struct AdjustmentFocusContext: Sendable {
    var activeID: String?
    var setActive: @MainActor @Sendable (String?) -> Void
}

private struct AdjustmentFocusKey: EnvironmentKey {
    static let defaultValue = AdjustmentFocusContext(activeID: nil, setActive: { _ in })
}

extension EnvironmentValues {
    var adjustmentFocus: AdjustmentFocusContext {
        get { self[AdjustmentFocusKey.self] }
        set { self[AdjustmentFocusKey.self] = newValue }
    }
}

private struct AdjustmentFocusDimmingModifier: ViewModifier {
    @Environment(\.adjustmentFocus) private var focus
    func body(content: Content) -> some View {
        content
            .opacity(focus.activeID == nil ? 1 : 0.015)
            .allowsHitTesting(focus.activeID == nil)
            .animation(.easeOut(duration: 0.12), value: focus.activeID)
    }
}

extension View {
    func dimsDuringAdjustment() -> some View { modifier(AdjustmentFocusDimmingModifier()) }
}

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
    @State private var editing = false
    @Environment(\.adjustmentFocus) private var focus

    private var activeRange: ClosedRange<Double> {
        guard fine else { return range }
        let radius = (range.upperBound - range.lowerBound) / 20
        return max(range.lowerBound, fineOrigin - radius)...min(range.upperBound, fineOrigin + radius)
    }
    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(width: 82, alignment: .leading)
            Slider(value: Binding(get: { value }, set: { next in
                if (value < 0 && next >= 0) || (value > 0 && next <= 0) { zeroFeedback += 1 }
                onChange(next)
            }), in: activeRange, step: fine ? step / 10 : step, onEditingChanged: { editing in
                if editing {
                    self.editing = true
                    focus.setActive(accessibilityID)
                    onBegin()
                } else {
                    finishEditing()
                }
            })
            .overlay(alignment: .center) {
                if !fine && range.lowerBound == -range.upperBound { Rectangle().fill(.white.opacity(0.55)).frame(width: 1, height: 9).allowsHitTesting(false) }
            }
            .frame(minHeight: 30)
            .onTapGesture(count: 2, perform: onReset)
            .accessibilityLabel(title)
            .accessibilityIdentifier(accessibilityID)
            .accessibilityValue(String(format: "%.2f", value))
            .sensoryFeedback(.selection, trigger: zeroFeedback)
            .simultaneousGesture(DragGesture(minimumDistance: 0).onEnded { _ in finishEditing() })
            Button {
                fine.toggle(); fineOrigin = value
            } label: {
                Text(value, format: .number.precision(.fractionLength(fine ? precision + 1 : precision)))
                    .font(.system(.caption, design: .monospaced)).monospacedDigit()
                    .foregroundStyle(fine ? Color.mint : Color.secondary)
                    .frame(width: 48, height: 40)
            }
            .accessibilityLabel("\(title), réglage fin")
            .accessibilityValue(fine ? "Activé" : "Désactivé")
            Button(action: onReset) {
                Image(systemName: "arrow.counterclockwise").font(.caption).frame(width: 32, height: 40)
            }
            .foregroundStyle(.secondary)
            .accessibilityLabel("Réinitialiser \(title)")
        }
        .frame(minHeight: 42)
        .opacity(focus.activeID == nil || focus.activeID == accessibilityID ? 1 : 0.015)
        .allowsHitTesting(focus.activeID == nil || focus.activeID == accessibilityID)
        .animation(.easeOut(duration: 0.12), value: focus.activeID)
        .onChange(of: value) { _, next in
            // Undo/reset can move the value outside the currently magnified interval.
            if fine && !activeRange.contains(next) { fineOrigin = next }
        }
        .onDisappear {
            finishEditing()
        }
    }

    private func finishEditing() {
        guard editing else { return }
        editing = false
        focus.setActive(nil)
        onEnd()
    }
}
