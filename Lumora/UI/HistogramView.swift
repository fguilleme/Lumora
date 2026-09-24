import SwiftUI

/// Draws already-computed preview bins. Expanding never resamples pixels;
/// the renderer owns the histogram for the entire edited photograph.
struct HistogramView: View {
    let histogram: Histogram
    let imageSize: CGSize
    let diagnosticActivationCount: Int?
    let onClippingPressChanged: (Bool) -> Void
    @State private var expanded = false
    @State private var longPressConsumed = false
    @State private var dragConsumed = false
    @State private var compactPosition: CGPoint?
    @State private var expandedPosition: CGPoint?
    @GestureState private var clippingPressed = false
    @GestureState private var dragTranslation = CGSize.zero

    init(histogram: Histogram, imageSize: CGSize,
         initiallyExpanded: Bool = false,
         diagnosticActivationCount: Int? = nil,
         onClippingPressChanged: @escaping (Bool) -> Void = { _ in }) {
        self.histogram = histogram
        self.imageSize = imageSize
        self.diagnosticActivationCount = diagnosticActivationCount
        self.onClippingPressChanged = onClippingPressChanged
        _expanded = State(initialValue: initiallyExpanded)
    }

    var body: some View {
        GeometryReader { geometry in
            let photo = imageRect(in: geometry.size)
            let availableWidth = max(1, geometry.size.width - 16)
            let compactWidth = min(availableWidth, min(220, max(128, photo.width * 0.42)))
            let expandedWidth = min(availableWidth, max(280, photo.width * 0.84))
            let width = expanded ? expandedWidth : compactWidth
            let height: CGFloat = expanded ? 150 : 62
            let defaultCenter = CGPoint(x: expanded ? photo.midX : photo.minX + width / 2 + 8,
                                        y: photo.minY + height / 2 + 8)
            let savedPosition = expanded ? expandedPosition : compactPosition
            let baseCenter = savedPosition.map {
                CGPoint(x: $0.x * geometry.size.width, y: $0.y * geometry.size.height)
            } ?? defaultCenter
            let center = bounded(CGPoint(x: baseCenter.x + dragTranslation.width,
                                         y: baseCenter.y + dragTranslation.height),
                                 in: geometry.size, width: width, height: height)
            Button {
                guard !longPressConsumed && !dragConsumed else { return }
                withAnimation(.easeInOut(duration: 0.18)) { expanded.toggle() }
            } label: {
                VStack(spacing: 4) {
                    if expanded {
                        HStack(spacing: 5) {
                            clippingIndicator(fraction: histogram.shadowFraction,
                                              symbol: "arrowtriangle.down.fill", label: "Blacks")
                            Spacer()
                            Text("RGB").font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.72))
                            Spacer()
                            clippingIndicator(fraction: histogram.highlightFraction,
                                              symbol: "arrowtriangle.up.fill", label: "Whites")
                        }
                        .frame(height: 15)
                    }
                    histogramGraph
                }
                .padding(expanded ? 10 : 7)
                .frame(width: width, height: height)
                .background(.black.opacity(0.76), in: RoundedRectangle(cornerRadius: 10))
                .contentShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .simultaneousGesture(clippingGesture)
            .simultaneousGesture(movingGesture(in: geometry.size, from: baseCenter,
                                               width: width, height: height))
            .accessibilityIdentifier("histogram-overlay")
            .accessibilityLabel(expanded ? "Collapse RGB histogram" : "Expand RGB histogram")
            .accessibilityValue("Near-black pixels: \(histogram.shadowFraction.formatted(.percent.precision(.fractionLength(2)))). Near-white pixels: \(histogram.highlightFraction.formatted(.percent.precision(.fractionLength(2)))). SDR preview, not clipping in the original file." + (diagnosticActivationCount.map { " Clipping activations: \($0)." } ?? ""))
            .accessibilityHint(expanded
                ? "Double-tap to collapse. Drag to move. Hold to temporarily show near-black areas in blue and near-white areas in red."
                : "Double-tap to expand. Drag to move. Hold to temporarily show near-black areas in blue and near-white areas in red.")
            .onChange(of: clippingPressed) { _, active in
                if active { longPressConsumed = true }
                onClippingPressChanged(active)
                if !active {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        longPressConsumed = false
                    }
                }
            }
            .onDisappear { onClippingPressChanged(false) }
            .position(center)
        }
    }

    private func movingGesture(in size: CGSize, from baseCenter: CGPoint,
                               width: CGFloat, height: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .updating($dragTranslation) { value, translation, _ in
                translation = value.translation
            }
            .onChanged { _ in dragConsumed = true }
            .onEnded { value in
                let center = bounded(CGPoint(x: baseCenter.x + value.translation.width,
                                             y: baseCenter.y + value.translation.height),
                                     in: size, width: width, height: height)
                let normalized = CGPoint(x: center.x / max(1, size.width),
                                         y: center.y / max(1, size.height))
                if expanded { expandedPosition = normalized } else { compactPosition = normalized }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { dragConsumed = false }
            }
    }

    private func bounded(_ point: CGPoint, in size: CGSize,
                         width: CGFloat, height: CGFloat) -> CGPoint {
        let xInset = min(size.width / 2, width / 2 + 8)
        let yInset = min(size.height / 2, height / 2 + 8)
        return CGPoint(x: min(max(point.x, xInset), size.width - xInset),
                       y: min(max(point.y, yInset), size.height - yInset))
    }

    private var clippingGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.35, maximumDistance: 16)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .updating($clippingPressed) { value, active, _ in
                if case .second(true, _) = value { active = true }
            }
    }

    private var histogramGraph: some View {
        Canvas { context, size in
            let channels: [([Int], Color)] = [(histogram.red, .red),
                                              (histogram.green, .green),
                                              (histogram.blue, .blue)]
            let peak = max(1, channels.map { $0.0.max() ?? 0 }.max() ?? 0)
            context.blendMode = .plusLighter
            for (bins, color) in channels {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: size.height))
                for i in bins.indices {
                    path.addLine(to: CGPoint(x: Double(i) / Double(Histogram.endpointBin) * size.width,
                                             y: size.height * (1 - Histogram.displayedHeight(bins[i], peak: peak))))
                }
                path.addLine(to: CGPoint(x: size.width, y: size.height))
                path.closeSubpath()
                context.fill(path, with: .color(color.opacity(0.48)))
            }
        }
        .accessibilityHidden(true)
    }

    private func clippingIndicator(fraction: Double, symbol: String, label: String) -> some View {
        // A few outlier samples do not create a conspicuous warning. The
        // indicator communicates endpoint occupancy, never RAW recoverability.
        return Group {
            if fraction >= 0.002 {
                HStack(spacing: 3) {
                    Image(systemName: symbol).font(.system(size: 8, weight: .medium))
                    Text(label).font(.system(size: 9, weight: .medium))
                }
                .foregroundStyle(.white.opacity(min(0.85, 0.3 + sqrt(fraction))))
            } else {
                Color.clear
            }
        }
        .frame(width: 48, height: 15)
        .accessibilityHidden(true)
    }

    private func imageRect(in size: CGSize) -> CGRect {
        guard size.width > 0, size.height > 0, imageSize.width > 0, imageSize.height > 0 else { return .zero }
        let scale = min(size.width / imageSize.width, size.height / imageSize.height)
        let fitted = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(x: (size.width - fitted.width) / 2,
                      y: (size.height - fitted.height) / 2,
                      width: fitted.width, height: fitted.height)
    }
}
