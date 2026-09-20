import SwiftUI

struct ToneCurveEditor: View {
    let curves: ToneCurves
    let histogram: Histogram
    let onBegin: (String) -> Void
    let onChange: (CurveChannel, ToneCurve) -> Void
    let onEnd: () -> Void
    @State private var channel: CurveChannel = .rgb
    @State private var selected = 0
    @State private var dragging: Int?
    @State private var gestureStarted = false

    private var curve: ToneCurve { curves[channel] }
    private var accent: Color {
        switch channel { case .rgb: .white; case .red: .red; case .green: .green; case .blue: .cyan }
    }
    private var selectedIndex: Int { min(selected, curve.points.count - 1) }
    var body: some View {
        VStack(spacing: 8) {
            Picker("Canal de la courbe", selection: $channel) {
                ForEach(CurveChannel.allCases) { item in Text(item.title).tag(item) }
            }.pickerStyle(.segmented)
                .onChange(of: channel) { _, _ in finishGesture(); selected = 0 }
            GeometryReader { geometry in
                Canvas { context, size in
                    drawHistogram(context: &context, size: size)
                    var grid = Path()
                    for division in 0...4 {
                        let x = size.width * Double(division) / 4, y = size.height * Double(division) / 4
                        grid.move(to: CGPoint(x: x, y: 0)); grid.addLine(to: CGPoint(x: x, y: size.height))
                        grid.move(to: CGPoint(x: 0, y: y)); grid.addLine(to: CGPoint(x: size.width, y: y))
                    }
                    context.stroke(grid, with: .color(.white.opacity(0.12)), lineWidth: 1)
                    var diagonal = Path()
                    diagonal.move(to: CGPoint(x: 0, y: size.height)); diagonal.addLine(to: CGPoint(x: size.width, y: 0))
                    context.stroke(diagonal, with: .color(.white.opacity(0.25)), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    var path = Path()
                    for sample in 0...256 {
                        let x = Double(sample) / 256
                        let point = CGPoint(x: x * size.width, y: (1 - curve.evaluate(x)) * size.height)
                        if sample == 0 { path.move(to: point) } else { path.addLine(to: point) }
                    }
                    context.stroke(path, with: .color(accent), lineWidth: 2)
                    for (index, point) in curve.points.enumerated() {
                        let center = CGPoint(x: point.x * size.width, y: (1 - point.y) * size.height)
                        let radius: CGFloat = index == selectedIndex ? 7 : 5
                        let circle = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
                        context.fill(circle, with: .color(index == selectedIndex ? accent : .black))
                        context.stroke(circle, with: .color(accent), lineWidth: 2)
                    }
                }
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                    guard geometry.size.width > 0, geometry.size.height > 0 else { return }
                    let x = min(1, max(0, value.location.x / geometry.size.width))
                    let y = min(1, max(0, 1 - value.location.y / geometry.size.height))
                    if !gestureStarted {
                        gestureStarted = true
                        onBegin("Courbe \(channel.title)")
                        let nearest = curve.points.indices.min { a, b in
                            distance(curve.points[a], to: value.startLocation, size: geometry.size)
                                < distance(curve.points[b], to: value.startLocation, size: geometry.size)
                        }
                        if let nearest, distance(curve.points[nearest], to: value.startLocation, size: geometry.size) <= 24 {
                            dragging = nearest; selected = nearest
                        } else {
                            var updated = curve
                            if let added = updated.add(x: x, y: y) {
                                dragging = added; selected = added; onChange(channel, updated)
                                return
                            }
                        }
                    }
                    if let dragging {
                        var updated = curve
                        updated.move(index: dragging, x: x, y: y)
                        onChange(channel, updated)
                    }
                }.onEnded { _ in finishGesture() })
                .accessibilityIdentifier("tone-curve-chart")
                .accessibilityLabel("Courbe \(channel.title)")
                .accessibilityValue("\(curve.points.count) points. Utilisez les commandes de point ci-dessous.")
            }
            .frame(height: 155).padding(.horizontal, 8).padding(.vertical, 8)
            HStack {
                Button { selected = max(0, selectedIndex - 1) } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
                    .disabled(selectedIndex == 0).accessibilityLabel("Point précédent")
                Text("Point \(selectedIndex + 1) / \(curve.points.count)").font(.caption.monospacedDigit())
                Button { selected = min(curve.points.count - 1, selectedIndex + 1) } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }
                    .disabled(selectedIndex == curve.points.count - 1).accessibilityLabel("Point suivant")
                Spacer(minLength: 0)
                Button(action: addPoint) { Image(systemName: "plus").frame(width: 44, height: 44) }
                    .disabled(curve.points.count >= ToneCurve.maximumPoints).accessibilityLabel("Ajouter un point")
                Button {
                    var updated = curve; updated.remove(index: selectedIndex)
                    onChange(channel, updated); selected = max(0, selectedIndex - 1)
                } label: { Image(systemName: "trash").frame(width: 44, height: 44) }
                    .disabled(selectedIndex == 0 || selectedIndex == curve.points.count - 1).accessibilityLabel("Supprimer le point")
                Button {
                    onChange(channel, ToneCurve()); selected = 0
                } label: { Image(systemName: "arrow.counterclockwise").frame(width: 44, height: 44) }
                    .accessibilityLabel("Réinitialiser la courbe \(channel.title)")
            }
            coordinateControl("Entrée", horizontal: true)
            coordinateControl("Sortie", horizontal: false)
            Text("Touchez pour ajouter · Glissez pour déplacer").font(.caption2).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .onDisappear(perform: finishGesture)
        .onChange(of: curves) { _, _ in selected = min(selected, curve.points.count - 1) }
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
            .accessibilityValue(String(format: "%.1f", (horizontal ? point.x : point.y) * 100))
            Text((horizontal ? point.x : point.y) * 100, format: .number.precision(.fractionLength(1)))
                .font(.caption.monospacedDigit()).frame(width: 40, alignment: .trailing)
        }.frame(minHeight: 36)
    }
    private func addPoint() {
        // Insert into the widest interval, preserving the current curve's value there.
        let index = (0..<(curve.points.count - 1)).max {
            curve.points[$0 + 1].x - curve.points[$0].x < curve.points[$1 + 1].x - curve.points[$1].x
        } ?? 0
        let x = (curve.points[index].x + curve.points[index + 1].x) / 2
        var updated = curve
        if let added = updated.add(x: x, y: updated.evaluate(x)) {
            onChange(channel, updated); selected = added
        }
    }
    private func finishGesture() {
        if gestureStarted { onEnd() }
        gestureStarted = false; dragging = nil
    }
    private func distance(_ point: CurvePoint, to location: CGPoint, size: CGSize) -> Double {
        hypot(point.x * size.width - location.x, (1 - point.y) * size.height - location.y)
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
            path.addLine(to: CGPoint(x: Double(index) / 255 * size.width, y: size.height * (1 - Double(bins[index]) / Double(peak))))
        }
        path.addLine(to: CGPoint(x: size.width, y: size.height)); path.closeSubpath()
        context.fill(path, with: .color(accent.opacity(0.12)))
    }
}
