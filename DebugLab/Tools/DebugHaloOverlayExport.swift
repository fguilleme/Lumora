import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
@main struct ExportOverlays {
 static func main() throws {
  let directory=URL(fileURLWithPath:CommandLine.arguments[1],isDirectory:true)
  try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
  let files=CommandLine.arguments[2...3].map{URL(fileURLWithPath:$0)}
  let images=files.compactMap{file -> CGImage? in
   guard let source=CGImageSourceCreateWithURL(file as CFURL,nil) else{return nil}
   return CGImageSourceCreateImageAtIndex(source,0,nil)
  }
  guard images.count==2 else {throw NSError(domain:"input",code:1)}
  let result=try DebugHaloDiagnostics.evaluate(original:images[0],processed:images[1],scene:nil)
  for (key,image) in result.overlays {
   let safe=key.replacingOccurrences(of:" ",with:"_")
   let url=directory.appendingPathComponent(safe+".png")
   if let destination=CGImageDestinationCreateWithURL(url as CFURL,UTType.png.identifier as CFString,1,nil) {
    CGImageDestinationAddImage(destination,image,nil);CGImageDestinationFinalize(destination)
   }
  }
  let encoder=JSONEncoder();encoder.outputFormatting=[.prettyPrinted,.sortedKeys]
  try encoder.encode(result.metrics).write(to:directory.appendingPathComponent("metrics.json"))
  print(directory.path,result.metrics.worstX,result.metrics.worstY,result.metrics.worstResidual)
 }
}
