import Foundation
import CoreImage
import CoreML
import ImageIO

enum PhotoError:Error { case renderFailed }
struct BeautyMasks { let skin:CGImage?;let eyes:CGImage? }

@main struct Probe {
 static func main() throws {
    let root=URL(fileURLWithPath:CommandLine.arguments[1]), output=root.appendingPathComponent("Validation/RelightingPhases")
    let context=CIContext(options:[.workingColorSpace:CGColorSpace(name:CGColorSpace.extendedLinearSRGB)!, .workingFormat:CIFormat.RGBAf])
    func pixels(_ im:CIImage)->[Float] {
        var a=[Float](repeating:0,count:Int(im.extent.width*im.extent.height)*4)
        a.withUnsafeMutableBytes { context.render(im,toBitmap:$0.baseAddress!,rowBytes:Int(im.extent.width)*16,bounds:im.extent,format:.RGBAf,colorSpace:CGColorSpace(name:CGColorSpace.extendedLinearSRGB)!) };return a
    }
    func png(_ im:CIImage,_ name:String) throws {
        let cg=context.createCGImage(im,from:im.extent,format:.RGBA8,colorSpace:CGColorSpace(name:CGColorSpace.sRGB)!)!
        let dest=CGImageDestinationCreateWithURL(output.appendingPathComponent(name+".png") as CFURL,"public.png" as CFString,1,nil)!
        CGImageDestinationAddImage(dest,cg,nil);guard CGImageDestinationFinalize(dest) else {throw PhotoError.renderFailed}
    }
    func assert(_ ok:Bool,_ message:String) { guard ok else { fatalError(message) }; print("PASS",message) }
    let rect=CGRect(x:0,y:0,width:128,height:192)
    let source=CIImage(color:CIColor(red:0.25,green:0.18,blue:0.12,alpha:0.7)).cropped(to:rect)
    var d=[Float](repeating:1,count:128*192*4)
    for y in 0..<192 {for x in 0..<128 {let z:Float=y>150 ? 0:0.55+Float(x)/300+Float(y)/900;for c in 0..<3 {d[(y*128+x)*4+c]=z}}}
    let depth=CIImage(bitmapData:d.withUnsafeBytes{Data($0)},bytesPerRow:128*16,size:rect.size,format:.RGBAf,colorSpace:nil)
    var s=DepthLightingSettings();s.enabled=true
    let new=try DepthLightingRenderer.apply(source,depth:depth,low:0,high:1,settings:s)
    let old=try LegacyLightingRenderer.apply(source,depth:depth,low:0,high:1,settings:s)
    let dif=zip(pixels(new),pixels(old)).map{abs($0-$1)}.max()!
    assert(dif<0.000001,"Legacy pixels unchanged (max \(dif))")
    let decoded=try JSONDecoder().decode(DepthLightingSettings.self,from:Data("{\"enabled\":true,\"azimuth\":-35,\"elevation\":30,\"red\":1,\"green\":0.86,\"blue\":0.72}".utf8))
    assert(decoded==s,"Old document defaults retain legacy renderer")
    s.intensity=0;s.originalLighting=50
    let dim=pixels(try DepthLightingRenderer.apply(source,depth:depth,low:0,high:1,settings:s)), base=pixels(source)
    var correct=true
    for i in stride(from:0,to:base.count,by:4) { if abs(dim[i]-base[i]*Float(0.5))>Float(0.00001) || dim[i+3] != base[i+3] {correct=false} }
    assert(correct,"Original lighting 50%, zero lamp, alpha retained")
    s.surfaceNormals=true;s.portraitShading=80;s.shadowStrength=70;s.intensity=100
    assert(try JSONDecoder().decode(DepthLightingSettings.self,from:JSONEncoder().encode(s))==s,"New settings round-trip")
    let full=CIImage(color:CIColor(red:0.5,green:0.5,blue:0,alpha:1)).cropped(to:rect)
    let materials=DepthLightingMaterials(skin:CIImage(color:.white).cropped(to:rect),eyes:nil)
    let enhanced=try DepthLightingRenderer.apply(source,depth:depth,low:0,high:1,settings:s,normals:full,materials:materials)
    assert(pixels(enhanced).allSatisfy{$0.isFinite},"Enhanced kernel finite")
    // Explicit source-side direction check with a camera-facing normal.
    var geometry=DepthLightingSettings();geometry.enabled=true;geometry.surfaceNormals=true;geometry.softness=100;geometry.red=1;geometry.green=1;geometry.blue=1;geometry.azimuth=0;geometry.elevation=0
    let opaque=CIImage(color:CIColor(red:0.2,green:0.2,blue:0.2)).cropped(to:rect)
    let uniformDepth=CIImage(color:CIColor(red:0.8,green:0.8,blue:0.8)).cropped(to:rect)
    let front=CIImage(color:CIColor(red:0.5,green:0.5,blue:0)).cropped(to:rect)
    let facing=pixels(try DepthLightingRenderer.apply(opaque,depth:uniformDepth,low:0,high:1,settings:geometry,normals:front))
    let back=CIImage(color:CIColor(red:0.5,green:0.5,blue:1)).cropped(to:rect)
    let away=pixels(try DepthLightingRenderer.apply(opaque,depth:uniformDepth,low:0,high:1,settings:geometry,normals:back))
    assert(facing.reduce(0,+)>away.reduce(0,+),"Normals orient the diffuse response")
    geometry.elevation=35
    let up=CIImage(color:CIColor(red:0.5,green:0.14645,blue:0.14645)).cropped(to:rect)
    let down=CIImage(color:CIColor(red:0.5,green:0.85355,blue:0.14645)).cropped(to:rect)
    let top=pixels(try DepthLightingRenderer.apply(opaque,depth:uniformDepth,low:0,high:1,settings:geometry,normals:up))
    let bottom=pixels(try DepthLightingRenderer.apply(opaque,depth:uniformDepth,low:0,high:1,settings:geometry,normals:down))
    assert(top.reduce(0,+)>bottom.reduce(0,+),"Enhanced source elevation illuminates upward-facing surfaces")
    geometry.elevation=0
    geometry.portraitShading=100
    let eyes=pixels(try DepthLightingRenderer.apply(opaque,depth:uniformDepth,low:0,high:1,settings:geometry,normals:front,materials:DepthLightingMaterials(skin:nil,eyes:CIImage(color:.white).cropped(to:rect))))
    assert(eyes.reduce(0,+)<facing.reduce(0,+),"Eye mask restrains added light")
    geometry.portraitShading=0;geometry.azimuth=70;geometry.shadowStrength=100
    var wallPixels=[Float](repeating:1,count:128*192*4)
    for y in 0..<192 {for x in 0..<128 {let v:Float=(72...76).contains(x) ? 1:0.55;for c in 0..<3 {wallPixels[(y*128+x)*4+c]=v}}}
    let wallDepth=CIImage(bitmapData:wallPixels.withUnsafeBytes{Data($0)},bytesPerRow:128*16,size:rect.size,format:.RGBAf,colorSpace:nil)
    let shadowed=pixels(try DepthLightingRenderer.apply(opaque,depth:wallDepth,low:0,high:1,settings:geometry,normals:front))
    geometry.shadowStrength=0
    let unshadowed=pixels(try DepthLightingRenderer.apply(opaque,depth:wallDepth,low:0,high:1,settings:geometry,normals:front))
    assert(zip(shadowed,unshadowed).allSatisfy{$0 <= $1+Float(0.00001)},"Shadows attenuate only added light")
    let largeRect=CGRect(x:24,y:32,width:512,height:768)
    let shadowDifference=zip(shadowed,unshadowed).map{abs($0-$1)}.reduce(0,+)
    assert(shadowDifference>0.01,"Depth blockers produce shadows (total difference \(shadowDifference))")
    let small=try DepthLightingRenderer.apply(opaque,depth:uniformDepth,low:0,high:1,settings:geometry,normals:front)
    let filled=CIImage(color:CIColor(red:0.2,green:0.2,blue:0.2)).cropped(to:largeRect)
    let shifted=try DepthLightingRenderer.apply(filled,depth:uniformDepth,low:0,high:1,settings:geometry,normals:front)
        .transformed(by:CGAffineTransform(translationX:-24,y:-32)).transformed(by:CGAffineTransform(scaleX:0.25,y:0.25))
    let mismatch=zip(pixels(small),pixels(shifted)).map{abs($0-$1)}.max()!
    assert(mismatch<0.003,"Reference scale and shifted origin (max \(mismatch))")
    let hdr=CIImage(color:CIColor(red:2,green:1.3,blue:0.6)).cropped(to:rect)
    let litHDR=pixels(try DepthLightingRenderer.apply(hdr,depth:depth,low:0,high:1,settings:geometry,normals:front))
    assert(zip(litHDR,pixels(hdr)).allSatisfy{abs($0-$1)<0.00001},"Existing HDR highlights preserved at original100")
    let modelURL=try MLModel.compileModel(at:root.appendingPathComponent("Lumora/RelightingResources/MoGeNormals.mlpackage"))
    let desc=try MLModel(contentsOf:modelURL).modelDescription
    print(desc)
    let estimator=MoGeNormalEstimator(modelURL:modelURL)
    var measurements=[[String:Any]]()
    for name in ["01_portrait_simple","02_hair_bright","03_glasses","08_landscape"] {
        let url=root.appendingPathComponent("Validation/DepthLighting/Samples/\(name).png")
        guard let photo=CIImage(contentsOf:url) else {continue}
        let start=CFAbsoluteTimeGetCurrent()
        let normal=try estimator.estimate(photo,context:context)
        let ms=(CFAbsoluteTimeGetCurrent()-start)*1000
        let values=pixels(normal)
        let valid=stride(from:3,to:values.count,by:4).filter{values[$0]>0.9}.count
        let fraction=Double(valid)/Double(values.count/4)
        assert(fraction>0.1,"\(name) has valid normals")
        try png(normal,name+"-normals")
        // Synthetic depth solely for direction inspection; corpus DA2 validation follows.
        let flat=CIImage(color:CIColor(red:0.8,green:0.8,blue:0.8)).cropped(to:photo.extent)
        var lighting=DepthLightingSettings();lighting.enabled=true;lighting.surfaceNormals=true
        try png(photo,name+"-source")
        try png(try DepthLightingRenderer.apply(photo,depth:flat,low:0,high:1,settings:lighting,normals:normal),name+"-normals-light")
        measurements.append(["sample":name,"normalMS":ms,"validFraction":fraction])
    }
    try JSONSerialization.data(withJSONObject:measurements,options:[.prettyPrinted,.sortedKeys]).write(to:output.appendingPathComponent("normal-benchmark.json"))
 }
}
