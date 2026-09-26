import Foundation
import CoreImage
import ImageIO
import Testing
@testable import LumoraCore

private func integrationPixels(_ image: CGImage) -> [Float] {
    var data = [Float](repeating: 0, count: image.width * image.height * 4)
    let space = CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!
    CIContext().render(CIImage(cgImage: image), toBitmap: &data, rowBytes: image.width * 16,
                       bounds: CGRect(x: 0, y: 0, width: image.width, height: image.height),
                       format: .RGBAf, colorSpace: space)
    return data
}

/// Real photo -> production RenderEngine -> persisted settings -> image.
/// No Visual Test Lab or replacement renderer.
@Test func beautyMainProductionPhotoWiring() async throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let url = root.appendingPathComponent("BeautyValidation/Sources/08_open_smile_teeth.jpg")
    let engine = RenderEngine()
    let base = EditState()
    let neutral = try await engine.render(url: url, state: base, quality: .interactive)
    let a = integrationPixels(neutral.image)
    var rows = ["control,value,meanRGBDifference,maxRGBDifference"]
    for control in BeautyV2Control.productionCases {
        for value in (control == .faceBalance ? [100.0, -100.0] : [100.0]) {
            var edit = base
            var finishing = BeautyV2Settings(); finishing[control] = value
            edit.beauty.finishing = finishing
            let restored = try JSONDecoder().decode(EditState.self, from: JSONEncoder().encode(edit))
            #expect(restored.beauty.finishing?[control] == value)
            let result = try await engine.render(url: url, state: restored, quality: .interactive)
            let b = integrationPixels(result.image)
            let differences = zip(a,b).map { abs($0-$1) }
            let maxDelta = differences.max() ?? 0
            #expect(maxDelta > 0.00001, "No production response for \(control)")
            #expect(b.allSatisfy { $0.isFinite })
            rows.append("\(control.rawValue),\(value),\(differences.reduce(0,+)/Float(differences.count)),\(maxDelta)")
        }
    }
    var combined = base
    var values = BeautyV2Settings(); values.lipColor = 100; values.lipBrightness = 100
    combined.beauty.finishing = values
    let high = try await engine.render(url:url, state:combined, quality:.high)
    #expect(integrationPixels(high.image).allSatisfy { $0.isFinite })
    var options = ExportSettings(); options.format = .png; options.maximumDimension = 960
    let directory = root.appendingPathComponent("BeautyIntegration/Exports")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let exported = try await engine.export(request:.init(sourceURL:url,state:combined,name:"lips-production"),settings:options,directory:directory)
    let exportedSource = try #require(CGImageSourceCreateWithURL(exported.url as CFURL,nil))
    let exportedImage = try #require(CGImageSourceCreateImageAtIndex(exportedSource,0,nil))
    #expect(integrationPixels(exportedImage).allSatisfy { $0.isFinite })
    let exportedNeutral = try await engine.export(request:.init(sourceURL:url,state:base,name:"neutral"),settings:options,directory:directory)
    let neutralSource = try #require(CGImageSourceCreateWithURL(exportedNeutral.url as CFURL,nil))
    let neutralImage = try #require(CGImageSourceCreateImageAtIndex(neutralSource,0,nil))
    let exportDelta = zip(integrationPixels(exportedImage),integrationPixels(neutralImage)).map { abs($0-$1) }.max() ?? 0
    #expect(exportDelta > 0.00001)
    rows.append("combinedExport,100,not-computed,\(exportDelta)")
    try rows.joined(separator: "\n").write(to: root.appendingPathComponent("BeautyIntegration/render-wiring.csv"), atomically: true, encoding: .utf8)
}

@Test func beautyMainManualPersistenceAndRender() async throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let url = root.appendingPathComponent("BeautyValidation/Sources/03_acne_redness.jpg")
    let engine = RenderEngine()
    var edit = EditState()
    let data = try await engine.prepareManualHealing(url: url, state: edit)
    // Search eligible skin using the unchanged production proposer; no mask bypass.
    var proposal: HealingProposal?
    for y in [0.45,0.5,0.55,0.6,0.65] {
        for x in [0.4,0.45,0.5,0.55,0.6] where proposal == nil {
            proposal = try data.propose(at: .init(x:x,y:y), existing:[])
        }
    }
    let chosen = try #require(proposal)
    edit.beauty.corrections = [chosen.correction]
    var history = HistoryManager()
    history.begin("Zone", state: edit)
    var c = chosen.correction
    c.resizeTarget(to: c.targetRadius * 1.2); c.strength = 75
    c.sourceCenter.x += 0.01; c.manualSource = true
    c.targetStrokes = [.init(points:[c.targetCenter],radius:c.targetRadius*1.3,erase:false),
                       .init(points:[c.targetCenter],radius:c.targetRadius*0.25,erase:true)]
    edit.beauty.corrections = [c]; history.commit(edit)
    #expect(history.undo()?.beauty.corrections == [chosen.correction])
    #expect(history.redo()?.beauty.corrections == [c])
    let store = DocumentStore(root: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
    var doc = try await store.importPhoto(at: url); doc.state = edit
    try await store.save(doc, revision:1)
    let restored = try await store.load(doc.id)
    #expect(restored.state.beauty.corrections == [c.validated])
    let before = try await engine.render(url:url,state:edit,quality:.interactive)
    let after = try await engine.render(url:url,state:restored.state,quality:.interactive)
    #expect(integrationPixels(before.image) == integrationPixels(after.image))
    // Preserve a real production-created correction for Simulator persistence/UI validation.
    try JSONEncoder().encode(doc).write(to: root.appendingPathComponent("BeautyIntegration/manual-document.json"))
}

@Test func beautyMainHealingAutoCacheAndNeutralIdentity() async throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let url = root.appendingPathComponent("BeautyValidation/Sources/03_acne_redness.jpg")
    var state = EditState()
    state.coreImageAuto = .init(osVersion:"integration-test",filters:[])
    state.geometry.quarterTurns = 1
    state.geometry.cropZoom = 10
    let engine = RenderEngine()
    let a = try await engine.render(url:url,state:state,quality:.interactive)
    state.beauty.corrections = [.init(targetCenter:.init(x:0.5,y:0.5),targetRadius:0.02,sourceCenter:.init(x:0.55,y:0.5))]
    state.beauty.amount = 0
    let neutral = try await engine.render(url:url,state:state,quality:.interactive)
    #expect(integrationPixels(a.image) == integrationPixels(neutral.image))
    state.beauty.amount = 100
    let changed = try await engine.render(url:url,state:state,quality:.interactive)
    #expect(integrationPixels(changed.image) != integrationPixels(neutral.image))
    #expect(integrationPixels(changed.image).allSatisfy { $0.isFinite })
    let repeated = try await engine.render(url:url,state:state,quality:.interactive)
    #expect(integrationPixels(changed.image) == integrationPixels(repeated.image))
}
