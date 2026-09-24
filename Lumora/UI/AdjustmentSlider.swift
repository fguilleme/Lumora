import SwiftUI
import UIKit

struct AdjustmentFocusContext: Sendable {
    var activeID: String?
    var setActive: @MainActor @Sendable (String?) -> Void
}

private struct AdjustmentFocusKey: EnvironmentKey {
    static let defaultValue = AdjustmentFocusContext(activeID: nil, setActive: { _ in })
}

private struct SideControlLayoutKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var adjustmentFocus: AdjustmentFocusContext {
        get { self[AdjustmentFocusKey.self] }
        set { self[AdjustmentFocusKey.self] = newValue }
    }
    var usesSideControlLayout: Bool {
        get { self[SideControlLayoutKey.self] }
        set { self[SideControlLayoutKey.self] = newValue }
    }
}

private struct AdjustmentFocusDimmingModifier: ViewModifier {
    @Environment(\.adjustmentFocus) private var focus
    func body(content: Content) -> some View {
        content
            .opacity(focus.activeID == nil ? 1 : 0)
            .allowsHitTesting(focus.activeID == nil)
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
    @Environment(\.usesSideControlLayout) private var usesSideControlLayout

    private var activeRange: ClosedRange<Double> {
        guard fine else { return range }
        let radius = (range.upperBound - range.lowerBound) / 20
        return max(range.lowerBound, fineOrigin - radius)...min(range.upperBound, fineOrigin + radius)
    }
    var body: some View {
        Group {
            if usesSideControlLayout {
                VStack(spacing: 0) {
                    HStack(spacing: 4) {
                        titleLabel
                        Spacer(minLength: 4)
                        fineButton
                        resetButton
                    }
                    slider
                }
            } else {
                HStack(spacing: 8) {
                    titleLabel.frame(width: 82, alignment: .leading)
                    slider
                    fineButton
                    resetButton
                }
                .frame(minHeight: 42)
            }
        }
        .opacity(focus.activeID == nil || focus.activeID == accessibilityID ? 1 : 0)
        .allowsHitTesting(focus.activeID == nil || focus.activeID == accessibilityID)
        .onChange(of: value) { _, next in
            // Undo/reset can move the value outside the currently magnified interval.
            if fine && !activeRange.contains(next) { fineOrigin = next }
        }
        .onDisappear { finishEditing() }
    }

    private var titleLabel: some View {
        Text(title)
            .font(.caption)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
    }

    private var slider: some View {
        TouchTrackingSlider(value: value, range: activeRange, step: fine ? step / 10 : step,
                                title: title, accessibilityID: accessibilityID,
                                onBegin: beginEditing, onChange: { next in
                if (value < 0 && next >= 0) || (value > 0 && next <= 0) { zeroFeedback += 1 }
                onChange(next)
            }, onEnd: finishEditing, onReset: onReset)
            .overlay(alignment: .center) {
                if !fine && range.lowerBound == -range.upperBound { Rectangle().fill(.white.opacity(0.55)).frame(width: 1, height: 9).allowsHitTesting(false) }
            }
            .frame(minHeight: 30)
            .sensoryFeedback(.selection, trigger: zeroFeedback)
    }

    private var fineButton: some View {
        Button {
                fine.toggle(); fineOrigin = value
            } label: {
                Text(value, format: .number.precision(.fractionLength(fine ? precision + 1 : precision)))
                    .font(.system(.caption, design: .monospaced)).monospacedDigit()
                    .foregroundStyle(fine ? Color.mint : Color.secondary)
                    .frame(width: 48, height: 40)
            }
            .accessibilityLabel(String(format: NSLocalizedString("%@, fine adjustment", comment: "Slider accessibility"), title))
            .accessibilityValue(fine ? "On" : "Off")
    }

    private var resetButton: some View {
        Button(action: onReset) {
            Image(systemName: "arrow.counterclockwise")
                .font(.caption)
                .frame(width: usesSideControlLayout ? 44 : 32, height: 40)
        }
            .foregroundStyle(.secondary)
            .accessibilityLabel(String(format: NSLocalizedString("Reset %@", comment: "Slider accessibility"), title))
    }

    private func finishEditing() {
        guard editing else { return }
        editing = false
        focus.setActive(nil)
        onEnd()
    }

    private func beginEditing() {
        guard !editing else { return }
        editing = true
        focus.setActive(accessibilityID)
        onBegin()
    }
}

/// UIControl touch-up is the single end-of-edit signal. SwiftUI Slider's editing
/// callback and an additional DragGesture can each end while the thumb is still
/// moving, briefly clearing focus between renderer updates.
private struct TouchTrackingSlider: UIViewRepresentable {
    let value: Double
    let range: ClosedRange<Double>
    let step: Double
    let title: String
    let accessibilityID: String
    let onBegin: () -> Void
    let onChange: (Double) -> Void
    let onEnd: () -> Void
    let onReset: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UISlider {
        let slider = UISlider()
        slider.minimumTrackTintColor = .systemMint
        slider.maximumTrackTintColor = UIColor(white: 0.16, alpha: 1)
        slider.thumbTintColor = .white
        slider.isContinuous = true
        slider.addTarget(context.coordinator, action: #selector(Coordinator.touchDown), for: .touchDown)
        slider.addTarget(context.coordinator, action: #selector(Coordinator.valueChanged(_:)), for: .valueChanged)
        slider.addTarget(context.coordinator, action: #selector(Coordinator.touchEnded),
                         for: [.touchUpInside, .touchUpOutside, .touchCancel])
        let doubleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.reset))
        doubleTap.numberOfTapsRequired = 2
        doubleTap.cancelsTouchesInView = false
        slider.addGestureRecognizer(doubleTap)
        return slider
    }

    func updateUIView(_ slider: UISlider, context: Context) {
        context.coordinator.owner = self
        slider.minimumValue = Float(range.lowerBound)
        slider.maximumValue = Float(range.upperBound)
        if !context.coordinator.isTracking {
            slider.value = Float(value)
            context.coordinator.lastSent = value
        }
        slider.accessibilityLabel = title
        slider.accessibilityIdentifier = accessibilityID
        slider.accessibilityValue = String(format: "%.2f", value)
    }

    @MainActor final class Coordinator: NSObject {
        var owner: TouchTrackingSlider
        var isTracking = false
        var lastSent: Double

        init(_ owner: TouchTrackingSlider) {
            self.owner = owner
            lastSent = owner.value
        }

        @objc func touchDown() {
            guard !isTracking else { return }
            isTracking = true
            owner.onBegin()
        }

        @objc func valueChanged(_ slider: UISlider) {
            let discreteAdjustment = !slider.isTracking
            touchDown()
            let lower = owner.range.lowerBound
            let rounded = lower + ((Double(slider.value) - lower) / owner.step).rounded() * owner.step
            let next = min(owner.range.upperBound, max(lower, rounded))
            slider.value = Float(next)
            if next != lastSent {
                lastSent = next
                owner.onChange(next)
            }
            if discreteAdjustment { touchEnded() }
        }

        @objc func touchEnded() {
            guard isTracking else { return }
            isTracking = false
            owner.onEnd()
        }

        @objc func reset() { owner.onReset() }
    }
}
