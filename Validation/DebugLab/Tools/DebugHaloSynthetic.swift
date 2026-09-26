import Foundation
import CoreGraphics
@main struct Synthetic {
 static func main() throws {
  let w=256,h=128
  func bitmap(_ modifier:(Int,Float)->Float) throws -> CGImage {
   var pixels=[Float](repeating:1,count:w*h*4)
   for row in 0..<h {for x in 0..<w {
    let value=modifier(x,x<128 ? 0.2:0.8)
    let i=4*(row*w+x)
    pixels[i]=value;pixels[i+1]=value;pixels[i+2]=value
   }}
   return try DebugLabBitmap.display(pixels,width:w,height:h)
  }
  let original=try bitmap{$1}
  let cases:[(String,(Int,Float)->Float)]=[
   ("identity",{$1}),
   ("global monotone", {_,y in pow(y,0.9)}),
   ("bright halo",{x,y in y + ((131...135).contains(x) ? 0.08:0)}),
   ("dark halo",{x,y in y - ((120...124).contains(x) ? 0.08:0)}),
   ("edge contrast",{x,y in y + (x==128 ? 0.06:x==127 ? -0.06:0)}),
   ("broad edge contrast",{x,y in y + ((131...133).contains(x) ? 0.08:(123...125).contains(x) ? -0.08:0)}),
   ("left border",{x,y in y + (x<8 ? 0.05:0)})
  ]
  for (name,modifier) in cases {
   let output=try bitmap(modifier)
   let m=try DebugHaloDiagnostics.evaluate(original:original,processed:output,scene:nil,makeOverlays:false).metrics
   print(name, "mean",m.meanAbsoluteY,"bright",m.brightHaloCount,"dark",m.darkHaloCount,
         "enhance",m.edgeEnhancementCount,"L/R",m.leftRightExcessAsymmetry)
  }
 }
}
