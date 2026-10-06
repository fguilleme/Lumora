import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct EditorView: View {
    @State private var session = EditorSession()
    @State private var selection: PhotosPickerItem?
    @State private var showFiles = false
    @State private var showPhotos = false
    @State private var showLibrary = false
    @State private var showFullscreenPhoto = false
    @State private var photoLoading = false
    @State private var placingLightingSubject = true
    @State private var panel: Panel = .light
    @State private var maskOverlayVisible = true
    @State private var clippingPressed = false
    @State private var clippingOverlay: CGImage?
    @State private var clippingSource: CGImage?
    @State private var clippingRequest = 0
    @State private var clippingActivationCount = 0
    @State private var exportRequest: ExportRequest?
    @State private var showHeaderOptions = false
    @State private var exporter = ExportController()
    @State private var presetController = PresetController()
    @State private var focusedAdjustmentID: String?
    @State private var selectedCreativeEffectID: UUID?
    @State private var selectedEffectParameter = EffectAdjustment.cinematicGlow.rawValue
    @State private var curveChannel: CurveChannel = .rgb
    @State private var curveEditMode = false
    @State private var curveEyedropper = false
    @State private var curveSelectedPoint: Int?
    @State private var curveSample: CurveSample?
    @State private var curveSamplingBuffer: CurveSamplingBuffer?
    @State private var selectedLightParameter = Adjustment.exposure.rawValue
    @State private var selectedColorParameter = Adjustment.temperature.rawValue
    @AppStorage("editor.controlsSide") private var controlsSideRaw = ControlsSide.leading.rawValue
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.layoutDirection) private var layoutDirection
    private enum ControlsSide: String { case leading, trailing }
    private var controlsSide: ControlsSide { ControlsSide(rawValue: controlsSideRaw) ?? .leading }
    private typealias Panel = EditorPanel
    @AppStorage("editor.showHistogram") private var showHistogram = true
    @AppStorage("export.includeMetadata") private var includeMetadataInExport = true
    @AppStorage("editor.tabOrder") private var tabOrder = ""
    @AppStorage("editor.hiddenTabs") private var hiddenTabs = ""
    @State private var showSettingsSheet = false
    private var visiblePanels: [Panel] { EditorTabPreferences.visible(order: tabOrder, hidden: hiddenTabs) }

    init() {
        #if DEBUG
        if let option = CommandLine.arguments.firstIndex(of: "--app-store-panel"),
           CommandLine.arguments.indices.contains(option + 1),
           let panel = Panel(rawValue: CommandLine.arguments[option + 1]) {
            _panel = State(initialValue: panel)
        }
        #endif
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
                    let landscape = available.size.width > available.size.height
                    VStack(spacing: 0) {
                        if panel == .exif || panel == .help || panel == .settings {
                            editorControls(result)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(.black)
                                .accessibilityIdentifier("editor-full-page")
                        } else {
                        EditorWorkspaceLayout(landscape: landscape,
                                              isPhone: UIDevice.current.userInterfaceIdiom == .phone,
                                              controlsSide: controlsSideRaw,
                                              direction: layoutDirection,
                                              portraitControlsHeight: portraitControlContentHeight + (showsPhotoInformation ? 24 : 0),
                                              overlayOnly: false) {
                PhotoCanvas(result: result, clippingOverlay: activeClippingOverlay(for: result.image),
                            onClippingOverlayAppear: {
                                // Test-only accessibility counter: proves the photo overlay
                                // appeared during an XCTest press without persisting UI state.
                                if ProcessInfo.processInfo.arguments.contains("-ui-testing-clipping") {
                                    clippingActivationCount &+= 1
                                }
                            },
                            diagnosticGeneration: ProcessInfo.processInfo.arguments.contains("-ui-testing-landscape") ? session.generation : nil,
                            curveSampling: panel == .curve && curveEyedropper && session.selectedMaskID == nil && curveSamplingBuffer != nil,
                            curveSampleLocation: curveSample?.location,
                            onCurveSample: { location in
                                if let value = curveSamplingBuffer?.sample(at: location) { curveSample = value }
                            },
                            depthFocusActive: panel == .depthLens && session.state.depthLens?.enabled == true,
                            depthFocusPoint: CGPoint(x: session.state.depthLens?.focusX ?? 0.5, y: session.state.depthLens?.focusY ?? 0.5),
                            onDepthFocus: session.focusDepthLens,
                            lightingSettings: panel == .lighting ? session.state.depthLighting : nil,
                            lightingSubjectMode: placingLightingSubject,
                            onLightingBegin: { session.beginInteraction(String(localized: "Lighting")) },
                            onLightingMove: { subject, point in
                                session.changeDepthLighting {
                                    if subject { $0.targetX = point.x; $0.targetY = point.y }
                                }
                            },
                            onLightingAngles: { azimuth, elevation in
                                session.changeDepthLighting {
                                    $0.azimuth = azimuth; $0.elevation = elevation
                                }
                            },
                            onLightingEnd: session.finishInteraction,
                            healingActive: panel == .beauty && session.healingActive,
                            healingPaintZone: session.healingPaintZone,
                            onHealingPaint: session.paintHealing,
                            onHealingPaintEnd: session.endHealingStroke,
                            healingCorrections: session.state.beauty.corrections,
                            healingSelectedID: session.selectedHealingID,
                            healingGeometry: session.healingGeometry,
                            onHealingTap: session.healingTap,
                            onHealingSelect: { session.selectedHealingID = $0 },
                            onHealingBegin: { session.beginInteraction(String(localized: "Correction")) },
                            onHealingMove: { session.moveHealing($0, source: $1, visible: $2) },
                            onHealingEnd: session.finishInteraction,
                            onPhotoTap: { showFullscreenPhoto = true },
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
                            onBrushBegin: { session.beginBrushStroke(displayScale: $0) },
                            onBrushPoint: session.appendBrushPoint,
                            onBrushEnd: session.finishBrushStroke,
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
                        if showHistogram { HistogramView(histogram: result.histogram,
                                      imageSize: CGSize(width: result.image.width, height: result.image.height),
                                      diagnosticActivationCount: ProcessInfo.processInfo.arguments.contains("-ui-testing-clipping") ? clippingActivationCount : nil,
                                      onClippingPressChanged: { active in
                                          setClippingPress(active, image: result.image)
                                      })
                            .id(session.document?.id)
                        }
                    }
                    .overlay {
                        if panel == .curve { curveOverlay(result) }
                    }
                editorControlColumn(result, landscape: landscape)
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("editor-controls-column")
                        }
                        .frame(maxHeight: .infinity)
                        }
                        if landscape && panel != .exif && panel != .help && panel != .settings { landscapeToolbar } else { toolBar().dimsDuringAdjustment() }
                    }
                    .onChange(of: landscape) { _, _ in session.finishInteraction() }
                }
            } else {
                Spacer()
                Image(systemName: "camera.aperture").font(.system(size: 64, weight: .ultraLight)).foregroundStyle(.mint)
                Text("Light, your way.").font(.title2).padding(.top, 20)
                Text("Import a photo to get started.\nYour original stays intact, and your edits stay local.")
                    .font(.subheadline).multilineTextAlignment(.center).foregroundStyle(.secondary).padding()
                importButtons
                Button("Settings", systemImage: "gearshape") { showSettingsSheet = true }.padding()
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
        .fullScreenCover(isPresented: $showFullscreenPhoto) {
            if let result = session.result {
                FullscreenPhotoView(image: session.showingOriginal ? result.original : result.image) {
                    showFullscreenPhoto = false
                }
            }
        }
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
        .sheet(isPresented: $showSettingsSheet) {
            NavigationStack { EditorSettingsView(showHistogram: $showHistogram, includeMetadataInExport: $includeMetadataInExport,
                                                  tabOrder: $tabOrder, hiddenTabs: $hiddenTabs).navigationTitle("Settings")
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Close") { showSettingsSheet = false } } }
            }.preferredColorScheme(.dark)
        }
        .onChange(of: showHistogram) { _, shown in if !shown { clippingPressed = false; clippingRequest += 1; clippingOverlay = nil; clippingSource = nil } }
        .onChange(of: visiblePanels) { _, tabs in if !tabs.contains(panel) { selectPanel(tabs.first ?? .settings) } }
        .onAppear {
            if !visiblePanels.contains(panel) { selectPanel(visiblePanels.first ?? .settings) }
            if panel == .curve { curveEditMode = true }
            session.setMaskEditingPreview(panel == .masks)
        }
        .onChange(of: panel) { _, newPanel in
            session.closeHealing()
            session.setMaskEditingPreview(newPanel == .masks)
            if newPanel == .beauty { Task { await session.analyzeBeautyFaces() } }
            if newPanel == .curve { curveEditMode = true }
            else { curveEditMode = false; curveEyedropper = false
                curveSelectedPoint = nil; curveSample = nil; curveSamplingBuffer = nil }
        }
        .onChange(of: session.document?.id) { _, _ in
            session.closeHealing()
            curveEditMode = panel == .curve; curveEyedropper = false
            curveSelectedPoint = nil
            curveSample = nil; curveSamplingBuffer = nil
            clearClippingOverlay()
            if panel == .beauty { Task { await session.analyzeBeautyFaces() } }
        }
        .onChange(of: session.state.geometry) { _, _ in
            if panel == .beauty { Task { await session.analyzeBeautyFaces() } }
        }
        .onChange(of: session.state.optics) { _, _ in
            if panel == .beauty { Task { await session.analyzeBeautyFaces() } }
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
        .onChange(of: scenePhase) { _, phase in
            guard phase != .active else { return }
            // iOS can interrupt a UISlider without delivering touchUp/touchCancel
            // (Control Centre, app switcher, lock, incoming system UI). Never leave
            // the editor in its focused state, which hides the other controls.
            focusedAdjustmentID = nil
            session.flush()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)) { _ in session.memoryWarning() }
    }

    private func sourceFormat(_ result: RenderResult) -> String {
        if result.isRAW { return "RAW" }
        let ext = URL(fileURLWithPath: session.document?.originalName ?? "").pathExtension.uppercased()
        return ext == "JPEG" ? "JPG" : ext.isEmpty ? "IMAGE" : ext
    }

    private var showsPhotoInformation: Bool {
        ![Panel.creative, .depthLens, .lighting, .optics, .geometry, .masks, .presets, .exif, .help, .settings].contains(panel)
    }

    private var portraitControlContentHeight: CGFloat {
        switch panel {
        case .effects: 112
        case .light, .color: 154
        case .detail: 118
        case .curve: 224
        case .geometry: 220
        default: 252
        }
    }

    private func editorControlColumn(_ result: RenderResult, landscape: Bool) -> some View {
        VStack(spacing: 0) {
            if showsPhotoInformation { photoInformation(result) }
            editorControls(result)
                .environment(\.usesSideControlLayout, landscape)
                .frame(height: landscape ? nil : portraitControlContentHeight)
                .frame(maxHeight: landscape ? .infinity : nil)
                .background(.black)
                .clipped()
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
            Text("\(sourceFormat(result)) · \(result.sourceWidth) × \(result.sourceHeight)").fixedSize()
        }
        .font(.caption2).foregroundStyle(.secondary)
        .padding(.horizontal, 12).frame(height: 24)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("photo-information")
        .dimsDuringAdjustment()
    }

    private var landscapeToolbar: some View {
        ZStack(alignment: .trailing) {
            toolBar(trailingInset: 56)
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
            .padding(.trailing, 6)
            .background(.black)
        }
        .frame(height: 56)
        .frame(maxWidth: .infinity)
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
            Text("LUMORA✨").font(.system(.subheadline, design: .rounded)).tracking(3)
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
                    Button { showHeaderOptions = true } label: {
                        ZStack {
                            Rectangle().fill(Color(red: 0.055, green: 0.065, blue: 0.07))
                            Image(systemName: "ellipsis.circle")
                        }
                        .frame(width: 54, height: 48)
                        .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Import and options")
                    .accessibilityIdentifier("header-options")
                    .confirmationDialog("Options", isPresented: $showHeaderOptions, titleVisibility: .hidden) {
                        Button("Settings", systemImage: "gearshape") { selectPanel(.settings) }
                            .accessibilityIdentifier("open-editor-settings")
                        Button("Library", systemImage: "photo.stack") { showLibrary = true }
                        Button("Photos", systemImage: "photo.on.rectangle") { showPhotos = true }
                        Button("Export", systemImage: "square.and.arrow.up") {
                            exporter.settings.includeMetadata = includeMetadataInExport
                            exportRequest = session.exportRequest()
                        }
                            .accessibilityIdentifier("header-option-export")
                        Button("Files", systemImage: "folder") { showFiles = true }
                        Button("Reset settings", systemImage: "arrow.counterclockwise", action: session.resetAll)
                        Button("Cancel", role: .cancel) {}
                    }
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
            VStack(spacing: 4) {
                AutoCorrectionControls(session: session, module: .curves)
                CurvePointControls(curves: session.activeState.curves,
                                   channel: curveChannel,
                                   selected: $curveSelectedPoint,
                                   eyedropper: $curveEyedropper,
                                   eyedropperAvailable: session.selectedMaskID == nil,
                                   onClearSample: { curveSample = nil },
                                   onBegin: session.beginInteraction,
                                   onChange: session.setCurve,
                                   onEnd: session.finishInteraction)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
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
        case .lighting:
            DepthLightingView(session: session, placingSubject: $placingLightingSubject)
        case .depthLens:
            DepthLensView(session: session)
        case .detail:
            DetailView(settings: session.activeState.detail,
                       onBegin: session.beginInteraction,
                       onChange: session.setDetail,
                       onEnd: session.finishInteraction,
                       onReset: session.resetDetail)
        case .beauty:
            BeautyView(session: session, settings: session.state.beauty,
                       faceCount: session.beautyFaceCount,
                       isAnalyzing: session.isAnalyzingBeauty,
                       debugMasks: session.beautyDebugMasks,
                       onPreset: session.applyBeautyPreset,
                       onBegin: session.beginInteraction,
                       onChange: session.setBeauty,
                       onV2Change: session.setBeautyV2,
                       onEnd: session.finishInteraction,
                       onReset: session.resetBeauty)
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
            MasksView(sourceImage: session.result?.image,
                      masks: session.state.masks,
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
                      onMagicMask: session.commitMagicMask,
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
        case .exif:
            EXIFMetadataView(sourceURL: session.originalURL)
        case .help:
            EditorHelpView()
        case .settings:
            EditorSettingsView(showHistogram: $showHistogram, includeMetadataInExport: $includeMetadataInExport,
                               tabOrder: $tabOrder, hiddenTabs: $hiddenTabs)
        case .light, .color:
            controls
        }
    }

    private var controls: some View {
        VStack(spacing: 5) {
            AutoCorrectionControls(session: session, module: panel == .light ? .light : .color)
                .padding(.horizontal, 8)
            LinearAdjustmentControl(parameters: scalarParameters,
                                    selectedID: panel == .light ? $selectedLightParameter : $selectedColorParameter,
                                    onBegin: { parameter in
                                        if let adjustment = Adjustment(rawValue: parameter.id) { session.beginInteraction(adjustment) }
                                    },
                                    onChange: { parameter, value in
                                        if let adjustment = Adjustment(rawValue: parameter.id) { session.set(adjustment, to: value) }
                                    },
                                    onEnd: session.finishInteraction,
                                    onReset: { parameter in
                                        if let adjustment = Adjustment(rawValue: parameter.id) { session.reset(adjustment) }
                                    })
            Spacer(minLength: 0)
        }
        .padding(.top, 4)
    }

    private var scalarParameters: [LinearAdjustmentParameter] {
        (panel == .light ? Adjustment.light : Adjustment.color).map { adjustment in
            LinearAdjustmentParameter(id: adjustment.rawValue, title: adjustment.title,
                                      value: session.activeState[adjustment], range: adjustment.range,
                                      step: adjustment.step, precision: adjustment == .exposure ? 2 : 0,
                                      unit: adjustment == .exposure ? " EV" : "", resetValue: 0)
        }
    }

    private func curveOverlay(_ result: RenderResult) -> some View {
        CurveOverlayCard(curves: session.activeState.curves, histogram: result.histogram,
                         channel: $curveChannel, eyedropper: $curveEyedropper,
                         selectedPoint: $curveSelectedPoint, sample: curveSample,
                         eyedropperAvailable: session.selectedMaskID == nil,
                         onClearSample: { curveSample = nil },
                         onBegin: { session.beginInteraction($0) },
                         onChange: session.setCurve, onEnd: session.finishInteraction)
        .task(id: curveEyedropper ? session.generation : -1) {
            guard curveEyedropper, session.selectedMaskID == nil else {
                curveSamplingBuffer = nil; curveSample = nil; return
            }
            curveSamplingBuffer = try? CurveSamplingBuffer.prepare(original: result.original, state: session.state)
        }
    }
    private func toolBar(trailingInset: CGFloat = 0) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(visiblePanels, id: \.self) { item in
                        Button { selectPanel(item) } label: {
                            Label(item.title, systemImage: item.symbol)
                                .font(.subheadline.weight(.medium)).frame(minHeight: 44)
                                .padding(.horizontal, 8)
                                .background(panel == item ? Color.mint.opacity(0.09) : .clear, in: Capsule())
                        }.foregroundStyle(panel == item ? .mint : .secondary)
                            .id(item)
                            .accessibilityAddTraits(panel == item ? .isSelected : [])
                            .accessibilityIdentifier("editor-tab-\(item.rawValue)")
                            .contextMenu {
                                Section("Open a tab") {
                                    ForEach(visiblePanels, id: \.self) { candidate in
                                        Button {
                                            selectPanel(candidate)
                                        } label: {
                                            Label(candidate.title, systemImage: candidate.symbol)
                                        }
                                        .accessibilityIdentifier("tab-select-\(candidate.rawValue)")
                                    }
                                }
                                Divider()
                                Button("Manage tabs…", systemImage: "list.bullet") { selectPanel(.settings) }
                            }
                    }
                }
                .padding(.leading, 12)
                .padding(.trailing, 12 + trailingInset)
            }
            .onChange(of: panel) { _, selected in
                guard visiblePanels.contains(selected) else { return }
                withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(selected, anchor: .center) }
            }
        }
        .accessibilityIdentifier("tools-toolbar")
        .padding(.vertical, 4).background(.black.opacity(0.3))
    }
    private func selectPanel(_ item: Panel) {
        focusedAdjustmentID = nil
        if item == .lighting || item == .depthLens || item == .optics || item == .geometry || item == .beauty || item == .exif { session.selectBaseLayer() }
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
            LinearAdjustmentControl(parameters: effectParameters, selectedID: $selectedEffectParameter,
                onBegin: { parameter in
                    if parameter.id == EffectAdjustment.cinematicGlow.rawValue { session.selectBaseLayer() }
                    session.beginInteraction(parameter.title)
                },
                onChange: { parameter, value in
                    if let adjustment = EffectAdjustment(rawValue: parameter.id) { session.setEffect(adjustment, to: value) }
                }, onEnd: session.finishInteraction,
                onReset: { parameter in
                    if let adjustment = EffectAdjustment(rawValue: parameter.id) { session.resetEffect(adjustment) }
                })
                .padding(.bottom, 12)
        }
        .accessibilityIdentifier("effects-controls")
    }
    private var effectParameters: [LinearAdjustmentParameter] {
        EffectAdjustment.allCases.map { adjustment in
            let value = adjustment == .cinematicGlow
                ? session.state.effects.cinematicGlowIntensity
                : session.activeState.effects[adjustment]
            return LinearAdjustmentParameter(id: adjustment.rawValue, title: adjustment.title,
                value: value, range: adjustment.range, step: 1, precision: 0, resetValue: 0)
        }
    }

}

private struct FullscreenPhotoView: View {
    let image: CGImage
    let onDismiss: () -> Void

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                Image(decorative: image, scale: 1)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: geometry.size.width, height: geometry.size.height)
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onDismiss)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Full-screen photo")
            .accessibilityHint("Tap to return to the editor")
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("fullscreen-photo")
        }
        .ignoresSafeArea()
        .background(.black)
        .statusBarHidden()
    }
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
    let isPhone: Bool
    let controlsSide: String
    let direction: LayoutDirection
    let portraitControlsHeight: CGFloat
    let overlayOnly: Bool

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        CGSize(width: proposal.width ?? 0, height: proposal.height ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize,
                       subviews: Subviews, cache: inout ()) {
        guard subviews.count == 2 else { return }
        if overlayOnly {
            subviews[0].place(at: bounds.origin,
                              proposal: ProposedViewSize(width: bounds.width, height: bounds.height))
            subviews[1].place(at: CGPoint(x: bounds.minX, y: bounds.maxY),
                              proposal: ProposedViewSize(width: bounds.width, height: 0))
            return
        }
        if landscape {
            let desiredControlsWidth = min(640, max(460, bounds.width * 0.47))
            let minimumPhotoWidth = min(220, bounds.width * 0.32)
            let maximumControlsWidth = isPhone ? bounds.width * 0.5 : bounds.width
            let controlsWidth = min(desiredControlsWidth,
                                    max(0, bounds.width - minimumPhotoWidth),
                                    maximumControlsWidth)
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
