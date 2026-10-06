import SwiftUI

/// Core Image Auto is one full-image baseline shared by Light, Color and Curves.
/// Its parameters are not represented as Lumora sliders or curve points.
struct AutoCorrectionControls: View {
    let session: EditorSession
    let module: AutoModule

    var body: some View {
        HStack(spacing: 6) {
            Button {
                Task { await session.applyCoreImageAuto() }
            } label: {
                Label("Auto", systemImage: "wand.and.stars")
            }
            .buttonStyle(CompactEditorButtonStyle(selected: session.coreImageAutoApplied))
            .accessibilityIdentifier("auto-" + module.rawValue)
            .disabled(session.isAnalyzingAuto || session.selectedMaskID != nil)
            if session.isAnalyzingAuto {
                ProgressView().controlSize(.small).accessibilityLabel("Analyzing photo")
            }
            if session.coreImageAutoApplied {
                Button {
                    session.resetCoreImageAuto()
                } label: { Image(systemName: "arrow.counterclockwise").frame(width: 44, height: 44) }
                .buttonStyle(CompactEditorButtonStyle())
                .accessibilityLabel("Reset Auto")
                .accessibilityIdentifier("auto-reset")
            }
            Spacer()
            Text(session.coreImageAutoApplied ? String(localized: "Auto base") : String(localized: "Manual"))
                .font(.caption).foregroundStyle(.secondary)
                .accessibilityIdentifier("auto-status-" + module.rawValue)
        }
        .frame(minHeight: 44)
    }
}
