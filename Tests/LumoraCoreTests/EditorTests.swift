import Testing
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
@testable import LumoraCore

@Test func editStateRoundTripAndValidation() throws {
    var state = EditState()
    for control in Adjustment.allCases { state[control] = control.range.upperBound * 0.4 }
    #expect(try JSONDecoder().decode(EditState.self, from: JSONEncoder().encode(state)) == state)
    state[.exposure] = 80
    #expect(state.exposure == 5)
    state[.tint] = .nan
    #expect(state.tint == 0)
    #expect(EditState().validated == EditState())
}

@Test func historyGroupsGestureAndInvalidatesRedo() {
    var history = HistoryManager(), state = EditState()
    history.begin("Exposition", state: state)
    for value in 1...100 { state.exposure = Double(value) / 100 }
    history.commit(state)
    #expect(history.undoStack.count == 1)
    #expect(history.undo() == EditState())
    #expect(history.redo() == state)
    _ = history.undo()
    history.begin("Contraste", state: EditState())
    var branch = EditState(); branch.contrast = 12
    history.commit(branch)
    #expect(!history.canRedo)
    #expect(history.undo() == EditState())
}

@Test func noOpAndBoundedHistory() {
    var history = HistoryManager(), state = EditState()
    history.begin("Rien", state: state); history.commit(state)
    #expect(!history.canUndo)
    for i in 1...150 {
        history.begin("Valeur", state: state)
        state.contrast = Double(i)
        history.commit(state)
    }
    #expect(history.undoStack.count == 100)
}

@Test func neutralResponseAndTargetedTonalMasks() {
    for i in 0...100 {
        let x = Double(i) / 100
        #expect(abs(TonalResponse.map(x, state: EditState()) - x) < 1e-10)
    }
    var shadows = EditState(); shadows.shadows = 70
    #expect(TonalResponse.map(0.2, state: shadows) > 0.2)
    #expect(abs(TonalResponse.map(0.9, state: shadows) - 0.9) < 1e-10)
    var highlights = EditState(); highlights.highlights = -70
    #expect(TonalResponse.map(0.8, state: highlights) < 0.8)
    #expect(abs(TonalResponse.map(0.1, state: highlights) - 0.1) < 1e-10)
    for control in Adjustment.allCases {
        for extreme in [-100.0, 100.0] {
            var state = EditState(); state[control] = extreme
            for i in 0...100 {
                #expect((0...1).contains(TonalResponse.map(Double(i) / 100, state: state)))
            }
        }
    }
}

@Test func vibrancePreservesNeutralsAndProtectsSaturatedColors() {
    var state = EditState(); state.vibrance = 100
    let neutral = TonalResponse.color(0.4, 0.4, 0.4, state: state)
    #expect(abs(neutral.0 - 0.4) < 1e-9)
    #expect(abs(neutral.1 - 0.4) < 1e-9)
    let red = TonalResponse.color(1, 0, 0, state: state)
    #expect(red.0 == 1 && red.1 == 0 && red.2 == 0)
    state.saturation = -100
    let gray = TonalResponse.color(0.8, 0.4, 0.2, state: state)
    #expect(abs(gray.0 - gray.1) < 1e-9 && abs(gray.1 - gray.2) < 1e-9)
}

private func fixture(orientation: Int = 1) throws -> URL {
    let url = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString + (orientation == 1 ? ".png" : ".tiff"))
    let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
    let context = try #require(CGContext(data: nil, width: 64, height: 32, bitsPerComponent: 8,
                                       bytesPerRow: 256, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    for x in 0..<64 {
        let v = Double(x) / 63
        context.setFillColor(CGColor(red: v, green: v, blue: v, alpha: 1))
        context.fill(CGRect(x: x, y: 0, width: 1, height: 32))
    }
    let image = try #require(context.makeImage())
    let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, (orientation == 1 ? UTType.png : UTType.tiff).identifier as CFString, 1, nil))
    CGImageDestinationAddImage(destination, image, [kCGImagePropertyOrientation: orientation] as CFDictionary)
    #expect(CGImageDestinationFinalize(destination))
    return url
}

@Test func realRendererExposureCacheHistogramAndOriginal() async throws {
    let url = try fixture()
    defer { try? FileManager.default.removeItem(at: url) }
    let renderer = RenderEngine()
    let neutral = try await renderer.render(url: url, state: EditState(), quality: .high)
    #expect(neutral.image.width == 64 && neutral.image.height == 32)
    #expect(neutral.histogram.samples == 25600)
    #expect(!neutral.cacheHit)
    var state = EditState(); state.exposure = 1
    let edited = try await renderer.render(url: url, state: state, quality: .high)
    #expect(edited.cacheHit)
    #expect(edited.original === neutral.original)
    func mean(_ h: Histogram) -> Double {
        Double(h.luminance.enumerated().reduce(0) { $0 + $1.offset * $1.element }) / Double(h.samples)
    }
    #expect(mean(edited.histogram) > mean(neutral.histogram) + 10)
    state.shadows = 40; state.contrast = 25; state.vibrance = 20
    let lut = try await renderer.render(url: url, state: state, quality: .interactive)
    #expect(lut.histogram.samples > 0)
    await renderer.clearCaches()
    let cleared = try await renderer.render(url: url, state: EditState(), quality: .high)
    #expect(!cleared.cacheHit)
}

@Test func persistenceKeepsOriginalAndRejectsStaleWrites() async throws {
    let url = try fixture()
    let root = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: url); try? FileManager.default.removeItem(at: root) }
    let store = DocumentStore(root: root)
    var doc = try await store.importPhoto(at: url)
    try await store.select(doc)
    let original = await store.originalURL(for: doc)
    #expect(try Data(contentsOf: url) == Data(contentsOf: original))
    doc.state.exposure = 2
    try await store.save(doc, revision: 2)
    doc.state.exposure = 1
    try await store.save(doc, revision: 1)
    let restored = try await store.restore()
    #expect(restored?.state.exposure == 2)
    #expect(try Data(contentsOf: url) == Data(contentsOf: original))
}

@Test func documentStoreListsLoadsSortsAndDeletesLibrary() async throws {
    let firstURL = try fixture()
    let secondURL = try fixture()
    let root = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer {
        try? FileManager.default.removeItem(at: firstURL)
        try? FileManager.default.removeItem(at: secondURL)
        try? FileManager.default.removeItem(at: root)
    }
    let store = DocumentStore(root: root)
    var first = try await store.importPhoto(at: firstURL)
    first.createdAt = Date(timeIntervalSince1970: 10)
    try await store.save(first, revision: 1)
    var second = try await store.importPhoto(at: secondURL)
    second.createdAt = Date(timeIntervalSince1970: 20)
    second.state.exposure = 1.25
    try await store.save(second, revision: 2)
    try await store.select(second)

    #expect(try await store.list().map(\.id) == [second.id, first.id])
    #expect(try await store.load(second.id).state.exposure == 1.25)
    try await store.delete(second.id)
    try await store.save(second, revision: 999)
    #expect(try await store.list().map(\.id) == [first.id])
    #expect(try await store.restore() == nil)
    #expect(FileManager.default.fileExists(atPath: await store.originalURL(for: first).path))
}

@Test func libraryQuerySearchesSortsAndFavoriteMarkerPersists() async throws {
    let root = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let source = try fixture()
    defer { try? FileManager.default.removeItem(at: source); try? FileManager.default.removeItem(at: root) }
    let store = DocumentStore(root: root)
    let stored = try await store.importPhoto(at: source)
    #expect(!(await store.isFavorite(stored.id)))
    try await store.setFavorite(true, for: stored.id)
    #expect(await store.isFavorite(stored.id))

    let older = LibraryDocument(
        document: PhotoDocument(id: UUID(), originalName: "Été.jpg", originalFilename: "a.jpg",
                                createdAt: Date(timeIntervalSince1970: 10)), originalURL: source)
    let newer = LibraryDocument(
        document: PhotoDocument(id: UUID(), originalName: "Portrait.jpg", originalFilename: "b.jpg",
                                createdAt: Date(timeIntervalSince1970: 20)), originalURL: source, isFavorite: true)
    #expect(LibraryQuery.results([older, newer], search: "été", sort: .newest).map(\.id) == [older.id])
    #expect(LibraryQuery.results([older, newer], search: "", sort: .newest).map(\.id) == [newer.id, older.id])
    #expect(LibraryQuery.results([older, newer], search: "", sort: .oldest).map(\.id) == [older.id, newer.id])
    #expect(LibraryQuery.results([older, newer], search: "", sort: .name).map(\.id) == [older.id, newer.id])
}

@Test func libraryFoldersPersistAssignFilterAndDeleteWithoutDeletingPhotos() async throws {
    let root = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let source = try fixture()
    defer { try? FileManager.default.removeItem(at: source); try? FileManager.default.removeItem(at: root) }
    let store = DocumentStore(root: root)
    let stored = try await store.importPhoto(at: source)
    let trips = try await store.createFolder(named: " Voyages ")
    let family = try await store.createFolder(named: "Famille")
    #expect(try await store.folders().map(\.name) == ["Famille", "Voyages"])
    try await store.setFolder(trips.id, for: stored.id)
    #expect(await store.folderID(for: stored.id) == trips.id)

    let unfiled = LibraryDocument(
        document: PhotoDocument(id: UUID(), originalName: "Sans dossier.jpg", originalFilename: "a.jpg", createdAt: .now),
        originalURL: source)
    let filed = LibraryDocument(document: stored, originalURL: await store.originalURL(for: stored),
                                isFavorite: true, folderID: trips.id)
    #expect(LibraryQuery.results([unfiled, filed], search: "", sort: .newest, scope: .favorites).map(\.id) == [filed.id])
    #expect(LibraryQuery.results([unfiled, filed], search: "", sort: .newest, scope: .folder(trips.id)).map(\.id) == [filed.id])
    #expect(LibraryQuery.results([unfiled, filed], search: "", sort: .newest, scope: .folder(family.id)).isEmpty)

    try await store.deleteFolder(trips.id)
    #expect(await store.folderID(for: stored.id) == nil)
    #expect(try await store.load(stored.id).id == stored.id)
}

@Test func libraryTagsSupportMultipleAssignmentsFilteringAndSafeDeletion() async throws {
    let root = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let source = try fixture()
    defer { try? FileManager.default.removeItem(at: source); try? FileManager.default.removeItem(at: root) }
    let store = DocumentStore(root: root)
    let stored = try await store.importPhoto(at: source)
    let portrait = try await store.createTag(named: " Portrait ")
    let selected = try await store.createTag(named: "Sélection")
    #expect(try await store.tags().map(\.name) == ["Portrait", "Sélection"])
    try await store.setTag(portrait.id, enabled: true, for: stored.id)
    try await store.setTag(selected.id, enabled: true, for: stored.id)
    #expect(await store.tagIDs(for: stored.id) == [portrait.id, selected.id])

    let entry = LibraryDocument(document: stored, originalURL: await store.originalURL(for: stored),
                                tagIDs: await store.tagIDs(for: stored.id))
    #expect(LibraryQuery.results([entry], search: "", sort: .newest, scope: .tag(portrait.id)).map(\.id) == [stored.id])
    try await store.deleteTag(portrait.id)
    #expect(await store.tagIDs(for: stored.id) == [selected.id])
    #expect(try await store.load(stored.id).id == stored.id)
}

@Test func libraryBatchOperationsApplyToEverySelectedDocument() async throws {
    let root = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let source = try fixture()
    defer { try? FileManager.default.removeItem(at: source); try? FileManager.default.removeItem(at: root) }
    let store = DocumentStore(root: root)
    let first = try await store.importPhoto(at: source)
    let second = try await store.importPhoto(at: source)
    let ids: Set<UUID> = [first.id, second.id]
    let folder = try await store.createFolder(named: "Sélection")
    let tag = try await store.createTag(named: "À livrer")

    try await store.setFavorites(true, for: ids)
    try await store.setFolder(folder.id, for: ids)
    try await store.setTag(tag.id, enabled: true, for: ids)
    for id in ids {
        #expect(await store.isFavorite(id))
        #expect(await store.folderID(for: id) == folder.id)
        #expect(await store.tagIDs(for: id) == [tag.id])
    }

    try await store.setFavorites(false, for: ids)
    try await store.setFolder(nil, for: ids)
    try await store.setTag(tag.id, enabled: false, for: ids)
    for id in ids {
        #expect(!(await store.isFavorite(id)))
        #expect(await store.folderID(for: id) == nil)
        #expect(await store.tagIDs(for: id).isEmpty)
    }

    try await store.delete(ids)
    #expect(try await store.list().isEmpty)
}

@Test func rendererRejectsInvalidInputAndHonorsCancellation() async throws {
    let invalid = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".jpg")
    try Data("not an image".utf8).write(to: invalid)
    defer { try? FileManager.default.removeItem(at: invalid) }
    let renderer = RenderEngine()
    do {
        _ = try await renderer.render(url: invalid, state: EditState(), quality: .high)
        Issue.record("Invalid image accepted")
    } catch is PhotoError {} catch { Issue.record("Unexpected error: \(error)") }
    let task = Task {
        try await Task.sleep(for: .milliseconds(50))
        return try await renderer.render(url: invalid, state: EditState(), quality: .high)
    }
    task.cancel()
    do { _ = try await task.value; Issue.record("Cancellation ignored") }
    catch is CancellationError {} catch { Issue.record("Unexpected error: \(error)") }
}

@Test func skinSectorGetsLessVibranceThanEquivalentBlue() {
    var state = EditState(); state.vibrance = 80
    let skin = TonalResponse.color(0.7, 0.55, 0.4, state: state)
    let blue = TonalResponse.color(0.4, 0.55, 0.7, state: state)
    #expect(skin.0 - skin.2 < blue.2 - blue.0)
}

@Test func orientationIsAppliedOnce() async throws {
    let url = try fixture(orientation: 6)
    defer { try? FileManager.default.removeItem(at: url) }
    let result = try await RenderEngine().render(url: url, state: EditState(), quality: .high)
    #expect(result.image.width == 32)
    #expect(result.image.height == 64)
    #expect(result.original.width == result.image.width)
}

@Test func rendererAppliesRGBAndChannelCurves() async throws {
    let url = try fixture()
    defer { try? FileManager.default.removeItem(at: url) }
    let engine = RenderEngine()
    let neutral = try await engine.render(url: url, state: EditState(), quality: .high)
    var state = EditState()
    state.curves.rgb = ToneCurve(points: [.init(x: 0, y: 0), .init(x: 0.5, y: 0.75), .init(x: 1, y: 1)])
    let brighter = try await engine.render(url: url, state: state, quality: .high)
    func mean(_ bins: [Int]) -> Double {
        Double(bins.enumerated().reduce(0) { $0 + $1.offset * $1.element }) / Double(bins.reduce(0, +))
    }
    #expect(mean(brighter.histogram.luminance) > mean(neutral.histogram.luminance) + 10)
    #expect(brighter.original === neutral.original)
    state.curves = ToneCurves()
    state.curves.red = ToneCurve(points: [.init(x: 0, y: 0), .init(x: 0.5, y: 0.75), .init(x: 1, y: 1)])
    let red = try await engine.render(url: url, state: state, quality: .high)
    #expect(mean(red.histogram.red) > mean(neutral.histogram.red) + 10)
    #expect(abs(mean(red.histogram.green) - mean(neutral.histogram.green)) < 2)
    #expect(abs(mean(red.histogram.blue) - mean(neutral.histogram.blue)) < 2)
    #expect(red.cacheHit)
}

@Test func rendererMixerDesaturatesOnlyTargetedColor() async throws {
    let url = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".png")
    defer { try? FileManager.default.removeItem(at: url) }
    let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
    let context = try #require(CGContext(data: nil, width: 64, height: 32, bitsPerComponent: 8,
                                       bytesPerRow: 256, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    context.setFillColor(try #require(CGColor(colorSpace: space, components: [1, 0, 0, 1])))
    context.fill(CGRect(x: 0, y: 0, width: 32, height: 32))
    context.setFillColor(try #require(CGColor(colorSpace: space, components: [0, 0, 1, 1])))
    context.fill(CGRect(x: 32, y: 0, width: 32, height: 32))
    let image = try #require(context.makeImage())
    let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil))
    CGImageDestinationAddImage(destination, image, nil)
    #expect(CGImageDestinationFinalize(destination))
    let engine = RenderEngine()
    var state = EditState(); state.colorMixer[.red] = MixerAdjustment(saturation: -100)
    let result = try await engine.render(url: url, state: state, quality: .high)
    func pixel(_ x: Int, image: CGImage) throws -> [UInt8] {
        let crop = try #require(image.cropping(to: CGRect(x: x, y: 16, width: 1, height: 1)))
        var bytes = [UInt8](repeating: 0, count: 4)
        try bytes.withUnsafeMutableBytes { buffer in
            let context = try #require(CGContext(data: buffer.baseAddress, width: 1, height: 1, bitsPerComponent: 8,
                                                bytesPerRow: 4, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(crop, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        }
        return bytes
    }
    let gray = try pixel(16, image: result.image), blue = try pixel(48, image: result.image)
    #expect(try pixel(16, image: result.original) == [255, 0, 0, 255])
    #expect(try pixel(48, image: result.original) == [0, 0, 255, 255])
    #expect(abs(Int(gray[0]) - Int(gray[1])) <= 2 && abs(Int(gray[1]) - Int(gray[2])) <= 2)
    #expect((125...130).contains(Int(gray[0])))
    #expect(blue[0] <= 2 && blue[1] <= 2 && blue[2] >= 253)
    #expect(result.original.width == 64)
}

@Test func rendererGradingTintsNeutralRampAndRestoresIdentity() async throws {
    let url = try fixture()
    defer { try? FileManager.default.removeItem(at: url) }
    let engine = RenderEngine()
    let original = try await engine.render(url: url, state: EditState(), quality: .high)
    var state = EditState()
    state.colorGrading.midtones = GradingWheel(hue: 240, saturation: 80)
    let edited = try await engine.render(url: url, state: state, quality: .high)
    func mean(_ bins: [Int]) -> Double {
        Double(bins.enumerated().reduce(0) { $0 + $1.offset * $1.element }) / Double(bins.reduce(0, +))
    }
    #expect(mean(edited.histogram.blue) > mean(edited.histogram.red) + 5)
    #expect(edited.original === original.original)
    let reset = try await engine.render(url: url, state: EditState(), quality: .high)
    #expect(reset.histogram.red == original.histogram.red)
    #expect(reset.histogram.blue == original.histogram.blue)
}
