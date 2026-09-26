import Foundation

/// A portable snapshot: no file URL, Adobe profile, or recursive Creative stack is retained.
struct XMPPresetSnapshot: Codable, Sendable, Equatable {
    var name: String
    var values: [String: Double]
    var curves: ToneCurves
    var unsupported: [String]
    var whiteBalance: String?
    var sourceKeys: [String]?
    var approximated: [String]?

    var editState: EditState {
        var state = EditState()
        for (key, adjustment) in Self.adjustments { state[adjustment] = values[key] ?? 0 }
        // Modern PV2012 controls take precedence over stale legacy tags in the same XMP.
        if values["Exposure2012"] == nil { state[.exposure] = values["Exposure"] ?? 0 }
        if values["Contrast2012"] == nil, let contrast = values["Contrast"] { state[.contrast] = contrast - 25 }
        if values["Highlights2012"] == nil { state[.highlights] = -(values["Recovery"] ?? 0) }
        if values["Shadows2012"] == nil { state[.shadows] = values["FillLight"] ?? 0 }
        if values["Blacks2012"] == nil, let blacks = values["Shadows"] { state[.blacks] = -(blacks - 5) }
        let wb = whiteBalance?.lowercased().replacingOccurrences(of: " ", with: "")
        if wb != "asshot" {
            if values["IncrementalTemperature"] == nil, let temperature = values["Temperature"] {
                // Approximation relative to Lumora's already-developed 6500 K reference.
                state[.temperature] = temperature >= 2000 ? (temperature - 6500) / 35 : temperature
            }
            if values["IncrementalTint"] == nil, let tint = values["Tint"] { state[.tint] = tint / 0.6 }
        }
        state.curves = curves
        let brightness = values["Exposure2012"] == nil ? ((values["Brightness"] ?? 50) - 50) / 200 : 0
        let parametricKeys = ["ParametricShadows", "ParametricDarks", "ParametricLights", "ParametricHighlights"]
        if brightness != 0 || parametricKeys.contains(where: { (values[$0] ?? 0) != 0 }) {
            let low = min(0.49, max(0.01, (values["ParametricShadowSplit"] ?? 25) / 100))
            let mid = min(0.74, max(low + 0.01, (values["ParametricMidtoneSplit"] ?? 50) / 100))
            let high = min(0.99, max(mid + 0.01, (values["ParametricHighlightSplit"] ?? 75) / 100))
            state.curves.rgb = ToneCurve(points: (0...15).map { index in
                let x = Double(index) / 15
                let y = curves.rgb.evaluate(x)
                let a = TonalResponse.smoothstep(0, low * 2, x)
                let b = TonalResponse.smoothstep(low, high, x)
                let c = TonalResponse.smoothstep(mid, 1, x)
                let weights = [1 - a, max(0, a - b), max(0, b - c), c]
                let shift = zip(parametricKeys, weights).reduce(0.0) { $0 + (values[$1.0] ?? 0) / 100 * $1.1 }
                return CurvePoint(x: x, y: y + (brightness + shift * 0.35) * 4 * y * (1 - y))
            })
        }
        for (key, adjustment) in Self.geometry { if let value = values[key] { state.geometry[adjustment] = value } }
        state.effects.grain = grain.amount
        if values["GrainSize"] != nil { state.effects.grainSize = grain.size }
        if values["GrainFrequency"] != nil { state.effects.grainIrregularity = grain.irregularity }
        state.colorGrading.global = GradingWheel(hue: values["ColorGradeGlobalHue"] ?? 0,
            saturation: values["ColorGradeGlobalSat"] ?? 0, luminance: values["ColorGradeGlobalLum"] ?? 0)
        for channel in MixerChannel.allCases {
            let suffix = channel.rawValue.prefix(1).uppercased() + channel.rawValue.dropFirst()
            state.colorMixer[channel] = MixerAdjustment(hue: values["HueAdjustment" + suffix] ?? 0,
                saturation: values["SaturationAdjustment" + suffix] ?? 0,
                luminance: values["LuminanceAdjustment" + suffix] ?? 0)
        }
        state.colorGrading.shadows = GradingWheel(hue: values["SplitToningShadowHue"] ?? 0,
            saturation: values["SplitToningShadowSaturation"] ?? 0, luminance: values["ColorGradeShadowLum"] ?? 0)
        state.colorGrading.highlights = GradingWheel(hue: values["SplitToningHighlightHue"] ?? 0,
            saturation: values["SplitToningHighlightSaturation"] ?? 0, luminance: values["ColorGradeHighlightLum"] ?? 0)
        state.colorGrading.midtones = GradingWheel(hue: values["ColorGradeMidtoneHue"] ?? 0,
            saturation: values["ColorGradeMidtoneSat"] ?? 0, luminance: values["ColorGradeMidtoneLum"] ?? 0)
        state.colorGrading.balance = values["SplitToningBalance"] ?? 0
        state.colorGrading.blending = values["ColorGradeBlending"] ?? 50
        state.effects.texture = values["Texture"] ?? 0
        state.effects.clarity = values["Clarity2012"] ?? values["Clarity"] ?? 0
        state.effects.dehaze = values["Dehaze"] ?? 0
        state.effects.vignette = values["PostCropVignetteAmount"] ?? 0
        state.detail.sharpening.amount = values["Sharpness"] ?? 0
        state.detail.sharpening.radius = values["SharpenRadius"] ?? 1
        state.detail.sharpening.detail = values["SharpenDetail"] ?? 25
        state.detail.sharpening.masking = values["SharpenEdgeMasking"] ?? 0
        state.detail.noiseReduction.luminance = values["LuminanceSmoothing"] ?? 0
        state.detail.noiseReduction.detail = values["LuminanceNoiseReductionDetail"] ?? 50
        state.detail.noiseReduction.contrast = values["LuminanceNoiseReductionContrast"] ?? 0
        state.detail.colorNoiseReduction.color = values["ColorNoiseReduction"] ?? 0
        state.detail.colorNoiseReduction.detail = values["ColorNoiseReductionDetail"] ?? 50
        state.detail.colorNoiseReduction.smoothness = values["ColorNoiseReductionSmoothness"] ?? 50
        return state.validated
    }

    var grain: FilmGrainSettings {
        var settings = FilmGrainSettings()
        settings.amount = values["GrainAmount"] ?? 0
        settings.size = values["GrainSize"] ?? 25
        settings.irregularity = values["GrainFrequency"] ?? 50
        return settings.validated
    }

    func makeEffect() -> CreativeEffect {
        var effect = CreativeEffect(.importedXMP)
        effect.importedXMP = self
        return effect
    }

    static let adjustments: [String: Adjustment] = [
        "Exposure2012": .exposure, "Contrast2012": .contrast, "Highlights2012": .highlights,
        "Shadows2012": .shadows, "Whites2012": .whites, "Blacks2012": .blacks,
        "IncrementalTemperature": .temperature, "IncrementalTint": .tint,
        "Vibrance": .vibrance, "Saturation": .saturation
    ]
    static let geometry: [String: GeometryAdjustment] = [
        "PerspectiveRotate": .straighten, "PerspectiveScale": .perspectiveScale,
        "PerspectiveX": .perspectiveOffsetX, "PerspectiveY": .perspectiveOffsetY,
        "PerspectiveVertical": .perspectiveVertical, "PerspectiveHorizontal": .perspectiveHorizontal,
        "PerspectiveAspect": .perspectiveAspect
    ]
    static let curveKeys: [String: CurveChannel] = ["ToneCurve": .rgb,
        "ToneCurveRed": .red, "ToneCurveGreen": .green, "ToneCurveBlue": .blue, "ToneCurvePV2012": .rgb,
        "ToneCurvePV2012Red": .red, "ToneCurvePV2012Green": .green, "ToneCurvePV2012Blue": .blue]
    static let numericKeys: Set<String> = Set(adjustments.keys).union(geometry.keys).union([
        "Exposure", "Brightness", "Contrast", "Shadows", "FillLight", "Recovery", "Clarity", "Temperature", "Tint",
        "ColorGradeGlobalHue", "ColorGradeGlobalSat", "ColorGradeGlobalLum",
        "ParametricShadows", "ParametricDarks", "ParametricLights", "ParametricHighlights",
        "ParametricShadowSplit", "ParametricMidtoneSplit", "ParametricHighlightSplit",
        "SplitToningShadowHue", "SplitToningShadowSaturation", "SplitToningHighlightHue",
        "SplitToningHighlightSaturation", "SplitToningBalance", "ColorGradeMidtoneHue", "ColorGradeMidtoneSat",
        "ColorGradeShadowLum", "ColorGradeMidtoneLum", "ColorGradeHighlightLum", "ColorGradeBlending",
        "Texture", "Clarity2012", "Dehaze", "PostCropVignetteAmount", "Sharpness", "SharpenRadius",
        "SharpenDetail", "SharpenEdgeMasking", "LuminanceSmoothing", "LuminanceNoiseReductionDetail",
        "LuminanceNoiseReductionContrast", "ColorNoiseReduction", "ColorNoiseReductionDetail",
        "ColorNoiseReductionSmoothness", "GrainAmount", "GrainSize", "GrainFrequency"
    ]).union(MixerChannel.allCases.flatMap { channel in
        let suffix = channel.rawValue.prefix(1).uppercased() + channel.rawValue.dropFirst()
        return ["HueAdjustment", "SaturationAdjustment", "LuminanceAdjustment"].map { $0 + suffix }
    })
}

enum XMPImportError: LocalizedError {
    case invalid, unsupported, tooLarge
    var errorDescription: String? {
        switch self {
        case .invalid: String(localized: "The XMP file is invalid or contains invalid settings.")
        case .unsupported: String(localized: "No compatible Camera Raw settings found. Proprietary Nik recipes cannot be imported.")
        case .tooLarge: String(localized: "The XMP file exceeds the 2 MB limit.")
        }
    }
}

enum XMPPresetImporter {
    static let maximumBytes = 2 * 1024 * 1024
    static func read(_ url: URL) throws -> XMPPresetSnapshot {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        let file = try FileHandle(forReadingFrom: url)
        defer { try? file.close() }
        let data = try file.read(upToCount: maximumBytes + 1) ?? Data()
        return try parse(data, fallbackName: url.deletingPathExtension().lastPathComponent)
    }
    static func parse(_ data: Data, fallbackName: String) throws -> XMPPresetSnapshot {
        guard data.count <= maximumBytes else { throw XMPImportError.tooLarge }
        let delegate = XMPReader()
        let parser = XMLParser(data: data)
        parser.shouldProcessNamespaces = true
        parser.shouldReportNamespacePrefixes = true
        parser.shouldResolveExternalEntities = false
        parser.delegate = delegate
        guard parser.parse(), !delegate.invalid else { throw XMPImportError.invalid }
        var values: [String: Double] = [:]
        for key in XMPPresetSnapshot.numericKeys {
            if let text = delegate.fields[key] {
                guard let value = Double(text.trimmingCharacters(in: .whitespacesAndNewlines)), value.isFinite else {
                    throw XMPImportError.invalid
                }
                values[key] = value
            }
        }
        var curves = ToneCurves()
        for (key, channel) in XMPPresetSnapshot.curveKeys {
            if !key.contains("PV2012"), delegate.lists[key.replacingOccurrences(of: "ToneCurve", with: "ToneCurvePV2012")] != nil { continue }
            guard let entries = delegate.lists[key] else { continue }
            let points = try entries.map { entry -> CurvePoint in
                let parts = entry.split(separator: ",", omittingEmptySubsequences: false)
                guard parts.count == 2,
                      let x = Double(parts[0].trimmingCharacters(in: .whitespacesAndNewlines)),
                      let y = Double(parts[1].trimmingCharacters(in: .whitespacesAndNewlines)),
                      x.isFinite, y.isFinite, (0...255).contains(x), (0...255).contains(y) else {
                    throw XMPImportError.invalid
                }
                return CurvePoint(x: x / 255, y: y / 255)
            }
            guard points.count >= 2, points.count <= ToneCurve.maximumPoints,
                  points.first?.x == 0, points.last?.x == 1,
                  zip(points, points.dropFirst()).allSatisfy({ $1.x - $0.x >= ToneCurve.minimumSpacing }) else {
                throw XMPImportError.invalid
            }
            curves[channel] = ToneCurve(points: points)
        }
        guard !values.isEmpty || !delegate.lists.keys.filter({ XMPPresetSnapshot.curveKeys[$0] != nil }).isEmpty else {
            throw XMPImportError.unsupported
        }
        let metadata: Set<String> = ["Name", "ShortName", "SortName", "Group", "Description", "PresetType", "Cluster",
            "UUID", "Copyright", "ContactInfo", "Version", "ProcessVersion", "HasSettings", "WhiteBalance",
            "CameraModelRestriction", "ToneCurveName", "ToneCurveName2012", "ShowInPresets", "ShowInQuickActions",
            "CameraProfileDigest", "RawFileName", "AlreadyApplied", "LensProfileDigest", "LensProfileName",
            "LensProfileFilename", "LensProfileSetup", "CurveRefineSaturation"]
        func inactive(_ key: String) -> Bool {
            guard let text = delegate.fields[key]?.trimmingCharacters(in: .whitespacesAndNewlines) else { return false }
            return text.isEmpty || text.lowercased() == "false" || Double(text) == 0
        }
        var unsupported = delegate.keys.subtracting(XMPPresetSnapshot.numericKeys)
            .subtracting(XMPPresetSnapshot.curveKeys.keys).subtracting(metadata)
            .filter { key in
                if key.hasPrefix("Supports") || inactive(key) { return false }
                // A hue interval has no effect when the corresponding defringe amount is zero/absent.
                if key.hasPrefix("DefringeGreenHue") {
                    return !(delegate.fields["DefringeGreenAmount"] == nil || inactive("DefringeGreenAmount"))
                }
                if key.hasPrefix("DefringePurpleHue") {
                    return !(delegate.fields["DefringePurpleAmount"] == nil || inactive("DefringePurpleAmount"))
                }
                if key.hasPrefix("PostCropVignette"), (values["PostCropVignetteAmount"] ?? 0) == 0 { return false }
                return true
            }
        let wb = delegate.fields["WhiteBalance"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        let asShot = wb?.lowercased().replacingOccurrences(of: " ", with: "") == "asshot"
        if let wb, !asShot, !wb.isEmpty, values["Temperature"] == nil,
           values["IncrementalTemperature"] == nil { unsupported.insert("WhiteBalance") }
        var approximated: Set<String> = []
        let legacy: [String: String] = ["Exposure": "Exposure2012", "Brightness": "Exposure2012", "Contrast": "Contrast2012",
            "Shadows": "Blacks2012", "FillLight": "Shadows2012", "Recovery": "Highlights2012", "Clarity": "Clarity2012"]
        for (key, modern) in legacy where values[key] != nil && values[modern] == nil { approximated.insert(key) }
        if !asShot {
            if values["Temperature"] != nil && values["IncrementalTemperature"] == nil { approximated.insert("Temperature") }
            if values["Tint"] != nil && values["IncrementalTint"] == nil { approximated.insert("Tint") }
        }
        for key in ["ParametricShadows", "ParametricDarks", "ParametricLights", "ParametricHighlights"]
            where (values[key] ?? 0) != 0 { approximated.insert(key) }
        for key in XMPPresetSnapshot.geometry.keys where values[key] != nil && values[key] != (key == "PerspectiveScale" ? 100 : 0) {
            approximated.insert(key)
        }

        let name = (delegate.name ?? delegate.fields["Name"] ?? fallbackName).trimmingCharacters(in: .whitespacesAndNewlines)
        return XMPPresetSnapshot(name: name.isEmpty ? "Imported XMP" : String(name.prefix(200)),
                                 values: values, curves: curves, unsupported: unsupported.sorted(),
                                 whiteBalance: wb, sourceKeys: delegate.keys.sorted(), approximated: approximated.sorted())
    }
}

/// Only the outer RDF description is read. Embedded Look/Profile descriptions must never
/// overwrite the preset name or settings. Namespace URIs, rather than fixed prefixes, identify CRS.
private final class XMPReader: NSObject, XMLParserDelegate {
    static let crs = "http://ns.adobe.com/camera-raw-settings/1.0/"
    static let rdf = "http://www.w3.org/1999/02/22-rdf-syntax-ns#"
    var fields: [String: String] = [:], lists: [String: [String]] = [:]
    var keys = Set<String>()
    var name: String?
    var invalid = false
    private var path: [(uri: String, name: String)] = []
    private var texts: [String] = []
    private var prefixes: [String: [String]] = [:]
    private var rootDepth: Int?
    private var defaultName = false
    private var itemIsDefault = false

    func parser(_ parser: XMLParser, didStartMappingPrefix prefix: String, toURI namespaceURI: String) {
        prefixes[prefix, default: []].append(namespaceURI)
    }
    func parser(_ parser: XMLParser, didEndMappingPrefix prefix: String) { _ = prefixes[prefix]?.popLast() }
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String]) {
        let parent = path.last
        path.append((namespaceURI ?? "", elementName)); texts.append("")
        if path.count > 32 { invalid = true; parser.abortParsing(); return }
        if namespaceURI == Self.rdf && elementName == "Description" && parent?.uri == Self.rdf && parent?.name == "RDF" {
            rootDepth = path.count
            for (key, value) in attributes {
                let parts = key.split(separator: ":", maxSplits: 1).map(String.init)
                if parts.count == 2, prefixes[parts[0]]?.last == Self.crs {
                    keys.insert(parts[1]); fields[parts[1]] = value
                }
            }
        }
        if let depth = rootDepth, path.count == depth + 1, namespaceURI == Self.crs { keys.insert(elementName) }
        if namespaceURI == Self.rdf && elementName == "li" { itemIsDefault = attributes["xml:lang"] == "x-default" }
    }
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if !texts.isEmpty { texts[texts.count - 1] += string }
    }
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName: String?) {
        guard let text = texts.popLast() else { return }
        if let depth = rootDepth {
            if path.count == depth + 1, namespaceURI == Self.crs, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                fields[elementName] = text
            }
            if path.count == depth + 3, namespaceURI == Self.rdf, elementName == "li", path[depth].uri == Self.crs {
                let key = path[depth].name
                if key == "Name", !defaultName {
                    name = text; defaultName = itemIsDefault
                } else if XMPPresetSnapshot.curveKeys[key] != nil { lists[key, default: []].append(text) }
            }
            if path.count == depth { rootDepth = nil }
        }
        path.removeLast()
    }
    func parser(_ parser: XMLParser, foundInternalEntityDeclarationWithName name: String, value: String?) {
        invalid = true; parser.abortParsing()
    }
    func parser(_ parser: XMLParser, foundExternalEntityDeclarationWithName name: String, publicID: String?, systemID: String?) {
        invalid = true; parser.abortParsing()
    }
}


struct XMPImportReport: Codable, Sendable, Equatable {
    var unsupported: [String]
    var approximated: [String]
}

extension XMPPresetSnapshot {
    func makePreset() -> Preset {
        let state = editState
        let keys = Set(sourceKeys ?? Array(values.keys))
        var sections: Set<PresetSection> = []
        if keys.contains(where: { Self.adjustments[$0].map { Adjustment.light.contains($0) } ?? false }) ||
            !keys.isDisjoint(with: ["Exposure", "Contrast", "Shadows", "FillLight", "Recovery"]) { sections.insert(.light) }
        if keys.contains(where: { Self.adjustments[$0].map { Adjustment.color.contains($0) } ?? false }) ||
            !keys.isDisjoint(with: ["Temperature", "Tint"]) { sections.insert(.color) }
        if !keys.isDisjoint(with: Self.curveKeys.keys) || keys.contains("Brightness") ||
            keys.contains(where: { $0.hasPrefix("Parametric") }) || !curves.isIdentity { sections.insert(.curves) }
        if keys.contains(where: { $0.hasPrefix("HueAdjustment") || $0.hasPrefix("SaturationAdjustment") || $0.hasPrefix("LuminanceAdjustment") }) { sections.insert(.mixer) }
        if keys.contains(where: { $0.hasPrefix("ColorGrade") || $0.hasPrefix("SplitToning") }) { sections.insert(.grading) }
        if !keys.isDisjoint(with: ["Texture", "Clarity", "Clarity2012", "Dehaze", "PostCropVignetteAmount", "GrainAmount", "GrainSize", "GrainFrequency"]) { sections.insert(.effects) }
        if keys.contains(where: { $0.hasPrefix("Sharpen") || $0 == "Sharpness" || $0.hasPrefix("Luminance") && !$0.hasPrefix("LuminanceAdjustment") || $0.hasPrefix("ColorNoise") }) { sections.insert(.detail) }
        // Identity geometry tags are ubiquitous in presets; do not reset the user's crop for them.
        if !state.geometry.isIdentity { sections.insert(.geometry) }
        var preset = Preset(name: name, sections: sections, values: state)
        preset.xmpImport = XMPImportReport(unsupported: unsupported, approximated: approximated ?? [])
        return preset
    }
}
