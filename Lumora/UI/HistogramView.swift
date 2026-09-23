import SwiftUI

/// Draws already-computed preview bins. Expanding never resamples pixels;
/// the renderer owns the histogram for the entire edited photograph.
struct HistogramView: View {
    let histogram: Histogram
    let imageSize: CGSize
    @State private var expanded = false

    init(histogram: Histogram, imageSize: CGSize, initiallyExpanded: Bool = false) {
        self.histogram = histogram
        self.imageSize = imageSize
        _expanded = State(initialValue: initiallyExpanded)
    }

    var body: some View {
        GeometryReader { geometry in
            let photo = imageRect(in: geometry.size)
            let compactWidth = min(220, max(128, photo.width * 0.42))
            let expandedWidth = max(128, photo.width * 0.84)
            let width = expanded ? expandedWidth : compactWidth
            let height: CGFloat = expanded ? 150 : 62
            Button {
                withAnimation(.easeInOut(duration: 0.18)) { expanded.toggle() }
            } label: {
                VStack(spacing: 4) {
                    if expanded {
                        HStack(spacing: 5) {
                            clippingIndicator(fraction: histogram.shadowFraction,
                                              symbol: "arrowtriangle.down.fill", label: "Noirs")
                            Spacer()
                            Text("RVB").font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.72))
                            Spacer()
                            clippingIndicator(fraction: histogram.highlightFraction,
                                              symbol: "arrowtriangle.up.fill", label: "Blancs")
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
            .accessibilityIdentifier("histogram-overlay")
            .accessibilityLabel(expanded ? "Réduire l’histogramme RVB" : "Agrandir l’histogramme RVB")
            .accessibilityValue("Noirs proches du bord : \(histogram.shadows) sur \(histogram.samples). Blancs proches du bord : \(histogram.highlights) sur \(histogram.samples). Aperçu SDR, pas écrêtage du fichier original.")
            .accessibilityHint("Touchez deux fois pour \(expanded ? "réduire" : "agrandir")")
            .position(x: photo.minX + width / 2 + 8,
                      y: photo.minY + height / 2 + 8)
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
