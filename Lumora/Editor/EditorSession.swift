import Foundation
import Observation
import CoreGraphics

@MainActor @Observable
final class EditorSession {
    private(set) var state = EditState()
    private(set) var history = HistoryManager()
    private(set) var document: PhotoDocument?
    private(set) var result: RenderResult?
    private(set) var isImporting = false
    private(set) var isRendering = false
    private(set) var isGeneratingMask = false
    private(set) var isAnalyzingGeometry = false
    private(set) var beautyFaceCount: Int?
    private(set) var isAnalyzingBeauty = false
    #if DEBUG
    private(set) var beautyDebugMasks: BeautyMasks?
    #else
    var beautyDebugMasks: BeautyMasks? { nil }
    #endif
    var healingActive = false
    var healingPaintZone = false
    var healingEraseZone = false
    var healingBrushRadius = 0.006
    private var healingDrawing = false
    var selectedHealingID: UUID?
    private(set) var beautyAnalysisError: String?
    private(set) var healingPreparing = false
    private(set) var healingAnalysis: ManualHealingAnalysis?
    private(set) var healingCandidates: [HealingCandidate] = []
    private(set) var healingNotice: String?
    @ObservationIgnored private var healingTask: Task<Void, Never>?
    @ObservationIgnored private var healingToken = 0
    @ObservationIgnored private var healingPreparedState: EditState?
    private var healingInputState: EditState {
        var value = state; value.beauty = BeautyState(); return value
    }
    var selectedHealing: ManualBlemishCorrection? {
        state.beauty.corrections.first { $0.id == selectedHealingID }
    }
    var healingGeometry: HealingGeometry? {
        guard let result else { return nil }
        return HealingGeometry(size: CGSize(width: result.sourceWidth, height: result.sourceHeight), settings: state.geometry)
    }
    func closeHealing() {
        finishInteraction(); healingToken &+= 1; healingTask?.cancel()
        healingActive = false; healingPaintZone = false; healingDrawing = false; healingPreparing = false; healingAnalysis = nil
        selectedHealingID = nil; healingCandidates = []; healingNotice = nil
    }
    func toggleHealing() {
        if healingActive { closeHealing(); return }
        guard let sourceURL, let id = document?.id else { return }
        healingActive = true; showingOriginal = false; healingPreparing = true
        selectedHealingID = state.beauty.corrections.last?.id
        healingToken &+= 1; let token = healingToken, snapshot = state
        let inputSnapshot = healingInputState
        healingTask = Task {
            defer { if token == healingToken { healingPreparing = false } }
            do {
                let data = try await engine.prepareManualHealing(url: sourceURL, state: snapshot)
                guard !Task.isCancelled, healingActive, token == healingToken, document?.id == id,
                      healingInputState == inputSnapshot else { return }
                healingPreparedState = inputSnapshot
                healingAnalysis = data
                if data.faceWidthFraction == 0 { healingNotice = String(localized: "No face detected") }
            } catch is CancellationError {} catch {
                if token == healingToken { healingNotice = String(localized: "Face analysis unavailable") }
            }
        }
    }
    func healingTap(_ visible: MaskPoint) {
        guard let map = healingGeometry, !healingPreparing, let id = document?.id else { return }
        let point = map.canonical(visible)
        guard (0...1).contains(point.x), (0...1).contains(point.y) else { return }
        let existing = state.beauty.corrections
        if let hit = existing.reversed().first(where: {
            hypot((point.x-$0.targetCenter.x)*map.inputSize.width,(point.y-$0.targetCenter.y)*map.inputSize.height)
                <= $0.targetRadius*min(map.inputSize.width,map.inputSize.height)*1.4
        }) { selectedHealingID = hit.id; return }
        guard let data = healingAnalysis else { return }
        guard healingPreparedState == healingInputState else {
            closeHealing(); toggleHealing(); return
        }
        healingPreparing = true; healingNotice = nil
        healingToken &+= 1; let token = healingToken, snapshot = state
        healingTask = Task {
            defer { if token == healingToken { healingPreparing = false } }
            do {
                let worker = Task.detached { try data.propose(at: point, existing: existing) }
                let proposal = try await withTaskCancellationHandler(operation: { try await worker.value }, onCancel: { worker.cancel() })
                guard !Task.isCancelled, token == healingToken, healingActive, document?.id == id,
                      state == snapshot else { return }
                guard let proposal else {
                    healingNotice = String(localized: "No safe skin source here. Try a nearby skin area."); return
                }
                finishInteraction(); history.begin(String(localized: "Correction"), state: state)
                state.beauty.corrections.append(proposal.correction)
                selectedHealingID = proposal.correction.id; healingCandidates = proposal.candidates
                history.commit(state); persist(); requestRender(.high)
            } catch is CancellationError {} catch { self.error = error.localizedDescription }
        }
    }
    func moveHealing(_ id: UUID, source: Bool, visible: MaskPoint) {
        guard let map = healingGeometry else { return }
        let point = map.canonical(visible).validated
        changeHealing(id) { c in
            if source { c.sourceCenter = point; c.confidence = 0; c.manualSource = true } else { c.moveTarget(to:point) }
        }
    }
    func changeHealing(_ id: UUID, update: (inout ManualBlemishCorrection) -> Void) {
        guard let index = state.beauty.corrections.firstIndex(where: { $0.id == id }) else { return }
        if !interacting { history.begin(String(localized: "Correction"), state: state) }
        update(&state.beauty.corrections[index])
        state.beauty.corrections[index] = state.beauty.corrections[index].validated
        requestRender(interacting ? .interactive : .high)
        if !interacting { history.commit(state); persist() }
    }
    func paintHealing(_ visible: MaskPoint) {
        guard healingActive, healingPaintZone, let map=healingGeometry, let c=selectedHealing else {return}
        let point=map.canonical(visible)
        guard (0...1).contains(point.x), (0...1).contains(point.y) else {return}
        if !healingDrawing {
            guard (c.targetStrokes?.count ?? 0)<128 else {return}
            beginInteraction(String(localized:"Target area"));healingDrawing=true
            changeHealing(c.id) { value in
                if value.targetStrokes == nil {value.targetStrokes=[]}
                value.targetStrokes?.append(.init(points:[point],radius:healingBrushRadius,erase:healingEraseZone))
            }
        } else {
            changeHealing(c.id) { value in
                guard let index=value.targetStrokes?.indices.last,
                      let last=value.targetStrokes?[index].points.last,
                      (value.targetStrokes?[index].points.count ?? 0)<4096 else {return}
                let distance=hypot((point.x-last.x)*map.inputSize.width,(point.y-last.y)*map.inputSize.height)
                if distance>max(0.5,healingBrushRadius*min(map.inputSize.width,map.inputSize.height)*0.15) {
                    value.targetStrokes?[index].points.append(point)
                }
            }
        }
    }
    func endHealingStroke() {healingDrawing=false;finishInteraction()}
    func deleteHealing(all: Bool = false) {
        healingDrawing=false; healingPaintZone=false
        finishInteraction(); history.begin(String(localized: "Delete correction"), state: state)
        if all { state.beauty.corrections = [] }
        else { state.beauty.corrections.removeAll { $0.id == selectedHealingID } }
        selectedHealingID = nil; history.commit(state); persist(); requestRender(.high)
    }

    private(set) var libraryDocuments: [LibraryDocument] = []
    private(set) var libraryFolders: [LibraryFolder] = []
    private(set) var libraryTags: [LibraryTag] = []
    private(set) var isLoadingLibrary = false
    private(set) var generation = 0
    var error: String?
    var showingOriginal = false
    var bypassCreative = false
    var selectedMaskID: UUID?
    var selectedMaskComponentID: UUID?
    var brushMode = BrushMode.paint
    @ObservationIgnored private let engine = RenderEngine()
    @ObservationIgnored private let store = DocumentStore()
    @ObservationIgnored private let maskGenerator = MaskGenerator()
    @ObservationIgnored private let geometryAnalyzer = GeometryAnalyzer()
    @ObservationIgnored private var maskEditingPreview = false
    @ObservationIgnored private var deferredMaskRender = false
    @ObservationIgnored private var renderTask: Task<Void, Never>?
    @ObservationIgnored private var sourceURL: URL?
    @ObservationIgnored private var revision = 0
    @ObservationIgnored private var importGeneration = 0
    @ObservationIgnored private var interacting = false
    @ObservationIgnored private var didRestore = false

    private(set) var isAnalyzingAuto = false
    @ObservationIgnored private var autoRequest = 0
    @ObservationIgnored private var beautyRequest = 0

    var coreImageAutoApplied: Bool { state.coreImageAuto != nil }

    func applyCoreImageAuto() async {
        finishInteraction()
        guard let url = sourceURL, let documentID = document?.id, selectedMaskID == nil else { return }
        autoRequest += 1
        let token = autoRequest, snapshot = state, importToken = importGeneration
        isAnalyzingAuto = true
        defer { if token == autoRequest { isAnalyzingAuto = false } }
        do {
            let (capture, _, _) = try await engine.captureCoreImageAuto(url: url, state: snapshot)
            guard token == autoRequest, importToken == importGeneration,
                  document?.id == documentID, sourceURL == url,
                  state.optics == snapshot.optics, state.geometry == snapshot.geometry,
                  selectedMaskID == nil,
                  !Task.isCancelled else { return }
            history.begin("Core Image Auto", state: state)
            state.coreImageAuto = capture.state
            history.commit(state); persist(); requestRender(.high)
        } catch is CancellationError { }
        catch { if token == autoRequest, document?.id == documentID { self.error = error.localizedDescription } }
    }

    func resetCoreImageAuto() {
        finishInteraction()
        guard state.coreImageAuto != nil else { return }
        autoRequest &+= 1
        history.begin("Reset Auto", state: state)
        state.coreImageAuto = nil
        history.commit(state); persist(); requestRender(.high)
    }

    func restore() async {
        guard !didRestore else { return }
        didRestore = true
        let token = importGeneration
        do {
            await loadLibrary()
            if let saved = try await store.restore(), token == importGeneration {
                try await activate(saved, token: token)
            }
        } catch { self.error = error.localizedDescription }
    }

    func loadLibrary() async {
        isLoadingLibrary = true
        defer { isLoadingLibrary = false }
        do {
            let documents = try await store.list()
            libraryFolders = try await store.folders()
            libraryTags = try await store.tags()
            var entries: [LibraryDocument] = []
            for document in documents {
                entries.append(LibraryDocument(document: document,
                                               originalURL: await store.originalURL(for: document),
                                               isFavorite: await store.isFavorite(document.id),
                                               folderID: await store.folderID(for: document.id),
                                               tagIDs: await store.tagIDs(for: document.id)))
            }
            libraryDocuments = entries
        } catch { self.error = error.localizedDescription }
    }

    func openDocument(_ id: UUID) async {
        guard document?.id != id else { return }
        importGeneration += 1
        let token = importGeneration
        isImporting = true
        finishInteraction()
        defer { if token == importGeneration { isImporting = false } }
        do {
            let saved = try await store.load(id)
            try await activate(saved, token: token)
        } catch { if token == importGeneration { self.error = error.localizedDescription } }
    }

    func deleteDocument(_ id: UUID) async {
        do {
            if document?.id == id {
                finishInteraction()
                importGeneration += 1
                renderTask?.cancel(); generation += 1
                document = nil; sourceURL = nil; result = nil; state = EditState(); history = HistoryManager()
                beautyRequest &+= 1; beautyFaceCount = nil; isAnalyzingBeauty = false
                #if DEBUG
                beautyDebugMasks = nil
                #endif
                selectedMaskID = nil; selectedMaskComponentID = nil; showingOriginal = false
                isRendering = false
            }
            try await store.delete(id)
            libraryDocuments.removeAll { $0.id == id }
        } catch { self.error = error.localizedDescription }
    }

    func toggleFavorite(_ id: UUID) async {
        guard let index = libraryDocuments.firstIndex(where: { $0.id == id }) else { return }
        let favorite = !libraryDocuments[index].isFavorite
        do {
            try await store.setFavorite(favorite, for: id)
            guard let refreshedIndex = libraryDocuments.firstIndex(where: { $0.id == id }) else { return }
            libraryDocuments[refreshedIndex].isFavorite = favorite
        } catch { self.error = error.localizedDescription }
    }

    func setFavorites(_ favorite: Bool, for documentIDs: Set<UUID>) async {
        guard !documentIDs.isEmpty else { return }
        do {
            try await store.setFavorites(favorite, for: documentIDs)
            for index in libraryDocuments.indices where documentIDs.contains(libraryDocuments[index].id) {
                libraryDocuments[index].isFavorite = favorite
            }
        } catch { self.error = error.localizedDescription }
    }

    func createLibraryFolder(named name: String) async {
        do {
            let folder = try await store.createFolder(named: name)
            libraryFolders.append(folder)
            libraryFolders.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        } catch { self.error = error.localizedDescription }
    }

    func deleteLibraryFolder(_ id: UUID) async {
        do {
            try await store.deleteFolder(id)
            libraryFolders.removeAll { $0.id == id }
            for index in libraryDocuments.indices where libraryDocuments[index].folderID == id {
                libraryDocuments[index].folderID = nil
            }
        } catch { self.error = error.localizedDescription }
    }

    func setLibraryFolder(_ folderID: UUID?, for documentID: UUID) async {
        do {
            try await store.setFolder(folderID, for: documentID)
            guard let index = libraryDocuments.firstIndex(where: { $0.id == documentID }) else { return }
            libraryDocuments[index].folderID = folderID
        } catch { self.error = error.localizedDescription }
    }

    func setLibraryFolder(_ folderID: UUID?, for documentIDs: Set<UUID>) async {
        guard !documentIDs.isEmpty else { return }
        do {
            try await store.setFolder(folderID, for: documentIDs)
            for index in libraryDocuments.indices where documentIDs.contains(libraryDocuments[index].id) {
                libraryDocuments[index].folderID = folderID
            }
        } catch { self.error = error.localizedDescription }
    }

    func createLibraryTag(named name: String) async {
        do {
            let tag = try await store.createTag(named: name)
            libraryTags.append(tag)
            libraryTags.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        } catch { self.error = error.localizedDescription }
    }

    func deleteLibraryTag(_ id: UUID) async {
        do {
            try await store.deleteTag(id)
            libraryTags.removeAll { $0.id == id }
            for index in libraryDocuments.indices { libraryDocuments[index].tagIDs.remove(id) }
        } catch { self.error = error.localizedDescription }
    }

    func toggleLibraryTag(_ tagID: UUID, for documentID: UUID) async {
        guard let index = libraryDocuments.firstIndex(where: { $0.id == documentID }) else { return }
        let enabled = !libraryDocuments[index].tagIDs.contains(tagID)
        do {
            try await store.setTag(tagID, enabled: enabled, for: documentID)
            guard let refreshedIndex = libraryDocuments.firstIndex(where: { $0.id == documentID }) else { return }
            if enabled { libraryDocuments[refreshedIndex].tagIDs.insert(tagID) }
            else { libraryDocuments[refreshedIndex].tagIDs.remove(tagID) }
        } catch { self.error = error.localizedDescription }
    }

    func setLibraryTag(_ tagID: UUID, enabled: Bool, for documentIDs: Set<UUID>) async {
        guard !documentIDs.isEmpty else { return }
        do {
            try await store.setTag(tagID, enabled: enabled, for: documentIDs)
            for index in libraryDocuments.indices where documentIDs.contains(libraryDocuments[index].id) {
                if enabled { libraryDocuments[index].tagIDs.insert(tagID) }
                else { libraryDocuments[index].tagIDs.remove(tagID) }
            }
        } catch { self.error = error.localizedDescription }
    }

    func deleteDocuments(_ documentIDs: Set<UUID>) async {
        guard !documentIDs.isEmpty else { return }
        do {
            if let currentID = document?.id, documentIDs.contains(currentID) {
                finishInteraction()
                importGeneration += 1
                renderTask?.cancel(); generation += 1
                document = nil; sourceURL = nil; result = nil; state = EditState(); history = HistoryManager()
                beautyRequest &+= 1; beautyFaceCount = nil; isAnalyzingBeauty = false
                #if DEBUG
                beautyDebugMasks = nil
                #endif
                selectedMaskID = nil; selectedMaskComponentID = nil; showingOriginal = false
                isRendering = false
            }
            try await store.delete(documentIDs)
            libraryDocuments.removeAll { documentIDs.contains($0.id) }
        } catch {
            self.error = error.localizedDescription
            await loadLibrary()
        }
    }

    func importPhoto(at url: URL, temporary: Bool = false) async {
        importGeneration += 1
        let token = importGeneration
        isImporting = true
        finishInteraction()
        defer {
            if token == importGeneration { isImporting = false }
            if temporary { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        }
        do {
            let imported = try await store.importPhoto(at: url)
            let original = await store.originalURL(for: imported)
            // Validate before replacing a working document.
            let preview = try await engine.render(url: original, state: imported.state, quality: .high)
            guard token == importGeneration else { return }
            renderTask?.cancel(); generation += 1
            document = imported; sourceURL = original; state = imported.state
            beautyRequest &+= 1; beautyFaceCount = nil; isAnalyzingBeauty = false
            #if DEBUG
            beautyDebugMasks = nil
            #endif
            history = HistoryManager(); result = preview
            selectedMaskID = nil; selectedMaskComponentID = nil; selectFirstMaskIfNeeded()
            brushMode = .paint
            showingOriginal = false; isRendering = false
            try await store.select(imported)
            await loadLibrary()
        } catch { if token == importGeneration { self.error = error.localizedDescription } }
    }

    func beginInteraction(_ adjustment: Adjustment) {
        beginInteraction(adjustment.title)
    }
    func beginInteraction(_ name: String) {
        history.begin(name, state: state)
        interacting = true
    }
    func setCurve(_ channel: CurveChannel, curve: ToneCurve) {
        if !interacting { history.begin("\(channel.title) curve", state: state) }
        if let index = selectedMaskIndex { state.masks[index].adjustments.curves[channel] = curve }
        else { state.curves[channel] = curve }
        requestRender(interacting ? .interactive : .high)
        if !interacting { history.commit(state); persist() }
    }
    func setMixer(_ channel: MixerChannel, adjustment: MixerAdjustment) {
        if !interacting { history.begin("Color Mixer \(channel.title)", state: state) }
        if let index = selectedMaskIndex { state.masks[index].adjustments.colorMixer[channel] = adjustment }
        else { state.colorMixer[channel] = adjustment }
        requestRender(interacting ? .interactive : .high)
        if !interacting { history.commit(state); persist() }
    }
    func setGrading(_ grading: ColorGrading) {
        if !interacting { history.begin("Color grading", state: state) }
        if let index = selectedMaskIndex { state.masks[index].adjustments.colorGrading = grading.validated }
        else { state.colorGrading = grading.validated }
        requestRender(interacting ? .interactive : .high)
        if !interacting { history.commit(state); persist() }
    }
    func setEffect(_ adjustment: EffectAdjustment, to value: Double) {
        if !interacting { history.begin(adjustment.title, state: state) }
        if let index = selectedMaskIndex { state.masks[index].adjustments.effects[adjustment] = value }
        else { state.effects[adjustment] = value }
        requestRender(interacting ? .interactive : .high)
        if !interacting { history.commit(state); persist() }
    }
    func changeCreative(_ name: String, _ change: (inout CreativeEffectStack) -> Void) {
        if !interacting { history.begin(name, state: state) }
        change(&state.creative)
        state.creative = state.creative.validated
        showingOriginal = false
        requestRender(interacting ? .interactive : .high)
        if !interacting { history.commit(state); persist() }
    }
    func setCreativeBypass(_ bypass: Bool) {
        finishInteraction(); bypassCreative = bypass; requestRender(.high)
    }
    @ObservationIgnored private var creativeTileEngine: RenderEngine?
    func creativeTile(region: CGRect, maximum: Int = 1024) async throws -> CGImage? {
        guard let sourceURL else { return nil }
        // Separate owner prevents tile decode from blocking interactive preview renders.
        if creativeTileEngine == nil { creativeTileEngine = RenderEngine() }
        return try await creativeTileEngine!.renderFullResolutionTile(url: sourceURL, state: state,
            region: region, maximum: maximum, bypassCreative: bypassCreative)
    }
    func setDetail(_ adjustment: DetailAdjustment, to value: Double) {
        if !interacting { history.begin(adjustment.title, state: state) }
        if let index = selectedMaskIndex { state.masks[index].adjustments.detail[adjustment] = value }
        else { state.detail[adjustment] = value }
        requestRender(interacting ? .interactive : .high)
        if !interacting { history.commit(state); persist() }
    }
    func analyzeBeautyFaces() async {
        guard let sourceURL, let documentID = document?.id else { return }
        beautyRequest &+= 1
        let token = beautyRequest, importToken = importGeneration
        let snapshot = state
        beautyFaceCount = nil
        beautyAnalysisError = nil
        #if DEBUG
        beautyDebugMasks = nil
        #endif
        isAnalyzingBeauty = true
        defer { if token == beautyRequest { isAnalyzingBeauty = false } }
        do {
            let masks = try await engine.beautyAnalysis(url: sourceURL, state: snapshot)
            guard token == beautyRequest, importToken == importGeneration,
                  document?.id == documentID, state.geometry == snapshot.geometry,
                  state.optics == snapshot.optics, !Task.isCancelled else { return }
            beautyFaceCount = masks.faceCount
            #if DEBUG
            beautyDebugMasks = masks
            #endif
        } catch is CancellationError { }
        catch { if token == beautyRequest, document?.id == documentID { beautyAnalysisError = error.localizedDescription } }
    }
    func setBeauty(_ control: BeautyControl, to value: Double) {
        if !interacting { history.begin(control.title, state: state) }
        state.beauty[control] = value
        requestRender(interacting ? .interactive : .high)
        if !interacting { history.commit(state); persist() }
    }
    func setBeautyV2(_ control: BeautyV2Control, to value: Double) {
        if !interacting { history.begin(control.title, state: state) }
        var finishing = state.beauty.finishing ?? BeautyV2Settings()
        finishing[control] = value
        state.beauty.finishing = finishing.hasStoredValues ? finishing : nil
        requestRender(interacting ? .interactive : .high)
        if !interacting { history.commit(state); persist() }
    }
    func applyBeautyPreset(_ preset: BeautyPreset) {
        finishInteraction()
        history.begin(preset.title, state: state)
        let corrections = state.beauty.corrections
        state.beauty = preset.settings
        state.beauty.corrections = corrections
        history.commit(state); persist(); requestRender(.high)
    }
    func resetBeauty() {
        closeHealing()
        guard state.beauty != BeautyState() else { return }
        history.begin("Reset Beauty", state: state)
        state.beauty = BeautyState()
        history.commit(state); persist(); requestRender(.high)
    }
    func setOptics(_ adjustment: OpticsAdjustment, to value: Double) {
        if !interacting { history.begin(adjustment.title, state: state) }
        state.optics[adjustment] = value
        requestRender(interacting ? .interactive : .high)
        if !interacting { history.commit(state); persist() }
    }
    func setProfileCorrection(_ enabled: Bool) {
        finishInteraction()
        history.begin("Lens profile", state: state)
        state.optics.profileCorrection = enabled
        history.commit(state); persist(); requestRender(.high)
    }
    func setGeometry(_ adjustment: GeometryAdjustment, to value: Double) {
        if !interacting { history.begin(adjustment.title, state: state) }
        state.geometry[adjustment] = value
        requestRender(interacting ? .interactive : .high)
        if !interacting { history.commit(state); persist() }
    }
    func setCropAspect(_ aspect: CropAspect) {
        finishInteraction()
        history.begin("Format \(aspect.title)", state: state)
        state.geometry.aspect = aspect
        history.commit(state); persist(); requestRender(.high)
    }
    func rotateGeometry(clockwise: Bool) {
        finishInteraction()
        history.begin(clockwise ? "Rotate right" : "Rotate left", state: state)
        state.geometry.quarterTurns += clockwise ? 1 : -1
        state.geometry = state.geometry.validated
        history.commit(state); persist(); requestRender(.high)
    }
    func toggleGeometryFlip(horizontal: Bool) {
        finishInteraction()
        history.begin(horizontal ? "Flip horizontally" : "Flip vertically", state: state)
        if horizontal { state.geometry.flipHorizontal.toggle() }
        else { state.geometry.flipVertical.toggle() }
        history.commit(state); persist(); requestRender(.high)
    }
    func autoStraighten() async {
        finishInteraction()
        guard !isAnalyzingGeometry, let image = result?.image, let documentID = document?.id else { return }
        isAnalyzingGeometry = true
        defer { isAnalyzingGeometry = false }
        do {
            let correction = try await geometryAnalyzer.straightenAngle(from: image)
            try Task.checkCancellation()
            guard document?.id == documentID else { return }
            let current = state.geometry.straighten
            let updated = min(GeometryAdjustment.straighten.range.upperBound,
                              max(GeometryAdjustment.straighten.range.lowerBound, current + correction))
            guard abs(updated - current) >= 0.01 else { return }
            history.begin("Redressement automatique", state: state)
            state.geometry.straighten = updated
            history.commit(state); persist(); requestRender(.high)
        } catch is CancellationError {
        } catch {
            self.error = error.localizedDescription
        }
    }
    func autoPerspective() async {
        finishInteraction()
        guard !isAnalyzingGeometry, let image = result?.image, let documentID = document?.id else { return }
        isAnalyzingGeometry = true
        defer { isAnalyzingGeometry = false }
        do {
            let correction = try await geometryAnalyzer.perspectiveCorrection(from: image)
            try Task.checkCancellation()
            guard document?.id == documentID else { return }
            let currentVertical = state.geometry.perspectiveVertical
            let currentHorizontal = state.geometry.perspectiveHorizontal
            let vertical = min(GeometryAdjustment.perspectiveVertical.range.upperBound,
                               max(GeometryAdjustment.perspectiveVertical.range.lowerBound,
                                   currentVertical + correction.vertical))
            let horizontal = min(GeometryAdjustment.perspectiveHorizontal.range.upperBound,
                                 max(GeometryAdjustment.perspectiveHorizontal.range.lowerBound,
                                     currentHorizontal + correction.horizontal))
            guard abs(vertical - currentVertical) >= 0.01 || abs(horizontal - currentHorizontal) >= 0.01 else { return }
            history.begin("Perspective automatique", state: state)
            state.geometry.perspectiveVertical = vertical
            state.geometry.perspectiveHorizontal = horizontal
            history.commit(state); persist(); requestRender(.high)
        } catch is CancellationError {
        } catch {
            self.error = error.localizedDescription
        }
    }
    func set(_ adjustment: Adjustment, to value: Double) {
        if !interacting { history.begin(adjustment.title, state: state) }
        if let index = selectedMaskIndex { state.masks[index].adjustments.set(adjustment, to: value) }
        else { state[adjustment] = value }
        requestRender(interacting ? .interactive : .high)
        if !interacting { history.commit(state); persist() }
    }
    func applyPreset(_ preset: Preset) {
        finishInteraction(); history.begin("Preset · \(preset.name)", state: state)
        if let index = selectedMaskIndex, !preset.sections.contains(.masks) {
            let applied = preset.applying(to: state.masks[index].adjustments.editState)
            if preset.sections.contains(.creative) {
                state.creative = applied.creative
                for i in state.creative.effects.indices { state.creative.effects[i].maskID = selectedMaskID }
            }
            state.masks[index].adjustments = LocalAdjustmentState(editState: applied).validated
        } else {
            state = preset.applying(to: state)
        }
        selectFirstMaskIfNeeded(); history.commit(state); persist(); requestRender(.high)
    }
    var selectedMask: LocalMask? { state.masks.first { $0.id == selectedMaskID } }
    var activeLayerName: String { selectedMask?.name ?? "Whole photo" }
    var activeState: EditState {
        guard let index = selectedMaskIndex else { return state }
        var projected = state.masks[index].adjustments.editState
        projected.optics = state.optics
        projected.geometry = state.geometry
        return projected
    }
    var selectedMaskComponent: MaskComponent? {
        selectedMask?.components.first { $0.id == selectedMaskComponentID }
    }
    func selectMask(_ id: UUID) {
        finishInteraction(); selectedMaskID = id
        selectedMaskComponentID = state.masks.first { $0.id == id }?.components.last?.id
        showingOriginal = false
    }
    func selectBaseLayer() {
        finishInteraction()
        selectedMaskID = nil
        selectedMaskComponentID = nil
        showingOriginal = false
    }
    func selectMaskComponent(_ id: UUID) {
        finishInteraction(); selectedMaskComponentID = id; showingOriginal = false
    }
    func setSelectedMaskComponentOperation(_ operation: MaskOperation) {
        finishInteraction(); guard let (maskIndex, componentIndex) = selectedComponentIndex,
                                   state.masks[maskIndex].components[componentIndex].operation != operation else { return }
        history.begin(operation == .add ? "Additive component" : "Subtractive component", state: state)
        state.masks[maskIndex].components[componentIndex].operation = operation
        history.commit(state); persist(); requestRender(.high)
    }
    func moveSelectedMaskComponent(by offset: Int) {
        finishInteraction(); guard let (maskIndex, componentIndex) = selectedComponentIndex else { return }
        let destination = min(state.masks[maskIndex].components.count - 1, max(0, componentIndex + offset))
        guard destination != componentIndex else { return }
        history.begin(destination > componentIndex ? "Move component later" : "Move component earlier", state: state)
        let component = state.masks[maskIndex].components.remove(at: componentIndex)
        state.masks[maskIndex].components.insert(component, at: destination)
        history.commit(state); persist(); requestRender(.high)
    }
    func deleteSelectedMaskComponent() {
        finishInteraction(); guard let (maskIndex, componentIndex) = selectedComponentIndex,
                                   state.masks[maskIndex].components.count > 1 else { return }
        history.begin("Delete component", state: state)
        state.masks[maskIndex].components.remove(at: componentIndex)
        let replacement = min(componentIndex, state.masks[maskIndex].components.count - 1)
        selectedMaskComponentID = state.masks[maskIndex].components[replacement].id
        history.commit(state); persist(); requestRender(.high)
    }
    func setSelectedMaskShape(_ shape: MaskShape) {
        guard let (maskIndex, componentIndex) = selectedComponentIndex else { return }
        if !interacting { history.begin("Transform component", state: state) }
        var component = state.masks[maskIndex].components[componentIndex]
        component.shape = shape
        state.masks[maskIndex].components[componentIndex] = component.validated
        showingOriginal = false
        requestRender(interacting ? .interactive : .high)
        if !interacting { history.commit(state); persist() }
    }
    func createMask(_ kind: MaskKind) {
        finishInteraction(); history.begin("Create mask", state: state)
        let component = MaskComponent(shape: kind.shape())
        let mask = LocalMask(name: "\(kind.title) \(state.masks.count + 1)", components: [component])
        state.masks.append(mask); selectedMaskID = mask.id; selectedMaskComponentID = component.id
        history.commit(state); persist(); requestRender(.high); showingOriginal = false
    }
    func addMaskComponent(_ kind: MaskKind, operation: MaskOperation) {
        finishInteraction(); guard let index = selectedMaskIndex else { return }
        history.begin(operation == .add ? "Add to mask" : "Subtract from mask", state: state)
        let component = MaskComponent(operation: operation, shape: kind.shape())
        state.masks[index].components.append(component); selectedMaskComponentID = component.id
        history.commit(state); persist(); requestRender(.high)
    }
    func generateSmartMask(_ kind: SmartMaskKind, operation: MaskOperation? = nil) async {
        finishInteraction()
        guard !isGeneratingMask, let image = result?.image, let documentID = document?.id else { return }
        isGeneratingMask = true
        defer { isGeneratingMask = false }
        do {
            let generated = try await maskGenerator.generate(kind, from: image)
            try Task.checkCancellation()
            guard document?.id == documentID else { return }
            history.begin(operation == nil ? "Detect \(kind.title)" : "Edit with \(kind.title)", state: state)
            let component = MaskComponent(operation: operation ?? .add, shape: .generated(generated))
            if operation != nil, let index = selectedMaskIndex {
                state.masks[index].components.append(component)
                selectedMaskComponentID = component.id
            } else {
                let mask = LocalMask(name: kind.title, components: [component])
                state.masks.append(mask)
                selectedMaskID = mask.id
                selectedMaskComponentID = component.id
            }
            history.commit(state); persist(); requestRender(.high); showingOriginal = false
        } catch is CancellationError {
        } catch {
            self.error = error.localizedDescription
        }
    }
    func deleteSelectedMask() {
        finishInteraction(); guard let index = selectedMaskIndex else { return }
        history.begin("Delete layer", state: state)
        state.masks.remove(at: index); history.commit(state)
        selectedMaskID = nil; selectedMaskComponentID = nil
        persist(); requestRender(.high)
    }
    func renameSelectedLayer(to name: String) {
        finishInteraction(); guard let index = selectedMaskIndex else { return }
        let cleanName = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(60))
        guard !cleanName.isEmpty, cleanName != state.masks[index].name else { return }
        history.begin("Rename layer", state: state)
        state.masks[index].name = cleanName
        history.commit(state); persist()
    }
    func toggleSelectedLayerVisibility() {
        finishInteraction(); guard let index = selectedMaskIndex else { return }
        history.begin(state.masks[index].isVisible ? "Hide layer" : "Show layer", state: state)
        state.masks[index].isVisible.toggle()
        history.commit(state); persist(); requestRender(.high)
    }
    func setSelectedLayerOpacity(_ opacity: Double) {
        guard let index = selectedMaskIndex else { return }
        if !interacting { history.begin("Layer opacity", state: state) }
        state.masks[index].opacity = opacity.isFinite ? min(100, max(0, opacity)) : 100
        requestRender(interacting ? .interactive : .high)
        if !interacting { history.commit(state); persist() }
    }
    func moveSelectedLayer(by offset: Int) {
        finishInteraction(); guard let index = selectedMaskIndex else { return }
        let destination = min(state.masks.count - 1, max(0, index + offset))
        guard destination != index else { return }
        history.begin(destination > index ? "Apply layer later" : "Apply layer earlier", state: state)
        let layer = state.masks.remove(at: index)
        state.masks.insert(layer, at: destination)
        history.commit(state); persist(); requestRender(.high)
    }
    func toggleMaskInversion() {
        finishInteraction(); guard let index = selectedMaskIndex else { return }
        history.begin("Invert mask", state: state)
        state.masks[index].inverted.toggle(); history.commit(state); persist(); requestRender(.high)
    }
    func setLocalAdjustment(_ adjustment: LocalAdjustment, to value: Double) {
        guard let index = selectedMaskIndex else { return }
        if !interacting { history.begin("Mask · \(adjustment.title)", state: state) }
        state.masks[index].adjustments[adjustment] = value
        requestRender(interacting ? .interactive : .high)
        if !interacting { history.commit(state); persist() }
    }
    func resetLocalAdjustment(_ adjustment: LocalAdjustment) {
        finishInteraction(); setLocalAdjustment(adjustment, to: 0)
    }
    func setMaskParameter(_ parameter: MaskParameter, to value: Double) {
        guard let (maskIndex, componentIndex) = selectedComponentIndex else { return }
        if !interacting { history.begin("Mask · \(parameter.title)", state: state) }
        var shape = state.masks[maskIndex].components[componentIndex].shape
        switch shape {
        case .brush(var brush):
            switch parameter {
            case .size: brush.size = value; case .feather: brush.feather = value
            case .flow: brush.flow = value; case .opacity: brush.opacity = value
            default: break
            }
            shape = .brush(brush.validated)
        case .linear(var linear):
            switch parameter {
            case .angle: linear.angle = value
            case .centerX: linear.center.x = value / 100
            case .centerY: linear.center.y = value / 100
            case .feather: linear.feather = value
            default: break
            }
            shape = .linear(linear.validated)
        case .radial(var radial):
            switch parameter {
            case .centerX: radial.center.x = value / 100
            case .centerY: radial.center.y = value / 100
            case .radiusX: radial.radiusX = value / 100
            case .radiusY: radial.radiusY = value / 100
            case .feather: radial.feather = value
            default: break
            }
            shape = .radial(radial.validated)
        case .generated:
            return
        }
        state.masks[maskIndex].components[componentIndex].shape = shape
        requestRender(interacting ? .interactive : .high)
        if !interacting { history.commit(state); persist() }
    }
    func beginBrushStroke() {
        guard brushMode != .pan else { return }
        guard let (maskIndex, componentIndex) = selectedComponentIndex,
              case .brush(var brush) = state.masks[maskIndex].components[componentIndex].shape else { return }
        history.begin(brushMode == .paint ? "Paint mask" : "Erase mask", state: state)
        interacting = true
        if brushMode == .paint { brush.strokes.append([]) }
        else { brush.eraseStrokes.append([]) }
        state.masks[maskIndex].components[componentIndex].shape = .brush(brush)
        showingOriginal = false
    }
    func appendBrushPoint(_ point: MaskPoint) {
        guard interacting, let (maskIndex, componentIndex) = selectedComponentIndex,
              case .brush(var brush) = state.masks[maskIndex].components[componentIndex].shape,
              brushMode == .paint ? !brush.strokes.isEmpty : !brush.eraseStrokes.isEmpty else { return }
        if brushMode == .paint { brush.strokes[brush.strokes.count - 1].append(point.validated) }
        else { brush.eraseStrokes[brush.eraseStrokes.count - 1].append(point.validated) }
        state.masks[maskIndex].components[componentIndex].shape = .brush(brush)
        requestRender(.interactive)
    }
    func finishInteraction() {
        guard interacting else { return }
        interacting = false
        history.commit(state)
        persist()
        requestRender(.high)
    }
    func reset(_ adjustment: Adjustment) {
        finishInteraction()
        set(adjustment, to: 0)
    }
    func resetEffect(_ adjustment: EffectAdjustment) {
        finishInteraction()
        setEffect(adjustment, to: 0)
    }
    func resetDetail(_ adjustment: DetailAdjustment) {
        finishInteraction()
        setDetail(adjustment, to: adjustment.defaultValue)
    }
    func resetOptics(_ adjustment: OpticsAdjustment) {
        finishInteraction()
        setOptics(adjustment, to: 0)
    }
    func resetGeometry(_ adjustment: GeometryAdjustment) {
        finishInteraction()
        setGeometry(adjustment, to: adjustment.defaultValue)
    }
    func resetGeometry() {
        finishInteraction()
        history.begin("Reset geometry", state: state)
        state.geometry = GeometrySettings()
        history.commit(state); persist(); requestRender(.high)
    }
    func resetAll() {
        finishInteraction()
        history.begin("Reset", state: state)
        state = EditState()
        selectedMaskID = nil; selectedMaskComponentID = nil
        brushMode = .paint
        history.commit(state)
        persist(); requestRender(.high)
    }
    func undo() {
        finishInteraction()
        guard let previous = history.undo() else { return }
        state = previous; selectFirstMaskIfNeeded(); persist(); requestRender(.high)
    }
    func redo() {
        finishInteraction()
        guard let next = history.redo() else { return }
        state = next; selectFirstMaskIfNeeded(); persist(); requestRender(.high)
    }
    func exportRequest() -> ExportRequest? {
        finishInteraction()
        guard let sourceURL, let document else { return nil }
        return ExportRequest(sourceURL: sourceURL, state: state, name: document.originalName)
    }
    func memoryWarning() {
        Task { await engine.clearCaches() }
    }
    func flush() { finishInteraction(); persist() }

    private func persist() {
        guard var document else { return }
        document.state = state
        self.document = document
        revision += 1
        let revision = revision
        Task {
            do { try await store.save(document, revision: revision) }
            catch { self.error = error.localizedDescription }
        }
    }
    private func activate(_ saved: PhotoDocument, token: Int) async throws {
        let url = await store.originalURL(for: saved)
        let preview = try await engine.render(url: url, state: saved.state, quality: .high)
        guard token == importGeneration else { return }
        renderTask?.cancel(); generation += 1
        document = saved; state = saved.state; sourceURL = url; result = preview
        beautyRequest &+= 1; beautyFaceCount = nil; isAnalyzingBeauty = false
        #if DEBUG
        beautyDebugMasks = nil
        #endif
        history = HistoryManager(); selectedMaskID = nil; selectedMaskComponentID = nil
        selectFirstMaskIfNeeded(); brushMode = .paint; showingOriginal = false; isRendering = false
        try await store.select(saved)
    }
    /// Matte editing updates only the overlay. Develop once with the latest state
    /// when returning to a photographic adjustment panel.
    func setMaskEditingPreview(_ active: Bool) {
        guard maskEditingPreview != active else { return }
        finishInteraction()
        maskEditingPreview = active
        if active {
            deferredMaskRender = deferredMaskRender || isRendering
            renderTask?.cancel(); generation += 1; isRendering = false
        } else if deferredMaskRender {
            deferredMaskRender = false
            requestRender(.high)
        }
    }
    private func requestRender(_ quality: PreviewQuality) {
        if maskEditingPreview { deferredMaskRender = true; return }
        guard let sourceURL else { return }
        generation += 1
        let token = generation, snapshot = state, bypass = bypassCreative
        renderTask?.cancel()
        isRendering = true
        renderTask = Task {
            do {
                try await Task.sleep(for: .milliseconds(quality == .interactive ? 16 : 50))
                let rendered = try await engine.render(url: sourceURL, state: snapshot, quality: quality, bypassCreative: bypass)
                try Task.checkCancellation()
                guard token == generation else { return }
                result = rendered; isRendering = false
            } catch is CancellationError {
                // A newer generation owns the progress indicator.
            } catch {
                guard token == generation else { return }
                isRendering = false
                self.error = error.localizedDescription
            }
        }
    }

    private var selectedMaskIndex: Int? { state.masks.firstIndex { $0.id == selectedMaskID } }
    private var selectedComponentIndex: (Int, Int)? {
        guard let mask = selectedMaskIndex,
              let component = state.masks[mask].components.firstIndex(where: { $0.id == selectedMaskComponentID })
        else { return nil }
        return (mask, component)
    }
    private func selectFirstMaskIfNeeded() {
        if let selectedMaskID, let mask = state.masks.first(where: { $0.id == selectedMaskID }) {
            if let selectedMaskComponentID,
               mask.components.contains(where: { $0.id == selectedMaskComponentID }) { return }
            selectedMaskComponentID = mask.components.last?.id
            return
        }
        selectedMaskID = nil
        selectedMaskComponentID = nil
    }
}
