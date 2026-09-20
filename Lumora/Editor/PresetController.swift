import Foundation
import Observation

@MainActor @Observable
final class PresetController {
    private(set) var presets: [Preset] = []
    private(set) var isLoading = false
    var error: String?
    @ObservationIgnored private let store: PresetStore

    init(store: PresetStore = PresetStore()) { self.store = store }

    func load() async {
        isLoading = true; defer { isLoading = false }
        do { presets = try await store.load() }
        catch { self.error = error.localizedDescription }
    }
    func create(name: String, sections: Set<PresetSection>, state: EditState) async {
        do {
            let preset = try await store.save(Preset(name: name, sections: sections, values: state.validated))
            presets.removeAll { $0.id == preset.id }; presets.insert(preset, at: 0)
        } catch { self.error = error.localizedDescription }
    }
    func rename(_ preset: Preset, to name: String) async {
        do {
            var renamed = preset; renamed.name = name
            renamed = try await store.save(renamed)
            if let index = presets.firstIndex(where: { $0.id == preset.id }) { presets[index] = renamed }
        } catch { self.error = error.localizedDescription }
    }
    func delete(_ preset: Preset) async {
        do { try await store.delete(preset); presets.removeAll { $0.id == preset.id } }
        catch { self.error = error.localizedDescription }
    }
    func importPreset(from url: URL) async {
        do {
            let preset = try await store.importPreset(from: url)
            presets.insert(preset, at: 0)
        } catch { self.error = error.localizedDescription }
    }
}
