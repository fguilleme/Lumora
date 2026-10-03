import SwiftUI

struct MasksView: View {
    let sourceImage: CGImage?
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
    let onMagicMask: (GeneratedMask, MaskOperation?) -> Void
    let isGenerating: Bool
    let onDelete: () -> Void
    let onRename: (String) -> Void
    let overlayVisible: Bool
    let onToggleVisibility: () -> Void
    let onOpacity: (Double) -> Void
    let onMove: (Int) -> Void
    let onInvert: () -> Void
    let onBegin: (String) -> Void
    let onParameter: (MaskParameter, Double) -> Void
    let onEnd: () -> Void
    @State private var showingRename = false
    @State private var renameName = ""
    @State private var magicRequest: MagicSelectionRequest?

    private struct MagicSelectionRequest: Identifiable {
        let id = UUID()
        let operation: MaskOperation?
    }

    private var mask: LocalMask? { masks.first { $0.id == selectedMaskID } }
    private var maskIndex: Int? { masks.firstIndex { $0.id == selectedMaskID } }
    private var component: MaskComponent? { mask?.components.first { $0.id == selectedComponentID } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Adjustment stack").font(.headline)
                    Spacer()
                    if isGenerating {
                        ProgressView().controlSize(.small).accessibilityLabel("Mask detection")
                    }
                    newMaskMenu
                    if mask != nil {
                        Button(role: .destructive, action: onDelete) { Image(systemName: "trash") }
                            .accessibilityLabel("Delete mask")
                    }
                }
                maskPicker
                if mask == nil {
                    Label("This base layer covers the entire photo.", systemImage: "rectangle.fill")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Text("Paint, draw a gradient, or let Vision detect the subject.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    HStack {
                        ForEach(MaskKind.allCases) { kind in
                            Button(kind.title) { onCreate(kind) }.buttonStyle(.bordered)
                        }
                        smartMaskMenu("Detect", operation: nil)
                    }
                } else if let mask {
                        layerControls(mask)
                        AdjustmentSlider(title: "Layer opacity", range: 0...100,
                                         accessibilityID: "layer-opacity", value: mask.opacity,
                                         onBegin: { onBegin("Layer opacity") },
                                         onChange: onOpacity, onEnd: onEnd,
                                         onReset: { onOpacity(100) })
                        Divider()
                        HStack {
                            componentMenu("Add", operation: .add)
                            componentMenu("Subtract", operation: .subtract)
                            Spacer()
                            Toggle("Invert", isOn: Binding(get: { mask.inverted }, set: { _ in onInvert() }))
                                .fixedSize().accessibilityIdentifier("mask-invert")
                        }
                        componentPicker(mask)
                        if let component {
                            componentControls(component, in: mask)
                            shapeControls(component)
                        }

                }
            }.padding(.horizontal, 18).padding(.bottom, 12)
        }
        .accessibilityIdentifier("masks-controls")
        .alert("Rename layer", isPresented: $showingRename) {
            TextField("Name", text: $renameName).accessibilityIdentifier("layer-rename-field")
            Button("Cancel", role: .cancel) {}
            Button("Rename") { onRename(renameName) }
                .disabled(renameName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .fullScreenCover(item: $magicRequest) { request in
            if let sourceImage {
                MagicSelectionView(source: sourceImage,
                                   onCancel: { magicRequest = nil },
                                   onValidate: { generated in
                                       onMagicMask(generated, request.operation)
                                       magicRequest = nil
                                   })
            }
        }
    }

    private var newMaskMenu: some View {
        Menu {
            ForEach(MaskKind.allCases) { kind in Button(kind.title) { onCreate(kind) } }
            Divider()
            ForEach(SmartMaskKind.automaticCases) { kind in
                Button(kind.title, systemImage: kind.symbol) { onGenerate(kind, nil) }
            }
            Button("Magic Selection", systemImage: "wand.and.stars") {
                magicRequest = MagicSelectionRequest(operation: nil)
            }
        } label: { Label("New", systemImage: "plus.circle").frame(minHeight: 44) }
        .accessibilityIdentifier("mask-new")
        .disabled(isGenerating)
    }
    private var maskPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                Button("Whole photo") { onSelectBase() }
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
                Label(overlayVisible ? "Visible" : "Outline",
                      systemImage: overlayVisible ? "eye" : "eye.slash")
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("layer-visibility")
            .accessibilityHint("Show the red fill or just the mask outline")
            Button {
                renameName = mask.name
                showingRename = true
            } label: {
                Image(systemName: "pencil")
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Rename layer")
            .accessibilityIdentifier("layer-rename")
            Spacer()
            Button { onMove(-1) } label: { Image(systemName: "arrow.left") }
                .buttonStyle(.bordered)
                .disabled(maskIndex == 0)
                .accessibilityLabel("Apply earlier")
                .accessibilityIdentifier("layer-move-earlier")
            Button { onMove(1) } label: { Image(systemName: "arrow.right") }
                .buttonStyle(.bordered)
                .disabled(maskIndex == masks.indices.last)
                .accessibilityLabel("Apply later")
                .accessibilityIdentifier("layer-move-later")
        }
    }
    private func componentMenu(_ title: String, operation: MaskOperation) -> some View {
        Menu(title) {
            ForEach(MaskKind.allCases) { kind in Button(kind.title) { onAddComponent(kind, operation) } }
            Divider()
            ForEach(SmartMaskKind.automaticCases) { kind in
                Button(kind.title, systemImage: kind.symbol) { onGenerate(kind, operation) }
            }
            Button("Magic Selection", systemImage: "wand.and.stars") {
                magicRequest = MagicSelectionRequest(operation: operation)
            }
        }
        .buttonStyle(.bordered)
        .accessibilityIdentifier("mask-add-component-\(operation.rawValue)")
    }
    private func smartMaskMenu(_ title: String, operation: MaskOperation?) -> some View {
        Menu(title) {
            ForEach(SmartMaskKind.automaticCases) { kind in
                Button(kind.title, systemImage: kind.symbol) { onGenerate(kind, operation) }
                    .accessibilityIdentifier("mask-smart-\(kind.rawValue)")
            }
            Button("Magic Selection", systemImage: "wand.and.stars") {
                magicRequest = MagicSelectionRequest(operation: operation)
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
            Picker("Operation", selection: Binding(
                get: { component.operation },
                set: { operation in onComponentOperation(operation) }
            )) {
                Text("Add").tag(MaskOperation.add)
                Text("Subtract").tag(MaskOperation.subtract)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("mask-component-operation")
            Button { onMoveComponent(-1) } label: { Image(systemName: "arrow.left") }
                .buttonStyle(.bordered).disabled(index == 0)
                .accessibilityLabel("Move component earlier")
                .accessibilityIdentifier("mask-component-earlier")
            Button { onMoveComponent(1) } label: { Image(systemName: "arrow.right") }
                .buttonStyle(.bordered).disabled(index == mask.components.indices.last)
                .accessibilityLabel("Move component later")
                .accessibilityIdentifier("mask-component-later")
            Button(role: .destructive, action: onDeleteComponent) { Image(systemName: "trash") }
                .buttonStyle(.bordered).disabled(mask.components.count <= 1)
                .accessibilityLabel("Delete component")
                .accessibilityIdentifier("mask-component-delete")
        }
    }
    @ViewBuilder private func shapeControls(_ component: MaskComponent) -> some View {
        switch component.shape {
        case .brush(let brush):
            Picker("Brush mode", selection: Binding(get: { brushMode }, set: { onBrushMode($0) })) {
                ForEach(BrushMode.allCases, id: \.self) { mode in Text(mode.title).tag(mode) }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("brush-mode")
            Label(brushInstruction(component.operation),
                  systemImage: brushMode == .pan ? "hand.draw" : "paintbrush.pointed")
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
            Label("Vision detected \(generated.kind.title.lowercased()) mask",
                  systemImage: generated.kind.symbol)
                .font(.caption).foregroundStyle(.secondary)
        }
    }
    private func brushInstruction(_ operation: MaskOperation) -> String {
        if brushMode == .pan { return String(localized: "Pan the zoomed image without painting.") }
        if operation == .subtract {
            return brushMode == .paint
                ? String(localized: "Paint the area to subtract from the mask.")
                : String(localized: "Erase restores part of the subtracted area.")
        }
        return brushMode == .paint
            ? String(localized: "Paint on the photo. To navigate, choose Pan.")
            : String(localized: "Erase removes paint from the mask.")
    }
    private func parameter(_ parameter: MaskParameter, _ value: Double) -> some View {
        AdjustmentSlider(title: parameter.title, range: parameter.range,
                         accessibilityID: "mask-parameter-\(parameter.rawValue)", value: value,
                         onBegin: { onBegin("Mask · \(parameter.title)") },
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
