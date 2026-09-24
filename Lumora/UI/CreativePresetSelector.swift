import SwiftUI

/// Text-only Creative styles. The selection is derived from effect parameters,
/// so edits and Undo/Redo cannot leave a stale highlighted preset.
struct CreativePresetSelector<HeaderActions: View>: View {
    let presets: [CreativeFXPreset]
    let selectedID: String?
    let onSelect: (CreativeFXPreset) -> Void
    private let headerActions: HeaderActions
    @State private var selectionFeedback = 0

    init(presets: [CreativeFXPreset], selectedID: String?,
         onSelect: @escaping (CreativeFXPreset) -> Void,
         @ViewBuilder headerActions: () -> HeaderActions = { EmptyView() }) {
        self.presets = presets
        self.selectedID = selectedID
        self.onSelect = onSelect
        self.headerActions = headerActions()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                Text("Styles").font(.subheadline.weight(.semibold))
                Spacer(minLength: 4)
                headerActions
            }
            if selectedID == nil {
                Label("Custom", systemImage: "slider.horizontal.3")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("creative-preset-custom")
            }
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 6) {
                        ForEach(presets) { preset in
                            Button {
                                guard selectedID != preset.id else { return }
                                onSelect(preset)
                                selectionFeedback += 1
                            } label: {
                                HStack(spacing: 4) {
                                    Text(NSLocalizedString(preset.title, comment: "Creative preset"))
                                        .font(.subheadline.weight(selectedID == preset.id ? .semibold : .medium))
                                        .fixedSize(horizontal: true, vertical: false)
                                    if selectedID == preset.id {
                                        Image(systemName: "checkmark")
                                            .font(.caption.weight(.bold))
                                            .accessibilityHidden(true)
                                    }
                                }
                            }
                            .buttonStyle(CreativePresetChipStyle(selected: selectedID == preset.id))
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("\(preset.title), preset")
                            .accessibilityValue(selectedID == preset.id ? "Selected" : "Not selected")
                            .accessibilityAddTraits(selectedID == preset.id ? [.isButton, .isSelected] : .isButton)
                            .accessibilityIdentifier("creative-preset-chip-\(preset.id)")
                            .id(preset.id)
                        }
                    }
                    .padding(.horizontal, 2)
                    .padding(.vertical, 2)
                }
                .accessibilityIdentifier("creative-preset-strip")
                .onChange(of: selectedID) { _, id in
                    if let id {
                        withAnimation(.easeOut(duration: 0.18)) { proxy.scrollTo(id, anchor: .center) }
                    }
                }
            }
        }
        .sensoryFeedback(.selection, trigger: selectionFeedback)
    }
}

private struct CreativePresetChipStyle: ButtonStyle {
    let selected: Bool
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.colorSchemeContrast) private var contrast

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.primary)
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background {
                Capsule().fill(selected ? Color.mint.opacity(contrast == .increased ? 0.32 : 0.20)
                                         : Color.primary.opacity(contrast == .increased ? 0.13 : 0.07))
            }
            .overlay {
                Capsule().strokeBorder(selected ? Color.mint : Color.primary.opacity(contrast == .increased ? 0.48 : 0.20),
                                       lineWidth: selected ? 1.5 : 1)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(isEnabled ? (configuration.isPressed ? 0.78 : 1) : 0.45)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

#Preview("Few · Light") {
    CreativePresetSelector(presets: Array(CreativeFXPreset.all(for: .highKey).prefix(2)),
                           selectedID: CreativeFXPreset.all(for: .highKey)[0].id, onSelect: { _ in })
        .padding().preferredColorScheme(.light)
}

#Preview("Many · Dark") {
    CreativePresetSelector(presets: CreativeFXPreset.all(for: .detailExtractor),
                           selectedID: CreativeFXPreset.all(for: .detailExtractor)[2].id, onSelect: { _ in })
        .padding().preferredColorScheme(.dark)
}

#Preview("Custom · Large Type") {
    CreativePresetSelector(presets: CreativeFXPreset.all(for: .grain),
                           selectedID: nil, onSelect: { _ in })
        .padding().environment(\.dynamicTypeSize, .accessibility2).preferredColorScheme(.dark)
}

#Preview("Selected · Light") {
    CreativePresetSelector(presets: CreativeFXPreset.all(for: .tonalContrast),
                           selectedID: CreativeFXPreset.all(for: .tonalContrast)[1].id, onSelect: { _ in })
        .padding().preferredColorScheme(.light)
}
