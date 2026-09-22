import SwiftUI

struct MasksView: View {
    let masks: [LocalMask]
    let selectedMaskID: UUID?
    let selectedComponentID: UUID?
    let brushMode: BrushMode
    let onSelectBase: () -> Void
    let onSelectMask: (UUID) -> Void
    let onSelectComponent: (UUID) -> Void
    let onComponentOperation: (MaskOperation) -> Void
    let onMoveComponent: (Int) -> Void
    let onDeleteComponent: () -> Void
    let onBrushMode: (BrushMode) -> Void
    let onCreate: (MaskKind) -> Void
    let onAddComponent: (MaskKind, MaskOperation) -> Void
    let onGenerate: (SmartMaskKind, MaskOperation?) -> Void
    let isGenerating: Bool
    let onDelete: () -> Void
    let onRename: (String) -> Void
    let onToggleVisibility: () -> Void
    let onOpacity: (Double) -> Void
    let onMove: (Int) -> Void
    let onInvert: () -> Void
    let onBegin: (String) -> Void
    let onAdjustment: (LocalAdjustment, Double) -> Void
    let onResetAdjustment: (LocalAdjustment) -> Void
    let onParameter: (MaskParameter, Double) -> Void
    let onEnd: () -> Void
    @State private var showingRename = false
    @State private var renameName = ""

    private var mask: LocalMask? { masks.first { $0.id == selectedMaskID } }
    private var maskIndex: Int? { masks.firstIndex { $0.id == selectedMaskID } }
    private var component: MaskComponent? { mask?.components.first { $0.id == selectedComponentID } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Pile de modifications").font(.headline)
                    Spacer()
                    if isGenerating {
                        ProgressView().controlSize(.small).accessibilityLabel("Détection du masque")
                    }
                    newMaskMenu
                    if mask != nil {
                        Button(role: .destructive, action: onDelete) { Image(systemName: "trash") }
                            .accessibilityLabel("Supprimer le masque")
                    }
                }
                maskPicker
                if mask == nil {
                    Label("Ce premier calque couvre toute la photographie.", systemImage: "rectangle.fill")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Text("Peignez, tracez un dégradé ou laissez Vision détecter le sujet.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    HStack {
                        ForEach(MaskKind.allCases) { kind in
                            Button(kind.title) { onCreate(kind) }.buttonStyle(.bordered)
                        }
                        smartMaskMenu("Détecter", operation: nil)
                    }
                } else if let mask {
                        layerControls(mask)
                        AdjustmentSlider(title: "Opacité du calque", range: 0...100,
                                         accessibilityID: "layer-opacity", value: mask.opacity,
                                         onBegin: { onBegin("Opacité du calque") },
                                         onChange: onOpacity, onEnd: onEnd,
                                         onReset: { onOpacity(100) })
                        Divider()
                        HStack {
                            componentMenu("Ajouter", operation: .add)
                            componentMenu("Soustraire", operation: .subtract)
                            Spacer()
                            Toggle("Inverser", isOn: Binding(get: { mask.inverted }, set: { _ in onInvert() }))
                                .fixedSize().accessibilityIdentifier("mask-invert")
                        }
                        componentPicker(mask)
                        if let component {
                            componentControls(component, in: mask)
                            shapeControls(component)
                        }
                        Divider()
                        Text("Raccourcis du calque").font(.headline)
                        Text("Lumière, Couleur, Courbes, Colorimétrie, Effets et Détail agissent aussi sur ce calque tant qu’il reste sélectionné.")
                            .font(.caption).foregroundStyle(.secondary)
                        ForEach(LocalAdjustment.allCases) { adjustment in
                            AdjustmentSlider(title: adjustment.title, range: adjustment.range,
                                             step: adjustment == .exposure ? 0.01 : 1,
                                             precision: adjustment == .exposure ? 2 : 0,
                                             accessibilityID: "mask-adjustment-\(adjustment.rawValue)",
                                             value: mask.adjustments[adjustment],
                                             onBegin: { onBegin("Masque · \(adjustment.title)") },
                                             onChange: { onAdjustment(adjustment, $0) }, onEnd: onEnd,
                                             onReset: { onResetAdjustment(adjustment) })
                        }
                }
            }.padding(.horizontal, 18).padding(.bottom, 12)
        }
        .accessibilityIdentifier("masks-controls")
        .alert("Renommer le calque", isPresented: $showingRename) {
            TextField("Nom", text: $renameName).accessibilityIdentifier("layer-rename-field")
            Button("Annuler", role: .cancel) {}
            Button("Renommer") { onRename(renameName) }
                .disabled(renameName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private var newMaskMenu: some View {
        Menu {
            ForEach(MaskKind.allCases) { kind in Button(kind.title) { onCreate(kind) } }
            Divider()
            ForEach(SmartMaskKind.allCases) { kind in
                Button(kind.title, systemImage: kind.symbol) { onGenerate(kind, nil) }
            }
        } label: { Label("Nouveau", systemImage: "plus.circle").frame(minHeight: 44) }
        .accessibilityIdentifier("mask-new")
        .disabled(isGenerating)
    }
    private var maskPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                Button("Photo entière") { onSelectBase() }
                    .buttonStyle(.bordered).tint(selectedMaskID == nil ? .mint : .secondary)
                    .accessibilityIdentifier("layer-base")
                    .accessibilityAddTraits(selectedMaskID == nil ? .isSelected : [])
                ForEach(masks) { item in
                    Button { onSelectMask(item.id) } label: {
                        Label(item.name, systemImage: item.isVisible ? "circle.fill" : "eye.slash")
                    }
                        .buttonStyle(.bordered).tint(item.id == selectedMaskID ? .mint : .secondary)
                        .opacity(item.isVisible ? 1 : 0.55)
                        .accessibilityIdentifier("mask-\(item.id)")
                        .accessibilityAddTraits(item.id == selectedMaskID ? .isSelected : [])
                }
            }
        }
    }
    private func layerControls(_ mask: LocalMask) -> some View {
        HStack(spacing: 8) {
            Button {
                onToggleVisibility()
            } label: {
                Label(mask.isVisible ? "Visible" : "Masqué",
                      systemImage: mask.isVisible ? "eye" : "eye.slash")
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("layer-visibility")
            Button {
                renameName = mask.name
                showingRename = true
            } label: {
                Image(systemName: "pencil")
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Renommer le calque")
            .accessibilityIdentifier("layer-rename")
            Spacer()
            Button { onMove(-1) } label: { Image(systemName: "arrow.left") }
                .buttonStyle(.bordered)
                .disabled(maskIndex == 0)
                .accessibilityLabel("Appliquer plus tôt")
                .accessibilityIdentifier("layer-move-earlier")
            Button { onMove(1) } label: { Image(systemName: "arrow.right") }
                .buttonStyle(.bordered)
                .disabled(maskIndex == masks.indices.last)
                .accessibilityLabel("Appliquer plus tard")
                .accessibilityIdentifier("layer-move-later")
        }
    }
    private func componentMenu(_ title: String, operation: MaskOperation) -> some View {
        Menu(title) {
            ForEach(MaskKind.allCases) { kind in Button(kind.title) { onAddComponent(kind, operation) } }
            Divider()
            ForEach(SmartMaskKind.allCases) { kind in
                Button(kind.title, systemImage: kind.symbol) { onGenerate(kind, operation) }
            }
        }
        .buttonStyle(.bordered)
        .accessibilityIdentifier("mask-add-component-\(operation.rawValue)")
    }
    private func smartMaskMenu(_ title: String, operation: MaskOperation?) -> some View {
        Menu(title) {
            ForEach(SmartMaskKind.allCases) { kind in
                Button(kind.title, systemImage: kind.symbol) { onGenerate(kind, operation) }
                    .accessibilityIdentifier("mask-smart-\(kind.rawValue)")
            }
        }
        .buttonStyle(.bordered)
        .disabled(isGenerating)
        .overlay { if isGenerating { ProgressView().controlSize(.small) } }
    }
    private func componentPicker(_ mask: LocalMask) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(Array(mask.components.enumerated()), id: \.element.id) { index, item in
                    Button("\(item.operation == .add ? "+" : "−") \(item.shape.title) \(index + 1)") {
                        onSelectComponent(item.id)
                    }
                    .font(.caption).buttonStyle(.bordered)
                    .tint(item.id == selectedComponentID ? .mint : .secondary)
                }
            }
        }
    }
    private func componentControls(_ component: MaskComponent, in mask: LocalMask) -> some View {
        let index = mask.components.firstIndex { $0.id == component.id }
        return HStack(spacing: 8) {
            Picker("Opération", selection: Binding(
                get: { component.operation },
                set: { operation in onComponentOperation(operation) }
            )) {
                Text("Ajouter").tag(MaskOperation.add)
                Text("Soustraire").tag(MaskOperation.subtract)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("mask-component-operation")
            Button { onMoveComponent(-1) } label: { Image(systemName: "arrow.left") }
                .buttonStyle(.bordered).disabled(index == 0)
                .accessibilityLabel("Composante plus tôt")
                .accessibilityIdentifier("mask-component-earlier")
            Button { onMoveComponent(1) } label: { Image(systemName: "arrow.right") }
                .buttonStyle(.bordered).disabled(index == mask.components.indices.last)
                .accessibilityLabel("Composante plus tard")
                .accessibilityIdentifier("mask-component-later")
            Button(role: .destructive, action: onDeleteComponent) { Image(systemName: "trash") }
                .buttonStyle(.bordered).disabled(mask.components.count <= 1)
                .accessibilityLabel("Supprimer la composante")
                .accessibilityIdentifier("mask-component-delete")
        }
    }
    @ViewBuilder private func shapeControls(_ component: MaskComponent) -> some View {
        switch component.shape {
        case .brush(let brush):
            Picker("Mode du pinceau", selection: Binding(get: { brushMode }, set: { onBrushMode($0) })) {
                ForEach(BrushMode.allCases, id: \.self) { mode in Text(mode.title).tag(mode) }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("brush-mode")
            Label(brushMode == .pan ? "Déplacez l’image zoomée sans peindre." : "Peignez sur la photo. Pour naviguer, choisissez Déplacer.", systemImage: brushMode == .pan ? "hand.draw" : "paintbrush.pointed")
                .font(.caption).foregroundStyle(.secondary)
            parameter(.size, brush.size); parameter(.feather, brush.feather)
            parameter(.flow, brush.flow); parameter(.opacity, brush.opacity)
        case .linear(let linear):
            parameter(.angle, linear.angle); parameter(.centerX, linear.center.x * 100)
            parameter(.centerY, linear.center.y * 100); parameter(.feather, linear.feather)
        case .radial(let radial):
            parameter(.centerX, radial.center.x * 100); parameter(.centerY, radial.center.y * 100)
            parameter(.radiusX, radial.radiusX * 100); parameter(.radiusY, radial.radiusY * 100)
            parameter(.feather, radial.feather)
        case .generated(let generated):
            Label("Masque \(generated.kind.title.lowercased()) détecté par Vision",
                  systemImage: generated.kind.symbol)
                .font(.caption).foregroundStyle(.secondary)
        }
    }
    private func parameter(_ parameter: MaskParameter, _ value: Double) -> some View {
        AdjustmentSlider(title: parameter.title, range: parameter.range,
                         accessibilityID: "mask-parameter-\(parameter.rawValue)", value: value,
                         onBegin: { onBegin("Masque · \(parameter.title)") },
                         onChange: { onParameter(parameter, $0) }, onEnd: onEnd,
                         onReset: { onParameter(parameter, defaultValue(parameter)) })
    }
    private func defaultValue(_ parameter: MaskParameter) -> Double {
        switch parameter {
        case .size: 18; case .feather: 50; case .flow: 80; case .opacity: 100
        case .angle: 0; case .centerX, .centerY: 50; case .radiusX: 35; case .radiusY: 25
        }
    }
}
