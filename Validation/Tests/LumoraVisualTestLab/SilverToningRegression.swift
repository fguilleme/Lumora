import Foundation
import CoreImage
import Testing
@testable import LumoraCore

/// Temporary reference buffers against pre-toning HEAD, never Golden Masters.
@Test func silverToningExistingEffectsRegression() throws {
    guard let mode=ProcessInfo.processInfo.environment["LUMORA_TONING_REGRESSION"] else {return}
    let root=URL(fileURLWithPath:"/private/tmp/lumora-toning-reference-8e2ad94")
    try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
    let gpu=try LabGPU(),source=SilverBWTestChart.generate(size:128).image
    let kinds:[CreativeEffectKind]=[.silverBW,.grain,.filmEmulation,.crossProcessing,.bleachBypass,.glamourGlow,.proContrast,.tonalContrast,.detailExtractor,.highKey,.lowKey]
    var results:[String:Double]=[:]
    for kind in kinds {for (index,preset) in CreativeFXPreset.all(for:kind).enumerated() {
        var fx=preset.makeEffect();fx.seed=12345
        let output=try CreativeStackRenderer.apply(source,stack:.init(effects:[fx]),masks:[])
        let pixels=gpu.read(output,source.extent),data=pixels.withUnsafeBytes{Data($0)}
        let key=kind.rawValue+"-\(index)",file=root.appendingPathComponent(key+".rgba32f")
        if mode=="record" {try data.write(to:file)} else {
            let reference=try Data(contentsOf:file)
            #expect(reference==data,"Existing preset changed: \(key)")
            results[key]=reference==data ? 0:1
        }
    }}
    if mode != "record" {
        let repo=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let out=repo.appendingPathComponent("Validation/TestArtifacts/SilverToning")
        try FileManager.default.createDirectory(at:out,withIntermediateDirectories:true)
        try JSONEncoder().encode(results).write(to:out.appendingPathComponent("existing_effects_regression.json"))
    }
}
