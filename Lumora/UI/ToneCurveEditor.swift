import SwiftUI

struct ToneCurveEditor: View {
    let curves: ToneCurves
    let histogram: Histogram
    @Binding var channel: CurveChannel
    @Binding var editMode: Bool
    @Binding var eyedropper: Bool
    @Binding var selected: Int?
    let graphOnly: Bool
    let sample: CurveSample?
    let eyedropperAvailable: Bool
    let onClearSample: () -> Void
    let onBegin: (String) -> Void
    let onChange: (CurveChannel, ToneCurve) -> Void
    let onEnd: () -> Void
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
                Picker("Curve channel", selection: $channel) {
                    ForEach(CurveChannel.allCases) { item in Text(item.title).tag(item) }
                }
                .pickerStyle(.segmented)
                .onChange(of: channel) { _, _ in finishGesture(); selected = nil }
                if !graphOnly {
                    Button {
                        finishGesture()
                        editMode.toggle()
                        if !editMode { eyedropper = false; onClearSample(); selected = nil }
                    } label: {
                        Image(systemName: editMode ? "checkmark" : "pencil")
                    }
                    .buttonStyle(CompactEditorButtonStyle(selected: editMode))
                    .accessibilityLabel(editMode ? "Done" : "Edit")
                    .accessibilityIdentifier("curve-edit-mode")
                }
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
                                            onBegin("\(channel.title) curve")
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
                                .accessibilityLabel(String(format: NSLocalizedString("Point %d on the %@ curve", comment: "Curve point"), index + 1, channel.title))
                                .accessibilityIdentifier("curve-point-\(index)")
                        }
                    }
                }
                .contentShape(Rectangle())
                .overlay(alignment: .topLeading) {
                    if editMode, eyedropper, let sample {
                        Text(String(format: NSLocalizedString("Sample %d %%", comment: "Curve eyedropper"), Int((sample.value(for: channel) * 100).rounded())))
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
                    createPoint(at: value.location, size: geometry.size)
                }, including: editMode ? .all : .none)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("tone-curve-chart")
                .accessibilityLabel(String(format: NSLocalizedString("%@ curve", comment: "Curve chart"), channel.title))
                .accessibilityValue("\(curve.points.count) points. \(editMode ? "Editing" : "Viewing"). " +
                    curve.points.map { String(format: "%.4f:%.4f", $0.x, $0.y) }.joined(separator: ","))
            }
            .frame(height: 155).padding(.horizontal, 8).padding(.vertical, 8)
            if editMode && !graphOnly {
                HStack(spacing: 4) {
                    Spacer(minLength: 0)
                    Button {
                        eyedropper.toggle()
                        onClearSample()
                    } label: { Image(systemName: "eyedropper") }
                        .buttonStyle(CompactEditorButtonStyle(selected: eyedropper))
                        .accessibilityLabel("Eyedropper")
                        .accessibilityIdentifier("curve-eyedropper")
                        .accessibilityAddTraits(eyedropper ? .isSelected : [])
                        .disabled(!eyedropperAvailable)
                        .accessibilityHint(eyedropperAvailable ? "Tap the photo to locate its tone" : "Unavailable on a masked layer")
                    Button(action: addPoint) { Image(systemName: "plus") }
                        .buttonStyle(CompactEditorButtonStyle())
                        .accessibilityLabel(sample == nil ? "Add point" : "Add point from eyedropper")
                        .accessibilityIdentifier("curve-add-point")
                        .disabled(curve.points.count >= ToneCurve.maximumPoints)
                    Button(action: deletePoint) { Image(systemName: "trash") }
                        .buttonStyle(CompactEditorButtonStyle())
                        .accessibilityLabel("Delete point")
                        .accessibilityIdentifier("curve-delete-point")
                        .disabled(!canDelete)
                }
                .padding(.horizontal, 8)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("curve-edit-toolbar")
                HStack {
                    Button { selected = max(0, selectedIndex - 1) } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
                        .disabled(selectedIndex == 0).accessibilityLabel("Previous point")
                    Text("Point \(selectedIndex + 1) / \(curve.points.count)").font(.caption.monospacedDigit())
                    Button { selected = min(curve.points.count - 1, selectedIndex + 1) } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }
                        .disabled(selectedIndex == curve.points.count - 1).accessibilityLabel("Next point")
                    Spacer(minLength: 0)
                    Button { onChange(channel, ToneCurve()); selected = nil } label: {
                        Image(systemName: "arrow.counterclockwise").frame(width: 44, height: 44)
                    }.accessibilityLabel(String(format: NSLocalizedString("Reset %@ curve", comment: "Curve chart"), channel.title))
                }
                coordinateControl("Input", horizontal: true)
                coordinateControl("Output", horizontal: false)
                Text("Tap the curve to add · Drag a point to move")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, graphOnly ? 8 : 16)
        .onDisappear { finishGesture() }
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
                if editing { onBegin("\(channel.title) curve") } else { onEnd() }
            })
            .disabled(horizontal && (selectedIndex == 0 || selectedIndex == curve.points.count - 1))
            .accessibilityLabel("\(title) of point")
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

/// Fixed controls shown below the photo while the curve graph remains on it.
/// Keeping these controls outside the floating card prevents the graph overlay
/// from being rebuilt when a slider or Auto changes the rendered preview.
struct CurvePointControls: View {
    let curves: ToneCurves
    let channel: CurveChannel
    @Binding var selected: Int?
    @Binding var eyedropper: Bool
    let eyedropperAvailable: Bool
    let onClearSample: () -> Void
    let onBegin: (String) -> Void
    let onChange: (CurveChannel, ToneCurve) -> Void
    let onEnd: () -> Void

    private var curve: ToneCurve { curves[channel] }
    private var selectedIndex: Int { min(max(selected ?? 0, 0), max(0, curve.points.count - 1)) }
    private var canDelete: Bool { selectedIndex > 0 && selectedIndex < curve.points.count - 1 }

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Text("Point \(selectedIndex + 1) / \(curve.points.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Button {
                    eyedropper.toggle()
                    onClearSample()
                } label: {
                    Image(systemName: "eyedropper").frame(width: 44, height: 44)
                }
                .buttonStyle(CompactEditorButtonStyle(selected: eyedropper))
                .accessibilityLabel("Eyedropper")
                .accessibilityIdentifier("curve-eyedropper")
                .disabled(!eyedropperAvailable)
                Button {
                    guard canDelete else { return }
                    var updated = curve
                    updated.remove(index: selectedIndex)
                    onChange(channel, updated)
                    selected = nil
                } label: {
                    Image(systemName: "trash").frame(width: 44, height: 44)
                }
                .buttonStyle(CompactEditorButtonStyle())
                .accessibilityLabel("Delete point")
                .accessibilityIdentifier("curve-delete-point")
                .disabled(!canDelete)
            }
            coordinateControl("Input", horizontal: true)
            coordinateControl("Output", horizontal: false)
        }
        .onChange(of: curves) { _, _ in
            if selectedIndex >= curve.points.count { selected = nil }
            onClearSample()
        }
    }

    private func coordinateControl(_ title: LocalizedStringKey, horizontal: Bool) -> some View {
        let point = curve.points[selectedIndex]
        return HStack(spacing: 8) {
            Text(title).font(.caption).frame(width: 48, alignment: .leading)
            Slider(value: Binding(
                get: { (horizontal ? point.x : point.y) * 100 },
                set: { value in
                    var updated = curve
                    updated.move(index: selectedIndex,
                                 x: horizontal ? value / 100 : point.x,
                                 y: horizontal ? point.y : value / 100)
                    onChange(channel, updated)
                }), in: 0...100, step: 0.1,
                onEditingChanged: { editing in
                    if editing { onBegin("\(channel.title) curve") } else { onEnd() }
                })
                .disabled(horizontal && (selectedIndex == 0 || selectedIndex == curve.points.count - 1))
                .accessibilityLabel(title)
            Text((horizontal ? point.x : point.y) * 100,
                 format: .number.precision(.fractionLength(1)))
                .font(.caption.monospacedDigit())
                .frame(width: 42, alignment: .trailing)
        }
        .frame(minHeight: 36)
    }
}

/// Floating curve card. It never participates in workspace layout, so opening,
/// collapsing, or moving it leaves the photo canvas unchanged.
struct CurveOverlayCard: View {
    let curves: ToneCurves
    let histogram: Histogram
    @Binding var channel: CurveChannel
    @Binding var eyedropper: Bool
    @Binding var selectedPoint: Int?
    let sample: CurveSample?
    let eyedropperAvailable: Bool
    let onClearSample: () -> Void
    let onBegin: (String) -> Void
    let onChange: (CurveChannel, ToneCurve) -> Void
    let onEnd: () -> Void

    @State private var collapsed = false
    @State private var offset = CGSize(width: 10, height: 10)
    @State private var dragOrigin: CGSize?

    var body: some View {
        GeometryReader { geometry in
            let cardWidth = min(370, max(280, geometry.size.width - 20))
            let expandedHeight = min(270, max(210, geometry.size.height - 20))
            let cardSize = CGSize(width: cardWidth, height: collapsed ? 46 : expandedHeight)
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                        Text("Curves").font(.subheadline.weight(.semibold))
                        Spacer(minLength: 8)
                    }
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 3)
                        .onChanged { gesture in
                            if dragOrigin == nil { dragOrigin = offset }
                            let origin = dragOrigin ?? offset
                            offset = clamped(
                                CGSize(width: origin.width + gesture.translation.width,
                                       height: origin.height + gesture.translation.height),
                                in: geometry.size,
                                card: cardSize
                            )
                        }
                        .onEnded { _ in dragOrigin = nil })
                    Button {
                        var transaction = Transaction()
                        transaction.disablesAnimations = true
                        withTransaction(transaction) { collapsed.toggle() }
                    } label: {
                        Image(systemName: collapsed ? "chevron.down" : "chevron.up")
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(collapsed ? "Expand curves" : "Collapse curves")
                    .accessibilityIdentifier("curve-card-collapse")
                    .zIndex(1)
                }
                .padding(.leading, 12)
                .frame(height: 46)
                .background(.white.opacity(0.025))

                if !collapsed {
                    VStack(spacing: 5) {
                        ToneCurveEditor(curves: curves, histogram: histogram,
                                        channel: $channel, editMode: .constant(true),
                                        eyedropper: $eyedropper, selected: $selectedPoint,
                                        graphOnly: true, sample: sample,
                                        eyedropperAvailable: eyedropperAvailable,
                                        onClearSample: onClearSample, onBegin: onBegin,
                                        onChange: onChange, onEnd: onEnd)
                    }
                    .accessibilityIdentifier("curve-controls-scroll")
                    .frame(height: expandedHeight - 46, alignment: .top)
                    .background(.clear)
                    .clipped()
                }
            }
            .frame(width: cardWidth, height: collapsed ? 46 : expandedHeight, alignment: .top)
            .background {
                RoundedRectangle(cornerRadius: 15)
                    .fill(.black.opacity(0.40))
            }
            .clipShape(RoundedRectangle(cornerRadius: 15))
            .overlay(RoundedRectangle(cornerRadius: 15).stroke(.white.opacity(0.18), lineWidth: 0.7))
            .offset(offset)
            .transaction { transaction in transaction.disablesAnimations = true }
            .onChange(of: geometry.size) { _, size in
                offset = clamped(offset, in: size,
                                 card: CGSize(width: cardWidth, height: collapsed ? 46 : expandedHeight))
            }
            .onChange(of: collapsed) { _, _ in
                offset = clamped(offset, in: geometry.size,
                                 card: CGSize(width: cardWidth, height: collapsed ? 46 : expandedHeight))
            }
        }
    }

    private func clamped(_ proposed: CGSize, in bounds: CGSize, card: CGSize) -> CGSize {
        CGSize(width: min(max(0, proposed.width), max(0, bounds.width - card.width)),
               height: min(max(0, proposed.height), max(0, bounds.height - card.height)))
    }
}
