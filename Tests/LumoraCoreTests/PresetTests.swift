import Testing
import Foundation
@testable import LumoraCore

@Test func presetAppliesOnlySelectedSections() {
    var current = EditState()
    current.exposure = -1; current.temperature = 40; current.geometry.cropZoom = 25
    current.effects.grain = 12
    current.masks = [LocalMask(name: "Actuel", components: [MaskComponent(shape: .radial(RadialGradientMask()))])]
    var values = EditState()
    values.exposure = 2; values.contrast = 30; values.temperature = -60
    values.effects.texture = 45; values.effects.grain = 70
    values.geometry.cropZoom = 70
    let preset = Preset(name: "Lumière et effets", sections: [.light, .effects], values: values)
    #expect(preset.validated?.values.temperature == 0)
    #expect(preset.validated?.values.geometry == GeometrySettings())
    let applied = preset.applying(to: current)
    #expect(applied.exposure == 2 && applied.contrast == 30)
    #expect(applied.effects.texture == 45 && applied.effects.grain == 70)
    #expect(applied.temperature == 40)
    #expect(applied.geometry.cropZoom == 25)
    #expect(applied.masks == current.masks)
}

@Test func presetCanExplicitlyReplaceGeometryAndMasks() {
    var current = EditState(); current.geometry.quarterTurns = 1
    current.masks = [LocalMask(name: "Ancien", components: [MaskComponent(shape: .linear(LinearGradientMask()))])]
    var values = EditState(); values.geometry.aspect = .square
    values.masks = [LocalMask(name: "Nouveau", components: [MaskComponent(shape: .brush(BrushMask()))])]
    let preset = Preset(name: "Composition", sections: [.geometry, .masks], values: values)
    let applied = preset.applying(to: current)
    #expect(applied.geometry.quarterTurns == 0 && applied.geometry.aspect == .square)
    #expect(applied.masks.count == 1 && applied.masks[0].name == "Nouveau")
}

@Test func presetValidationAndSerializationAreStable() throws {
    var state = EditState(); state.exposure = 1.25
    let preset = Preset(name: "  Portrait doux  ", sections: [.light, .color], values: state)
    let decoded = try JSONDecoder().decode(Preset.self, from: JSONEncoder().encode(preset))
    #expect(decoded.validated?.name == "Portrait doux")
    #expect(decoded.applying(to: EditState()).exposure == 1.25)
    #expect(Preset(name: "", sections: [.light], values: state).validated == nil)
    #expect(Preset(name: "Vide", sections: [], values: state).validated == nil)
    var future = preset; future.formatVersion = 3
    #expect(future.validated == nil)
}

@Test func presetStoreCreatesRenamesImportsAndDeletes() async throws {
    let root = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let store = PresetStore(root: root)
    var state = EditState(); state.vibrance = 35
    let original = try await store.save(Preset(name: "Vif", sections: [.color], values: state))
    var loaded = try await store.load()
    #expect(loaded == [original])
    var renamed = original; renamed.name = "Vif doux"
    renamed = try await store.save(renamed)
    loaded = try await store.load()
    #expect(loaded.count == 1 && loaded[0].name == "Vif doux")

    let interchange = root.appendingPathComponent("shared.json")
    try await store.data(for: renamed).write(to: interchange)
    let imported = try await store.importPreset(from: interchange)
    #expect(imported.id != renamed.id && imported.name == renamed.name)
    #expect(try await store.load().count == 2)
    try await store.delete(renamed)
    #expect(try await store.load() == [imported])
}
