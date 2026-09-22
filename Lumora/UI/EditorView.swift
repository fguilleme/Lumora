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
    @State private var exportRequest: ExportRequest?
    @State private var exporter = ExportController()
    @State private var presetController = PresetController()
    @State private var focusedAdjustmentID: String?
    @State private var selectedCreativeEffectID: UUID?
    @Environment(\.scenePhase) private var scenePhase
    private enum Panel: String, CaseIterable {
        case creative = "Creative"
        case light = "Lumière", color = "Couleur", curve = "Courbes", colorTools = "Colorimétrie", effects = "Effets", detail = "Détail", optics = "Optique", geometry = "Géométrie", masks = "Masques", presets = "Presets"
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
                HistogramView(histogram: result.histogram)
                    .frame(height: 52).padding(.vertical, 4)
                    .dimsDuringAdjustment()
                PhotoCanvas(result: result, showingOriginal: $session.showingOriginal,
                            dlcSettings: activeDLCSettings,
                            onDLCBegin: { session.beginInteraction("Déplacer le centre") },
                            onDLCChange: { point in
                                guard let id = selectedCreativeEffectID else { return }
                                session.changeCreative("Déplacer le centre") { stack in
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
                            allowsMaskEditing: panel == .masks,
                            brushMode: session.brushMode,
                            onBrushBegin: session.beginBrushStroke,
                            onBrushPoint: session.appendBrushPoint,
                            onBrushEnd: session.finishInteraction,
                            onMaskTransformBegin: { session.beginInteraction("Transformer la composante") },
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
                if ![Panel.creative, .optics, .geometry, .masks, .presets].contains(panel) {
                    HStack(spacing: 6) {
                        Text(URL(fileURLWithPath: session.document?.originalName ?? "Photographie").deletingPathExtension().lastPathComponent)
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
                editorControls(result)
                    .frame(height: 252)
                    .background(.black)
                    .clipped()
                toolBar.dimsDuringAdjustment()
                #if DEBUG
                if showMetrics { metrics(result) }
                #endif
            } else {
                Spacer()
                Image(systemName: "camera.aperture").font(.system(size: 64, weight: .ultraLight)).foregroundStyle(.mint)
                Text("La lumière, à votre façon.").font(.title2).padding(.top, 20)
                Text("Importez une photographie pour commencer.\nVotre original reste intact, vos retouches restent locales.")
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
                    ProgressView("Ouverture de l’original…").padding(24).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
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
        .alert("Impossible de terminer", isPresented: Binding(get: { session.error != nil }, set: { if !$0 { session.error = nil } })) {
            Button("OK") { session.error = nil }
        } message: { Text(session.error ?? "") }
        .onAppear { session.setMaskEditingPreview(panel == .masks) }
        .onChange(of: panel) { _, newPanel in session.setMaskEditingPreview(newPanel == .masks) }
        .onDisappear { session.setMaskEditingPreview(false) }
        .onChange(of: scenePhase) { _, phase in if phase != .active { session.flush() } }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)) { _ in session.memoryWarning() }
    }

    private func sourceFormat(_ result: RenderResult) -> String {
        if result.isRAW { return "RAW" }
        let ext = URL(fileURLWithPath: session.document?.originalName ?? "").pathExtension.uppercased()
        return ext == "JPEG" ? "JPG" : ext.isEmpty ? "IMAGE" : ext
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("LUMORA").font(.system(.headline, design: .rounded)).tracking(3)
            Spacer()
            if session.result != nil {
                Button(action: session.undo) { Image(systemName: "arrow.uturn.backward").frame(width: 44, height: 44) }
                    .disabled(!session.history.canUndo).accessibilityLabel("Annuler")
                Button(action: session.redo) { Image(systemName: "arrow.uturn.forward").frame(width: 44, height: 44) }
                    .disabled(!session.history.canRedo).accessibilityLabel("Rétablir")
                Menu {
                    Button("Bibliothèque", systemImage: "photo.stack") { showLibrary = true }
                    Button("Photos", systemImage: "photo.on.rectangle") { showPhotos = true }
                    Button("Exporter", systemImage: "square.and.arrow.up") { exportRequest = session.exportRequest() }
                    Button("Fichiers", systemImage: "folder") { showFiles = true }
                    Button("Réinitialiser les réglages", systemImage: "arrow.counterclockwise", action: session.resetAll)
                    #if DEBUG
                    Toggle("Mesures de rendu", isOn: $showMetrics)
                    #endif
                } label: { Image(systemName: "ellipsis.circle").frame(width: 44, height: 44) }
                .accessibilityLabel("Importer et options")
            }
        }.padding(.horizontal)
    }
    private var importButtons: some View {
        HStack {
            Button { showLibrary = true } label: {
                Label("Bibliothèque", systemImage: "photo.stack").padding(6)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("library-open")
            Button { showPhotos = true } label: {
                Label("Photos", systemImage: "photo.on.rectangle").padding(6)
            }.buttonStyle(.borderedProminent)
            Button { showFiles = true } label: { Label("Fichiers", systemImage: "folder").padding(6) }.buttonStyle(.bordered)
        }
    }

    private var activeLayerMenu: some View {
        Menu {
            Button {
                selectQuickLayer(nil)
            } label: {
                Label("Photo entière",
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
        .accessibilityLabel("Calque actif")
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
                ToneCurveEditor(curves: session.activeState.curves, histogram: result.histogram,
                                onBegin: { session.beginInteraction($0) },
                                onChange: session.setCurve, onEnd: session.finishInteraction)
            }
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
                      onToggleVisibility: session.toggleSelectedLayerVisibility,
                      onOpacity: session.setSelectedLayerOpacity,
                      onMove: session.moveSelectedLayer,
                      onInvert: session.toggleMaskInversion,
                      onBegin: session.beginInteraction,
                      onParameter: session.setMaskParameter,
                      onEnd: session.finishInteraction)
        case .presets:
            PresetsView(controller: presetController, state: session.state, onApply: session.applyPreset)
        case .light, .color:
            controls
        }
    }

    private var controls: some View {
        ScrollView {
            VStack(spacing: 6) {
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
        Text(String(format: "%.1f ms · %@ · cache %@ · génération %d\n%d × %d preview · ≈ %.1f Mo pixels · FPS : non mesuré",
                    result.milliseconds, result.gpu ? "Metal" : "Core Image CPU", result.cacheHit ? "hit" : "miss", session.generation,
                    result.image.width, result.image.height,
                    Double(result.image.bytesPerRow * result.image.height + result.original.bytesPerRow * result.original.height) / 1_048_576))
            .font(.system(.caption2, design: .monospaced)).foregroundStyle(.secondary).padding(8)
    }
    #endif
}
