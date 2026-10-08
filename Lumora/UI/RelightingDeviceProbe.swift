#if DEBUG
import SwiftUI
import ImageIO
import Darwin

/// Invoked only by an explicit validation launch argument. Uses the production actor,
/// writes into its own Documents subfolder, and does not open or edit user documents.
struct RelightingDeviceProbe: View {
    @State private var status = "Validation Éclairage…"
    @State private var memoryWarnings = 0
    var body: some View {
        Text(status).padding()
            .onReceive(NotificationCenter.default.publisher(for:UIApplication.didReceiveMemoryWarningNotification)) { _ in memoryWarnings += 1 }
            .task { await run() }
    }
    private func memory() -> UInt64 {
        var info=task_vm_info_data_t()
        var count=mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size/MemoryLayout<integer_t>.size)
        let result=withUnsafeMutablePointer(to:&info) { p in
            p.withMemoryRebound(to:integer_t.self,capacity:Int(count)) { task_info(mach_task_self_,task_flavor_t(TASK_VM_INFO),$0,&count) }
        }
        return result == KERN_SUCCESS ? info.phys_footprint:0
    }
    @MainActor private func run() async {
        let documents=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0]
        let haloValidation=CommandLine.arguments.contains("--lighting-halo-probe")
        let inputs=documents.appendingPathComponent(haloValidation ? "LightingHaloInputs":"RelightingPhasesInputs")
        let output=documents.appendingPathComponent(haloValidation ? "LightingHaloProbe":"RelightingPhasesProbe")
        var rows=[[String:Any]]()
        func save() {
            try? JSONSerialization.data(withJSONObject:["rows":rows,"memoryWarnings":memoryWarnings,"os":UIDevice.current.systemVersion,"device":UIDevice.current.model],options:[.prettyPrinted,.sortedKeys])
                .write(to:output.appendingPathComponent("report.json"),options:.atomic)
        }
        func png(_ image:CGImage,_ name:String) throws {
            guard let destination=CGImageDestinationCreateWithURL(output.appendingPathComponent(name+".png") as CFURL,"public.png" as CFString,1,nil) else {throw PhotoError.renderFailed}
            CGImageDestinationAddImage(destination,image,nil)
            guard CGImageDestinationFinalize(destination) else {throw PhotoError.renderFailed}
        }
        do {
            try FileManager.default.createDirectory(at:output,withIntermediateDirectories:true)
            let urls=try FileManager.default.contentsOfDirectory(at:inputs,includingPropertiesForKeys:nil).filter{["png","jpg","jpeg"].contains($0.pathExtension.lowercased())}.sorted{$0.lastPathComponent<$1.lastPathComponent}
            guard !urls.isEmpty else {throw PhotoError.unreadable}
            let engine=RenderEngine()
            for url in urls {
                let name=url.deletingPathExtension().lastPathComponent
                var state=EditState()
                let phases=haloValidation ? ["source","studio","relief0"]:["source","legacy","original75","normals","portrait","shadows","slider"]
                for phase in phases {
                    status="\(name) · \(phase)"
                    if phase=="legacy" { var s=DepthLightingSettings();s.enabled=true;s.azimuth = -55;s.targetX=0.4;s.targetY=0.4;state.depthLighting=s }
                    if phase=="studio" {var s=DepthLightingSettings();s.enabled=true;state.depthLighting=s}
                    if phase=="relief0" {state.depthLighting?.relief=0}
                    if phase=="original75" {state.depthLighting?.originalLighting=75}
                    if phase=="normals" {state.depthLighting?.surfaceNormals=true}
                    if phase=="portrait" {state.depthLighting?.portraitShading=70}
                    if phase=="shadows" {state.depthLighting?.shadowStrength=70}
                    if phase=="slider" {state.depthLighting?.intensity=85}
                    let result=try await engine.render(url:url,state:state,quality:.interactive)
                    try png(result.image,name+"-"+phase)
                    rows.append(["sample":name,"phase":phase,"ms":result.milliseconds,"physicalBytes":memory(),"depthInferences":await engine.depthLensInferenceCount(),"normalInferences":await engine.lightingNormalInferenceCount(),"thermal":ProcessInfo.processInfo.thermalState.rawValue]);save()
                }
                let reopened=try JSONDecoder().decode(EditState.self,from:JSONEncoder().encode(state))
                rows.append(["phase":"persistence","sample":name,"equal":state==reopened]);save()
                var settings=ExportSettings();settings.format = .png
                if haloValidation {state.depthLighting?.relief=80}
                let start=CFAbsoluteTimeGetCurrent()
                let photo=try await engine.export(request:ExportRequest(sourceURL:url,state:state,name:name+"-export"),settings:settings,directory:output)
                rows.append(["phase":"export","sample":name,"width":photo.width,"height":photo.height,"ms":(CFAbsoluteTimeGetCurrent()-start)*1000,"physicalBytes":memory(),"normalInferences":await engine.lightingNormalInferenceCount()]);save()
            }
            rows.append(["phase":"completed"]);save();status="Validation Éclairage terminée"
        } catch {rows.append(["error":error.localizedDescription]);save();status=error.localizedDescription}
    }
}
#endif
