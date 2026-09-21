import Testing
import Foundation
import CoreImage
import Metal
@testable import LumoraCore

private func pixels(_ image: CIImage) throws -> [Float] {
    let device = try #require(MTLCreateSystemDefaultDevice())
    let space = try #require(CGColorSpace(name: CGColorSpace.extendedLinearSRGB))
    let context = CIContext(mtlDevice: device, options: [.workingColorSpace: space])
    let bounds = image.extent
    var data = [Float](repeating: 0, count: Int(bounds.width * bounds.height) * 4)
    data.withUnsafeMutableBytes { context.render(image, toBitmap: $0.baseAddress!, rowBytes: Int(bounds.width)*16, bounds: bounds, format: .RGBAf, colorSpace: space) }
    return data
}
private func patch(_ value: CGFloat = 0.25, size: Int = 256) -> CIImage {
    CIImage(color: CIColor(red: value, green: value, blue: value)).cropped(to: CGRect(x: 0, y: 0, width: size, height: size))
}
@Test func creativePersistenceHistoryAndStack() throws {
    let old = try JSONDecoder().decode(EditState.self, from: Data("{}".utf8))
    #expect(old.creative.effects.isEmpty)
    var state = old
    let effect = CreativeEffect(.highKey)
    state.creative.effects = [effect, CreativeEffect(.grain)]
    state.creative.duplicate(effect.id)
    #expect(Set(state.creative.effects.map(\.id)).count == 3)
    state.creative.move(effect.id, by: 2)
    #expect(state.creative.effects.last?.id == effect.id)
    state = state.validated
    #expect(try JSONDecoder().decode(EditState.self, from: JSONEncoder().encode(state)) == state)
    var history = HistoryManager(); history.begin("FX", state: old); history.commit(state)
    #expect(history.undo() == old); #expect(history.redo() == state)
    let mask = LocalMask(name: "Zone", components: [MaskComponent(shape: .radial(RadialGradientMask()))])
    state.masks = [mask]; state.creative.effects[0].maskID = mask.id
    let portable = Preset(name: "FX", sections: [.creative], values: state).applying(to: old)
    #expect(portable.creative.effects[0].maskID == nil)
    let complete = Preset(name: "FX + zone", sections: [.creative, .masks], values: state).applying(to: old)
    #expect(complete.creative.effects[0].maskID == complete.masks[0].id)
}

@Test func creativeBuiltInPresetsCoverEveryEffectAndPreserveStackContext() {
    for kind in CreativeEffectKind.allCases {
        let presets = CreativeFXPreset.all(for: kind)
        #expect(!presets.isEmpty)
        #expect(Set(presets.map(\.id)).count == presets.count)
        let maskID = UUID()
        var current = CreativeEffect(kind, maskID: maskID)
        current.opacity = 42
        current.enabled = false
        for spec in kind.descriptor.parameters { current[spec.id] = spec.range.upperBound }
        let applied = presets[0].applying(to: current)
        #expect(applied.id == current.id)
        #expect(applied.maskID == maskID)
        #expect(applied.opacity == 42)
        #expect(!applied.enabled)
        #expect(presets[0].matches(applied))
        #expect(presets[0].makeEffect(maskID: maskID).maskID == maskID)
        let other = CreativeEffect(kind == .highKey ? .lowKey : .highKey)
        #expect(presets[0].applying(to: other) == other)
    }
    let glow = CreativeFXPreset.all(for: .highKey).last!
    let ordinary = CreativeFXPreset.all(for: .highKey).first!
    #expect(glow.makeEffect()["glow"] > 0)
    #expect(ordinary.applying(to: glow.makeEffect())["glow"] == 0)
}

@Test func tonalContrastPersistencePresetHistoryAndValidation() throws {
    var effect = TonalContrastProfile.naturalTexture.applying(to: CreativeEffect(.tonalContrast))
    effect["shadows"] = -35
    effect["radius"] = 88
    var state = EditState()
    state.creative.effects = [effect]
    let encoded = try JSONEncoder().encode(state)
    let decoded = try JSONDecoder().decode(EditState.self, from: encoded)
    #expect(decoded == state.validated)
    let settings = TonalContrastSettings(effect: effect)
    #expect(try JSONDecoder().decode(TonalContrastSettings.self, from: JSONEncoder().encode(settings)) == settings)
    var history = HistoryManager()
    let original = EditState()
    history.begin("Tonal Contrast", state: original)
    history.commit(state)
    #expect(history.undo() == original)
    #expect(history.redo() == state)
    let preset = Preset(name: "Texture", sections: [.creative], values: state)
    #expect(preset.applying(to: original).creative.effects.first?.kind == .tonalContrast)
    effect["radius"] = .infinity
    #expect(effect["radius"] == 45)
}

@Test func detailExtractorIdentityPersistenceAndStackIntegration() throws {
    var effect = DetailExtractorProfile.naturalDetail.applying(to: CreativeEffect(.detailExtractor))
    let input = patch(size: 128)
    effect["amount"] = 0
    #expect(try pixels(CreativeStackRenderer.apply(input, stack: .init(effects: [effect]), masks: [])) == pixels(input))
    effect["amount"] = 70
    let output = try pixels(CreativeStackRenderer.apply(input, stack: .init(effects: [effect]), masks: []))
    #expect(output.allSatisfy { $0.isFinite })
    var state = EditState(); state.creative.effects = [effect]
    let roundTrip = try JSONDecoder().decode(EditState.self, from: JSONEncoder().encode(state))
    #expect(roundTrip == state.validated)
    let settings = DetailExtractorSettings(effect: effect)
    #expect(try JSONDecoder().decode(DetailExtractorSettings.self, from: JSONEncoder().encode(settings)) == settings)
    var history = HistoryManager(); history.begin("Detail Extractor", state: EditState()); history.commit(state)
    #expect(history.undo() == EditState()); #expect(history.redo() == state)
    let preset = Preset(name: "Détails", sections: [.creative], values: state)
    #expect(preset.applying(to: EditState()).creative.effects.first?.kind == .detailExtractor)
    effect["fine"] = .infinity
    #expect(effect["fine"] == 40)
}
@Test func creativeKeyDirectionProtectionAndIdentity() throws {
    for kind in [CreativeEffectKind.highKey, .lowKey] {
        var fx = CreativeEffect(kind); fx["amount"] = 100
        let renderer = KeyEffectRenderer(high: kind == .highKey)
        let original = try pixels(patch())
        let changed = try pixels(renderer.apply(patch(), effect: fx))
        #expect(kind == .highKey ? changed[0] > original[0] : changed[0] < original[0])
        #expect(abs(changed[0]-changed[1]) < 0.0001)
        for endpoint in [CGFloat(0), CGFloat(1)] {
            let result = try pixels(renderer.apply(patch(endpoint), effect: fx))
            #expect(abs(result[0]-Float(endpoint)) < 0.001)
        }
        fx["amount"] = 0
        #expect(try pixels(renderer.apply(patch(), effect: fx)) == original)
        fx["amount"] = 100; fx["glow"] = 50
        #expect(try pixels(renderer.apply(patch(0.8), effect: fx)).allSatisfy { $0.isFinite })
    }
}
@Test func creativeGrainDeterminismSeedAndTileCoordinates() throws {
    let input = patch(size: 512)
    var settings = FilmGrainSettings(); settings.amount = 90
    let grain = try FilmGrainEngine.apply(input, settings: settings)
    let a = try pixels(grain)
    #expect(a == (try pixels(FilmGrainEngine.apply(input, settings: settings))))
    settings.seed += 1
    #expect(a != (try pixels(FilmGrainEngine.apply(input, settings: settings))))
    #expect(a.allSatisfy { $0.isFinite })
    let roi = CGRect(x: 100, y: 100, width: 32, height: 32)
    let tile = try pixels(grain.cropped(to: roi))
    // CI bitmap rows run from top to bottom; Core Image regions use lower-left coordinates.
    for y in 0..<32 { for x in 0..<32 {
        #expect(abs(tile[(y*32+x)*4] - a[((y+380)*512+x+100)*4]) < 0.0001)
    } }
    settings.amount = 0
    #expect(try pixels(FilmGrainEngine.apply(input, settings: settings)) == pixels(input))
}
@Test func creativeStackOrderBypassAndExistingMask() throws {
    let input = patch()
    var high = CreativeEffect(.highKey); high["amount"] = 100
    var low = CreativeEffect(.lowKey); low["amount"] = 100
    let forward = try pixels(CreativeStackRenderer.apply(input, stack: .init(effects: [high,low]), masks: []))
    let reverse = try pixels(CreativeStackRenderer.apply(input, stack: .init(effects: [low,high]), masks: []))
    #expect(forward != reverse)
    high.opacity = 0
    #expect(try pixels(CreativeStackRenderer.apply(input, stack: .init(effects: [high]), masks: [])) == pixels(input))
    high.opacity = 100; high.maskID = UUID()
    #expect(try pixels(CreativeStackRenderer.apply(input, stack: .init(effects: [high]), masks: [])) == pixels(input))
    let mask = LocalMask(name: "Zone", components: [MaskComponent(shape: .radial(RadialGradientMask()))])
    high.maskID = mask.id
    let masked = try pixels(CreativeStackRenderer.apply(input, stack: .init(effects: [high]), masks: [mask]))
    #expect(masked[(128*256+128)*4] > masked[0])
}

@Test func creativeGrainPhotographicScaleEnergyAndChroma() throws {
    var settings = FilmGrainSettings()
    settings.amount = 100; settings.size = 100; settings.hardness = 0; settings.softness = 0
    let small = try pixels(FilmGrainEngine.apply(patch(size: 256), settings: settings))
    let large = try pixels(FilmGrainEngine.apply(patch(size: 512), settings: settings))
    let baseline = Double(try pixels(patch())[0])
    var xy = 0.0, xx = 0.0, yy = 0.0, mean = 0.0
    for y in 0..<256 { for x in 0..<256 {
        let a = Double(small[(y*256+x)*4]) - baseline
        let b = (Double(large[((y*2)*512+x*2)*4]) + Double(large[((y*2)*512+x*2+1)*4]) + Double(large[((y*2+1)*512+x*2)*4]) + Double(large[((y*2+1)*512+x*2+1)*4])) / 4 - baseline
        xy += a*b; xx += a*a; yy += b*b; mean += a
    } }
    // Cell placement should survive resolution changes, even with different footprint attenuation.
    #expect(xy / sqrt(xx*yy) > 0.8)
    #expect(abs(mean / 65536) < 0.002)
    #expect(abs(small[100] - small[101]) < 0.00001)
    settings.monochromatic = false; settings.chromaAmount = 100
    let color = try pixels(FilmGrainEngine.apply(patch(), settings: settings))
    #expect(abs(color[100]-color[101]) > 0.000001)
}

@Test func creativeKeyRampIsContinuousAndOrdered() throws {
    let ramp = CIFilter(name: "CILinearGradient", parameters: ["inputPoint0": CIVector(x: 0, y: 0), "inputPoint1": CIVector(x: 1024, y: 0), "inputColor0": CIColor(red: 0, green: 0, blue: 0), "inputColor1": CIColor(red: 1, green: 1, blue: 1)])!.outputImage!.cropped(to: CGRect(x: 0, y: 0, width: 1024, height: 1))
    for high in [true, false] {
        var effect = CreativeEffect(high ? .highKey : .lowKey); effect["amount"] = 100
        let result = try pixels(KeyEffectRenderer(high: high).apply(ramp, effect: effect))
        var largestJump: Float = 0
        var monotonic = true
        for x in 1..<1024 {
            let delta = result[x*4] - result[(x-1)*4]
            largestJump = max(largestJump, abs(delta)); monotonic = monotonic && delta >= -0.00001
        }
        #expect(monotonic); #expect(largestJump < 0.02)
    }
}
