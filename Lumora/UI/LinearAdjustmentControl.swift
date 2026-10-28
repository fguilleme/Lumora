import SwiftUI

/// A selectable parameter and the exact numeric contract already used by the renderer.
struct LinearAdjustmentParameter: Identifiable, Equatable {
    let id: String
    let title: String
    let value: Double
    let range: ClosedRange<Double>
    let step: Double
    let precision: Int
    var unit: String = ""
    let resetValue: Double
    var isEnabled: Bool = true
    var group: String? = nil

    var formattedValue: String {
        value.formatted(.number.precision(.fractionLength(precision))) + unit
    }
}

/// One common linear ruler for a horizontal row of scalar parameters.
/// The ruler is relative: touching it never changes the value until the finger moves.
struct LinearAdjustmentControl<Accessory: View>: View {
    let parameters: [LinearAdjustmentParameter]
    @Binding var selectedID: String
    let onBegin: (LinearAdjustmentParameter) -> Void
    let onChange: (LinearAdjustmentParameter, Double) -> Void
    let onEnd: () -> Void
    let onReset: (LinearAdjustmentParameter) -> Void
    let showsReset: Bool
    @ViewBuilder let accessory: () -> Accessory

    @State private var entryPresented = false
    @State private var entryText = ""

    init(parameters: [LinearAdjustmentParameter], selectedID: Binding<String>,
         onBegin: @escaping (LinearAdjustmentParameter) -> Void,
         onChange: @escaping (LinearAdjustmentParameter, Double) -> Void,
         onEnd: @escaping () -> Void,
         onReset: @escaping (LinearAdjustmentParameter) -> Void,
         showsReset: Bool = true,
         @ViewBuilder accessory: @escaping () -> Accessory) {
        self.parameters = parameters
        _selectedID = selectedID
        self.onBegin = onBegin
        self.onChange = onChange
        self.onEnd = onEnd
        self.onReset = onReset
        self.showsReset = showsReset
        self.accessory = accessory
    }

    private var selected: LinearAdjustmentParameter? {
        parameters.first(where: { $0.id == selectedID && $0.isEnabled })
            ?? parameters.first(where: \.isEnabled)
            ?? parameters.first
    }

    var body: some View {
        VStack(spacing: 4) {
            if parameters.count > 1 {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(parameterGroups.indices, id: \.self) { index in
                                let group = parameterGroups[index]
                                HStack(spacing: 6) {
                                    ForEach(group) { parameter in
                                        parameterButton(parameter).id(parameter.id)
                                    }
                                }
                                .padding(group.first?.group == nil ? 0 : 4)
                                .overlay {
                                    if group.first?.group != nil {
                                        RoundedRectangle(cornerRadius: 13)
                                            .stroke(Color.secondary.opacity(0.45), lineWidth: 0.7)
                                            .allowsHitTesting(false)
                                    }
                                }
                            }
                            accessory()
                        }
                        .padding(.horizontal, 8)
                    }
                    .accessibilityIdentifier("adjustment-parameters")
                    .onChange(of: selectedID) { _, id in
                        withAnimation(.easeOut(duration: 0.18)) { proxy.scrollTo(id, anchor: .center) }
                    }
                    .onAppear {
                        #if DEBUG
                        if CommandLine.arguments.contains("--app-store-1.3") { proxy.scrollTo(selectedID, anchor: .center) }
                        #endif
                    }
                }
            }
            if let selected {
                HStack(spacing: 6) {
                    Button {
                        entryText = selected.value.formatted(.number.precision(.fractionLength(selected.precision)))
                        entryPresented = true
                    } label: {
                        if parameters.count == 1 {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(selected.title).font(.caption2).lineLimit(1)
                                Text(selected.formattedValue)
                                    .font(.system(.body, design: .monospaced).weight(.semibold))
                                    .monospacedDigit()
                            }
                            .frame(minWidth: 94, minHeight: 44, alignment: .leading)
                            .contentShape(Rectangle())
                        } else {
                            Text(selected.formattedValue)
                                .font(.system(.body, design: .monospaced).weight(.semibold))
                                .monospacedDigit()
                                .lineLimit(1)
                                .minimumScaleFactor(0.78)
                                .frame(width: 92)
                                .frame(minHeight: 44)
                                .contentShape(Rectangle())
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.primary)
                    .disabled(!selected.isEnabled)
                    .accessibilityLabel(String(format: NSLocalizedString("Enter %@ value", comment: "Numeric adjustment entry"), selected.title))
                    .accessibilityIdentifier("adjustment-value-entry")

                    RelativeRuler(parameter: selected,
                                  onBegin: { onBegin(selected) },
                                  onChange: { onChange(selected, $0) },
                                  onEnd: onEnd)
                        .id(selected.id)

                    Group {
                        if showsReset {
                            Button { onReset(selected) } label: {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.caption)
                                    .frame(width: 44, height: 44)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                            .disabled(!selected.isEnabled)
                            .accessibilityLabel(String(format: NSLocalizedString("Reset %@", comment: "Adjustment reset"), selected.title))
                            .accessibilityIdentifier("adjustment-reset")
                        } else {
                            Color.clear.frame(width: 44, height: 44).allowsHitTesting(false)
                        }
                    }
                }
                .padding(.horizontal, 8)
            }
        }
        .alert(selected.map { String(format: NSLocalizedString("%@ value", comment: "Numeric adjustment entry title"), $0.title) } ?? "",
               isPresented: $entryPresented) {
            TextField("Value", text: $entryText)
                .keyboardType(.numbersAndPunctuation)
                .accessibilityIdentifier("adjustment-entry-field")
            Button("Cancel", role: .cancel) {}
                .accessibilityIdentifier("adjustment-entry-cancel")
            Button("Apply") { applyEntry() }
                .accessibilityIdentifier("adjustment-entry-apply")
        }
        .onAppear { repairSelection() }
        .onChange(of: parameters.map(\.id)) { _, _ in repairSelection() }
    }

    private func parameterButton(_ parameter: LinearAdjustmentParameter) -> some View {
        let active = parameter.id == selected?.id
        return Button { selectedID = parameter.id } label: {
            VStack(spacing: 1) {
                Text(parameter.title).font(.caption2).lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                Text(parameter.formattedValue)
                    .font(.caption.monospacedDigit()).monospacedDigit()
                    .foregroundStyle(active ? Color.mint : Color.secondary)
            }
            .padding(.horizontal, 8)
            .frame(minWidth: 70, minHeight: 44)
            .background(active ? Color.mint.opacity(0.14) : Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(active ? Color.mint.opacity(0.65) : .white.opacity(0.08), lineWidth: 0.7))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!parameter.isEnabled)
        .opacity(parameter.isEnabled ? 1 : 0.35)
        .accessibilityLabel(parameter.title)
        .accessibilityValue(parameter.formattedValue)
        .accessibilityAddTraits(active ? .isSelected : [])
        .accessibilityIdentifier("parameter-\(parameter.id)")
    }

    private var parameterGroups: [[LinearAdjustmentParameter]] {
        var groups: [[LinearAdjustmentParameter]] = []
        for parameter in parameters {
            if let last = groups.last, last.first?.group == parameter.group {
                groups[groups.count - 1].append(parameter)
            } else { groups.append([parameter]) }
        }
        return groups
    }

    private func repairSelection() {
        if !parameters.contains(where: { $0.id == selectedID && $0.isEnabled }),
           let first = parameters.first(where: \.isEnabled) ?? parameters.first {
            selectedID = first.id
        }
    }

    private func applyEntry() {
        guard let selected else { return }
        let normalized = entryText.replacingOccurrences(of: ",", with: ".")
        guard let raw = Double(normalized) else { return }
        let clamped = min(selected.range.upperBound, max(selected.range.lowerBound, raw))
        let rounded = selected.range.lowerBound + ((clamped - selected.range.lowerBound) / selected.step).rounded() * selected.step
        // Close before changing observable editor state; an asynchronous render
        // can rebuild the control during UIKit's automatic alert dismissal.
        entryPresented = false
        onBegin(selected)
        onChange(selected, rounded)
        onEnd()
    }
}

extension LinearAdjustmentControl where Accessory == EmptyView {
    init(parameters: [LinearAdjustmentParameter], selectedID: Binding<String>,
         onBegin: @escaping (LinearAdjustmentParameter) -> Void,
         onChange: @escaping (LinearAdjustmentParameter, Double) -> Void,
         onEnd: @escaping () -> Void,
         onReset: @escaping (LinearAdjustmentParameter) -> Void,
         showsReset: Bool = true) {
        self.init(parameters: parameters, selectedID: selectedID, onBegin: onBegin,
                  onChange: onChange, onEnd: onEnd, onReset: onReset,
                  showsReset: showsReset) { EmptyView() }
    }
}

private struct RelativeRuler: View {
    let parameter: LinearAdjustmentParameter
    let onBegin: () -> Void
    let onChange: (Double) -> Void
    let onEnd: () -> Void

    @State private var origin: Double?
    @State private var lastSent: Double?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Canvas { context, size in
                    drawTicks(context: &context, size: size)
                }
                Rectangle()
                    .fill(Color.mint)
                    .frame(width: 2.5, height: 28)
                    .shadow(color: .black.opacity(0.55), radius: 1)
                    .allowsHitTesting(false)
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { gesture in
                    if origin == nil {
                        origin = parameter.value
                        lastSent = parameter.value
                        onBegin()
                    }
                    guard let origin else { return }
                    let span = parameter.range.upperBound - parameter.range.lowerBound
                    let pointsForRange = max(360, Double(geometry.size.width) * 2.2)
                    let raw = origin - Double(gesture.translation.width) * span / pointsForRange
                    let clamped = min(parameter.range.upperBound, max(parameter.range.lowerBound, raw))
                    let rounded = parameter.range.lowerBound + ((clamped - parameter.range.lowerBound) / parameter.step).rounded() * parameter.step
                    if rounded != lastSent { lastSent = rounded; onChange(rounded) }
                }
                .onEnded { _ in finish() })
        }
        .frame(height: 44)
        .background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 10))
        .clipped()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(parameter.title)
        .accessibilityValue(parameter.formattedValue)
        .accessibilityHint("Swipe horizontally to adjust")
        .accessibilityAdjustableAction { direction in
            let delta = direction == .increment ? parameter.step : -parameter.step
            onBegin()
            onChange(min(parameter.range.upperBound, max(parameter.range.lowerBound, parameter.value + delta)))
            onEnd()
        }
        .accessibilityIdentifier("adjustment-ruler")
        .onDisappear { finish() }
    }

    private func finish() {
        guard origin != nil else { return }
        origin = nil
        lastSent = nil
        onEnd()
    }

    private func drawTicks(context: inout GraphicsContext, size: CGSize) {
        let span = parameter.range.upperBound - parameter.range.lowerBound
        guard span > 0 else { return }
        let minor = niceIncrement(span / 24)
        let major = minor * 5
        let pointsForRange = max(360, Double(size.width) * 2.2)
        let pointsPerUnit = pointsForRange / span
        let firstIndex = Int(floor(parameter.range.lowerBound / minor))
        let lastIndex = Int(ceil(parameter.range.upperBound / minor))
        for index in firstIndex...lastIndex {
            let tickValue = Double(index) * minor
            let x = size.width / 2 + CGFloat((tickValue - parameter.value) * pointsPerUnit)
            guard x >= -2, x <= size.width + 2 else { continue }
            let isMajor = abs((tickValue / major).rounded() - tickValue / major) < 0.001
            let height: CGFloat = isMajor ? 21 : 11
            var path = Path()
            path.move(to: CGPoint(x: x, y: size.height - 7))
            path.addLine(to: CGPoint(x: x, y: size.height - 7 - height))
            context.stroke(path, with: .color(.white.opacity(isMajor ? 0.62 : 0.30)), lineWidth: isMajor ? 1 : 0.7)
        }
    }

    private func niceIncrement(_ raw: Double) -> Double {
        guard raw > 0 else { return 1 }
        let magnitude = pow(10, floor(log10(raw)))
        let normalized = raw / magnitude
        let nice = normalized < 1.5 ? 1.0 : normalized < 3.5 ? 2.0 : normalized < 7.5 ? 5.0 : 10.0
        return nice * magnitude
    }
}
