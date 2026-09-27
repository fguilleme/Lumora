#if DEBUG
import SwiftUI
import Metal
import ImageIO
import Darwin

private func glowMemory()->[String:Any] {
 var info=task_vm_info_data_t();var count=mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size/MemoryLayout<integer_t>.size)
 let code=withUnsafeMutablePointer(to:&info){p in p.withMemoryRebound(to:integer_t.self,capacity:Int(count)){task_info(mach_task_self_,task_flavor_t(TASK_VM_INFO),$0,&count)}}
 return ["physicalBytes":code==KERN_SUCCESS ? info.phys_footprint:0,"metalBytes":MTLCreateSystemDefaultDevice()?.currentAllocatedSize ?? 0,"thermal":ProcessInfo.processInfo.thermalState.rawValue]
}
struct CinematicGlowDeviceProbe:View {
 @State private var status="Validation Cinematic Glow…"
 @State private var warnings=0
 var body:some View {Text(status).padding().onReceive(NotificationCenter.default.publisher(for:UIApplication.didReceiveMemoryWarningNotification)){_ in warnings+=1}.task{await run()}}
 @MainActor func run() async {
  let documents=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0]
  let output=documents.appendingPathComponent("GlowProductionResults")
  do {
   try FileManager.default.createDirectory(at:output,withIntermediateDirectories:true)
   let input=documents.appendingPathComponent("GlowValidationInput.png"),engine=RenderEngine()
   var rows=[[String:Any]]()
   for intensity in [0.0,40,70,100] {
    var state=EditState();state.effects[.cinematicGlow]=intensity
    for quality in [PreviewQuality.interactive,.high] {
     let start=CFAbsoluteTimeGetCurrent();let result=try await engine.render(url:input,state:state,quality:quality)
     let url=output.appendingPathComponent("\(Int(intensity))_\(quality.rawValue).png")
     let destination=CGImageDestinationCreateWithURL(url as CFURL,"public.png" as CFString,1,nil)!
     CGImageDestinationAddImage(destination,result.image,nil);guard CGImageDestinationFinalize(destination) else{throw PhotoError.renderFailed}
     rows.append(["intensity":intensity,"edge":quality.rawValue,"wallMS":(CFAbsoluteTimeGetCurrent()-start)*1000,"renderMS":result.milliseconds,"memory":glowMemory()])
    }
    var settings=ExportSettings();settings.format = .png;settings.colorSpace = .sRGB
    let start=CFAbsoluteTimeGetCurrent()
    let result=try await engine.export(request:ExportRequest(sourceURL:input,state:state,name:"Glow"),settings:settings,directory:output){_ in}
    rows.append(["intensity":intensity,"exportMS":(CFAbsoluteTimeGetCurrent()-start)*1000,"width":result.width,"height":result.height,"export":result.url.path,"memory":glowMemory()])
    status="Validation \(Int(intensity)) terminée"
   }
   // Repeated interactive frames exercise the same actor and texture pool as the slider.
   for index in 0..<90 {
    var state=EditState();state.effects[.cinematicGlow]=Double((index*17)%101)
    let result=try await engine.render(url:input,state:state,quality:.interactive)
    if index%15==0 {rows.append(["interactionFrame":index,"renderMS":result.milliseconds,"memory":glowMemory()])}
   }
   let report:[String:Any]=["completed":true,"os":UIDevice.current.systemVersion,"rows":rows,"warnings":warnings,"finalMemory":glowMemory()]
   try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]).write(to:output.appendingPathComponent("report.json"),options:.atomic)
   status="Validation terminée"
  }catch{status="Erreur : \(error)";try? Data(status.utf8).write(to:output.appendingPathComponent("error.txt"))}
 }
}
#endif
