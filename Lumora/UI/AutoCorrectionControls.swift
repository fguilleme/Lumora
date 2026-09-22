import SwiftUI

struct AutoCorrectionControls: View {
    let session: EditorSession
    let module: AutoModule
    @State private var style = AutoCurveStyle.balanced

    private var resolvedStyle: AutoCurveStyle {
        if session.autoIsApplied(.curves, style: style) { return style }
        return AutoCurveStyle.allCases.first { session.autoIsApplied(.curves, style: $0) } ?? style
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Button {
                    Task { await session.applyAuto(module, style: resolvedStyle) }
                } label: {
                    Label("Auto", systemImage: "wand.and.stars")
                        .frame(minHeight: 32)
                }
                .buttonStyle(.bordered).tint(.mint)
                .accessibilityIdentifier("auto-" + module.rawValue)
                .disabled(session.isAnalyzingAuto)
                if session.isAnalyzingAuto { ProgressView().controlSize(.small).accessibilityLabel("Analyse de la photo") }
                Spacer()
                Text(session.autoIsApplied(module, style: resolvedStyle) ? "Auto appliqué" : "Personnalisé")
                    .font(.caption).foregroundStyle(.secondary)
                    .accessibilityIdentifier("auto-status-" + module.rawValue)
            }
            if module == .curves {
                HStack(spacing: 6) {
                    ForEach(AutoCurveStyle.allCases) { item in
                        Button {
                            style = item
                            Task { await session.applyAuto(.curves, style: item) }
                        } label: {
                            HStack(spacing: 3) {
                                Text(item.title)
                                if session.autoIsApplied(.curves, style: item) { Image(systemName: "checkmark") }
                            }.font(.caption).frame(minHeight: 32)
                        }
                        .buttonStyle(.bordered)
                        .tint(session.autoIsApplied(.curves, style: item) ? .mint : .secondary)
                        .accessibilityIdentifier("auto-curve-" + item.rawValue)
                        .accessibilityAddTraits(session.autoIsApplied(.curves, style: item) ? .isSelected : [])
                        .disabled(session.isAnalyzingAuto)
                    }
                }
            }
            if module != .color {
                Text("Auto remplace les réglages Lumière et la courbe RVB.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
}
