import Testing
import Foundation

@Test func visualCreativeValidation() async throws {
    let env=ProcessInfo.processInfo.environment
    let repo=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let full=env["LUMORA_VISUAL_FULL"]=="1"
    let root=env["LUMORA_VISUAL_OUTPUT"].map{URL(fileURLWithPath:$0)} ?? repo.appendingPathComponent(full ? "TestArtifacts":"TestArtifacts/Quick")
    let lab=try LumoraVisualTestLab(root:root,full:full)
    try await lab.run()
    for c in lab.cases {
        for check in c.checks where check.hard { #expect(check.status != "FAIL", "\(c.name): \(check.name). Report: \(root.path)") }
    }
    print("Visual validation report: \(root.appendingPathComponent("CreativeFXValidationReport.md").path)")
}

@Test func chartCoordinatesAndMeasurementsAreIndependent() throws {
    let gpu=try LabGPU(),chart=MasterChart.generate(size:256)
    let black=chart.regions.first{$0.name=="gray-0.0"}!,white=chart.regions.first{$0.name=="gray-1.0"}!
    let b=gpu.compare(chart.image,chart.image,region:black.rect),w=gpu.compare(chart.image,chart.image,region:white.rect)
    #expect(abs(b.input.mean)<1e-6);#expect(abs(w.input.mean-1)<1e-6)
    let input=SyntheticCharts.gray(0.2,size:32),output=SyntheticCharts.gray(0.3,size:32)
    let m=gpu.compare(input,output)
    #expect(abs(m.residual.mean-0.1)<1e-6)
    #expect(abs(m.mae-0.1)<1e-6);#expect(abs(m.rmse-0.1)<1e-6)
    #expect(abs(m.ssim - (2*0.2*0.3+0.0001)/(0.2*0.2+0.3*0.3+0.0001)) < 1e-5)
}

@Test func fftAndCorrelationRecoverKnownSine() throws {
    let gpu=try LabGPU(),size=256
    let input=SyntheticCharts.gray(0.3,size:size)
    let output=SyntheticCharts.make(size:size) { x,_ in
        SIMD3(repeating:Float(0.3+0.01*sin(2*Double.pi*16*x)))
    }
    let s=gpu.structure(input,output,region:input.extent)
    #expect(abs(s.peakFrequency-16.0/256)<1.0/256)
    #expect(abs(s.autocorrelation["1,0"]!-cos(2*Double.pi/16))<0.01)
    #expect(abs(s.autocorrelation["0,1"]!-1)<1e-5)
}

@Test func goldenInfrastructureRequiresExplicitRecordingAndMatchingManifest() throws {
    let gpu=try LabGPU(),image=SyntheticCharts.gray(0.2,size:32)
    let folder=URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at:folder) }
    let compareEnv=["LUMORA_GOLDEN_DIR":folder.path]
    let absent=try GoldenStore.process(image,id:"analytic",inputIdentity:"known-constant",configuration:"test",gpu:gpu,environment:compareEnv)
    #expect(absent.1==nil)
    #expect(!FileManager.default.fileExists(atPath:folder.path))
    var recordEnv=compareEnv;recordEnv["LUMORA_RECORD_GOLDENS"]="YES_I_REVIEWED_THE_OUTPUTS"
    let recorded=try GoldenStore.process(image,id:"analytic",inputIdentity:"known-constant",configuration:"test",gpu:gpu,environment:recordEnv)
    #expect(recorded.1==nil)
    let comparison=try GoldenStore.process(SyntheticCharts.gray(0.3,size:32),id:"analytic",inputIdentity:"known-constant",configuration:"test",gpu:gpu,environment:compareEnv)
    #expect(abs(try #require(comparison.1).mae-0.1)<1e-5)
    #expect(throws:LabError.self) {
        _ = try GoldenStore.process(image,id:"analytic",inputIdentity:"different-source",configuration:"test",gpu:gpu,environment:compareEnv)
    }
}

@Test func lowKeyZonesUseInputLuminanceAndRatioOfMeans() throws {
    var ramp = Comparison()
    // Deliberately different pixel-wise ratios: mean ratios is not ratio of means.
    // .90 and .925 must remain outside the named photographic zones.
    ramp.transferInput = [0, 0.05, 0.10, 0.20, 0.30, 0.50, 0.65, 0.80, 0.90, 0.925, 0.95, 1]
    ramp.transferOutput = [0, 0.04, 0.10, 0.10, 0.24, 0.40, 0.52, 0.64, 0, 0, 0.76, 0.8]
    var result = LabCase(name: "independent analytic zone fixture")
    LumoraVisualTestLab.recordLowKeyZones(ramp, into: &result)
    for zone in LumoraVisualTestLab.lowKeyZones {
        #expect(result.metrics[zone.name + "-sampleCount"] == 2)
    }
    #expect(abs(try #require(result.metrics["shadows-absoluteChange"]) + 0.05) < 1e-12)
    #expect(abs(try #require(result.metrics["shadows-relativeChange"]) + 1.0/3) < 1e-12)
    #expect(abs(try #require(result.metrics["specular-whites-relativeChange"]) + 0.2) < 1e-12)
}

@Test func realPhotographsManualValidation() throws {
    let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let root = repo.appendingPathComponent("TestArtifacts")
    let lab = try LumoraVisualTestLab(root: root, full: true)
    let count = try lab.runRealPhotos()
    #expect(count > 0)
    print("Real photographs: \(count). Report: \(root.appendingPathComponent("RealPhotosValidationReport.md").path)")
}

@Test func tonalContrastValidation() async throws {
    let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
    let full = ProcessInfo.processInfo.environment["LUMORA_VISUAL_FULL"] == "1"
    let root = ProcessInfo.processInfo.environment["LUMORA_VISUAL_OUTPUT"].map { URL(fileURLWithPath: $0) }
        ?? repo.appendingPathComponent(full ? "TestArtifacts" : "TestArtifacts/Quick")
    let lab = try LumoraVisualTestLab(root: root, full: full)
    try await lab.runTonalContrast()
    for c in lab.cases where c.name.hasPrefix("TC_") {
        for check in c.checks where check.hard {
            #expect(check.status != "FAIL", "\(c.name): \(check.name). Report: \(root.path)")
        }
    }
    print("Tonal Contrast report: \(root.appendingPathComponent("TonalContrastValidationReport.md").path)")
}
