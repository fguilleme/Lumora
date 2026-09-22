import Foundation
import CoreImage
import Testing
@testable import LumoraCore

@Test func gradingManualRendererRegression() async throws {
    guard let mode=ProcessInfo.processInfo.environment["LUMORA_GRADING_REGRESSION"] else {return}
    let root=URL(fileURLWithPath:"/private/tmp/lumora-grading-manual-reference")
    try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
    let gpu=try LabGPU(),source=SilverBWTestChart.generate(size:128).image
    let file=root.appendingPathComponent("input.tiff")
    try gpu.context.writeTIFFRepresentation(of:source,to:file,format:.RGBAh,colorSpace:gpu.linear,options:[:])
    let engine=RenderEngine();var results:[String:Bool]=[:]
    for index in 0..<16 {
        var s=EditState()
        if index>0 {
            s.colorGrading.shadows=GradingWheel(hue:Double(index*23),saturation:Double(index*3),luminance:Double(index-8))
            s.colorGrading.midtones=GradingWheel(hue:Double(index*17),saturation:Double(index*2),luminance:Double(8-index))
            s.colorGrading.highlights=GradingWheel(hue:Double(index*31),saturation:Double(index*4),luminance:Double(index-4))
            s.colorGrading.balance=Double(index*10-80);s.colorGrading.blending=Double(index*6)
        }
        let rendered=try await engine.render(url:file,state:s,quality:.high),image=CIImage(cgImage:rendered.image)
        let pixels=gpu.read(image,image.extent),data=pixels.withUnsafeBytes{Data($0)},path=root.appendingPathComponent("manual-\(index).rgba32f")
        if mode=="record" {try data.write(to:path)}
        else {let match=try Data(contentsOf:path)==data;results[String(index)]=match;#expect(match,"Manual Grading \(index)")}
    }
    if mode != "record" {
        let repo=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let folder=repo.appendingPathComponent("TestArtifacts/ColorGradingPresets")
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        try JSONEncoder().encode(results).write(to:folder.appendingPathComponent("manual_non_regression.json"))
    }
}
