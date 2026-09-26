import CoreImage
import Foundation
import Testing
@testable import LumoraCore

@Test func healingCheekResizeDiagnostic() throws {
 let root=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
 let input=try #require(CIImage(contentsOf:root.appendingPathComponent("Validation/BeautyValidation/Sources/08_open_smile_teeth.jpg")))
 let folder=root.appendingPathComponent("Validation/BeautyIntegration/HealingResize")
 try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
 let context=CIContext(options:[.workingColorSpace:CGColorSpace(name:CGColorSpace.extendedLinearSRGB)!])
 let crop=CGRect(x:1150,y:770,width:270,height:250)
 func save(_ image:CIImage,_ name:String) throws {
  try context.writePNGRepresentation(of:image.cropped(to:crop),to:folder.appendingPathComponent(name+".png"),format:.RGBA8,colorSpace:CGColorSpace(name:CGColorSpace.sRGB)!)
 }
 try save(input,"original")
 for radius in [0.01,0.02] {
  let c=ManualBlemishCorrection(targetCenter:.init(x:0.412,y:0.55),targetRadius:radius,sourceCenter:.init(x:0.438,y:0.557))
  try save(ManualHealingRenderer.apply(input,corrections:[c]),"size-\(Int(radius*100))")
  try save(ManualHealingRenderer.diagnostic(input,correction:c,mode:5),"low-size-\(Int(radius*100))")
 }
}
