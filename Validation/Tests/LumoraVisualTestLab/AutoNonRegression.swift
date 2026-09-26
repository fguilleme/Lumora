import Foundation
import CoreImage
import Testing
@testable import LumoraCore

@Test func autoManualAndCreativeNonRegression() async throws {
    guard let mode=ProcessInfo.processInfo.environment["LUMORA_AUTO_REGRESSION"] else {return}
    let root=URL(fileURLWithPath:"/private/tmp/lumora-auto-reference-89c7e73")
    try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
    let gpu=try LabGPU(),source=SilverBWTestChart.generate(size:128).image
    let chart=root.appendingPathComponent("input.tiff")
    try gpu.context.writeTIFFRepresentation(of:source,to:chart,format:.RGBAh,colorSpace:gpu.linear,options:[:])
    var results:[String:Bool]=[:]
    func compare(_ pixels:[Float],_ key:String) throws {
        let data=pixels.withUnsafeBytes{Data($0)},file=root.appendingPathComponent(key+".rgba32f")
        if mode=="record" {try data.write(to:file)}
        else {let equal=try Data(contentsOf:file)==data;results[key]=equal;#expect(equal,"Non-regression \(key)")}
    }
    for kind in CreativeEffectKind.allCases {
        for (index,preset) in CreativeFXPreset.all(for:kind).enumerated() {
            var effect=preset.makeEffect();effect.seed=12345
            let output=try CreativeStackRenderer.apply(source,stack:.init(effects:[effect]),masks:[])
            try compare(gpu.read(output,source.extent),"creative-\(kind.rawValue)-\(index)")
        }
    }
    let engine=RenderEngine()
    var manual:[EditState]=[EditState()]
    for adjustment in Adjustment.allCases {
        for direction in [-1.0,1.0] {var s=EditState();s[adjustment]=direction*(adjustment == .exposure ? 1.2:25);manual.append(s)}
    }
    for channel in CurveChannel.allCases {
        var s=EditState();s.curves[channel]=ToneCurve(points:[.init(x:0,y:0.05),.init(x:0.3,y:0.2),.init(x:0.7,y:0.82),.init(x:1,y:0.95)]);manual.append(s)
    }
    for (index,state) in manual.enumerated() {
        let rendered=try await engine.render(url:chart,state:state,quality:.high)
        let image=CIImage(cgImage:rendered.image)
        try compare(gpu.read(image,image.extent),"manual-\(index)")
    }
    if mode != "record" {
        let repo=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let output=repo.appendingPathComponent("Validation/TestArtifacts/Auto/non_regression.json")
        try FileManager.default.createDirectory(at:output.deletingLastPathComponent(),withIntermediateDirectories:true)
        try JSONEncoder().encode(results).write(to:output)
    }
}
