import SwiftUI
import CoreImage
import ImageIO
import UniformTypeIdentifiers

private struct MagicBrushStroke: Sendable {
    var points: [CGPoint]
    var paints: Bool
    var size: Double
}

private enum MagicEditingMode: String, CaseIterable {
    case points, refine, pan
}

private enum MagicContrastRefiner {
    static let kernel = CIKernel(source: """
    kernel vec4 refineContrast(sampler currentMask, sampler zone, sampler source,
                               sampler foregroundColor, sampler backgroundColor,
                               sampler foregroundWeight, sampler backgroundWeight,
                               float sensitivity) {
        vec2 p = destCoord();
        float original = sample(currentMask, samplerTransform(currentMask, p)).r;
        float amount = sample(zone, samplerTransform(zone, p)).r;
        if (amount < 0.002) return vec4(original);
        vec3 pixel = unpremultiply(sample(source, samplerTransform(source, p))).rgb;
        float fw = sample(foregroundWeight, samplerTransform(foregroundWeight, p)).r;
        float bw = sample(backgroundWeight, samplerTransform(backgroundWeight, p)).r;
        // A stroke only marks the corridor in which the existing boundary may
        // move. It must not turn every contrast inside that corridor into a new
        // island. Require evidence from both sides of the current boundary.
        if (original <= 0.5 && fw < 0.012) return vec4(original);
        if (original > 0.5 && bw < 0.012) return vec4(original);
        vec3 foreground = sample(foregroundColor, samplerTransform(foregroundColor, p)).rgb / max(fw, 0.001);
        vec3 background = sample(backgroundColor, samplerTransform(backgroundColor, p)).rgb / max(bw, 0.001);
        float foregroundDifference = distance(pixel, foreground);
        float backgroundDifference = distance(pixel, background);
        // Classify relative to the two local reference colors. Looking only for
        // a difference from the background accepts dress patterns and branches.
        float foregroundAdvantage = backgroundDifference - foregroundDifference;
        float requiredAdvantage = mix(0.055, -0.012, sensitivity);
        float classified = smoothstep(requiredAdvantage,
                                      requiredAdvantage + 0.035,
                                      foregroundAdvantage);
        float oppositeWeight = original > 0.5 ? bw : fw;
        float boundarySupport = smoothstep(0.012, 0.14, oppositeWeight);
        return vec4(mix(original, classified, amount * boundarySupport));
    }
    """)!
}

struct MagicSelectionView: View {
    let source: CGImage
    let onCancel: () -> Void
    let onValidate: (GeneratedMask) -> Void

    @State private var engine: MagicSelectionEngine
    @State private var points: [MagicSelectionPoint] = []
    @State private var preview: CGImage?
    @State private var maskOnlyPreview: CGImage?
    @State private var includes = true
    @State private var candidate = 0
    @State private var editingMode = MagicEditingMode.points
    @State private var brushStrokes: [MagicBrushStroke] = []
    @State private var liveStroke: [CGPoint] = []
    @State private var brushBase: GeneratedMask?
    @State private var showingMaskOnly = false
    @State private var refinementSensitivity = 50.0
    @State private var busy = true
    @State private var status = String(localized: "Preparing Magic Selection…")
    @State private var zoom: CGFloat = 1
    @State private var offset = CGSize.zero
    @GestureState private var magnification: CGFloat = 1
    @GestureState private var translation = CGSize.zero

    init(source: CGImage, onCancel: @escaping () -> Void,
         onValidate: @escaping (GeneratedMask) -> Void) {
        self.source = source
        self.onCancel = onCancel
        self.onValidate = onValidate
        _engine = State(initialValue: MagicSelectionEngine(source: source))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Text("Touch the element to select. Add points to extend the selection, or remove points to exclude an area.")
                    .font(.callout).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                GeometryReader { geometry in
                    let imageSize = CGSize(width: source.width, height: source.height)
                    let fitted = aspectFit(imageSize, in: CGRect(origin: .zero, size: geometry.size))
                    let displayZoom = min(6, max(1, zoom * magnification))
                    let displayOffset = CGSize(width: offset.width + translation.width,
                                               height: offset.height + translation.height)
                    ZStack(alignment: .topLeading) {
                        Image(decorative: source, scale: 1).resizable().aspectRatio(contentMode: .fit)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .scaleEffect(displayZoom).offset(displayOffset)
                            .opacity(showingMaskOnly ? 0 : 1)
                        if let displayedPreview = showingMaskOnly ? maskOnlyPreview : preview {
                            Image(decorative: displayedPreview, scale: 1).resizable().aspectRatio(contentMode: .fit)
                                .frame(width: geometry.size.width, height: geometry.size.height)
                                .scaleEffect(displayZoom).offset(displayOffset).allowsHitTesting(false)
                        }
                        ForEach(points) { point in
                            Circle().fill(point.includes ? .green : .red).frame(width: 18, height: 18)
                                .overlay(Circle().stroke(.white, lineWidth: 2))
                                .position(displayPosition(point.location, fitted: fitted,
                                                          viewSize: geometry.size,
                                                          zoom: displayZoom,
                                                          offset: displayOffset))
                        }
                        if editingMode != .points {
                            brushOverlay(fitted: fitted, viewSize: geometry.size,
                                         zoom: displayZoom, offset: displayOffset)
                        }
                    }
                    .clipped()
                    .contentShape(Rectangle())
                    .gesture(SpatialTapGesture().onEnded { tap in
                        guard editingMode == .points else { return }
                        let location = imageLocation(tap.location, fitted: fitted,
                                                     viewSize: geometry.size,
                                                     zoom: displayZoom,
                                                     offset: displayOffset)
                        guard !busy, points.count < 8,
                              (0...1).contains(location.x), (0...1).contains(location.y) else { return }
                        points.append(MagicSelectionPoint(location: location, includes: includes))
                        updateMask()
                    })
                    .simultaneousGesture(MagnifyGesture()
                        .updating($magnification) { value, state, _ in state = value.magnification }
                        .onEnded { value in
                            zoom = min(6, max(1, zoom * value.magnification))
                            if zoom == 1 { offset = .zero }
                        })
                    .simultaneousGesture(DragGesture(minimumDistance: editingMode == .refine ? 0 : 8)
                        .updating($translation) { value, state, _ in
                            if zoom > 1 && (editingMode == .points || editingMode == .pan) {
                                state = value.translation
                            }
                        }
                        .onChanged { value in
                            guard editingMode == .refine else { return }
                            let point = imageLocation(value.location, fitted: fitted,
                                                      viewSize: geometry.size,
                                                      zoom: displayZoom, offset: displayOffset)
                            if (0...1).contains(point.x), (0...1).contains(point.y) {
                                liveStroke.append(point)
                            }
                        }
                        .onEnded { value in
                            if editingMode == .refine {
                                guard !liveStroke.isEmpty else { return }
                                let imageDiameter = 44 / max(1, min(fitted.width, fitted.height) * displayZoom) * 100
                                brushStrokes.append(MagicBrushStroke(points: liveStroke,
                                                                     paints: true,
                                                                     size: imageDiameter))
                                liveStroke = []
                                refreshBrushPreview()
                            } else if zoom > 1 {
                                offset.width += value.translation.width
                                offset.height += value.translation.height
                            }
                        })
                    .onTapGesture(count: 2) { zoom = 1; offset = .zero }
                }
                if editingMode == .points {
                    Picker("Point mode", selection: $includes) {
                        Text("Add a point").tag(true)
                        Text("Remove a point").tag(false)
                    }.pickerStyle(.segmented)
                } else {
                    Picker("Brush mode", selection: $editingMode) {
                        Text("Refine edges").tag(MagicEditingMode.refine)
                        Text("Pan").tag(MagicEditingMode.pan)
                    }.pickerStyle(.segmented)
                    Button {
                        showingMaskOnly.toggle()
                    } label: {
                        Label(showingMaskOnly ? "Show photo and mask" : "Show mask only",
                              systemImage: showingMaskOnly ? "photo" : "eye")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    HStack {
                        Text("Sensitivity")
                        Slider(value: $refinementSensitivity, in: 0...100, step: 1) { editing in
                            if !editing { refreshBrushPreview() }
                        }
                        Text("\(Int(refinementSensitivity))")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary).frame(width: 30, alignment: .trailing)
                    }
                }
                if preview != nil && editingMode == .points {
                    Picker("Selection variation", selection: $candidate) {
                        Text("Selection 1").tag(0)
                        Text("Selection 2").tag(1)
                        Text("Selection 3").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: candidate) { _, _ in showCandidate() }
                }
                HStack {
                    if editingMode == .points {
                        Button("Clear points") { points = []; preview = nil; brushStrokes = [] }
                            .disabled(points.isEmpty || busy)
                    } else {
                        Button("Back to points") {
                            editingMode = .points
                            showingMaskOnly = false
                            brushStrokes = []
                            brushBase = nil
                            showCandidate()
                        }
                        Button("Undo brush stroke") {
                            _ = brushStrokes.popLast()
                            refreshBrushPreview()
                        }
                            .disabled(brushStrokes.isEmpty)
                    }
                    Spacer()
                    if busy { ProgressView() }
                    Text(status).font(.caption).foregroundStyle(.secondary)
                }
                Button {
                    beginBrushEditing()
                } label: {
                    Label("Refine with brush", systemImage: "paintbrush.pointed")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.mint)
                .disabled(points.isEmpty || busy || preview == nil || editingMode != .points)
            }
            .padding()
            .background(.black).foregroundStyle(.white)
            .navigationTitle("Magic Selection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: onCancel) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Validate") { validate() }
                        .disabled(points.isEmpty || busy || preview == nil)
                }
            }
            .task {
                do {
                    try await engine.prepare()
                    status = String(localized: "Ready")
                } catch { status = error.localizedDescription }
                busy = false
            }
        }
    }

    private func updateMask() {
        busy = true
        status = String(localized: "Updating selection…")
        let requested = points
        Task {
            do {
                preview = try await engine.select(points: requested)
                candidate = await engine.selectedCandidateIndex()
                status = String(localized: "Selection updated")
            } catch { status = error.localizedDescription }
            busy = false
        }
    }

    private func showCandidate() {
        guard preview != nil, !busy else { return }
        Task {
            do {
                preview = try await engine.selectCandidate(candidate)
                status = String(localized: "Selection updated")
            } catch {
                status = error.localizedDescription
            }
        }
    }

    private func validate() {
        busy = true
        status = String(localized: "Preparing mask…")
        Task {
            do {
                let generated = try await engine.finalizedMask()
                onValidate(try applyContrastRefinement(brushStrokes, to: generated))
            }
            catch { status = error.localizedDescription; busy = false }
        }
    }

    private func brushOverlay(fitted: CGRect, viewSize: CGSize,
                              zoom: CGFloat, offset: CGSize) -> some View {
        Canvas { context, _ in
            for stroke in liveStroke.isEmpty ? [] : [MagicBrushStroke(
                points: liveStroke, paints: true,
                size: 44 / max(1, min(fitted.width, fitted.height) * zoom) * 100)] {
                let positions = stroke.points.map {
                    displayPosition($0, fitted: fitted, viewSize: viewSize, zoom: zoom, offset: offset)
                }
                guard let first = positions.first else { continue }
                var path = Path(); path.move(to: first)
                for point in positions.dropFirst() { path.addLine(to: point) }
                let width = min(fitted.width, fitted.height) * CGFloat(stroke.size / 100) * zoom
                context.stroke(path, with: .color(.yellow.opacity(0.45)),
                               style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
                if positions.count == 1 {
                    context.fill(Path(ellipseIn: CGRect(x: first.x - width / 2, y: first.y - width / 2,
                                                        width: width, height: width)),
                                 with: .color(.yellow.opacity(0.45)))
                }
            }
        }.allowsHitTesting(false)
    }

    private func beginBrushEditing() {
        busy = true
        status = String(localized: "Preparing mask…")
        Task {
            do {
                let base = try await engine.finalizedMask()
                brushBase = base
                brushStrokes = []
                preview = try maskOverlay(base)
                maskOnlyPreview = try maskOverlay(base, whiteOnBlack: true)
                editingMode = .refine
                status = String(localized: "Draw over an edge to refine it")
            } catch {
                status = error.localizedDescription
            }
            busy = false
        }
    }

    private func refreshBrushPreview() {
        guard let brushBase else { return }
        do {
            let refined = try applyContrastRefinement(brushStrokes, to: brushBase)
            preview = try maskOverlay(refined)
            maskOnlyPreview = try maskOverlay(refined, whiteOnBlack: true)
            status = String(localized: "Mask updated")
        } catch {
            status = error.localizedDescription
        }
    }

    private func maskOverlay(_ mask: GeneratedMask, whiteOnBlack: Bool = false) throws -> CGImage {
        guard let input = CIImage(data: mask.pngData) else { throw MagicSelectionError.encodingFailed }
        let extent = input.extent
        let foregroundColor = whiteOnBlack
            ? CIColor(red: 1, green: 1, blue: 1, alpha: 1)
            : CIColor(red: 132 / 255, green: 0, blue: 0, alpha: 132 / 255)
        let foreground = CIImage(color: foregroundColor).cropped(to: extent)
        let background = CIImage(color: whiteOnBlack ? .black : .clear).cropped(to: extent)
        let blend = CIFilter.blendWithMask()
        blend.inputImage = foreground
        blend.backgroundImage = background
        blend.maskImage = input
        guard let output = blend.outputImage,
              let color = CGColorSpace(name: CGColorSpace.sRGB),
              let image = CIContext(options: [.cacheIntermediates: false]).createCGImage(
                output, from: extent, format: .RGBA8, colorSpace: color)
        else { throw MagicSelectionError.encodingFailed }
        return image
    }

    private func applyContrastRefinement(_ strokes: [MagicBrushStroke], to mask: GeneratedMask) throws -> GeneratedMask {
        guard !strokes.isEmpty else { return mask }
        guard let source = CGImageSourceCreateWithData(mask.pngData as CFData, nil),
              let cgMask = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw MagicSelectionError.encodingFailed
        }
        let context = CIContext(options: [.cacheIntermediates: false])
        let extent = CGRect(x: 0, y: 0, width: mask.width, height: mask.height)
        let currentMask = CIImage(cgImage: cgMask).cropped(to: extent)
        var zone = CIImage(color: .black).cropped(to: extent)
        for stroke in strokes {
            let radius = min(extent.width, extent.height) * stroke.size / 200
            for point in interpolated(stroke.points, radius: radius, extent: extent) {
                let gradient = CIFilter.radialGradient()
                gradient.center = CGPoint(x: extent.width * point.x,
                                          y: extent.height * (1 - point.y))
                gradient.radius0 = Float(max(0, radius - 0.75))
                gradient.radius1 = Float(max(0.5, radius))
                gradient.color0 = .white; gradient.color1 = .black
                guard let dot = gradient.outputImage else { continue }
                let filter = CIFilter.maximumCompositing()
                filter.inputImage = dot; filter.backgroundImage = zone
                if let output = filter.outputImage { zone = output.cropped(to: extent) }
            }
        }
        let sourceImage = CIImage(cgImage: self.source).transformed(by: CGAffineTransform(
            scaleX: extent.width / CGFloat(self.source.width),
            y: extent.height / CGFloat(self.source.height))).cropped(to: extent)
        let invert = CIFilter.colorInvert(); invert.inputImage = currentMask
        guard let backgroundMask = invert.outputImage else { throw MagicSelectionError.encodingFailed }
        let black = CIImage(color: .black).cropped(to: extent)
        let foregroundBlend = CIFilter.blendWithMask()
        foregroundBlend.inputImage = sourceImage
        foregroundBlend.backgroundImage = black
        foregroundBlend.maskImage = currentMask
        let backgroundBlend = CIFilter.blendWithMask()
        backgroundBlend.inputImage = sourceImage
        backgroundBlend.backgroundImage = black
        backgroundBlend.maskImage = backgroundMask
        guard let foregroundPixels = foregroundBlend.outputImage,
              let backgroundPixels = backgroundBlend.outputImage else {
            throw MagicSelectionError.encodingFailed
        }
        // Keep the reference colors close to the boundary. A broad average mixes
        // skin, hair and background together and consequently misses thin strands,
        // even when they contrast strongly with the pixels directly behind them.
        let averageRadius = max(2, min(18, min(extent.width, extent.height) * 0.0035))
        func blurred(_ image: CIImage) -> CIImage {
            image.clampedToExtent().applyingFilter("CIGaussianBlur",
                                                   parameters: [kCIInputRadiusKey: averageRadius])
                .cropped(to: extent)
        }
        guard let result = MagicContrastRefiner.kernel.apply(
            extent: extent,
            roiCallback: { _, rect in rect.insetBy(dx: -averageRadius * 2,
                                                    dy: -averageRadius * 2) },
            arguments: [currentMask, zone, sourceImage,
                        blurred(foregroundPixels), blurred(backgroundPixels),
                        blurred(currentMask), blurred(backgroundMask),
                        NSNumber(value: refinementSensitivity / 100)])
        else { throw MagicSelectionError.encodingFailed }
        let width = mask.width
        let height = mask.height
        let rowBytes = width
        var originalBytes = [UInt8](repeating: 0, count: width * height)
        var proposedBytes = [UInt8](repeating: 0, count: width * height)
        guard let gray = CGColorSpace(name: CGColorSpace.linearGray) else {
            throw MagicSelectionError.encodingFailed
        }
        context.render(currentMask, toBitmap: &originalBytes, rowBytes: rowBytes,
                       bounds: extent, format: .L8, colorSpace: gray)
        context.render(result, toBitmap: &proposedBytes, rowBytes: rowBytes,
                       bounds: extent, format: .L8, colorSpace: gray)
        let connectedBytes = connectedBoundaryChanges(original: originalBytes,
                                                      proposed: proposedBytes,
                                                      width: width, height: height)
        guard let provider = CGDataProvider(data: Data(connectedBytes) as CFData),
              let image = CGImage(width: width, height: height,
                                  bitsPerComponent: 8, bitsPerPixel: 8,
                                  bytesPerRow: rowBytes, space: gray,
                                  bitmapInfo: CGBitmapInfo(rawValue: 0),
                                  provider: provider, decode: nil,
                                  shouldInterpolate: true, intent: .defaultIntent)
        else { throw MagicSelectionError.encodingFailed }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil)
        else { throw MagicSelectionError.encodingFailed }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw MagicSelectionError.encodingFailed }
        return GeneratedMask(kind: .magic, pngData: data as Data, width: image.width, height: image.height)
    }

    /// Keeps only proposed additions that connect back to the selected region,
    /// and proposed removals that connect back to the background. This prevents
    /// isolated texture edges inside the painted corridor from becoming mask
    /// islands or holes.
    private func connectedBoundaryChanges(original: [UInt8], proposed: [UInt8],
                                          width: Int, height: Int) -> [UInt8] {
        guard original.count == proposed.count, original.count == width * height else {
            return original
        }
        let count = original.count
        var direction = [Int8](repeating: 0, count: count)
        for index in 0..<count {
            let delta = Int(proposed[index]) - Int(original[index])
            if delta > 2 { direction[index] = 1 }
            else if delta < -2 { direction[index] = -1 }
        }

        let neighbors = [(-1, -1), (0, -1), (1, -1),
                         (-1, 0),           (1, 0),
                         (-1, 1),  (0, 1),  (1, 1)]
        var connected = [Bool](repeating: false, count: count)
        var queue: [Int] = []
        queue.reserveCapacity(min(count, 65_536))

        func touchesOriginalSide(_ index: Int, adding: Bool) -> Bool {
            let x = index % width
            let y = index / width
            for (dx, dy) in neighbors {
                let nx = x + dx, ny = y + dy
                guard nx >= 0, nx < width, ny >= 0, ny < height else { continue }
                let selected = original[ny * width + nx] >= 128
                if selected == adding { return true }
            }
            return false
        }

        for index in 0..<count where direction[index] != 0 {
            let adding = direction[index] > 0
            if touchesOriginalSide(index, adding: adding) {
                connected[index] = true
                queue.append(index)
            }
        }

        var cursor = 0
        while cursor < queue.count {
            let index = queue[cursor]
            cursor += 1
            let x = index % width
            let y = index / width
            for (dx, dy) in neighbors {
                let nx = x + dx, ny = y + dy
                guard nx >= 0, nx < width, ny >= 0, ny < height else { continue }
                let neighbor = ny * width + nx
                guard !connected[neighbor], direction[neighbor] == direction[index] else { continue }
                connected[neighbor] = true
                queue.append(neighbor)
            }
        }

        var output = proposed
        for index in 0..<count where direction[index] != 0 && !connected[index] {
            output[index] = original[index]
        }
        return output
    }

    private func interpolated(_ points: [CGPoint], radius: CGFloat, extent: CGRect) -> [CGPoint] {
        guard let first = points.first else { return [] }
        var output = [first]
        let spacing = max(1, radius * 0.35)
        for point in points.dropFirst() {
            let previous = output.last ?? first
            let count = max(1, Int(ceil(hypot((point.x - previous.x) * extent.width,
                                              (point.y - previous.y) * extent.height) / spacing)))
            for step in 1...count {
                let t = CGFloat(step) / CGFloat(count)
                output.append(CGPoint(x: previous.x + (point.x - previous.x) * t,
                                      y: previous.y + (point.y - previous.y) * t))
            }
        }
        return output
    }

    private func aspectFit(_ size: CGSize, in bounds: CGRect) -> CGRect {
        let scale = min(bounds.width / size.width, bounds.height / size.height)
        let fitted = CGSize(width: size.width * scale, height: size.height * scale)
        return CGRect(x: bounds.midX - fitted.width / 2, y: bounds.midY - fitted.height / 2,
                      width: fitted.width, height: fitted.height)
    }

    private func displayPosition(_ location: CGPoint, fitted: CGRect, viewSize: CGSize,
                                 zoom: CGFloat, offset: CGSize) -> CGPoint {
        let center = CGPoint(x: viewSize.width / 2, y: viewSize.height / 2)
        let base = CGPoint(x: fitted.minX + location.x * fitted.width,
                           y: fitted.minY + location.y * fitted.height)
        return CGPoint(x: center.x + (base.x - center.x) * zoom + offset.width,
                       y: center.y + (base.y - center.y) * zoom + offset.height)
    }

    private func imageLocation(_ location: CGPoint, fitted: CGRect, viewSize: CGSize,
                               zoom: CGFloat, offset: CGSize) -> CGPoint {
        let center = CGPoint(x: viewSize.width / 2, y: viewSize.height / 2)
        let base = CGPoint(x: center.x + (location.x - center.x - offset.width) / zoom,
                           y: center.y + (location.y - center.y - offset.height) / zoom)
        return CGPoint(x: (base.x - fitted.minX) / fitted.width,
                       y: (base.y - fitted.minY) / fitted.height)
    }
}
