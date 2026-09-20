import SwiftUI
import UniformTypeIdentifiers

struct PresetFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    let data: Data

    init(preset: Preset) throws {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        data = try encoder.encode(preset)
    }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}
