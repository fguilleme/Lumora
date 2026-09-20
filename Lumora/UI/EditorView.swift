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
    @Environment(\.scenePhase) private var scenePhase
    private enum Panel: String, CaseIterable {
        case light = "Lumière", color = "Couleur", curve = "Courbes", mixer = "Mélangeur", grading = "Grading", effects = "Effets", detail = "Détail", optics = "Optique", geometry = "Géométrie", masks = "Masques", presets = "Presets"
        var symbol: String {
            switch self {
            case .light: "sun.max"
            case .color: "slider.horizontal.3"
            case .curve: "point.topleft.down.to.point.bottomright.curvepath"
            case .mixer: "circle.lefthalf.filled"
            case .grading: "circle.hexagongrid"
            case .effects: "camera.filters"
            case .detail: "triangle"
            case .optics: "camera.aperture"
            case .geometry: "crop.rotate"
            case .masks: "circle.dashed.inset.filled"
            case .presets: "slider.horizontal.2.square"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            if let result = session.result {
                HistogramView(histogram: result.histogram).padding(.vertical, 8)
                PhotoCanvas(result: result, showingOriginal: $session.showingOriginal,
                            activeMask: panel == .masks ? session.selectedMask : nil,
                            activeComponentID: session.selectedMaskComponentID,
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
                HStack {
                    Text(session.document?.originalName ?? "Photographie").lineLimit(1)
                    Text("·")
                    Label(session.activeLayerName,
                          systemImage: session.selectedMaskID == nil ? "rectangle.fill" : "circle.dashed")
                        .lineLimit(1).accessibilityIdentifier("active-layer")
                    Spacer()
                    if session.isRendering { ProgressView().controlSize(.mini) }
                    Text(result.isRAW ? "RAW" : "\(result.sourceWidth) × \(result.sourceHeight)")
                }.font(.caption2).foregroundStyle(.secondary).padding(.horizontal).padding(.vertical, 6)
                if panel == .curve {
                    ScrollView {
                        ToneCurveEditor(curves: session.activeState.curves, histogram: result.histogram,
                                        onBegin: { session.beginInteraction($0) },
                                        onChange: session.setCurve, onEnd: session.finishInteraction)
                    }.frame(height: 335)
                } else if panel == .mixer {
                    ScrollView {
                        ColorMixerView(mixer: session.activeState.colorMixer,
                                       onBegin: { session.beginInteraction($0) },
                                       onChange: session.setMixer, onEnd: session.finishInteraction)
                    }.accessibilityIdentifier("mixer-controls").frame(height: 380)
                } else if panel == .grading {
                    ScrollView {
                        ColorGradingView(grading: session.activeState.colorGrading,
                                         onBegin: { session.beginInteraction($0) },
                                         onChange: session.setGrading, onEnd: session.finishInteraction)
                    }.accessibilityIdentifier("grading-controls").frame(height: 380)
                } else if panel == .effects {
                    effectsControls
                } else if panel == .detail {
                    DetailView(settings: session.activeState.detail,
                               onBegin: session.beginInteraction,
                               onChange: session.setDetail,
                               onEnd: session.finishInteraction,
                               onReset: session.resetDetail)
                        .frame(height: 340)
                } else if panel == .optics {
                    OpticsView(settings: session.state.optics, availability: result.optics, isRAW: result.isRAW,
                               onProfileChange: session.setProfileCorrection,
                               onBegin: session.beginInteraction,
                               onChange: session.setOptics,
                               onEnd: session.finishInteraction,
                               onReset: session.resetOptics)
                        .frame(height: 330)
                } else if panel == .geometry {
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
                        .frame(height: 350)
                } else if panel == .masks {
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
                              onAdjustment: session.setLocalAdjustment,
                              onResetAdjustment: session.resetLocalAdjustment,
                              onParameter: session.setMaskParameter,
                              onEnd: session.finishInteraction)
                        .frame(height: 370)
                } else if panel == .presets {
                    PresetsView(controller: presetController, state: session.state, onApply: session.applyPreset)
                        .frame(height: 370)
                } else {
                    controls
                }
                toolBar
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
        .onChange(of: scenePhase) { _, phase in if phase != .active { session.flush() } }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)) { _ in session.memoryWarning() }
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
        .frame(height: 230)
    }
    private var toolBar: some View {
        HStack(spacing: 6) {
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
            Button { session.showingOriginal.toggle() } label: {
                Image(systemName: session.showingOriginal ? "eye.fill" : "eye").frame(width: 44, height: 44)
            }.accessibilityLabel("Avant / après").accessibilityValue(session.showingOriginal ? "Original" : "Retouchée")
        }.padding(.horizontal, 12).padding(.vertical, 6).background(.black.opacity(0.3))
    }
    private func selectPanel(_ item: Panel) {
        if item == .optics || item == .geometry { session.selectBaseLayer() }
        else { session.finishInteraction() }
        panel = item
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
        .frame(height: 300)
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
