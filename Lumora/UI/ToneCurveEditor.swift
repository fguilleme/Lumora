import SwiftUI

struct ToneCurveEditor: View {
    let curves: ToneCurves
    let histogram: Histogram
    @Binding var channel: CurveChannel
    @Binding var editMode: Bool
    @Binding var eyedropper: Bool
    let sample: CurveSample?
    let eyedropperAvailable: Bool
    let onClearSample: () -> Void
    let onBegin: (String) -> Void
    let onChange: (CurveChannel, ToneCurve) -> Void
    let onEnd: () -> Void
    @State private var selected: Int?
    @State private var dragging: Int?

    private var curve: ToneCurve { curves[channel] }
    private var accent: Color {
        switch channel { case .rgb: .white; case .red: .red; case .green: .green; case .blue: .cyan }
    }
    private var selectedIndex: Int { min(selected ?? 0, curve.points.count - 1) }
    private var canDelete: Bool {
        guard let selected else { return false }
        return selected > 0 && selected < curve.points.count - 1
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Picker("Canal de la courbe", selection: $channel) {
                    ForEach(CurveChannel.allCases) { item in Text(item.title).tag(item) }
                }
                .pickerStyle(.segmented)
                .onChange(of: channel) { _, _ in finishGesture(); selected = nil }
                Button {
                    finishGesture()
                    editMode.toggle()
                    if !editMode { eyedropper = false; onClearSample(); selected = nil }
                } label: {
                    Image(systemName: editMode ? "checkmark" : "pencil")
                }
                .buttonStyle(CompactEditorButtonStyle(selected: editMode))
                .accessibilityLabel(editMode ? "Terminé" : "Modifier")
                .accessibilityIdentifier("curve-edit-mode")
            }
            GeometryReader { geometry in
                ZStack {
                    Canvas { context, size in
                        drawHistogram(context: &context, size: size)
                        var grid = Path()
                        for division in 0...4 {
                            let x = size.width * Double(division) / 4
                            let y = size.height * Double(division) / 4
                            grid.move(to: CGPoint(x: x, y: 0)); grid.addLine(to: CGPoint(x: x, y: size.height))
                            grid.move(to: CGPoint(x: 0, y: y)); grid.addLine(to: CGPoint(x: size.width, y: y))
                        }
                        context.stroke(grid, with: .color(.white.opacity(editMode ? 0.18 : 0.12)), lineWidth: 1)
                        var diagonal = Path()
                        diagonal.move(to: CGPoint(x: 0, y: size.height))
                        diagonal.addLine(to: CGPoint(x: size.width, y: 0))
                        context.stroke(diagonal, with: .color(.white.opacity(0.25)), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        var path = Path()
                        for index in 0...256 {
                            let x = Double(index) / 256
                            let point = CGPoint(x: x * size.width, y: (1 - curve.evaluate(x)) * size.height)
                            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
                        }
                        context.stroke(path, with: .color(accent), lineWidth: 2)
                        for (index, point) in curve.points.enumerated() {
                            let center = CGPoint(x: point.x * size.width, y: (1 - point.y) * size.height)
                            let radius: CGFloat = editMode ? (index == selected ? 7 : 5) : 3
                            let circle = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius,
                                                                width: radius * 2, height: radius * 2))
                            context.fill(circle, with: .color(index == selected && editMode ? accent : .black))
                            context.stroke(circle, with: .color(accent.opacity(editMode ? 1 : 0.6)), lineWidth: 2)
                        }
                        if editMode, eyedropper, let sample {
                            let x = sample.value(for: channel) * size.width
                            var marker = Path()
                            marker.move(to: CGPoint(x: x, y: 0))
                            marker.addLine(to: CGPoint(x: x, y: size.height))
                            context.stroke(marker, with: .color(.mint.opacity(0.85)), style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                            let y = (1 - curve.evaluate(sample.value(for: channel))) * size.height
                            context.stroke(Path(ellipseIn: CGRect(x: x - 6, y: y - 6, width: 12, height: 12)),
                                           with: .color(.mint), lineWidth: 2)
                        }
                    }
                    .allowsHitTesting(false)
                    if editMode {
                        ForEach(curve.points.indices, id: \.self) { index in
                            let point = curve.points[index]
                            Circle().fill(accent.opacity(0.001)).frame(width: 44, height: 44)
                                .contentShape(Circle())
                                .position(x: point.x * geometry.size.width,
                                          y: (1 - point.y) * geometry.size.height)
                                .onTapGesture { selected = index }
                                .gesture(DragGesture(minimumDistance: 2, coordinateSpace: .named("curve-plot"))
                                    .onChanged { value in
                                        if dragging == nil {
                                            dragging = index; selected = index
                                            onBegin("Courbe \(channel.title)")
                                        }
                                        var updated = curve
                                        updated.move(index: index,
                                                     x: Double(value.location.x / geometry.size.width),
                                                     y: Double(1 - value.location.y / geometry.size.height))
                                        if updated != curve { onChange(channel, updated) }
                                    }
                                    .onEnded { _ in finishGesture() })
                                .accessibilityElement(children: .ignore)
                                .accessibilityAddTraits(.isButton)
                                .accessibilityLabel("Point \(index + 1) de la courbe \(channel.title)")
                                .accessibilityIdentifier("curve-point-\(index)")
                        }
                    }
                }
                .contentShape(Rectangle())
                .overlay(alignment: .topTrailing) {
                    if editMode {
                        HStack(spacing: 4) {
                            Button {
                                eyedropper.toggle()
                                onClearSample()
                            } label: { Image(systemName: "eyedropper") }
                                .buttonStyle(CompactEditorButtonStyle(selected: eyedropper))
                                .accessibilityLabel("Pipette")
                                .accessibilityIdentifier("curve-eyedropper")
                                .accessibilityAddTraits(eyedropper ? .isSelected : [])
                                .disabled(!eyedropperAvailable)
                                .accessibilityHint(eyedropperAvailable ? "Touchez la photographie pour situer sa tonalité" : "Indisponible sur un calque masqué")
                            Button(action: addPoint) { Image(systemName: "plus") }
                                .buttonStyle(CompactEditorButtonStyle())
                                .accessibilityLabel(sample == nil ? "Ajouter un point" : "Ajouter un point depuis la pipette")
                                .accessibilityIdentifier("curve-add-point")
                                .disabled(curve.points.count >= ToneCurve.maximumPoints)
                            Button(action: deletePoint) { Image(systemName: "trash") }
                                .buttonStyle(CompactEditorButtonStyle())
                                .accessibilityLabel("Supprimer le point")
                                .accessibilityIdentifier("curve-delete-point")
                                .disabled(!canDelete)
                        }
                        .padding(3)
                        .background(.black.opacity(0.82), in: Capsule())
                    }
                }
                .overlay(alignment: .topLeading) {
                    if editMode, eyedropper, let sample {
                        Text("Échantillon \(Int((sample.value(for: channel) * 100).rounded())) %")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.mint)
                            .padding(.horizontal, 8).padding(.vertical, 5)
                            .background(.black.opacity(0.82), in: Capsule())
                            .padding(4)
                            .allowsHitTesting(false)
                            .accessibilityIdentifier("curve-sample-value")
                    }
                }
                .coordinateSpace(name: "curve-plot")
                .simultaneousGesture(SpatialTapGesture(coordinateSpace: .named("curve-plot")).onEnded { value in
                    guard editMode else { return }
                    // The compact controls occupy the upper-right corner of the plot.
                    if value.location.y < 48 && value.location.x > geometry.size.width - 150 { return }
                    createPoint(at: value.location, size: geometry.size)
                }, including: editMode ? .all : .none)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("tone-curve-chart")
                .accessibilityLabel("Courbe \(channel.title)")
                .accessibilityValue("\(curve.points.count) points. \(editMode ? "Édition" : "Consultation"). " +
                    curve.points.map { String(format: "%.4f:%.4f", $0.x, $0.y) }.joined(separator: ","))
            }
            .frame(height: 155).padding(.horizontal, 8).padding(.vertical, 8)
            if editMode {
                HStack {
                    Button { selected = max(0, selectedIndex - 1) } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
                        .disabled(selectedIndex == 0).accessibilityLabel("Point précédent")
                    Text("Point \(selectedIndex + 1) / \(curve.points.count)").font(.caption.monospacedDigit())
                    Button { selected = min(curve.points.count - 1, selectedIndex + 1) } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }
                        .disabled(selectedIndex == curve.points.count - 1).accessibilityLabel("Point suivant")
                    Spacer(minLength: 0)
                    Button { onChange(channel, ToneCurve()); selected = nil } label: {
                        Image(systemName: "arrow.counterclockwise").frame(width: 44, height: 44)
                    }.accessibilityLabel("Réinitialiser la courbe \(channel.title)")
                }
                coordinateControl("Entrée", horizontal: true)
                coordinateControl("Sortie", horizontal: false)
                Text("Touchez la courbe pour ajouter · Glissez un point pour déplacer")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .onDisappear { finishGesture(); eyedropper = false; editMode = false; onClearSample() }
        .onChange(of: curves) { _, _ in
            selected = selected.flatMap { $0 < curve.points.count ? $0 : nil }
            onClearSample()
        }
    }

    private func createPoint(at location: CGPoint, size: CGSize) {
        guard editMode, size.width > 0, size.height > 0 else { return }
        let x = min(1, max(0, Double(location.x / size.width)))
        let y = min(1, max(0, Double(1 - location.y / size.height)))
        insertPoint(x: x, y: y)
    }
    private func insertPoint(x: Double, y: Double) {
        if let near = curve.points.indices.min(by: { abs(curve.points[$0].x - x) < abs(curve.points[$1].x - x) }),
           abs(curve.points[near].x - x) < max(ToneCurve.minimumSpacing, 0.03) {
            selected = near
            return
        }
        var updated = curve
        if let added = updated.add(x: x, y: y) {
            onChange(channel, updated)
            selected = added
        }
    }
    private func addPoint() {
        if eyedropper, let sample {
            let x = sample.value(for: channel)
            insertPoint(x: x, y: curve.evaluate(x))
            onClearSample()
            return
        }
        let index = (0..<(curve.points.count - 1)).max {
            curve.points[$0 + 1].x - curve.points[$0].x < curve.points[$1 + 1].x - curve.points[$1].x
        } ?? 0
        let x = (curve.points[index].x + curve.points[index + 1].x) / 2
        insertPoint(x: x, y: curve.evaluate(x))
    }
    private func deletePoint() {
        guard canDelete else { return }
        var updated = curve
        updated.remove(index: selectedIndex)
        if updated != curve { onChange(channel, updated) }
        selected = nil
    }
    private func finishGesture() {
        if dragging != nil { onEnd() }
        dragging = nil
    }
    private func coordinateControl(_ title: String, horizontal: Bool) -> some View {
        let point = curve.points[selectedIndex]
        return HStack {
            Text(title).font(.caption).frame(width: 45, alignment: .leading)
            Slider(value: Binding(get: { (horizontal ? point.x : point.y) * 100 }, set: { value in
                var updated = curve
                updated.move(index: selectedIndex, x: horizontal ? value / 100 : point.x,
                             y: horizontal ? point.y : value / 100)
                onChange(channel, updated)
            }), in: 0...100, step: 0.1, onEditingChanged: { editing in
                if editing { onBegin("Courbe \(channel.title)") } else { onEnd() }
            })
            .disabled(horizontal && (selectedIndex == 0 || selectedIndex == curve.points.count - 1))
            .accessibilityLabel("\(title) du point")
            Text((horizontal ? point.x : point.y) * 100, format: .number.precision(.fractionLength(1)))
                .font(.caption.monospacedDigit()).frame(width: 40, alignment: .trailing)
        }.frame(minHeight: 36)
    }
    private func drawHistogram(context: inout GraphicsContext, size: CGSize) {
        let bins: [Int]
        switch channel {
        case .rgb: bins = histogram.luminance
        case .red: bins = histogram.red
        case .green: bins = histogram.green
        case .blue: bins = histogram.blue
        }
        let peak = max(1, bins.max() ?? 1)
        var path = Path(); path.move(to: CGPoint(x: 0, y: size.height))
        for index in bins.indices {
            path.addLine(to: CGPoint(x: Double(index) / 255 * size.width,
                                     y: size.height * (1 - Double(bins[index]) / Double(peak))))
        }
        path.addLine(to: CGPoint(x: size.width, y: size.height)); path.closeSubpath()
        context.fill(path, with: .color(accent.opacity(0.12)))
    }
}
