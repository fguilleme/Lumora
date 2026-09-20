import Foundation

enum PresetSection: String, CaseIterable, Codable, Sendable, Identifiable {
    case light, color, curves, mixer, grading, effects, detail, optics, geometry, masks
    var id: String { rawValue }
    var title: String {
        switch self {
        case .light: "Lumière"; case .color: "Couleur"; case .curves: "Courbes"
        case .mixer: "Mélangeur"; case .grading: "Grading"; case .effects: "Effets"
        case .detail: "Détail"; case .optics: "Optique"; case .geometry: "Géométrie"
        case .masks: "Masques"
        }
    }
    static let photographicDefaults: Set<Self> = [.light, .color, .curves, .mixer, .grading, .effects, .detail]
}

struct Preset: Codable, Sendable, Equatable, Identifiable {
    var id: UUID
    var name: String
    var createdAt: Date
    var sections: Set<PresetSection>
    var values: EditState
    var formatVersion = 1

    init(id: UUID = UUID(), name: String, createdAt: Date = Date(), sections: Set<PresetSection>, values: EditState) {
        self.id = id; self.name = name; self.createdAt = createdAt
        self.sections = sections; self.values = values
    }

    var validated: Self? {
        var value = self
        value.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard formatVersion == 1, !value.name.isEmpty, !sections.isEmpty else { return nil }
        value.name = String(value.name.prefix(60))
        value.values = Self.filtered(values.validated, sections: sections)
        return value
    }

    func applying(to current: EditState) -> EditState {
        guard let preset = validated else { return current }
        var result = current
        if preset.sections.contains(.light) { for adjustment in Adjustment.light { result[adjustment] = preset.values[adjustment] } }
        if preset.sections.contains(.color) { for adjustment in Adjustment.color { result[adjustment] = preset.values[adjustment] } }
        if preset.sections.contains(.curves) { result.curves = preset.values.curves }
        if preset.sections.contains(.mixer) { result.colorMixer = preset.values.colorMixer }
        if preset.sections.contains(.grading) { result.colorGrading = preset.values.colorGrading }
        if preset.sections.contains(.effects) { result.effects = preset.values.effects }
        if preset.sections.contains(.detail) { result.detail = preset.values.detail }
        if preset.sections.contains(.optics) { result.optics = preset.values.optics }
        if preset.sections.contains(.geometry) { result.geometry = preset.values.geometry }
        if preset.sections.contains(.masks) { result.masks = preset.values.masks }
        return result.validated
    }

    private static func filtered(_ source: EditState, sections: Set<PresetSection>) -> EditState {
        var result = EditState()
        if sections.contains(.light) { for adjustment in Adjustment.light { result[adjustment] = source[adjustment] } }
        if sections.contains(.color) { for adjustment in Adjustment.color { result[adjustment] = source[adjustment] } }
        if sections.contains(.curves) { result.curves = source.curves }
        if sections.contains(.mixer) { result.colorMixer = source.colorMixer }
        if sections.contains(.grading) { result.colorGrading = source.colorGrading }
        if sections.contains(.effects) { result.effects = source.effects }
        if sections.contains(.detail) { result.detail = source.detail }
        if sections.contains(.optics) { result.optics = source.optics }
        if sections.contains(.geometry) { result.geometry = source.geometry }
        if sections.contains(.masks) { result.masks = source.masks }
        return result.validated
    }
}

enum PresetError: LocalizedError {
    case invalid, unsupported, tooLarge
    var errorDescription: String? {
        switch self {
        case .invalid: "Ce preset est vide ou illisible."
        case .unsupported: "Cette version de preset n’est pas prise en charge."
        case .tooLarge: "Ce preset dépasse la taille maximale autorisée."
        }
    }
}
