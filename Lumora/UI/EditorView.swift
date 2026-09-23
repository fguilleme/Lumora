import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct EditorView: View {
    @State private var session = EditorSession()
    @State private var selection: PhotosPickerItem?
    @State private var showFiles = false
    @State private var showPhotos = false
    @State private var showLibrary = false
    @State private var photoLoading = false
    @State private var panel: Panel = .light
    @State private var showMetrics = false
    @State private var maskOverlayVisible = true
    @State private var clippingPressed = false
    @State private var clippingOverlay: CGImage?
    @State private var clippingSource: CGImage?
    @State private var clippingRequest = 0
    @State private var clippingActivationCount = 0
    @State private var exportRequest: ExportRequest?
    @State private var exporter = ExportController()
    @State private var presetController = PresetController()
    @State private var focusedAdjustmentID: String?
    @State private var selectedCreativeEffectID: UUID?
    @State private var curveChannel: CurveChannel = .rgb
    @State private var curveEditMode = false
    @State private var curveEyedropper = false
    @State private var curveSample: CurveSample?
    @State private var curveSamplingBuffer: CurveSamplingBuffer?
    @AppStorage("editor.controlsSide") private var controlsSideRaw = ControlsSide.leading.rawValue
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.layoutDirection) private var layoutDirection
    private enum ControlsSide: String { case leading, trailing }
    private var controlsSide: ControlsSide { ControlsSide(rawValue: controlsSideRaw) ?? .leading }
    private enum Panel: String, CaseIterable {
        case creative = "Creative"
        case light = "Light", color = "Color", curve = "Curves", colorTools = "Color Tools", effects = "Effects", detail = "Detail", optics = "Optics", geometry = "Geometry", masks = "Masks", presets = "Presets", help = "Help"
        var symbol: String {
            switch self {
            case .creative: "sparkles"
            case .light: "sun.max"
            case .color: "slider.horizontal.3"
            case .curve: "point.topleft.down.to.point.bottomright.curvepath"
            case .colorTools: "circle.lefthalf.filled"
            case .effects: "camera.filters"
            case .detail: "triangle"
            case .optics: "camera.aperture"
            case .geometry: "crop.rotate"
            case .masks: "circle.dashed.inset.filled"
            case .presets: "slider.horizontal.2.square"
            case .help: "questionmark.circle"
            }
        }
    }

    private var activeDLCSettings: DarkenLightenCenterSettings? {
        guard panel == .creative, !session.bypassCreative,
              let effect = session.state.creative.effects.first(where: { $0.id == selectedCreativeEffectID }),
              effect.kind == .darkenLightenCenter, effect.enabled, effect.opacity > 0 else { return nil }
        return DarkenLightenCenterSettings(effect: effect)
    }

    var body: some View {
        VStack(spacing: 0) {
            header.dimsDuringAdjustment()
            if let result = session.result {
                GeometryReader { available in
                    let landscape = UIDevice.current.userInterfaceIdiom == .phone
                        && available.size.width > available.size.height
                    EditorWorkspaceLayout(landscape: landscape,
                                          controlsSide: controlsSideRaw,
                                          direction: layoutDirection,
                                          portraitControlsHeight: 252 + 56 + (showsPhotoInformation ? 28 : 0)) {
                PhotoCanvas(result: result, clippingOverlay: activeClippingOverlay(for: result.image),
                            onClippingOverlayAppear: {
                                // Test-only accessibility counter: proves the photo overlay
                                // appeared during an XCTest press without persisting UI state.
                                if ProcessInfo.processInfo.arguments.contains("-ui-testing-clipping") {
                                    clippingActivationCount &+= 1
                                }
                            },
                            diagnosticGeneration: ProcessInfo.processInfo.arguments.contains("-ui-testing-landscape") ? session.generation : nil,
                            curveSampling: panel == .curve && curveEditMode && curveEyedropper && session.selectedMaskID == nil && curveSamplingBuffer != nil,
                            curveSampleLocation: curveSample?.location,
                            onCurveSample: { location in
                                if let value = curveSamplingBuffer?.sample(at: location) { curveSample = value }
                            },
                            showingOriginal: $session.showingOriginal,
                            dlcSettings: activeDLCSettings,
                            onDLCBegin: { session.beginInteraction("Move center") },
                            onDLCChange: { point in
                                guard let id = selectedCreativeEffectID else { return }
                                session.changeCreative("Move center") { stack in
                                    if let i = stack.effects.firstIndex(where: { $0.id == id }) {
                                        stack.effects[i]["centerX"] = point.x
                                        stack.effects[i]["centerY"] = point.y
                                    }
                                }
                            },
                            onDLCEnd: session.finishInteraction,
                            activeMask: session.selectedMask,
                            activeComponentID: session.selectedMaskComponentID,
                            showsMaskOverlay: panel == .masks && !isAdjustingSelectedMask,
                            maskOutlineOnly: !maskOverlayVisible,
                            allowsMaskEditing: panel == .masks,
                            brushMode: session.brushMode,
                            onBrushBegin: session.beginBrushStroke,
                            onBrushPoint: session.appendBrushPoint,
                            onBrushEnd: session.finishInteraction,
                            onMaskTransformBegin: { session.beginInteraction("Transform component") },
                            onMaskShapeChange: session.setSelectedMaskShape,
                            onMaskTransformEnd: session.finishInteraction,
                            showsGeometryGrid: panel == .geometry,
                            geometrySettings: panel == .geometry ? session.state.geometry : nil,
                            onGeometryBegin: session.beginInteraction,
                            onGeometryChange: session.setGeometry,
                            onGeometryEnd: session.finishInteraction)
                    .id(session.document?.id)
                    .frame(maxHeight: .infinity)
                    .background(.black)
                    .overlay {
                        HistogramView(histogram: result.histogram,
                                      imageSize: CGSize(width: result.image.width, height: result.image.height),
                                      compactLandscape: landscape,
                                      diagnosticActivationCount: ProcessInfo.processInfo.arguments.contains("-ui-testing-clipping") ? clippingActivationCount : nil,
                                      onClippingPressChanged: { active in
                                          setClippingPress(active, image: result.image)
                                      })
                            .id(session.document?.id)
                    }
                editorControlColumn(result, landscape: landscape)
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("editor-controls-column")
                    }
                    .onChange(of: landscape) { _, _ in session.finishInteraction() }
                }
                #if DEBUG
                if showMetrics { metrics(result) }
                #endif
            } else {
                Spacer()
                Image(systemName: "camera.aperture").font(.system(size: 64, weight: .ultraLight)).foregroundStyle(.mint)
                Text("Light, your way.").font(.title2).padding(.top, 20)
                Text("Import a photo to get started.\nYour original stays intact, and your edits stay local.")
                    .font(.subheadline).multilineTextAlignment(.center).foregroundStyle(.secondary).padding()
                importButtons
                Spacer()
            }
        }
        .background(Color(red: 0.055, green: 0.065, blue: 0.07))
        .environment(\.adjustmentFocus,
                     AdjustmentFocusContext(activeID: focusedAdjustmentID,
                                            setActive: { focusedAdjustmentID = $0 }))
        .tint(.mint).preferredColorScheme(.dark)
        .overlay {
            if session.isImporting || photoLoading {
                ZStack {
                    Color.black.opacity(0.6).ignoresSafeArea()
                    ProgressView("Opening original…").padding(24).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
                }
            }
        }
        .sheet(item: $exportRequest, onDismiss: { exporter.close() }) { request in
            ExportView(request: request, controller: exporter)
        }
        .sheet(isPresented: $showLibrary) { LibraryView(session: session) }
        .photosPicker(isPresented: $showPhotos, selection: $selection, matching: .images, preferredItemEncoding: .current)
        .task { await session.restore() }
        .task { await presetController.load() }
        .task(id: selection) {
            guard let selection else { return }
            photoLoading = true
            defer { photoLoading = false; self.selection = nil }
            do {
                guard let photo = try await selection.loadTransferable(type: ImportedPhoto.self) else { throw PhotoError.unreadable }
                if Task.isCancelled {
                    try? FileManager.default.removeItem(at: photo.url.deletingLastPathComponent())
                    return
                }
                await session.importPhoto(at: photo.url, temporary: true)
            } catch { if !Task.isCancelled { session.error = error.localizedDescription } }
        }
        .fileImporter(isPresented: $showFiles, allowedContentTypes: [.image, .rawImage], allowsMultipleSelection: false) { result in
            do {
                if let url = try result.get().first { Task { await session.importPhoto(at: url) } }
            } catch { session.error = error.localizedDescription }
        }
        .alert("Unable to finish", isPresented: Binding(get: { session.error != nil }, set: { if !$0 { session.error = nil } })) {
            Button("OK") { session.error = nil }
        } message: { Text(session.error ?? "") }
        .onAppear { session.setMaskEditingPreview(panel == .masks) }
        .onChange(of: panel) { _, newPanel in
            session.setMaskEditingPreview(newPanel == .masks)
            if newPanel != .curve { curveEditMode = false; curveEyedropper = false
                curveSample = nil; curveSamplingBuffer = nil }
        }
        .onChange(of: session.document?.id) { _, _ in
            curveEditMode = false; curveEyedropper = false
            curveSample = nil; curveSamplingBuffer = nil
            clearClippingOverlay()
        }
        .onChange(of: session.result.map { ObjectIdentifier($0.image) }) { _, _ in
            clippingOverlay = nil; clippingSource = nil; clippingRequest &+= 1
            if clippingPressed, let image = session.result?.image { setClippingPress(true, image: image) }
        }
        .onChange(of: session.selectedMaskID) { _, selectedMaskID in
            if selectedMaskID != nil {
                curveEyedropper = false
                curveSample = nil
                curveSamplingBuffer = nil
            }
        }
        .onDisappear { session.setMaskEditingPreview(false) }
        .onChange(of: scenePhase) { _, phase in if phase != .active { session.flush() } }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)) { _ in session.memoryWarning() }
    }

    private func sourceFormat(_ result: RenderResult) -> String {
        if result.isRAW { return "RAW" }
        let ext = URL(fileURLWithPath: session.document?.originalName ?? "").pathExtension.uppercased()
        return ext == "JPEG" ? "JPG" : ext.isEmpty ? "IMAGE" : ext
    }

    private var showsPhotoInformation: Bool {
        ![Panel.creative, .optics, .geometry, .masks, .presets, .help].contains(panel)
    }

    private func editorControlColumn(_ result: RenderResult, landscape: Bool) -> some View {
        VStack(spacing: 0) {
            if landscape { landscapeToolbar }
            if showsPhotoInformation { photoInformation(result) }
            editorControls(result)
                .environment(\.usesSideControlLayout, landscape)
                .frame(height: landscape ? nil : 252)
                .frame(maxHeight: landscape ? .infinity : nil)
                .background(.black)
                .clipped()
            if !landscape { toolBar.dimsDuringAdjustment() }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black)
    }

    private func photoInformation(_ result: RenderResult) -> some View {
        HStack(spacing: 6) {
            Text(URL(fileURLWithPath: session.document?.originalName ?? "Photo")
                .deletingPathExtension().lastPathComponent)
                .lineLimit(1).truncationMode(.middle)
            activeLayerMenu
            Spacer(minLength: 0)
            if session.isRendering { ProgressView().controlSize(.mini) }
            Text(sourceFormat(result)).fixedSize()
            Text("\(result.sourceWidth) × \(result.sourceHeight)").fixedSize()
        }
        .font(.caption2).foregroundStyle(.secondary)
        .padding(.horizontal).frame(height: 28)
        .accessibilityIdentifier("photo-information")
        .dimsDuringAdjustment()
    }

    private var landscapeToolbar: some View {
        HStack(spacing: 0) {
            toolBar
            Button {
                controlsSideRaw = controlsSide == .leading
                    ? ControlsSide.trailing.rawValue : ControlsSide.leading.rawValue
            } label: {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 15, weight: .medium))
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Switch controls side")
            .accessibilityValue(controlsSide == .leading ? "Leading" : "Trailing")
            .accessibilityIdentifier("controls-side-switch")
            .padding(.trailing, 4)
        }
        .frame(height: 56)
        .dimsDuringAdjustment()
    }

    private func activeClippingOverlay(for image: CGImage) -> CGImage? {
        guard clippingPressed, let clippingSource, clippingSource === image else { return nil }
        return clippingOverlay
    }

    private func setClippingPress(_ active: Bool, image: CGImage) {
        clippingPressed = active
        clippingRequest &+= 1
        guard active else { return }
        if let clippingSource, clippingSource === image, clippingOverlay != nil { return }
        clippingOverlay = nil; clippingSource = nil
        let request = clippingRequest
        Task { @MainActor in
            let mask = await Task.detached(priority: .userInitiated) {
                HistogramClippingOverlay.make(from: image)
            }.value
            guard clippingPressed, clippingRequest == request,
                  let current = session.result?.image, current === image else { return }
            clippingSource = image
            clippingOverlay = mask
        }
    }

    private func clearClippingOverlay() {
        clippingPressed = false
        clippingOverlay = nil
        clippingSource = nil
        clippingRequest &+= 1
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("LUMORA").font(.system(.headline, design: .rounded)).tracking(3)
            Spacer()
            if session.result != nil {
                HStack(spacing: 0) {
                    Button { showPhotos = true } label: {
                        Image(systemName: "photo.on.rectangle").frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Import from Photos")
                    .accessibilityIdentifier("header-photos")
                    Button { showLibrary = true } label: {
                        Image(systemName: "photo.stack").frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Open library")
                    .accessibilityIdentifier("header-library")
                    Button(action: session.undo) { Image(systemName: "arrow.uturn.backward").frame(width: 44, height: 44) }
                        .disabled(!session.history.canUndo).accessibilityLabel("Undo")
                    Button(action: session.redo) { Image(systemName: "arrow.uturn.forward").frame(width: 44, height: 44) }
                        .disabled(!session.history.canRedo).accessibilityLabel("Redo")
                    Menu {
                        Button("Library", systemImage: "photo.stack") { showLibrary = true }
                        Button("Photos", systemImage: "photo.on.rectangle") { showPhotos = true }
                        Button("Export", systemImage: "square.and.arrow.up") { exportRequest = session.exportRequest() }
                        Button("Files", systemImage: "folder") { showFiles = true }
                        Button("Reset settings", systemImage: "arrow.counterclockwise", action: session.resetAll)
                        #if DEBUG
                        Toggle("Render metrics", isOn: $showMetrics)
                        #endif
                    } label: { Image(systemName: "ellipsis.circle").frame(width: 44, height: 44) }
                    .accessibilityLabel("Import and options")
                }
            }
        }.padding(.horizontal)
    }
    private var importButtons: some View {
        HStack(spacing: 8) {
            welcomeImportButton("Library", symbol: "photo.stack") { showLibrary = true }
                .accessibilityIdentifier("library-open")
            welcomeImportButton("Photos", symbol: "photo.on.rectangle", prominent: true) { showPhotos = true }
            welcomeImportButton("Files", symbol: "folder") { showFiles = true }
        }
        .padding(.horizontal, 16)
    }

    private func welcomeImportButton(_ title: LocalizedStringKey, symbol: String,
                                     prominent: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: symbol)
                Text(title).lineLimit(1).minimumScaleFactor(0.8)
            }
            .font(.caption)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Capsule())
        }
        .buttonStyle(WelcomeImportButtonStyle(prominent: prominent))
    }

    private var activeLayerMenu: some View {
        Menu {
            Button {
                selectQuickLayer(nil)
            } label: {
                Label("Whole photo",
                      systemImage: session.selectedMaskID == nil ? "checkmark" : "rectangle.fill")
            }
            .accessibilityIdentifier("quick-layer-base")
            if !session.state.masks.isEmpty { Divider() }
            ForEach(Array(session.state.masks.enumerated()), id: \.element.id) { index, mask in
                Button {
                    selectQuickLayer(mask.id)
                } label: {
                    Label(mask.name,
                          systemImage: mask.id == session.selectedMaskID
                              ? "checkmark"
                              : (mask.isVisible ? "circle.fill" : "eye.slash"))
                }
                .accessibilityIdentifier("quick-layer-mask-\(index)")
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: session.selectedMaskID == nil ? "rectangle.fill" : "circle.dashed")
                Text(session.activeLayerName).lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Active layer")
        .accessibilityValue(session.activeLayerName)
        .accessibilityIdentifier("active-layer")
    }

    private func selectQuickLayer(_ id: UUID?) {
        focusedAdjustmentID = nil
        if let id {
            session.selectMask(id)
            if panel == .optics || panel == .geometry { panel = .light }
        } else {
            session.selectBaseLayer()
        }
    }

    @ViewBuilder private func editorControls(_ result: RenderResult) -> some View {
        switch panel {
        case .curve:
            ScrollView {
                AutoCorrectionControls(session: session, module: .curves).padding(.horizontal)
                ToneCurveEditor(curves: session.activeState.curves, histogram: result.histogram,
                                channel: $curveChannel, editMode: $curveEditMode,
                                eyedropper: $curveEyedropper, sample: curveSample,
                                eyedropperAvailable: session.selectedMaskID == nil,
                                onClearSample: { curveSample = nil },
                                onBegin: { session.beginInteraction($0) },
                                onChange: session.setCurve, onEnd: session.finishInteraction)
                    .task(id: curveEyedropper ? session.generation : -1) {
                        guard curveEditMode, curveEyedropper, session.selectedMaskID == nil else {
                            curveSamplingBuffer = nil; curveSample = nil; return
                        }
                        curveSamplingBuffer = try? CurveSamplingBuffer.prepare(
                            original: result.original, state: session.state)
                    }
            }
            .accessibilityIdentifier("curve-controls-scroll")
        case .colorTools:
            ColorToolsView(mixer: session.activeState.colorMixer,
                           grading: session.activeState.colorGrading,
                           onBegin: session.beginInteraction,
                           onMixerChange: session.setMixer,
                           onGradingChange: session.setGrading,
                           onEnd: session.finishInteraction)
        case .creative:
            CreativeEffectsView(session: session, selected: $selectedCreativeEffectID)
        case .effects:
            effectsControls
        case .detail:
            DetailView(settings: session.activeState.detail,
                       onBegin: session.beginInteraction,
                       onChange: session.setDetail,
                       onEnd: session.finishInteraction,
                       onReset: session.resetDetail)
        case .optics:
            OpticsView(settings: session.state.optics, availability: result.optics, isRAW: result.isRAW,
                       onProfileChange: session.setProfileCorrection,
                       onBegin: session.beginInteraction,
                       onChange: session.setOptics,
                       onEnd: session.finishInteraction,
                       onReset: session.resetOptics)
        case .geometry:
            GeometryView(settings: session.state.geometry,
                         onRotate: session.rotateGeometry,
                         onFlip: session.toggleGeometryFlip,
                         onAspect: session.setCropAspect,
                         onAutoStraighten: { Task { await session.autoStraighten() } },
                         onAutoPerspective: { Task { await session.autoPerspective() } },
                         isAnalyzing: session.isAnalyzingGeometry,
                         onBegin: session.beginInteraction,
                         onChange: session.setGeometry,
                         onEnd: session.finishInteraction,
                         onResetAdjustment: session.resetGeometry,
                         onResetAll: session.resetGeometry)
        case .masks:
            MasksView(masks: session.state.masks,
                      selectedMaskID: session.selectedMaskID,
                      selectedComponentID: session.selectedMaskComponentID,
                      brushMode: session.brushMode,
                      onSelectBase: session.selectBaseLayer,
                      onSelectMask: session.selectMask,
                      onSelectComponent: session.selectMaskComponent,
                      onComponentOperation: session.setSelectedMaskComponentOperation,
                      onMoveComponent: session.moveSelectedMaskComponent,
                      onDeleteComponent: session.deleteSelectedMaskComponent,
                      onBrushMode: { session.brushMode = $0 },
                      onCreate: session.createMask,
                      onAddComponent: session.addMaskComponent,
                      onGenerate: { kind, operation in
                          Task { await session.generateSmartMask(kind, operation: operation) }
                      },
                      isGenerating: session.isGeneratingMask,
                      onDelete: session.deleteSelectedMask,
                      onRename: session.renameSelectedLayer,
                      overlayVisible: maskOverlayVisible,
                      onToggleVisibility: { maskOverlayVisible.toggle() },
                      onOpacity: session.setSelectedLayerOpacity,
                      onMove: session.moveSelectedLayer,
                      onInvert: session.toggleMaskInversion,
                      onBegin: session.beginInteraction,
                      onParameter: session.setMaskParameter,
                      onEnd: session.finishInteraction)
        case .presets:
            PresetsView(controller: presetController, state: session.state, onApply: session.applyPreset)
        case .help:
            EditorHelpView()
        case .light, .color:
            controls
        }
    }

    private var controls: some View {
        ScrollView {
            VStack(spacing: 6) {
                AutoCorrectionControls(session: session, module: panel == .light ? .light : .color)
                ForEach(panel == .light ? Adjustment.light : Adjustment.color) { adjustment in
                    AdjustmentSlider(adjustment: adjustment, value: session.activeState[adjustment],
                                     onBegin: { session.beginInteraction(adjustment) },
                                     onChange: { session.set(adjustment, to: $0) },
                                     onEnd: session.finishInteraction,
                                     onReset: { session.reset(adjustment) })
                }
            }.padding(.horizontal, 22).padding(.bottom, 12)
        }
    }
    private var toolBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Panel.allCases, id: \.self) { item in
                    Button { selectPanel(item) } label: {
                        Label(item.rawValue, systemImage: item.symbol)
                            .font(.subheadline.weight(.medium)).frame(minHeight: 44)
                            .padding(.horizontal, 10)
                            .background(panel == item ? Color.mint.opacity(0.12) : .clear, in: Capsule())
                    }.foregroundStyle(panel == item ? .mint : .secondary)
                        .accessibilityAddTraits(panel == item ? .isSelected : [])
                }
            }
        }
        .accessibilityIdentifier("tools-toolbar")
        .padding(.horizontal, 12).padding(.vertical, 6).background(.black.opacity(0.3))
    }
    private func selectPanel(_ item: Panel) {
        focusedAdjustmentID = nil
        if item == .optics || item == .geometry { session.selectBaseLayer() }
        else { session.finishInteraction() }
        panel = item
    }
    private var isAdjustingSelectedMask: Bool {
        guard session.selectedMaskID != nil, let id = focusedAdjustmentID else { return false }
        if Adjustment(rawValue: id) != nil { return true }
        return id.hasPrefix("creative-")
            || id.hasPrefix("effect-")
            || id.hasPrefix("detail-")
            || id.hasPrefix("mixer-")
            || id.hasPrefix("grading-")
    }
    private var effectsControls: some View {
        ScrollView {
            VStack(spacing: 6) {
                ForEach(EffectAdjustment.allCases) { adjustment in
                    AdjustmentSlider(title: adjustment.title, range: adjustment.range,
                                     accessibilityID: "effect-\(adjustment.rawValue)",
                                     value: session.activeState.effects[adjustment],
                                     onBegin: { session.beginInteraction(adjustment.title) },
                                     onChange: { session.setEffect(adjustment, to: $0) },
                                     onEnd: session.finishInteraction,
                                     onReset: { session.resetEffect(adjustment) })
                }
            }.padding(.horizontal, 22).padding(.bottom, 12)
        }
        .accessibilityIdentifier("effects-controls")
    }
    #if DEBUG
    private func metrics(_ result: RenderResult) -> some View {
        Text(String(format: "%.1f ms · %@ · cache %@ · generation %d\n%d × %d preview · ≈ %.1f MB pixels · FPS: not measured",
                    result.milliseconds, result.gpu ? "Metal" : "Core Image CPU", result.cacheHit ? "hit" : "miss", session.generation,
                    result.image.width, result.image.height,
                    Double(result.image.bytesPerRow * result.image.height + result.original.bytesPerRow * result.original.height) / 1_048_576))
            .font(.system(.caption2, design: .monospaced)).foregroundStyle(.secondary).padding(8)
    }
    #endif
}

private struct WelcomeImportButtonStyle: ButtonStyle {
    let prominent: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(prominent ? Color.black : Color.mint)
            .background(Capsule().fill(Color.mint.opacity(prominent ? 1 : 0.16)))
            .opacity(configuration.isPressed ? 0.65 : 1)
    }
}

/// Keeps the canvas in the same SwiftUI identity across rotations and side
/// switches, preserving its transient zoom and pan state.
private struct EditorWorkspaceLayout: Layout {
    let landscape: Bool
    let controlsSide: String
    let direction: LayoutDirection
    let portraitControlsHeight: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        CGSize(width: proposal.width ?? 0, height: proposal.height ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize,
                       subviews: Subviews, cache: inout ()) {
        guard subviews.count == 2 else { return }
        if landscape {
            let controlsWidth = min(340, max(248, bounds.width * 0.35))
            let photoWidth = max(0, bounds.width - controlsWidth)
            let leadingIsLeft = direction == .leftToRight
            let controlsOnLeft = (controlsSide != "trailing") == leadingIsLeft
            let controlsX = controlsOnLeft ? bounds.minX : bounds.maxX - controlsWidth
            let photoX = controlsOnLeft ? bounds.minX + controlsWidth : bounds.minX
            subviews[0].place(at: CGPoint(x: photoX, y: bounds.minY),
                              proposal: ProposedViewSize(width: photoWidth, height: bounds.height))
            subviews[1].place(at: CGPoint(x: controlsX, y: bounds.minY),
                              proposal: ProposedViewSize(width: controlsWidth, height: bounds.height))
        } else {
            let controlsHeight = min(bounds.height, portraitControlsHeight)
            subviews[0].place(at: CGPoint(x: bounds.minX, y: bounds.minY),
                              proposal: ProposedViewSize(width: bounds.width,
                                                         height: max(0, bounds.height - controlsHeight)))
            subviews[1].place(at: CGPoint(x: bounds.minX, y: bounds.maxY - controlsHeight),
                              proposal: ProposedViewSize(width: bounds.width, height: controlsHeight))
        }
    }
}
