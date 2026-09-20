import Foundation

actor PresetStore {
    private let root: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(root: URL = URL.applicationSupportDirectory.appendingPathComponent("Lumora", isDirectory: true)
        .appendingPathComponent("Presets", isDirectory: true)) {
        self.root = root
        encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        decoder = JSONDecoder()
    }

    func load() throws -> [Preset] {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let urls = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "lumorapreset" }
        return urls.compactMap { url in
            guard let data = try? Data(contentsOf: url), data.count <= 5_000_000,
                  let decoded = try? decoder.decode(Preset.self, from: data), let preset = decoded.validated
            else { return nil }
            return preset
        }.sorted { $0.createdAt > $1.createdAt }
    }

    @discardableResult func save(_ preset: Preset) throws -> Preset {
        guard let preset = preset.validated else { throw PresetError.invalid }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try encoder.encode(preset).write(to: url(for: preset.id), options: .atomic)
        return preset
    }

    func delete(_ preset: Preset) throws {
        let url = url(for: preset.id)
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
    }

    func importPreset(from source: URL) throws -> Preset {
        let scoped = source.startAccessingSecurityScopedResource()
        defer { if scoped { source.stopAccessingSecurityScopedResource() } }
        let data = try Data(contentsOf: source)
        guard data.count <= 5_000_000 else { throw PresetError.tooLarge }
        let decoded = try decoder.decode(Preset.self, from: data)
        guard decoded.formatVersion == 1 else { throw PresetError.unsupported }
        guard var preset = decoded.validated else { throw PresetError.invalid }
        preset.id = UUID(); preset.createdAt = Date()
        return try save(preset)
    }

    func data(for preset: Preset) throws -> Data {
        guard let preset = preset.validated else { throw PresetError.invalid }
        return try encoder.encode(preset)
    }

    private func url(for id: UUID) -> URL { root.appendingPathComponent(id.uuidString + ".lumorapreset") }
}
