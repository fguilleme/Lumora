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
    @State private var selectedID = GeometryAdjustment.straighten.rawValue

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 5) {
                    toolButton("Rotate left", "rotate.left") { onRotate(false) }
                    toolButton("Rotate right", "rotate.right") { onRotate(true) }
                    toolButton("Flip horizontally", "arrow.left.and.right") {
                        onFlip(true)
                    }
                    toolButton("Flip vertically", "arrow.up.and.down") {
                        onFlip(false)
                    }
                    autoToolButton("Auto horizon", "level",
                                   identifier: "geometry-auto-straighten", action: onAutoStraighten)
                    autoToolButton("Auto perspective", "viewfinder.rectangular",
                                   identifier: "geometry-auto-perspective", action: onAutoPerspective)
                    if isAnalyzing { ProgressView().controlSize(.small) }
                    toolButton("Reset", "arrow.counterclockwise", identifier: "geometry-reset", action: onResetAll)
                }

                HStack(spacing: 6) {
                    ForEach(CropAspect.allCases) { aspect in
                        Button { onAspect(aspect) } label: {
                            if aspect == .original {
                                Image(systemName: "photo")
                                    .font(.system(size: 17, weight: .medium))
                                    .frame(minHeight: 22)
                            } else {
                                Text(aspect.title).lineLimit(1)
                            }
                        }
                            .buttonStyle(.bordered)
                            .tint(settings.aspect == aspect ? .mint : .secondary)
                            .frame(maxWidth: .infinity)
                            .accessibilityLabel(aspect.title)
                            .accessibilityIdentifier("geometry-aspect-\(aspect.rawValue)")
                            .accessibilityAddTraits(settings.aspect == aspect ? .isSelected : [])
                    }
                }

                LinearAdjustmentControl(parameters: parameters, selectedID: $selectedID,
                    onBegin: { onBegin($0.title) },
                    onChange: { parameter, value in
                        if let adjustment = GeometryAdjustment(rawValue: parameter.id) { onChange(adjustment, value) }
                    }, onEnd: onEnd,
                    onReset: { parameter in
                        if let adjustment = GeometryAdjustment(rawValue: parameter.id) { onResetAdjustment(adjustment) }
                    })
                    .padding(.horizontal, -22)
            }.padding(.horizontal, 22).padding(.bottom, 12)
        }
        .accessibilityIdentifier("geometry-controls")
    }

    private var parameters: [LinearAdjustmentParameter] {
        GeometryAdjustment.allCases.map { adjustment in
            LinearAdjustmentParameter(id: adjustment.rawValue, title: adjustment.title,
                value: settings[adjustment], range: adjustment.range, step: 1,
                precision: 0, resetValue: adjustment.defaultValue)
        }
    }

    private func toolButton(_ label: String, _ symbol: String, identifier: String? = nil,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .medium))
                .frame(width: 36, height: 36)
                .background(Color.mint.opacity(0.17), in: Circle())
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.mint)
        .frame(maxWidth: .infinity)
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier ?? "")
    }
    private func autoToolButton(_ label: String, _ symbol: String,
                                identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .medium))
                .frame(width: 36, height: 36)
                .background(Color.mint.opacity(0.17), in: Circle())
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.mint)
        .frame(maxWidth: .infinity)
        .disabled(isAnalyzing)
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier)
    }
}
