import Foundation
import CoreImage
import Testing
@testable import LumoraCore

@Test func dlcReadbackDiagnostics() throws {
    let lab=try LumoraVisualTestLab(root:URL(fileURLWithPath:"/private/tmp/dlc-diagnostics"),full:false)
    let a=lab.dlcFlat(512,512)
    let black=CIImage(color:CIColor(red:0,green:0,blue:0)).cropped(to:a.extent)
    let upper=CIImage(color:CIColor(red:1,green:1,blue:1)).cropped(to:CGRect(x:0,y:256,width:512,height:256)).composited(over:black)
    let q=lab.silverPixels(upper)
    #expect(q[0] == 1 && q[q.count-4] == 0, "Bitmap readback starts at the top row, unlike CI image-space y")
    let shifted=a.transformed(by:CGAffineTransform(translationX:137.25,y:-91.75))
    #expect(shifted.extent == CGRect(x:137,y:-92,width:513,height:513), "Core Image outward-rounds fractional transformed extents")
}
