import Foundation
import Darwin
import Testing
@testable import LumoraCore

/// Follow up the initial upward RSS trend through repeated complete corpus cycles.
/// This adds observations, never changes a preset or an existing validation threshold.
@Test func gradingPresetMemoryFollowup() async throws {
    let repo=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let files=try FileManager.default.contentsOfDirectory(at:repo.appendingPathComponent("VisualTestAssets"),includingPropertiesForKeys:nil).filter{$0.pathExtension=="png"}.sorted{$0.path<$1.path}
    #expect(files.count==8)
    let engine=RenderEngine();var readings:[Double]=[]
    for _ in 0..<4 {
        for file in files {for preset in ColorGradingPreset.allCases {
            _=try await engine.render(url:file,state:preset.applying(to:EditState()),quality:.interactive)
        }}
        var info=mach_task_basic_info(),count=mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size/MemoryLayout<natural_t>.size)
        let status=withUnsafeMutablePointer(to:&info){p in p.withMemoryRebound(to:integer_t.self,capacity:Int(count)){task_info(mach_task_self_,task_flavor_t(MACH_TASK_BASIC_INFO),$0,&count)}}
        #expect(status==KERN_SUCCESS)
        readings.append(Double(info.resident_size))
    }
    let root=repo.appendingPathComponent("TestArtifacts/ColorGradingPresets")
    try JSONEncoder().encode(readings).write(to:root.appendingPathComponent("memory_followup.json"))
}

@Test func gradingFinalizeMemoryReport() throws {
    guard ProcessInfo.processInfo.environment["LUMORA_GRADING_FINALIZE"] == "1" else {return}
    let repo=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let root=repo.appendingPathComponent("TestArtifacts/ColorGradingPresets"),decoder=JSONDecoder()
    let readings=try decoder.decode([Double].self,from:Data(contentsOf:root.appendingPathComponent("memory_followup.json")))
    #expect(readings.count==4)
    var cases=try decoder.decode([LabCase].self,from:Data(contentsOf:root.appendingPathComponent("checks.json")))
    cases.removeAll{$0.name=="Extended memory followup"}
    var c=LabCase(name:"Extended memory followup")
    c.metrics=["RSS after 128":readings[0],"RSS after 256":readings[1],"RSS after 384":readings[2],"RSS after 512":readings[3]]
    c.check("Warm RSS growth",readings[3]-readings[0]<64*1024*1024,"Same 64MiB review threshold as initial memory test; four full eight-photo cycles. Continued RSS growth is a WARN, not proof of a leak. No cache/renderer modification authorized here.")
    cases.append(c)
    let encoder=JSONEncoder();encoder.outputFormatting=[.prettyPrinted,.sortedKeys]
    try encoder.encode(cases).write(to:root.appendingPathComponent("checks.json"))
    let counts=Dictionary(grouping:cases.flatMap(\.checks),by:{$0.status}).mapValues(\.count)
    let reportURL=repo.appendingPathComponent("TestArtifacts/ColorGradingPresetsValidationReport.md")
    var report=try String(contentsOf:reportURL,encoding:.utf8)
    report=report.replacingOccurrences(of:"PASS [0-9]+ / WARN [0-9]+ / FAIL [0-9]+",with:"PASS \(counts["PASS",default:0]) / WARN \(counts["WARN",default:0]) / FAIL \(counts["FAIL",default:0])",options:.regularExpression)
    let section="""
    ## Extended memory validation

    **\(c.status)** [quality heuristic] — four complete corpus cycles, 512 selections. RSS after each 128 selections: \(readings) bytes. Growth from warm first cycle to fourth: \((readings[3]-readings[0])/1048576) MiB, compared with the existing 64MiB review threshold. A stable plateau was not demonstrated; no claim of leak-free long-session behavior is made. The new preset selector owns no image/texture cache. Retention in the existing CI/Metal/allocator pipeline is a possible cause, not a proven diagnosis. No memory optimization or renderer modification was made. Initial 876 PASS / 28 WARN / 0 FAIL results remain preserved in ValidationHistory/initial_results.json and initial_report.md.

    """
    if !report.contains("## Extended memory validation") {report=report.replacingOccurrences(of:"## Priority Visual Inspection",with:section+"\n## Priority Visual Inspection")}
    try report.write(to:reportURL,atomically:true,encoding:.utf8)
}
