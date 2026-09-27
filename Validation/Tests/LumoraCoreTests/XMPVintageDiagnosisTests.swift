import Testing
import Foundation
import CoreImage
@testable import LumoraCore

/// Explicit diagnostic: run only when the user's XMP is available locally.
@Test func xmpVintageStageDiagnosis() throws {
    let xmp = URL(fileURLWithPath: "/Volumes/XTRA/Downloads/Vintage Classic one.xmp")
    guard FileManager.default.fileExists(atPath: xmp.path) else { return }
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let folder = root.appendingPathComponent("XMPVintageDiagnosis")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let parsed = try XMPPresetImporter.read(xmp)
    let full = parsed.editState
    var exposure = EditState(); exposure.exposure = full.exposure
    var tonal = exposure
    for a in Adjustment.light { tonal[a] = full[a] }
    var curves = tonal; curves.curves = full.curves
    var grading = curves; grading.colorGrading = full.colorGrading
    var mixer = grading; mixer.colorMixer = full.colorMixer; mixer.saturation = full.saturation
    let stages: [(String, EditState)] = [("00_original", EditState()), ("01_exposure", exposure), ("02_tonal", tonal),
        ("03_curves", curves), ("04_grading", grading), ("05_mixer", mixer), ("06_full_without_grain", full)]
    let linear = try #require(CGColorSpace(name: CGColorSpace.extendedLinearSRGB))
    let srgb = try #require(CGColorSpace(name: CGColorSpace.sRGB))
    let context = CIContext(options: [.workingColorSpace: linear, .workingFormat: CIFormat.RGBAf])
    let w = 1024
    var ramp = [Float](repeating: 1, count: w*4)
    for x in 0..<w { for c in 0..<3 { ramp[x*4+c] = Float(x)/Float(w-1) } }
    let input = CIImage(bitmapData: ramp.withUnsafeBytes { Data($0) }, bytesPerRow: w*16,
        size: CGSize(width: w, height: 1), format: .RGBAf, colorSpace: srgb)
    let portraitURL = root.appendingPathComponent("DepthLensDA2Mobile/Payload/01_portrait_simple.png")
    let portrait = try #require(CIImage(contentsOf: portraitURL, options: [.applyOrientationProperty: true]))
    let scale = min(1, 1200/max(portrait.extent.width, portrait.extent.height))
    let photo = portrait.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
    var csv = "stage,input_srgb,red,green,blue\n"
    var report = "stage,upper_ramp_max_adjacent_RGB_difference,distinct_upper_ramp_RGB_rounded_5dp\n"
    for (name,state) in stages {
        let result = try DevelopmentRenderer.apply(input, state: state, cube: RenderEngine.makeCube)
        var pixels = [Float](repeating: 0, count: w*4)
        pixels.withUnsafeMutableBytes { context.render(result, toBitmap: $0.baseAddress!, rowBytes: w*16,
            bounds: input.extent, format: .RGBAf, colorSpace: srgb) }
        #expect(pixels.allSatisfy { $0.isFinite })
        for x in 0..<w { csv += "\(name),\(ramp[x*4]),\(pixels[x*4]),\(pixels[x*4+1]),\(pixels[x*4+2])\n" }
        var upper = Set<String>(), maxDelta: Float = 0
        for x in 800..<w {
            upper.insert((0..<3).map { String(format: "%.5f",pixels[x*4+$0]) }.joined(separator: ","))
            if x>800 { for c in 0..<3 { maxDelta = max(maxDelta, abs(pixels[x*4+c]-pixels[(x-1)*4+c])) } }
        }
        report += "\(name),\(maxDelta),\(upper.count)\n"
        let image = try DevelopmentRenderer.apply(photo, state: state, cube: RenderEngine.makeCube)
        try context.writePNGRepresentation(of: image, to: folder.appendingPathComponent(name+".png"), format: .RGBA8, colorSpace: srgb)
    }
    let complete = try CreativeXMPRenderer().apply(photo, effect: parsed.makeEffect())
    try context.writePNGRepresentation(of: complete, to: folder.appendingPathComponent("07_complete.png"), format: .RGBA8, colorSpace: srgb)
    try csv.write(to: folder.appendingPathComponent("ramps.csv"), atomically: true, encoding: .utf8)
    try report.write(to: folder.appendingPathComponent("summary.csv"), atomically: true, encoding: .utf8)
    print(report)
}
