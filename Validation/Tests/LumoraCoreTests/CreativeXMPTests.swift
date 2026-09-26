import Testing
import Foundation
import CoreImage
@testable import LumoraCore

struct CreativeXMPTests {
    private func xml(_ attributes: String = "", body: String = "") -> Data {
        Data("""
        <x:xmpmeta xmlns:x="adobe:ns:meta/"><r:RDF xmlns:r="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
        <r:Description xmlns:c="http://ns.adobe.com/camera-raw-settings/1.0/" \(attributes)>\(body)</r:Description>
        </r:RDF></x:xmpmeta>
        """.utf8)
    }

    @Test func vintageFixture() throws {
        let preset = try XMPPresetImporter.parse(Data(Self.vintage.utf8), fallbackName: "fallback")
        #expect(preset.name == "Vintage Classic one")
        let state = preset.editState
        #expect(state.exposure == 1.64)
        #expect(state.highlights == -70)
        #expect(state.shadows == 62)
        #expect(state.effects.clarity == -41)
        #expect(state.colorMixer[.red].saturation == -27)
        #expect(state.curves.rgb.points.count == 5)
        #expect(state.curves.green.points.count == 6)
        #expect(state.curves.rgb.points[0].y == 9.0 / 255)
        #expect(state.colorGrading.midtones.hue == 280)
        #expect(state.detail.sharpening.amount == 40)
        #expect(preset.grain.amount == 42)
        #expect(preset.grain.size == 12)
        #expect(preset.unsupported.contains("Look"))
        #expect(!preset.unsupported.contains("ColorGradeGlobalSat"))
        #expect(state.colorGrading.global.saturation == 10)
        #expect(state.creative.effects.isEmpty)
    }

    @Test func namespacesElementsAndNestedProfile() throws {
        let data = xml(body: """
        <c:Exposure2012>+1.2</c:Exposure2012>
        <c:Name><r:Alt><r:li xml:lang="fr">Traduit</r:li><r:li xml:lang="x-default">Original</r:li></r:Alt></c:Name>
        <c:Look><r:Description c:Name="Adobe Color" c:Exposure2012="5"/></c:Look>
        """)
        let preset = try XMPPresetImporter.parse(data, fallbackName: "fallback")
        #expect(preset.name == "Original")
        #expect(preset.editState.exposure == 1.2)
        #expect(try XMPPresetImporter.parse(xml("c:Exposure2012=\"99\""), fallbackName: "Filename").editState.exposure == 5)
    }

    @Test func malformedAndUnsupportedFiles() {
        for data in [Data("<broken>".utf8), xml("c:Exposure2012=\"NaN\""),
                     xml("c:Exposure2012=\"infinity\""), xml("c:Exposure2012=\"text\""),
                     xml("c:Name=\"Nik proprietary recipe\""),
                     xml(body: "<c:ToneCurvePV2012><r:Seq><r:li>0, 0</r:li><r:li>bad</r:li></r:Seq></c:ToneCurvePV2012>"),
                     Data(repeating: 32, count: XMPPresetImporter.maximumBytes + 1),
                     Data("<!DOCTYPE x [<!ENTITY e '1'>]><x>&e;</x>".utf8)] {
            #expect(throws: (any Error).self) { try XMPPresetImporter.parse(data, fallbackName: "Test") }
        }
        let wrongNamespace = Data(String(decoding: xml("c:Exposure2012=\"1\""), as: UTF8.self)
            .replacingOccurrences(of: "http://ns.adobe.com/camera-raw-settings/1.0/", with: "urn:unrelated").utf8)
        #expect(throws: (any Error).self) { try XMPPresetImporter.parse(wrongNamespace, fallbackName: "Test") }
    }

    @Test func vintageRenderingIsFiniteAndVisible() throws {
        let preset = try XMPPresetImporter.parse(Data(Self.vintage.utf8), fallbackName: "Vintage")
        let input = CIImage(color: CIColor(red: 0.25, green: 0.18, blue: 0.1))
            .cropped(to: CGRect(x: 0, y: 0, width: 64, height: 64))
        let output = try CreativeStackRenderer.apply(input, stack: .init(effects: [preset.makeEffect()]), masks: [])
        #expect(output.extent == input.extent)
        let space = try #require(CGColorSpace(name: CGColorSpace.extendedLinearSRGB))
        let context = CIContext(options: [.workingColorSpace: space])
        func pixels(_ image: CIImage) -> [Float] {
            var data = [Float](repeating: 0, count: 64 * 64 * 4)
            data.withUnsafeMutableBytes {
                context.render(image, toBitmap: $0.baseAddress!, rowBytes: 64 * 16,
                               bounds: image.extent, format: .RGBAf, colorSpace: space)
            }
            return data
        }
        let before = pixels(input), after = pixels(output)
        #expect(after.allSatisfy { $0.isFinite })
        let distance = zip(before, after).reduce(0.0) { $0 + Double(abs($1.0 - $1.1)) } / Double(after.count)
        #expect(distance > 0.01)
    }

    @Test func nativePresetImportStoreAndApplication() async throws {
        let root = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("Vintage.XMP")
        try Data(Self.vintage.utf8).write(to: url)
        let store = PresetStore(root: root.appendingPathComponent("Presets"))
        let preset = try await store.importPreset(from: url)
        #expect(preset.name == "Vintage Classic one")
        #expect(!preset.sections.contains(.creative))
        #expect(preset.values.creative.effects.isEmpty)
        #expect(preset.values.effects.grain == 42)
        #expect(preset.values.effects.grainSettings.size == 12)
        #expect(preset.values.effects.grainSettings.irregularity == 19)
        #expect(preset.values.colorGrading.global.hue == 210)
        #expect(try await store.load() == [preset])
        var current = EditState()
        current.creative.effects = [CreativeEffect(.grain)]
        current.geometry.cropZoom = 25
        let applied = preset.applying(to: current)
        #expect(applied.exposure == 1.64)
        #expect(applied.creative == current.creative.validated)
        #expect(preset.applying(to: applied) == applied)
        #expect(applied.geometry == current.geometry)
        let decoded = try JSONDecoder().decode(Preset.self, from: JSONEncoder().encode(preset))
        #expect(decoded == preset)
        #expect(decoded.xmpImport?.unsupported.contains("Look") == true)
        var history = HistoryManager(); history.begin("Preset", state: current); history.commit(applied)
        #expect(history.undo() == current)
        #expect(history.redo() == applied)
    }

    @Test func legacySettingsAndModernPrecedence() throws {
        let old = try XMPPresetImporter.parse(xml("c:Exposure=\"1.2\" c:Brightness=\"75\" c:Contrast=\"40\" c:Shadows=\"20\" c:FillLight=\"30\" c:Recovery=\"50\" c:Clarity=\"12\""), fallbackName: "Old")
        #expect(old.editState.exposure == 1.2)
        #expect(old.editState.contrast == 15)
        #expect(old.editState.blacks == -15)
        #expect(old.editState.shadows == 30)
        #expect(old.editState.highlights == -50)
        #expect(old.editState.effects.clarity == 12)
        #expect(old.editState.curves.rgb.evaluate(0.5) > 0.5)
        #expect(old.unsupported.isEmpty)
        #expect(old.approximated?.contains("Brightness") == true)
        let modern = try XMPPresetImporter.parse(xml("c:Exposure=\"2\" c:Exposure2012=\"0.1\" c:Brightness=\"75\" c:Contrast=\"40\" c:Contrast2012=\"0\" c:Shadows=\"20\" c:Blacks2012=\"0\""), fallbackName: "Modern")
        #expect(modern.editState.exposure == 0.1)
        #expect(modern.editState.contrast == 0)
        #expect(modern.editState.blacks == 0)
        #expect(modern.editState.curves.isIdentity)
    }

    @Test func inactiveOptionsDoNotBecomeMissingSettings() throws {
        let preset = try XMPPresetImporter.parse(xml("c:Exposure2012=\"0\" c:PerspectiveScale=\"100\" c:PerspectiveRotate=\"0.0\" c:PerspectiveX=\"+0.000\" c:PerspectiveY=\"0\" c:DefringeGreenHueLo=\"40\" c:DefringeGreenHueHi=\"60\" c:DefringeGreenAmount=\"0.0\" c:CameraProfileDigest=\"ABCDEF\" c:WhiteBalance=\"As Shot\" c:RedHue=\"+0.000\" c:CameraProfile=\"Adobe Standard\""), fallbackName: "Report")
        #expect(preset.unsupported == ["CameraProfile"])
        #expect(!preset.makePreset().sections.contains(.geometry))
        let active = try XMPPresetImporter.parse(xml("c:Exposure2012=\"0\" c:DefringeGreenAmount=\"5\" c:DefringeGreenHueLo=\"40\""), fallbackName: "Active")
        #expect(active.unsupported.contains("DefringeGreenAmount"))
    }

    @Test func whiteBalanceGeometryAndLegacyCurves() throws {
        let preset = try XMPPresetImporter.parse(xml("c:WhiteBalance=\"Custom\" c:Temperature=\"7200\" c:Tint=\"12\" c:PerspectiveRotate=\"2\" c:PerspectiveScale=\"110\" c:PerspectiveX=\"8\"", body: "<c:ToneCurve><r:Seq><r:li>0, 0</r:li><r:li>128, 150</r:li><r:li>255, 255</r:li></r:Seq></c:ToneCurve>"), fallbackName: "WB")
        #expect(preset.editState.temperature == 20)
        #expect(preset.editState.tint == 20)
        #expect(preset.editState.geometry.straighten == 2)
        #expect(preset.editState.geometry.perspectiveScale == 110)
        #expect(preset.editState.geometry.perspectiveOffsetX == 8)
        #expect(preset.editState.curves.rgb.points.count == 3)
        #expect(preset.unsupported.isEmpty)
        #expect(preset.makePreset().sections.contains(.geometry))
        let asShot = try XMPPresetImporter.parse(xml("c:WhiteBalance=\"As Shot\" c:Temperature=\"7200\" c:Tint=\"12\""), fallbackName: "As Shot")
        #expect(asShot.editState.temperature == 0 && asShot.editState.tint == 0)
    }

    @Test func globalGradingMigrationAndResponse() throws {
        let old = try JSONDecoder().decode(ColorGrading.self, from: Data("{}".utf8))
        #expect(old.global == GradingWheel())
        var settings = old; settings.global = GradingWheel(hue: 210, saturation: 30, luminance: 10)
        #expect(!settings.isIdentity)
        let transformed = GradingTransform(settings).apply(0.4, 0.4, 0.4)
        #expect(transformed.2 > transformed.0)
        #expect(try JSONDecoder().decode(ColorGrading.self, from: JSONEncoder().encode(settings)) == settings)
        #expect(try JSONDecoder().decode(EffectsSettings.self,
            from: Data("{\"texture\":0,\"clarity\":0,\"dehaze\":0,\"vignette\":0,\"grain\":25}".utf8)).grainSettings.size == 35)
    }

    @Test func persistenceAndHistory() throws {
        let imported = try XMPPresetImporter.parse(Data(Self.vintage.utf8), fallbackName: "Vintage").makeEffect()
        var state = EditState(); state.exposure = -0.3
        let before = state
        state.creative.effects.append(imported)
        state = state.validated
        let decoded = try JSONDecoder().decode(EditState.self, from: JSONEncoder().encode(state))
        #expect(decoded == state)
        #expect(decoded.exposure == -0.3)
        #expect(decoded.creative.effects[0].importedXMP?.name == "Vintage Classic one")
        var history = HistoryManager(); history.begin("Import XMP", state: before); history.commit(state)
        #expect(history.undo() == before)
        #expect(history.redo() == state)
        state.creative.duplicate(imported.id)
        #expect(state.creative.effects.count == 2)
        #expect(state.creative.effects[0].importedXMP == state.creative.effects[1].importedXMP)
        #expect(state.creative.effects[0].id != state.creative.effects[1].id)
    }

    @Test func renderingOpacityBypassAndMissingMask() throws {
        let input = CIImage(color: CIColor(red: 0.2, green: 0.2, blue: 0.2)).cropped(to: CGRect(x: 0, y: 0, width: 8, height: 8))
        var effect = try XMPPresetImporter.parse(xml("c:Exposure2012=\"1\""), fallbackName: "Exposure").makeEffect()
        let context = CIContext(options: [.workingColorSpace: CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!])
        func pixel(_ image: CIImage) -> Float {
            var rgba = [Float](repeating: 0, count: 4)
            rgba.withUnsafeMutableBytes {
                context.render(image, toBitmap: $0.baseAddress!, rowBytes: 16, bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                               format: .RGBAf, colorSpace: CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!)
            }
            return rgba[0]
        }
        func render() throws -> Float {
            let output = try CreativeStackRenderer.apply(input, stack: CreativeEffectStack(effects: [effect]), masks: [])
            #expect(output.extent == input.extent)
            return pixel(output)
        }
        let base = pixel(input)
        #expect(abs(try render() - 2 * base) < 0.005)
        effect.opacity = 50
        #expect(abs(try render() - 1.5 * base) < 0.005)
        effect.opacity = 0
        #expect(abs(try render() - base) < 0.005)
        effect.opacity = 100; effect.enabled = false
        #expect(abs(try render() - base) < 0.005)
        effect.enabled = true; effect.maskID = UUID()
        #expect(abs(try render() - base) < 0.005)
    }
}

private extension CreativeXMPTests {
    static let vintage = """
<x:xmpmeta xmlns:x="adobe:ns:meta/" x:xmptk="Adobe XMP Core 7.0-c000 1.000000, 0000/00/00-00:00:00        ">
 <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
  <rdf:Description rdf:about=""
    xmlns:crs="http://ns.adobe.com/camera-raw-settings/1.0/"
   crs:PresetType="Normal"
   crs:Cluster=""
   crs:UUID="3DB30E8DEF664F55841D37AF07A271F2"
   crs:SupportsAmount2="True"
   crs:SupportsAmount="True"
   crs:SupportsColor="True"
   crs:SupportsMonochrome="True"
   crs:SupportsHighDynamicRange="True"
   crs:SupportsNormalDynamicRange="True"
   crs:SupportsSceneReferred="True"
   crs:SupportsOutputReferred="True"
   crs:RequiresRGBTables="False"
   crs:ShowInPresets="True"
   crs:ShowInQuickActions="False"
   crs:CameraModelRestriction=""
   crs:Copyright=""
   crs:ContactInfo=""
   crs:Version="18.5.1"
   crs:ProcessVersion="15.4"
   crs:WhiteBalance="As Shot"
   crs:IncrementalTemperature="0"
   crs:IncrementalTint="0"
   crs:Exposure2012="+1.64"
   crs:Contrast2012="+7"
   crs:Highlights2012="-70"
   crs:Shadows2012="+62"
   crs:Whites2012="-13"
   crs:Blacks2012="-50"
   crs:Texture="+19"
   crs:Clarity2012="-41"
   crs:Dehaze="+7"
   crs:Vibrance="0"
   crs:Saturation="-4"
   crs:ParametricShadows="0"
   crs:ParametricDarks="0"
   crs:ParametricLights="0"
   crs:ParametricHighlights="0"
   crs:ParametricShadowSplit="25"
   crs:ParametricMidtoneSplit="50"
   crs:ParametricHighlightSplit="75"
   crs:Sharpness="40"
   crs:SharpenRadius="+1.0"
   crs:SharpenDetail="25"
   crs:SharpenEdgeMasking="0"
   crs:LuminanceSmoothing="0"
   crs:ColorNoiseReduction="25"
   crs:ColorNoiseReductionDetail="50"
   crs:ColorNoiseReductionSmoothness="50"
   crs:HueAdjustmentRed="+1"
   crs:HueAdjustmentOrange="-1"
   crs:HueAdjustmentYellow="-1"
   crs:HueAdjustmentGreen="+1"
   crs:HueAdjustmentAqua="+5"
   crs:HueAdjustmentBlue="+1"
   crs:HueAdjustmentPurple="-10"
   crs:HueAdjustmentMagenta="+6"
   crs:SaturationAdjustmentRed="-27"
   crs:SaturationAdjustmentOrange="-20"
   crs:SaturationAdjustmentYellow="-10"
   crs:SaturationAdjustmentGreen="-20"
   crs:SaturationAdjustmentAqua="+8"
   crs:SaturationAdjustmentBlue="+9"
   crs:SaturationAdjustmentPurple="-15"
   crs:SaturationAdjustmentMagenta="-20"
   crs:LuminanceAdjustmentRed="-25"
   crs:LuminanceAdjustmentOrange="-10"
   crs:LuminanceAdjustmentYellow="0"
   crs:LuminanceAdjustmentGreen="0"
   crs:LuminanceAdjustmentAqua="0"
   crs:LuminanceAdjustmentBlue="-12"
   crs:LuminanceAdjustmentPurple="0"
   crs:LuminanceAdjustmentMagenta="0"
   crs:SplitToningShadowHue="107"
   crs:SplitToningShadowSaturation="5"
   crs:SplitToningHighlightHue="196"
   crs:SplitToningHighlightSaturation="2"
   crs:SplitToningBalance="0"
   crs:ColorGradeMidtoneHue="280"
   crs:ColorGradeMidtoneSat="21"
   crs:ColorGradeShadowLum="0"
   crs:ColorGradeMidtoneLum="0"
   crs:ColorGradeHighlightLum="0"
   crs:ColorGradeBlending="100"
   crs:ColorGradeGlobalHue="210"
   crs:ColorGradeGlobalSat="10"
   crs:ColorGradeGlobalLum="0"
   crs:GrainAmount="42"
   crs:GrainSize="12"
   crs:GrainFrequency="19"
   crs:PostCropVignetteAmount="0"
   crs:ShadowTint="0"
   crs:RedHue="0"
   crs:RedSaturation="0"
   crs:GreenHue="0"
   crs:GreenSaturation="0"
   crs:BlueHue="0"
   crs:BlueSaturation="0"
   crs:HDREditMode="0"
   crs:CurveRefineSaturation="100"
   crs:OverrideLookVignette="False"
   crs:ToneCurveName2012="Custom"
   crs:HasSettings="True">
   <crs:Name>
    <rdf:Alt>
     <rdf:li xml:lang="x-default">Vintage Classic one</rdf:li>
    </rdf:Alt>
   </crs:Name>
   <crs:ShortName>
    <rdf:Alt>
     <rdf:li xml:lang="x-default"/>
    </rdf:Alt>
   </crs:ShortName>
   <crs:SortName>
    <rdf:Alt>
     <rdf:li xml:lang="x-default"/>
    </rdf:Alt>
   </crs:SortName>
   <crs:Group>
    <rdf:Alt>
     <rdf:li xml:lang="x-default"/>
    </rdf:Alt>
   </crs:Group>
   <crs:Description>
    <rdf:Alt>
     <rdf:li xml:lang="x-default"/>
    </rdf:Alt>
   </crs:Description>
   <crs:ToneCurvePV2012>
    <rdf:Seq>
     <rdf:li>0, 9</rdf:li>
     <rdf:li>49, 58</rdf:li>
     <rdf:li>100, 112</rdf:li>
     <rdf:li>177, 182</rdf:li>
     <rdf:li>255, 248</rdf:li>
    </rdf:Seq>
   </crs:ToneCurvePV2012>
   <crs:ToneCurvePV2012Red>
    <rdf:Seq>
     <rdf:li>0, 0</rdf:li>
     <rdf:li>255, 255</rdf:li>
    </rdf:Seq>
   </crs:ToneCurvePV2012Red>
   <crs:ToneCurvePV2012Green>
    <rdf:Seq>
     <rdf:li>0, 0</rdf:li>
     <rdf:li>28, 33</rdf:li>
     <rdf:li>71, 71</rdf:li>
     <rdf:li>101, 104</rdf:li>
     <rdf:li>165, 167</rdf:li>
     <rdf:li>255, 255</rdf:li>
    </rdf:Seq>
   </crs:ToneCurvePV2012Green>
   <crs:ToneCurvePV2012Blue>
    <rdf:Seq>
     <rdf:li>0, 0</rdf:li>
     <rdf:li>255, 255</rdf:li>
    </rdf:Seq>
   </crs:ToneCurvePV2012Blue>
   <crs:Look>
    <rdf:Description
     crs:Name="Adobe Color"
     crs:Amount="1"
     crs:UUID="B952C231111CD8E0ECCF14B86BAA7077"
     crs:SupportsAmount="false"
     crs:SupportsMonochrome="false"
     crs:SupportsOutputReferred="false"
     crs:Copyright="© 2018 Adobe Systems, Inc."
     crs:Stubbed="true">
    <crs:Group>
     <rdf:Alt>
      <rdf:li xml:lang="x-default">Profiles</rdf:li>
     </rdf:Alt>
    </crs:Group>
    </rdf:Description>
   </crs:Look>
  </rdf:Description>
 </rdf:RDF>
</x:xmpmeta>
"""
}
