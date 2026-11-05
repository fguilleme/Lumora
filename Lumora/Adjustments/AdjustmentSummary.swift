import Foundation

/// A tab groups its adjustments across the base and masked layers.
enum AdjustmentSection: String, CaseIterable, Codable, Sendable {
    case light = "Light", color = "Color", curves = "Curves", colorTools = "Color Tools"
    case effects = "Effects", detail = "Detail", creative = "Creative", beauty = "Beauty"
    case depthLens = "Depth Lens", lighting = "Lighting", optics = "Optics", geometry = "Geometry", masks = "Masks"

    var supportsEyeToggle: Bool { self != .lighting && self != .depthLens }
}

extension EditState {
    var effectiveGeometry: GeometrySettings {
        suspendedSections.contains(.geometry) ? GeometrySettings() : geometry
    }

    /// Neutralize suspended modules in a copy for preview and export.
    var renderingState: EditState {
        guard !suspendedSections.isEmpty else { return self }
        var result = self
        result.suspendedSections.removeAll()
        for section in suspendedSections { result.clearAdjustments(in: section) }

        let localSections = suspendedSections.intersection([.light, .color, .curves, .colorTools, .effects, .detail])
        if !localSections.isEmpty {
            for index in result.masks.indices {
                var local = result.masks[index].adjustments.editState
                for section in localSections { local.clearAdjustments(in: section) }
                result.masks[index].adjustments = LocalAdjustmentState(editState: local)
            }
        }
        return result
    }

    private mutating func clearAdjustments(in section: AdjustmentSection) {
        switch section {
        case .light:
            for adjustment in Adjustment.light { self[adjustment] = 0 }
            coreImageAuto = nil
        case .color:
            for adjustment in Adjustment.color { self[adjustment] = 0 }
        case .curves: curves = ToneCurves()
        case .colorTools:
            colorMixer = ColorMixer()
            colorGrading = ColorGrading()
        case .effects:
            effects = EffectsSettings()
            detail.blur = 0
        case .detail:
            let blur = detail.blur
            detail = DetailSettings()
            detail.blur = blur
        case .creative: creative = CreativeEffectStack()
        case .beauty: beauty = BeautyState()
        case .depthLens, .lighting: break
        case .optics:
            optics = OpticsSettings()
            optics.profileCorrection = false
        case .geometry: geometry = GeometrySettings()
        case .masks:
            masks.removeAll()
            creative.effects.removeAll { $0.maskID != nil }
        }
    }

    func hasAdjustments(in section: AdjustmentSection, includingMasks: Bool = false) -> Bool {
        let changed: Bool = switch section {
        case .light: coreImageAuto != nil || Adjustment.light.contains { self[$0] != 0 }
        case .color: Adjustment.color.contains { self[$0] != 0 }
        case .curves: !curves.isIdentity
        case .colorTools: colorMixer != ColorMixer() || colorGrading != ColorGrading()
        case .effects: effects != EffectsSettings() || detail.blur != 0
        case .detail: detail.hasDetailAdjustments
        case .creative: !creative.effects.isEmpty
        case .beauty: beauty != BeautyState()
        case .depthLens: (depthLens ?? DepthLensSettings()) != DepthLensSettings()
        case .lighting: (depthLighting ?? DepthLightingSettings()) != DepthLightingSettings()
        case .optics: optics != OpticsSettings()
        case .geometry: !geometry.isIdentity
        case .masks: !masks.isEmpty
        }
        return changed || (includingMasks && masks.contains {
            $0.adjustments.editState.hasAdjustments(in: section)
        })
    }

    /// Full, persistent summary for a masked layer, independent of transient feedback.
    var adjustmentSummary: String {
        var items: [String] = []
        func number(_ value: Double, precision: Int = 0) -> String {
            value.formatted(.number.precision(.fractionLength(precision)))
        }
        for adjustment in Adjustment.allCases where self[adjustment] != 0 {
            let unit = adjustment == .exposure ? " EV" : ""
            items.append("\(adjustment.title) \(number(self[adjustment], precision: adjustment == .exposure ? 2 : 0))\(unit)")
        }
        if !curves.isIdentity { items.append(String(localized: "Curves")) }
        if colorMixer != ColorMixer() { items.append(String(localized: "Color Mixer")) }
        if colorGrading != ColorGrading() { items.append(String(localized: "Color Grading")) }
        for adjustment in EffectAdjustment.allCases where effects[adjustment] != EffectsSettings()[adjustment] {
            items.append("\(adjustment.title) \(number(effects[adjustment]))")
        }
        for adjustment in DetailAdjustment.allCases where detail[adjustment] != adjustment.defaultValue {
            let group: String = switch adjustment.group {
            case 0: String(localized: "Sharpening")
            case 1: String(localized: "Noise L")
            case 2: String(localized: "Noise C")
            default: ""
            }
            let title = group.isEmpty || group == adjustment.title ? adjustment.title : "\(group) · \(adjustment.title)"
            items.append("\(title) \(number(detail[adjustment], precision: adjustment.precision))")
        }
        return items.isEmpty ? String(localized: "No adjustments") : items.joined(separator: " · ")
    }
}
