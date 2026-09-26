import Foundation
import CoreGraphics
import ImageIO
@main struct PortraitContext {
 static func main() async throws {
  let path="Validation/AdaptiveTone/Baseline/VisualTestAssets_01_portrait_light_skin.png"
  let url=URL(fileURLWithPath:path)
  let source=CGImageSourceCreateWithURL(url as CFURL,nil)!
  let image=CGImageSourceCreateImageAtIndex(source,0,nil)!
  let decoded=try DebugLabBitmap.linear(image,maximum:512)
  let preview=try DebugLabBitmap.display(decoded.pixels,width:decoded.width,height:decoded.height)
  let scene=try await DebugSceneAnalyzer.shared.analyze(preview)
  for p95:Float in [-1,0.48,0.60,0.75] {
   let runner=try Runner(image:FloatImage(width:decoded.width,height:decoded.height,pixels:decoded.pixels),formatMode:"optimized",importanceMap:nil,budgetVariant:nil,toneKernel:"finalTone")
   let (_,pixels,_)=try runner.run(amount:1,readback:true,globalSide:nil,p95Override:p95,profile:false)
   let bitmap=try DebugLabBitmap.display(pixels!,width:decoded.width,height:decoded.height)
   let metric=try DebugHaloDiagnostics.evaluate(original:preview,processed:bitmap,scene:scene,makeOverlays:false).metrics
   print("override",p95,"actual",runner.p95.contents().assumingMemoryBound(to:Float.self).pointee,
    "meanY",metric.meanAbsoluteY,"subjectSigned",metric.subject?.meanSignedY ?? 0,
    "backgroundSigned",metric.background?.meanSignedY ?? 0,
    "localContrast",metric.meanSignedLocalContrastChange)
  }
 }
}
