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
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button {
                    Task { await session.applyAuto(module, style: resolvedStyle) }
                } label: {
                    Label("Auto", systemImage: "wand.and.stars")
                }
                .buttonStyle(CompactEditorButtonStyle())
                .accessibilityIdentifier("auto-" + module.rawValue)
                .disabled(session.isAnalyzingAuto)
                if session.isAnalyzingAuto { ProgressView().controlSize(.small).accessibilityLabel("Analyse de la photo") }
                Spacer()
                Text(session.autoIsApplied(module, style: resolvedStyle) ? "Auto appliqué" : "Personnalisé")
                    .font(.caption).foregroundStyle(.secondary)
                    .accessibilityIdentifier("auto-status-" + module.rawValue)
            }
            if module == .curves {
                HStack(spacing: 0) {
                    ForEach(AutoCurveStyle.allCases) { item in
                        Button {
                            style = item
                            Task { await session.applyAuto(.curves, style: item) }
                        } label: {
                            HStack(spacing: 3) {
                                Text(item.title)
                                if session.autoIsApplied(.curves, style: item) { Image(systemName: "checkmark") }
                            }.frame(maxWidth: .infinity)
                        }
                        .buttonStyle(CompactEditorButtonStyle(
                            selected: session.autoIsApplied(.curves, style: item), segment: true))
                        .accessibilityIdentifier("auto-curve-" + item.rawValue)
                        .accessibilityAddTraits(session.autoIsApplied(.curves, style: item) ? .isSelected : [])
                        .disabled(session.isAnalyzingAuto)
                    }
                }
                .background {
                    RoundedRectangle(cornerRadius: 9)
                        .fill(Color.primary.opacity(0.06))
                        .padding(.vertical, 4)
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Style Auto")
            }
            if module != .color {
                Text("Auto remplace les réglages Lumière et la courbe RVB.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
}
