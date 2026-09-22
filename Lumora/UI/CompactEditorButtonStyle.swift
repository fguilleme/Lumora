import SwiftUI

/// Compact visual surface, with a separate 44-point interactive area.
struct CompactEditorButtonStyle: ButtonStyle {
    var selected = false
    var segment = false
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.colorSchemeContrast) private var contrast

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption)
            .foregroundStyle(selected ? Color.mint : Color.primary)
            .padding(.horizontal, segment ? 8 : 12)
            .frame(minWidth: 44, minHeight: 36)
            .background {
                RoundedRectangle(cornerRadius: segment ? 7 : 18)
                    .fill(selected ? Color.mint.opacity(contrast == .increased ? 0.30 : 0.16)
                          : Color.primary.opacity(segment ? 0 : 0.06))
            }
            .overlay {
                RoundedRectangle(cornerRadius: segment ? 7 : 18)
                    .strokeBorder(selected ? Color.mint : Color.primary.opacity(segment ? 0 : 0.22),
                                  lineWidth: selected ? 1.5 : 1)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
            .opacity(isEnabled ? (configuration.isPressed ? 0.60 : 1) : 0.40)
    }
}
