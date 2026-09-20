import SwiftUI

struct HistogramView: View {
    let histogram: Histogram
    @State private var rgb = true
    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: 3) {
                Image(systemName: histogram.shadows > 0 ? "triangle.fill" : "triangle")
                Text("Noirs").font(.caption2)
            }.foregroundStyle(histogram.shadows > 0 ? .mint : .secondary)
            Canvas { context, size in
                let channels: [([Int], Color)] = rgb
                    ? [(histogram.red, .red), (histogram.green, .green), (histogram.blue, .blue)]
                    : [(histogram.luminance, .white)]
                let peak = max(1, channels.flatMap { $0.0 }.max() ?? 1)
                context.blendMode = .plusLighter
                for (bins, color) in channels {
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: size.height))
                    for i in bins.indices {
                        path.addLine(to: CGPoint(x: Double(i) / 255 * size.width,
                                                 y: size.height * (1 - Double(bins[i]) / Double(peak))))
                    }
                    path.addLine(to: CGPoint(x: size.width, y: size.height)); path.closeSubpath()
                    context.fill(path, with: .color(color.opacity(0.45)))
                }
            }
            .frame(height: 44)
            .accessibilityHidden(true)
            VStack(spacing: 3) {
                Image(systemName: histogram.highlights > 0 ? "triangle.fill" : "triangle")
                Text("Blancs").font(.caption2)
            }.foregroundStyle(histogram.highlights > 0 ? .mint : .secondary)
        }
        .padding(.horizontal)
        .contentShape(Rectangle())
        .onTapGesture { rgb.toggle() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Histogramme \(rgb ? "RVB" : "luminance")")
        .accessibilityValue("\(histogram.shadows) échantillons noirs bouchés, \(histogram.highlights) échantillons avec un canal écrêté")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { rgb.toggle() }
    }
}
