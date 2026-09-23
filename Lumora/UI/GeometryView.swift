import SwiftUI

struct GeometryView: View {
    let settings: GeometrySettings
    let onRotate: (Bool) -> Void
    let onFlip: (Bool) -> Void
    let onAspect: (CropAspect) -> Void
    let onAutoStraighten: () -> Void
    let onAutoPerspective: () -> Void
    let isAnalyzing: Bool
    let onBegin: (String) -> Void
    let onChange: (GeometryAdjustment, Double) -> Void
    let onEnd: () -> Void
    let onResetAdjustment: (GeometryAdjustment) -> Void
    let onResetAll: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    toolButton("Rotate left", "rotate.left") { onRotate(false) }
                    toolButton("Rotate right", "rotate.right") { onRotate(true) }
                    toolButton("Flip horizontally", "arrow.left.and.right") {
                        onFlip(true)
                    }
                    toolButton("Flip vertically", "arrow.up.and.down") {
                        onFlip(false)
                    }
                    Spacer()
                    Button("Reset", action: onResetAll)
                        .font(.caption).accessibilityIdentifier("geometry-reset")
                }

                HStack {
                    Button(action: onAutoStraighten) {
                        Label("Auto horizon", systemImage: "wand.and.rays")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.mint)
                    .disabled(isAnalyzing)
                    .accessibilityIdentifier("geometry-auto-straighten")
                    Button(action: onAutoPerspective) {
                        Label("Auto perspective", systemImage: "square.on.square")
                    }
                    .buttonStyle(.bordered)
                    .tint(.mint)
                    .disabled(isAnalyzing)
                    .accessibilityIdentifier("geometry-auto-perspective")
                    if isAnalyzing { ProgressView().controlSize(.small) }
                    Spacer()
                }

                Text("Format").font(.headline)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(CropAspect.allCases) { aspect in
                            Button(aspect.title) { onAspect(aspect) }
                                .buttonStyle(.bordered)
                                .tint(settings.aspect == aspect ? .mint : .secondary)
                                .accessibilityIdentifier("geometry-aspect-\(aspect.rawValue)")
                                .accessibilityAddTraits(settings.aspect == aspect ? .isSelected : [])
                        }
                    }
                }

                Text("Perspective").font(.headline)
                ForEach(GeometryAdjustment.perspective) { adjustment in
                    adjustmentSlider(adjustment)
                }
                Text("Crop").font(.headline)
                ForEach(GeometryAdjustment.crop) { adjustment in
                    adjustmentSlider(adjustment)
                }
            }.padding(.horizontal, 22).padding(.bottom, 12)
        }
        .accessibilityIdentifier("geometry-controls")
    }

    private func adjustmentSlider(_ adjustment: GeometryAdjustment) -> some View {
        AdjustmentSlider(title: adjustment.title, range: adjustment.range,
                         accessibilityID: "geometry-\(adjustment.rawValue)",
                         value: settings[adjustment],
                         onBegin: { onBegin(adjustment.title) },
                         onChange: { onChange(adjustment, $0) }, onEnd: onEnd,
                         onReset: { onResetAdjustment(adjustment) })
    }

    private func toolButton(_ label: String, _ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: symbol).frame(width: 34, height: 34) }
            .buttonStyle(.bordered).accessibilityLabel(label)
    }
}
