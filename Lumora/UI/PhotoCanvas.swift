import SwiftUI
import CoreImage

struct PhotoCanvas: View {
    let result: RenderResult
    var clippingOverlay: CGImage? = nil
    var onClippingOverlayAppear: () -> Void = {}
    var curveSampling = false
    var curveSampleLocation: MaskPoint? = nil
    var onCurveSample: (MaskPoint) -> Void = { _ in }
    @Binding var showingOriginal: Bool
    let dlcSettings: DarkenLightenCenterSettings?
    let onDLCBegin: () -> Void
    let onDLCChange: (CGPoint) -> Void
    let onDLCEnd: () -> Void
    let activeMask: LocalMask?
    let activeComponentID: UUID?
    let showsMaskOverlay: Bool
    var maskOutlineOnly = false
    let allowsMaskEditing: Bool
    let brushMode: BrushMode
    let onBrushBegin: () -> Void
    let onBrushPoint: (MaskPoint) -> Void
    let onBrushEnd: () -> Void
    let onMaskTransformBegin: () -> Void
    let onMaskShapeChange: (MaskShape) -> Void
    let onMaskTransformEnd: () -> Void
    let showsGeometryGrid: Bool
    let geometrySettings: GeometrySettings?
    let onGeometryBegin: (String) -> Void
    let onGeometryChange: (GeometryAdjustment, Double) -> Void
    let onGeometryEnd: () -> Void
    @State private var zoom: CGFloat = 1
    @State private var offset = CGSize.zero
    @GestureState private var magnification: CGFloat = 1
    @GestureState private var translation = CGSize.zero
    @GestureState private var pressing = false
    @State private var dlcDragging = false
    @State private var brushActive = false
    @State private var brushLocation: CGPoint?

    private var activeComponent: MaskComponent? {
        activeMask?.components.first { $0.id == activeComponentID }
    }
    private var isPainting: Bool {
        guard allowsMaskEditing, brushMode != .pan else { return false }
        guard let component = activeComponent else { return false }
        if case .brush = component.shape { return true }
        return false
    }
    private var activeBrush: BrushMask? {
        guard let component = activeComponent, case .brush(let brush) = component.shape else { return nil }
        return brush
    }
    private var hasTransformHandles: Bool {
        guard allowsMaskEditing else { return false }
        guard let component = activeComponent else { return false }
        switch component.shape {
        case .linear, .radial: return true
        default: return false
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let image = showingOriginal || pressing ? result.original : result.image
            let displayScale = min(6, max(1, zoom * magnification))
            let displayOffset = CGSize(width: offset.width + (zoom > 1 ? translation.width : 0),
                                       height: offset.height + (zoom > 1 ? translation.height : 0))
            ZStack {
                Image(decorative: image, scale: 1)
                .resizable().aspectRatio(contentMode: .fit)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .overlay {
                    if let clippingOverlay, !showingOriginal && !pressing {
                        Image(decorative: clippingOverlay, scale: 1)
                            .resizable().aspectRatio(contentMode: .fit)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .accessibilityLabel("Zones proches du noir et du blanc sur l’aperçu SDR")
                            .accessibilityIdentifier("clipping-warning-overlay")
                            .allowsHitTesting(false)
                            .onAppear(perform: onClippingOverlayAppear)
                    }
                }
                .scaleEffect(displayScale)
                .offset(displayOffset)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .contentShape(Rectangle())
                .clipped()
                // Attach comparison to the photo itself. Interactive overlays above
                // it keep their touches, so a held mask/crop handle stays draggable.
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 0.3, maximumDistance: 12)
                        .sequenced(before: DragGesture(minimumDistance: 0))
                        .updating($pressing) { value, state, _ in
                            if case .second(true, _) = value { state = true }
                        }
                )
                .simultaneousGesture(DragGesture(minimumDistance: 8).updating($translation) { value, state, _ in
                    if zoom > 1 && !isPainting && !dlcDragging && !curveSampling { state = value.translation }
                }.onEnded { value in
                    if zoom > 1 && !isPainting && !dlcDragging && !curveSampling {
                        offset = bounded(CGSize(width: offset.width + value.translation.width,
                                                height: offset.height + value.translation.height), size: geometry.size)
                    }
                })
                .overlay(alignment: .topLeading) {
                    if showingOriginal || pressing {
                        Text("ORIGINAL").font(.caption.bold()).padding(8)
                            .background(.black.opacity(0.75), in: Capsule()).padding()
                    }
                }
                .overlay {
                    if let activeMask, showsMaskOverlay {
                        MaskOverlay(mask: activeMask, outlineOnly: maskOutlineOnly,
                                    imageSize: CGSize(width: result.image.width, height: result.image.height),
                                    displayScale: displayScale,
                                    displayOffset: displayOffset)
                            .opacity(showsMaskOverlay && !showingOriginal && !pressing ? 1 : 0)
                            .accessibilityHidden(!showsMaskOverlay || showingOriginal || pressing)
                            .allowsHitTesting(false)
                    }
                }
                .overlay {
                    if showsGeometryGrid && !showingOriginal && !pressing {
                        GeometryGrid(imageSize: CGSize(width: result.image.width,
                                                       height: result.image.height))
                            .allowsHitTesting(false)
                    }
                }
                .overlay {
                    if let geometrySettings, !showingOriginal && !pressing {
                        GeometryHandlesOverlay(settings: geometrySettings,
                                               imageSize: CGSize(width: result.image.width,
                                                                 height: result.image.height),
                                               onBegin: onGeometryBegin,
                                               onChange: onGeometryChange,
                                               onEnd: onGeometryEnd)
                    }
                }
                .overlay {
                    if isPainting && !showingOriginal {
                        Color.clear.contentShape(Rectangle())
                            .gesture(brushGesture(viewSize: geometry.size, displayScale: displayScale,
                                                  displayOffset: displayOffset))
                            .overlay {
                                if let brushLocation, let brush = activeBrush,
                                   let diameter = brushDiameter(brush, viewSize: geometry.size,
                                                               imageSize: CGSize(width: result.image.width,
                                                                                 height: result.image.height),
                                                               displayScale: displayScale) {
                                    Circle()
                                        .stroke(brushMode == .paint ? .red : .cyan, lineWidth: 2)
                                        .frame(width: diameter, height: diameter)
                                        .position(brushLocation)
                                        .allowsHitTesting(false)
                                        .accessibilityHidden(true)
                                }
                            }
                            .accessibilityLabel("Zone de peinture du masque")
                            .accessibilityHint(brushMode == .paint ? "Faites glisser pour peindre" : "Faites glisser pour effacer")
                    }
                }
                .overlay {
                    if curveSampling && !showingOriginal {
                        Color.clear.contentShape(Rectangle())
                            .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                                if let point = normalized(value.location, viewSize: geometry.size,
                                    imageSize: CGSize(width: result.image.width, height: result.image.height),
                                    displayScale: displayScale, displayOffset: displayOffset) {
                                    onCurveSample(point)
                                }
                            })
                            .overlay {
                                if let curveSampleLocation {
                                    let rect = sampledImageRect(viewSize: geometry.size,
                                        imageSize: CGSize(width: result.image.width, height: result.image.height),
                                        displayScale: displayScale, displayOffset: displayOffset)
                                    Circle().stroke(.mint, lineWidth: 2).frame(width: 22, height: 22)
                                        .position(x: rect.minX + rect.width * curveSampleLocation.x,
                                                  y: rect.minY + rect.height * curveSampleLocation.y)
                                        .allowsHitTesting(false)
                                }
                            }
                            .accessibilityIdentifier("curve-photo-sampling")
                            .accessibilityLabel("Échantillonner la photographie")
                            .accessibilityElement(children: .ignore)
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Photographie, \(showingOriginal || pressing ? "original" : "développement")")
                .accessibilityValue("Zoom \(Int((zoom * 100).rounded())) %")
                .accessibilityIdentifier("photo-canvas")
                .accessibilityAction(named: "Comparer à l’original") { showingOriginal.toggle() }
                .accessibilityAction(named: "Réinitialiser le zoom") { restoreZoom() }
                if let component = activeComponent, hasTransformHandles,
                   !showingOriginal && !pressing {
                    MaskHandlesOverlay(component: component,
                                       imageSize: CGSize(width: result.image.width,
                                                         height: result.image.height),
                                       displayScale: displayScale,
                                       displayOffset: displayOffset,
                                       onBegin: onMaskTransformBegin,
                                       onChange: onMaskShapeChange,
                                       onEnd: onMaskTransformEnd)
                }
                // Sibling of the accessible image: its handle remains a separate element.
                if let dlcSettings, !showingOriginal && !pressing {
                    DLCCenterOverlay(settings: dlcSettings,
                        imageSize: CGSize(width: result.image.width, height: result.image.height),
                        zoom: displayScale, pan: displayOffset,
                        onBegin: { dlcDragging = true; onDLCBegin() }, onChange: onDLCChange,
                        onEnd: { onDLCEnd(); dlcDragging = false })
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .contentShape(Rectangle())
            .gesture(MagnifyGesture().updating($magnification) { value, state, _ in state = value.magnification }
                .onEnded { value in
                    zoom = min(6, max(1, zoom * value.magnification))
                    offset = bounded(offset, size: geometry.size)
                })
            .simultaneousGesture(TapGesture(count: 2).onEnded { if !isPainting { restoreZoom() } })
        }
        .onChange(of: isPainting) { _, painting in if painting { showingOriginal = false } }
        .onChange(of: hasTransformHandles) { _, editing in
            if editing { showingOriginal = false }
        }
        .onChange(of: geometrySettings != nil) { _, editing in
            if editing { zoom = 1; offset = .zero; showingOriginal = false }
        }
    }
    private func brushGesture(viewSize: CGSize, displayScale: CGFloat,
                              displayOffset: CGSize) -> some Gesture {
        TapGesture(count: 2).map { true }
        .exclusively(before: DragGesture(minimumDistance: 0))
        .onChanged { gesture in
            guard case .second(let value) = gesture else { return }
            if !brushActive { brushActive = true; onBrushBegin() }
            brushLocation = value.location
            if let point = normalized(value.location, viewSize: viewSize,
                                      imageSize: CGSize(width: result.image.width,
                                                        height: result.image.height),
                                      displayScale: displayScale,
                                      displayOffset: displayOffset) {
                onBrushPoint(point)
            }
        }
        .onEnded { gesture in
            switch gesture {
            case .first:
                restoreZoom()
            case .second:
                if brushActive { onBrushEnd() }
            }
            brushActive = false
            brushLocation = nil
        }
    }

    private func restoreZoom() {
        zoom = 1
        offset = .zero
    }
    private func bounded(_ value: CGSize, size: CGSize) -> CGSize {
        let x = size.width * (zoom - 1) / 2, y = size.height * (zoom - 1) / 2
        return CGSize(width: min(x, max(-x, value.width)), height: min(y, max(-y, value.height)))
    }
    private func sampledImageRect(viewSize: CGSize, imageSize: CGSize,
                                  displayScale: CGFloat, displayOffset: CGSize) -> CGRect {
        let scale = min(viewSize.width / imageSize.width, viewSize.height / imageSize.height)
        let fitted = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(x: viewSize.width / 2 - fitted.width * displayScale / 2 + displayOffset.width,
                      y: viewSize.height / 2 - fitted.height * displayScale / 2 + displayOffset.height,
                      width: fitted.width * displayScale, height: fitted.height * displayScale)
    }
    private func normalized(_ location: CGPoint, viewSize: CGSize, imageSize: CGSize,
                            displayScale: CGFloat, displayOffset: CGSize) -> MaskPoint? {
        guard imageSize.width > 0, imageSize.height > 0 else { return nil }
        let scale = min(viewSize.width / imageSize.width, viewSize.height / imageSize.height)
        let fitted = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let transformed = CGRect(
            x: viewSize.width / 2 + ((viewSize.width - fitted.width) / 2 - viewSize.width / 2) * displayScale + displayOffset.width,
            y: viewSize.height / 2 + ((viewSize.height - fitted.height) / 2 - viewSize.height / 2) * displayScale + displayOffset.height,
            width: fitted.width * displayScale, height: fitted.height * displayScale)
        guard transformed.contains(location) else { return nil }
        return MaskPoint(x: (location.x - transformed.minX) / transformed.width,
                         y: (location.y - transformed.minY) / transformed.height)
    }
    private func brushDiameter(_ brush: BrushMask, viewSize: CGSize, imageSize: CGSize,
                               displayScale: CGFloat) -> CGFloat? {
        guard imageSize.width > 0, imageSize.height > 0 else { return nil }
        let scale = min(viewSize.width / imageSize.width, viewSize.height / imageSize.height)
        let fitted = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return min(fitted.width, fitted.height) * CGFloat(brush.size / 100) * displayScale
    }
}

private struct GeometryHandlesOverlay: View {
    let settings: GeometrySettings
    let imageSize: CGSize
    let onBegin: (String) -> Void
    let onChange: (GeometryAdjustment, Double) -> Void
    let onEnd: () -> Void
    private let coordinateSpace = "geometry-handles"

    var body: some View {
        GeometryReader { geometry in
            let extent = fittedRect(geometry.size)
            let corners = perspectiveCorners(in: extent)
            ZStack {
                Path { path in
                    path.move(to: corners.topLeft)
                    path.addLine(to: corners.topRight)
                    path.addLine(to: corners.bottomRight)
                    path.addLine(to: corners.bottomLeft)
                    path.closeSubpath()
                }
                .stroke(.orange.opacity(0.9), style: StrokeStyle(lineWidth: 2, dash: [7, 4]))

                perspectiveHandle(.topLeft, position: corners.topLeft, extent: extent,
                                  identifier: "geometry-handle-perspective-top-left")
                perspectiveHandle(.topRight, position: corners.topRight, extent: extent,
                                  identifier: "geometry-handle-perspective-top-right")
                perspectiveHandle(.bottomRight, position: corners.bottomRight, extent: extent,
                                  identifier: "geometry-handle-perspective-bottom-right")
                perspectiveHandle(.bottomLeft, position: corners.bottomLeft, extent: extent,
                                  identifier: "geometry-handle-perspective-bottom-left")

                MaskDragHandle(position: cropPosition(in: extent), color: .white,
                               identifier: "geometry-handle-crop-position",
                               label: "Position du recadrage", coordinateSpace: coordinateSpace,
                               onBegin: { onBegin("Position du recadrage") }) { location in
                    let point = normalized(location, in: extent)
                    let crop = GeometryDirectManipulation.cropPosition(normalizedPoint: point)
                    onChange(.cropX, crop.x)
                    onChange(.cropY, crop.y)
                } onEnd: { onEnd() }

                MaskDragHandle(position: cropZoomPosition(in: extent), color: .cyan,
                               identifier: "geometry-handle-crop-zoom",
                               label: "Zoom du recadrage", coordinateSpace: coordinateSpace,
                               onBegin: { onBegin("Zoom du recadrage") }) { location in
                    let point = normalized(location, in: extent)
                    onChange(.cropZoom,
                             GeometryDirectManipulation.cropZoom(normalizedY: Double(point.y)))
                } onEnd: { onEnd() }
            }
        }
        .coordinateSpace(name: coordinateSpace)
        .accessibilityElement(children: .contain)
    }

    private func perspectiveHandle(_ corner: GeometryPerspectiveCorner, position: CGPoint,
                                   extent: CGRect, identifier: String) -> some View {
        MaskDragHandle(position: position, color: .orange, identifier: identifier,
                       label: "Coin de perspective", coordinateSpace: coordinateSpace,
                       onBegin: { onBegin("Perspective directe") }) { location in
            let correction = GeometryDirectManipulation.perspective(
                corner: corner, normalizedPoint: normalized(location, in: extent))
            onChange(.perspectiveVertical, correction.vertical)
            onChange(.perspectiveHorizontal, correction.horizontal)
        } onEnd: { onEnd() }
    }

    private func perspectiveCorners(in extent: CGRect) -> (topLeft: CGPoint, topRight: CGPoint,
                                                          bottomRight: CGPoint, bottomLeft: CGPoint) {
        let vertical = CGFloat(settings.perspectiveVertical / 100) * extent.width * 0.22
        let horizontal = CGFloat(settings.perspectiveHorizontal / 100) * extent.height * 0.22
        let topInset = max(0, vertical), bottomInset = max(0, -vertical)
        let rightInset = max(0, horizontal), leftInset = max(0, -horizontal)
        return (
            CGPoint(x: extent.minX + topInset, y: extent.minY + leftInset),
            CGPoint(x: extent.maxX - topInset, y: extent.minY + rightInset),
            CGPoint(x: extent.maxX - bottomInset, y: extent.maxY - rightInset),
            CGPoint(x: extent.minX + bottomInset, y: extent.maxY - leftInset)
        )
    }

    private func cropPosition(in extent: CGRect) -> CGPoint {
        CGPoint(x: extent.minX + extent.width * CGFloat(0.5 + settings.cropX / 200),
                y: extent.minY + extent.height * CGFloat(0.5 - settings.cropY / 200))
    }

    private func cropZoomPosition(in extent: CGRect) -> CGPoint {
        CGPoint(x: extent.midX,
                y: extent.maxY - extent.height * CGFloat(settings.cropZoom / 100 * 0.35))
    }

    private func normalized(_ point: CGPoint, in extent: CGRect) -> CGPoint {
        CGPoint(x: min(1, max(0, (point.x - extent.minX) / max(1, extent.width))),
                y: min(1, max(0, (point.y - extent.minY) / max(1, extent.height))))
    }

    private func fittedRect(_ canvas: CGSize) -> CGRect {
        let imageRatio = imageSize.width / max(1, imageSize.height)
        let canvasRatio = canvas.width / max(1, canvas.height)
        let fitted: CGSize = imageRatio > canvasRatio
            ? CGSize(width: canvas.width, height: canvas.width / imageRatio)
            : CGSize(width: canvas.height * imageRatio, height: canvas.height)
        return CGRect(x: (canvas.width - fitted.width) / 2,
                      y: (canvas.height - fitted.height) / 2,
                      width: fitted.width, height: fitted.height)
    }
}

private struct MaskHandlesOverlay: View {
    let component: MaskComponent
    let imageSize: CGSize
    let displayScale: CGFloat
    let displayOffset: CGSize
    let onBegin: () -> Void
    let onChange: (MaskShape) -> Void
    let onEnd: () -> Void
    private let coordinateSpace = "mask-handles"

    var body: some View {
        GeometryReader { geometry in
            let extent = fittedRect(geometry.size)
            switch component.shape {
            case .linear(let linear):
                linearHandles(linear, extent: extent)
            case .radial(let radial):
                radialHandles(radial, extent: extent)
            default:
                EmptyView()
            }
        }
        .coordinateSpace(name: coordinateSpace)
        .accessibilityElement(children: .contain)
    }

    private func linearHandles(_ linear: LinearGradientMask, extent: CGRect) -> some View {
        let center = screenPoint(linear.center, in: extent)
        let radians = CGFloat(linear.angle) * .pi / 180
        let unit = CGVector(dx: cos(radians), dy: sin(radians))
        let distance = min(extent.width, extent.height) * 0.28
        let direction = CGPoint(x: center.x + unit.dx * distance,
                                y: center.y + unit.dy * distance)
        let transitionHalfWidth = hypot(extent.width, extent.height)
            * CGFloat(0.08 + linear.feather / 100 * 0.42) / 2
        let feather = CGPoint(x: center.x - unit.dx * transitionHalfWidth,
                              y: center.y - unit.dy * transitionHalfWidth)
        return ZStack {
            Path { path in
                path.move(to: feather)
                path.addLine(to: direction)
            }
            .stroke(.white.opacity(0.9), style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
            MaskDragHandle(position: center, color: .white,
                           identifier: "mask-handle-center", label: "Centre du dégradé",
                           coordinateSpace: coordinateSpace, onBegin: onBegin) { location in
                var updated = linear
                updated.center = normalized(location, in: extent)
                onChange(.linear(updated.validated))
            } onEnd: { onEnd() }
            MaskDragHandle(position: direction, color: .yellow,
                           identifier: "mask-handle-direction", label: "Angle du dégradé",
                           coordinateSpace: coordinateSpace, onBegin: onBegin) { location in
                var updated = linear
                let angle = atan2(location.y - center.y, location.x - center.x) * 180 / .pi
                updated.angle = Double(angle)
                onChange(.linear(updated.validated))
            } onEnd: { onEnd() }
            MaskDragHandle(position: feather, color: .orange,
                           identifier: "mask-handle-feather", label: "Contour progressif du dégradé",
                           coordinateSpace: coordinateSpace, onBegin: onBegin) { location in
                var updated = linear
                let projectedDistance = max(0,
                    -((location.x - center.x) * unit.dx + (location.y - center.y) * unit.dy))
                let diagonal = max(1, hypot(extent.width, extent.height))
                updated.feather = Double(((projectedDistance * 2 / diagonal) - 0.08) / 0.42 * 100)
                onChange(.linear(updated.validated))
            } onEnd: { onEnd() }
        }
    }

    private func radialHandles(_ radial: RadialGradientMask, extent: CGRect) -> some View {
        let center = screenPoint(radial.center, in: extent)
        let horizontal = CGPoint(x: min(extent.maxX, center.x + extent.width * radial.radiusX), y: center.y)
        let vertical = CGPoint(x: center.x, y: min(extent.maxY, center.y + extent.height * radial.radiusY))
        let innerScale = CGFloat(1 - radial.feather / 100)
        let feather = CGPoint(x: center.x - extent.width * radial.radiusX * innerScale * 0.707,
                              y: center.y - extent.height * radial.radiusY * innerScale * 0.707)
        let innerRect = CGRect(x: center.x - extent.width * radial.radiusX * innerScale,
                               y: center.y - extent.height * radial.radiusY * innerScale,
                               width: extent.width * radial.radiusX * innerScale * 2,
                               height: extent.height * radial.radiusY * innerScale * 2)
        return ZStack {
            Path { path in
                path.move(to: center); path.addLine(to: horizontal)
                path.move(to: center); path.addLine(to: vertical)
                path.move(to: center); path.addLine(to: feather)
            }
            .stroke(.white.opacity(0.9), style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
            Path(ellipseIn: innerRect)
                .stroke(.orange.opacity(0.9), style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
            MaskDragHandle(position: center, color: .white,
                           identifier: "mask-handle-center", label: "Centre du radial",
                           coordinateSpace: coordinateSpace, onBegin: onBegin) { location in
                var updated = radial
                updated.center = normalized(location, in: extent)
                onChange(.radial(updated.validated))
            } onEnd: { onEnd() }
            MaskDragHandle(position: horizontal, color: .yellow,
                           identifier: "mask-handle-radius-x", label: "Largeur du radial",
                           coordinateSpace: coordinateSpace, onBegin: onBegin) { location in
                var updated = radial
                updated.radiusX = Double(abs(location.x - center.x) / max(1, extent.width))
                onChange(.radial(updated.validated))
            } onEnd: { onEnd() }
            MaskDragHandle(position: vertical, color: .yellow,
                           identifier: "mask-handle-radius-y", label: "Hauteur du radial",
                           coordinateSpace: coordinateSpace, onBegin: onBegin) { location in
                var updated = radial
                updated.radiusY = Double(abs(location.y - center.y) / max(1, extent.height))
                onChange(.radial(updated.validated))
            } onEnd: { onEnd() }
            MaskDragHandle(position: feather, color: .orange,
                           identifier: "mask-handle-feather", label: "Contour progressif du radial",
                           coordinateSpace: coordinateSpace, onBegin: onBegin) { location in
                var updated = radial
                let normalizedX = (location.x - center.x) / max(1, extent.width * radial.radiusX)
                let normalizedY = (location.y - center.y) / max(1, extent.height * radial.radiusY)
                let innerRadius = min(1, hypot(normalizedX, normalizedY))
                updated.feather = Double((1 - innerRadius) * 100)
                onChange(.radial(updated.validated))
            } onEnd: { onEnd() }
        }
    }

    private func screenPoint(_ point: MaskPoint, in extent: CGRect) -> CGPoint {
        CGPoint(x: extent.minX + extent.width * point.x,
                y: extent.minY + extent.height * point.y)
    }

    private func normalized(_ point: CGPoint, in extent: CGRect) -> MaskPoint {
        MaskPoint(x: Double((point.x - extent.minX) / max(1, extent.width)),
                  y: Double((point.y - extent.minY) / max(1, extent.height))).validated
    }

    private func fittedRect(_ canvas: CGSize) -> CGRect {
        let imageRatio = imageSize.width / max(1, imageSize.height)
        let canvasRatio = canvas.width / max(1, canvas.height)
        let fitted: CGSize = imageRatio > canvasRatio
            ? CGSize(width: canvas.width, height: canvas.width / imageRatio)
            : CGSize(width: canvas.height * imageRatio, height: canvas.height)
        let base = CGRect(x: (canvas.width - fitted.width) / 2,
                          y: (canvas.height - fitted.height) / 2,
                          width: fitted.width, height: fitted.height)
        return CGRect(x: canvas.width / 2 + (base.minX - canvas.width / 2) * displayScale + displayOffset.width,
                      y: canvas.height / 2 + (base.minY - canvas.height / 2) * displayScale + displayOffset.height,
                      width: base.width * displayScale, height: base.height * displayScale)
    }
}

private struct MaskDragHandle: View {
    let position: CGPoint
    let color: Color
    let identifier: String
    let label: String
    let coordinateSpace: String
    let onBegin: () -> Void
    let onChange: (CGPoint) -> Void
    let onEnd: () -> Void
    @State private var dragging = false

    var body: some View {
        Circle()
            .fill(color)
            .stroke(.black.opacity(0.75), lineWidth: 2)
            .frame(width: 22, height: 22)
            .padding(11)
            .contentShape(Circle())
            .position(position)
            .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .named(coordinateSpace))
                .onChanged { value in
                    if !dragging { dragging = true; onBegin() }
                    onChange(value.location)
                }
                .onEnded { _ in dragging = false; onEnd() })
            .accessibilityElement()
            .accessibilityLabel(label)
            .accessibilityIdentifier(identifier)
    }
}

private struct GeometryGrid: View {
    let imageSize: CGSize

    var body: some View {
        Canvas { context, size in
            let extent = fittedRect(size)
            var path = Path()
            for fraction in [1.0 / 3, 2.0 / 3] {
                path.move(to: CGPoint(x: extent.minX + extent.width * fraction, y: extent.minY))
                path.addLine(to: CGPoint(x: extent.minX + extent.width * fraction, y: extent.maxY))
                path.move(to: CGPoint(x: extent.minX, y: extent.minY + extent.height * fraction))
                path.addLine(to: CGPoint(x: extent.maxX, y: extent.minY + extent.height * fraction))
            }
            context.stroke(path, with: .color(.white.opacity(0.72)), lineWidth: 0.8)
            context.stroke(Path(extent), with: .color(.white.opacity(0.5)), lineWidth: 1)
        }
        .accessibilityHidden(true)
    }

    private func fittedRect(_ canvas: CGSize) -> CGRect {
        let imageRatio = imageSize.width / max(1, imageSize.height)
        let canvasRatio = canvas.width / max(1, canvas.height)
        let fitted: CGSize = imageRatio > canvasRatio
            ? CGSize(width: canvas.width, height: canvas.width / imageRatio)
            : CGSize(width: canvas.height * imageRatio, height: canvas.height)
        return CGRect(x: (canvas.width - fitted.width) / 2,
                      y: (canvas.height - fitted.height) / 2,
                      width: fitted.width, height: fitted.height)
    }
}

private struct MaskOverlay: View {
    let mask: LocalMask
    let outlineOnly: Bool
    let imageSize: CGSize
    let displayScale: CGFloat
    let displayOffset: CGSize
    @State private var overlay: CGImage?

    private struct RenderKey: Equatable {
        let mask: LocalMask
        let outlineOnly: Bool
        let imageSize: CGSize
    }

    var body: some View {
        // Keep a concrete view alive before the first bitmap exists; an empty
        // Group does not reliably start its task. Match the photo's canvas frame
        // before applying zoom and pan, including its letterboxed space.
        GeometryReader { geometry in
            if let overlay {
                Image(decorative: overlay, scale: 1)
                    .resizable().aspectRatio(contentMode: .fit)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .scaleEffect(displayScale)
                    .offset(displayOffset)
            }
        }
        .clipped()
        .task(id: RenderKey(mask: mask, outlineOnly: outlineOnly, imageSize: imageSize)) {
            let rendered = await MaskOverlayRenderer.shared.render(mask, imageSize: imageSize, outlineOnly: outlineOnly)
            guard !Task.isCancelled else { return }
            overlay = rendered
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(outlineOnly ? "Contour du masque" : "Superposition rouge du masque")
        .accessibilityIdentifier(outlineOnly ? "mask-outline-overlay" : "mask-red-overlay")
    }
}

private actor MaskOverlayRenderer {
    static let shared = MaskOverlayRenderer()
    private let context = CIContext(options: [.cacheIntermediates: false])

    func render(_ mask: LocalMask, imageSize: CGSize, outlineOnly: Bool) -> CGImage? {
        guard !Task.isCancelled, imageSize.width > 0, imageSize.height > 0 else { return nil }
        let reduction = min(1, 1_024 / max(imageSize.width, imageSize.height))
        let extent = CGRect(x: 0, y: 0,
                            width: max(1, (imageSize.width * reduction).rounded()),
                            height: max(1, (imageSize.height * reduction).rounded()))
        let image: CIImage
        if outlineOnly {
            // Outline the composed footprint at 5% coverage, independently of layer opacity.
            // This display-only matte includes subtraction and inversion, including brush/Vision masks.
            var footprint = mask
            footprint.opacity = 100
            guard let matte = try? MaskRenderer.makeMask(footprint, extent: extent) else { return nil }
            let silhouette = matte.applyingFilter("CIColorThreshold", parameters: ["inputThreshold": 0.05])
            let outer = silhouette.applyingFilter("CIMorphologyMaximum", parameters: ["inputRadius": 1.5])
            let inner = silhouette.applyingFilter("CIMorphologyMinimum", parameters: ["inputRadius": 1.5])
            let edge = outer.applyingFilter("CIDifferenceBlendMode", parameters: [kCIInputBackgroundImageKey: inner])
            image = edge.applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: 0, y: 0, z: 0, w: 0),
                "inputGVector": CIVector(x: 0, y: 0, z: 0, w: 0),
                "inputBVector": CIVector(x: 0, y: 0, z: 0, w: 0),
                "inputAVector": CIVector(x: 0.9, y: 0, z: 0, w: 0),
                "inputBiasVector": CIVector(x: 1, y: 1, z: 1, w: 0)
            ]).cropped(to: extent)
        } else {
            guard let red = try? MaskRenderer.makeRedOverlay(mask, extent: extent) else { return nil }
            image = red
        }
        guard !Task.isCancelled else { return nil }
        return context.createCGImage(image, from: extent)
    }
}
