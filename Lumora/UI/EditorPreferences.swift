import Foundation

enum EditorPanel: String, CaseIterable {
        case creative = "Creative"
        case light = "Light", color = "Color", curve = "Curves", colorTools = "Color Tools", effects = "Effects", detail = "Detail", depthLens = "Depth Lens", lighting = "Lighting", beauty = "Beauty", optics = "Optics", geometry = "Geometry", masks = "Masks", presets = "Presets", help = "Help", settings = "Settings"
        var title: String { NSLocalizedString(rawValue, comment: "Editor tab") }
        var symbol: String {
            switch self {
            case .creative: "sparkles"
            case .light: "sun.max"
            case .color: "slider.horizontal.3"
            case .curve: "point.topleft.down.to.point.bottomright.curvepath"
            case .colorTools: "circle.lefthalf.filled"
            case .effects: "camera.filters"
            case .detail: "triangle"
            case .depthLens: "camera.aperture"
            case .lighting: "lightbulb"
            case .beauty: "face.smiling"
            case .optics: "camera.aperture"
            case .geometry: "crop.rotate"
            case .masks: "circle.dashed.inset.filled"
            case .presets: "slider.horizontal.2.square"
            case .help: "questionmark.circle"
            case .settings: "gearshape"
            }
        }
    }


/// String identifiers survive translations and newly added tabs. Settings stays reachable.
enum EditorTabPreferences {
    static func ordered(_ stored: String) -> [EditorPanel] {
        let ids = (try? JSONDecoder().decode([String].self, from: Data(stored.utf8))) ?? []
        var result: [EditorPanel] = []
        for id in ids { if let tab = EditorPanel(rawValue: id), !result.contains(tab) { result.append(tab) } }
        return result + EditorPanel.allCases.filter { !result.contains($0) }
    }
    static func hidden(_ stored: String) -> Set<String> {
        Set((try? JSONDecoder().decode([String].self, from: Data(stored.utf8))) ?? []).subtracting([EditorPanel.settings.rawValue])
    }
    static func visible(order: String, hidden: String) -> [EditorPanel] {
        let excluded = self.hidden(hidden)
        return ordered(order).filter { !excluded.contains($0.rawValue) }
    }
    static func encode(_ values: [String]) -> String {
        String(data: (try? JSONEncoder().encode(values)) ?? Data(), encoding: .utf8) ?? ""
    }
}
