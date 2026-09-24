import Foundation

enum PresetSection: String, CaseIterable, Codable, Sendable, Identifiable {
    case light, color, curves, mixer, grading, effects, detail, optics, geometry, masks, creative
    var id: String { rawValue }
    var title: String {
        switch self {
        case .light: String(localized: "Light"); case .color: String(localized: "Color"); case .curves: String(localized: "Curves")
        case .mixer: String(localized: "Color Mixer"); case .grading: "Grading"; case .effects: String(localized: "Effects")
        case .detail: String(localized: "Detail"); case .optics: String(localized: "Optics"); case .geometry: String(localized: "Geometry")
        case .masks: String(localized: "Masks"); case .creative: "Creative"
        }
    }
    static let photographicDefaults: Set<Self> = [.light, .color, .curves, .mixer, .grading, .effects, .detail, .creative]
}

struct Preset: Codable, Sendable, Equatable, Identifiable {
    var id: UUID
    var name: String
    var createdAt: Date
    var sections: Set<PresetSection>
    var values: EditState
    var formatVersion = 2

    init(id: UUID = UUID(), name: String, createdAt: Date = Date(), sections: Set<PresetSection>, values: EditState) {
        self.id = id; self.name = name; self.createdAt = createdAt
        self.sections = sections; self.values = values
    }

    var validated: Self? {
        var value = self
        value.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (1...2).contains(formatVersion), !value.name.isEmpty, !sections.isEmpty else { return nil }
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
        if preset.sections.contains(.creative) {
            result.creative = preset.values.creative
            // A creative-only preset is portable: mask links require the Masks section.
            if !preset.sections.contains(.masks) {
                for i in result.creative.effects.indices { result.creative.effects[i].maskID = nil }
            }
        }
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
        if sections.contains(.creative) { result.creative = source.creative }
        return result.validated
    }
}

enum PresetError: LocalizedError {
    case invalid, unsupported, tooLarge
    var errorDescription: String? {
        switch self {
        case .invalid: "This preset is empty or unreadable."
        case .unsupported: "This preset version is not supported."
        case .tooLarge: "This preset exceeds the maximum allowed size."
        }
    }
}
