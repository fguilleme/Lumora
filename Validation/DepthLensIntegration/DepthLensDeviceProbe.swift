#if DEBUG
import SwiftUI
import ImageIO
import Darwin

private func depthMemory() -> UInt64 {
    var info = task_vm_info_data_t(); var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
    let code = withUnsafeMutablePointer(to: &info) { p in p.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count) } }
    return code == KERN_SUCCESS ? info.phys_footprint : 0
}
private func samePixels(_ a:CGImage,_ b:CGImage)->Bool {
    guard a.width==b.width,a.height==b.height,a.bitsPerPixel==b.bitsPerPixel,
          let ad=a.dataProvider?.data,let bd=b.dataProvider?.data,
          let ap=CFDataGetBytePtr(ad),let bp=CFDataGetBytePtr(bd) else{return false}
    for y in 0..<a.height {
        if memcmp(ap.advanced(by:y*a.bytesPerRow),bp.advanced(by:y*b.bytesPerRow),a.width*a.bitsPerPixel/8) != 0 {return false}
    }
    return true
}
struct DepthLensDeviceProbe: View {
    @State private var status = "Validation Depth Lens…"
    @State private var warnings = 0
    var body: some View {
        Text(status).padding().onReceive(NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)) { _ in warnings += 1 }.task { await run() }
    }
    @MainActor func run() async {
        let root = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let folder = root.appendingPathComponent(CommandLine.arguments.contains("--depth-4k") ? "DepthLensIntegration4K" : "DepthLensIntegration")
        var rows = [[String: Any]]()
        func save() {
            try? JSONSerialization.data(withJSONObject: ["rows": rows, "warnings": warnings, "os": UIDevice.current.systemVersion], options: [.prettyPrinted, .sortedKeys]).write(to: folder.appendingPathComponent("report.json"), options: .atomic)
        }
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let source = root.appendingPathComponent(CommandLine.arguments.contains("--depth-4k") ? "GlowValidationInput.png" : "DepthLensInput.png")
            let engine = RenderEngine()
            var state = EditState()
            let baseline = try await engine.render(url: source, state: state, quality: .interactive)
            state.depthLens = .init()
            let disabled = try await engine.render(url: source, state: state, quality: .interactive)
            rows.append(["phase": "bypass", "equal": samePixels(baseline.image, disabled.image), "inferences": await engine.depthLensInferenceCount()]); save()
            state.depthLens = DepthLensSettings(enabled: true, aperture: 1.4, focal: 85, focusX: 0.7, focusY: 0.23)
            for quality in [PreviewQuality.interactive, .high, .interactive] {
                status = "Rendu \(quality.rawValue) px…"
                let result = try await engine.render(url: source, state: state, quality: quality)
                let destination = CGImageDestinationCreateWithURL(folder.appendingPathComponent("render-\(quality.rawValue).png") as CFURL, "public.png" as CFString, 1, nil)!
                CGImageDestinationAddImage(destination, result.image, nil); _ = CGImageDestinationFinalize(destination)
                rows.append(["phase": "render", "edgeRequested": quality.rawValue, "width": result.image.width, "height": result.image.height, "ms": result.milliseconds, "physicalBytes": depthMemory(), "thermal": ProcessInfo.processInfo.thermalState.rawValue, "inferences": await engine.depthLensInferenceCount()]); save()
            }
            for index in 0..<20 {
                state.depthLens!.aperture = 1.4 + Double(index % 7)
                let result = try await engine.render(url: source, state: state, quality: .interactive)
                rows.append(["phase": "slider", "ms": result.milliseconds, "physicalBytes": depthMemory(), "inferences": await engine.depthLensInferenceCount()]); save()
            }
            state.depthLens!.aperture = 1.4
            var settings = ExportSettings(); settings.format = .png
            status = "Export natif…"
            let start = CFAbsoluteTimeGetCurrent()
            let output = try await engine.export(request: ExportRequest(sourceURL: source, state: state, name: "Depth Lens"), settings: settings, directory: folder) { _ in }
            rows.append(["phase": "export", "width": output.width, "height": output.height, "ms": (CFAbsoluteTimeGetCurrent()-start)*1000, "physicalBytes": depthMemory(), "inferences": await engine.depthLensInferenceCount()]); save()
            // The document state survives serialization; native export above uses the same graph.

            let reopened = try JSONDecoder().decode(EditState.self, from: JSONEncoder().encode(state))
            rows.append(["phase": "persistence", "equal": state == reopened])
            rows.append(["phase": "completed"]); save(); status = "Validation Depth Lens terminée"
        } catch { rows.append(["error": error.localizedDescription]); save(); status = error.localizedDescription }
    }
}
#endif
