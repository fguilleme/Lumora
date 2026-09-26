import CoreImage
import ImageIO
import Foundation
import Testing
@testable import LumoraCore

@Test func beautyEyesLipsResponsePhotos() throws {
 let root=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
 let phase=ProcessInfo.processInfo.environment["BEAUTY_RESPONSE_PHASE"] ?? "after"
 let folder=root.appendingPathComponent("Validation/BeautyValidation/EyeMaskCorrection/\(phase)")
 try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
 let linear=CGColorSpace(name:CGColorSpace.extendedLinearSRGB)!
 let context=CIContext(options:[.workingColorSpace:linear])
 func read(_ image:CIImage,_ r:CGRect)->[Float] {
  var p=[Float](repeating:0,count:Int(r.width*r.height)*4)
  context.render(image,toBitmap:&p,rowBytes:Int(r.width)*16,bounds:r,format:.RGBAf,colorSpace:linear)
  return p
 }
 var rows=["photo,control,value,maskedMeanRGBDifference,maskedMaxRGBDifference"]
 for (name, controls) in [
  ("08_open_smile_teeth", ["eyeBrightness","eyeDetail"]),
  ("10_detailed_eyes", ["eyeBrightness","eyeDetail"])
 ] {
  let url=root.appendingPathComponent("Validation/BeautyValidation/Sources/\(name).jpg")
  let source=try #require(CGImageSourceCreateWithURL(url as CFURL,nil))
  let cg=try #require(CGImageSourceCreateImageAtIndex(source,0,nil))
  let masks=try BeautyFaceAnalysis.analyze(cg)
  #expect(masks.faceCount>0)
  let input=CIImage(cgImage:cg),extent=input.extent
  for control in controls {
   let v2Control=BeautyV2Control(rawValue:control)
   let v1Control=BeautyControl(rawValue:control)
   let matte=try #require(control.hasPrefix("lip") ? masks.v2.lips :
    control.hasPrefix("eye") ? masks.eyes : control=="teeth" ? masks.teeth :
    control=="blemishes" ? masks.blemishes : control=="darkCircles" ? masks.underEyes : masks.skin)
   let mask=CIImage(cgImage:matte).transformed(by:.init(scaleX:extent.width/CGFloat(matte.width),y:extent.height/CGFloat(matte.height)))
   let weights=read(mask,extent)
   var x0=Int(extent.width),x1=0,y0=Int(extent.height),y1=0
   for y in 0..<Int(extent.height) {for x in 0..<Int(extent.width) where weights[(y*Int(extent.width)+x)*4]>0.05 {
    x0=min(x0,x);x1=max(x1,x);y0=min(y0,y);y1=max(y1,y)
   }}
   #expect(x1>x0 && y1>y0)
   let crop=CGRect(x:x0-80,y:Int(extent.height)-1-y1-80,width:x1-x0+161,height:y1-y0+161).intersection(extent).integral
   let original=read(input,crop),w=read(mask,crop)
   let levels=(v2Control?.range.lowerBound ?? v1Control?.range.lowerBound ?? 0)<0 ? [-100.0,-50,0,50,100] : [0.0,25,50,75,100]
   var sheet=CIImage(color:.black).cropped(to:CGRect(x:0,y:0,width:crop.width*5,height:crop.height))
   var previous=0.0
   for (column,value) in levels.enumerated() {
    var settings=BeautyState()
    let result:CIImage
    if let v2Control {
     var v2=BeautyV2Settings();v2[v2Control]=value
     result=try BeautyV2Renderer.apply(input,settings:v2,masks:masks,amount:100)
    } else {
     settings[try #require(v1Control)]=value
     result=try BeautyRenderer.apply(input,settings:settings,masks:masks)
    }
    let pixels=read(result,crop)
    #expect(pixels.allSatisfy {$0.isFinite})
    var total=0.0,maximum=0.0,count=0
    for i in stride(from:0,to:pixels.count,by:4) where w[i]>0.05 {
     for c in 0..<3 {let delta=Double(abs(pixels[i+c]-original[i+c]));total+=delta;maximum=max(maximum,delta);count+=1}
    }
    let mean=total/Double(max(1,count))
    if value==0 {#expect(maximum<0.00001)} else {#expect(maximum>0.00001)}
    if levels.first==0 {#expect(mean+1e-6>=previous);previous=mean}
    rows.append("\(name),\(control),\(value),\(mean),\(maximum)")
    let tile=result.cropped(to:crop).transformed(by:.init(translationX:-crop.minX+Double(column)*crop.width,y:-crop.minY))
    sheet=tile.composited(over:sheet)
   }
   try context.writePNGRepresentation(of:sheet,to:folder.appendingPathComponent("\(name)-\(control).png"),format:.RGBA8,colorSpace:CGColorSpace(name:CGColorSpace.sRGB)!)
  }
 }
 try rows.joined(separator:"\n").write(to:folder.appendingPathComponent("metrics.csv"),atomically:true,encoding:.utf8)
}

@Test func beautyEyesLipsColorAndHDRInvariants() throws {
 let extent=CGRect(x:0,y:0,width:64,height:64)
 let linear=CGColorSpace(name:CGColorSpace.extendedLinearSRGB)!
 let context=CIContext(options:[.workingColorSpace:linear])
 let white=try #require(context.createCGImage(CIImage(color:.white).cropped(to:extent),from:extent))
 let black=try #require(context.createCGImage(CIImage(color:.black).cropped(to:extent),from:extent))
 func masks(_ matte:CGImage)->BeautyMasks {
  BeautyMasks(faceCount:1,faceWidthFraction:0.5,faceRects:[],skin:nil,eyes:matte,underEyes:nil,teeth:nil,blemishes:nil,v2:BeautyV2Masks(lips:matte,innerMouth:nil,hair:nil))
 }
 func pixel(_ image:CIImage)->[Float] {
  var p=[Float](repeating:0,count:4)
  context.render(image,toBitmap:&p,rowBytes:16,bounds:CGRect(x:32,y:32,width:1,height:1),format:.RGBAf,colorSpace:linear)
  return p
 }
 for rgb in [[0.0,0,0],[0.18,0.18,0.18],[0.5,0.13,0.18],[1.0,1,1],[8.0,4,2]] {
  let input=CIImage(color:CIColor(red:rgb[0],green:rgb[1],blue:rgb[2])).cropped(to:extent)
  let original=pixel(input)
  for value in [-100.0,0,100] {
   var settings=BeautyV2Settings();settings.lipColor=value
   let rendered=try BeautyV2Renderer.apply(input,settings:settings,masks:masks(white),amount:100)
   #expect(rendered === input) // Legacy lip hue must not remain hidden and active.
   let result=pixel(rendered)
   #expect(result.allSatisfy {$0.isFinite})
   let deltaY=abs((result[0]-original[0])*0.2126+(result[1]-original[1])*0.7152+(result[2]-original[2])*0.0722)
   #expect(deltaY<0.0001)
   if rgb[0]==rgb[1] && rgb[1]==rgb[2] {#expect(zip(result,original).allSatisfy {abs($0-$1)<0.0001})}
   let outside=pixel(try BeautyV2Renderer.apply(input,settings:settings,masks:masks(black),amount:100))
   #expect(zip(outside,original).allSatisfy {abs($0-$1)<0.0001})
   #expect(try BeautyV2Renderer.apply(input,settings:settings,masks:masks(white),amount:0) === input)
  }
  var eyes=BeautyState();eyes.eyeBrightness=100;eyes.eyeDetail=100
  let eyePixel=pixel(try BeautyRenderer.apply(input,settings:eyes,masks:masks(white)))
  #expect(eyePixel.allSatisfy {$0.isFinite})
  // Multiplicative correction retains RGB ratios / iris hue.
  #expect(abs(eyePixel[0]*original[1]-eyePixel[1]*original[0])<0.0001)
  #expect(abs(eyePixel[0]*original[2]-eyePixel[2]*original[0])<0.0001)
  if rgb[0]==0 || rgb[0]>=1 {#expect(zip(eyePixel,original).allSatisfy {abs($0-$1)<0.001})}
  let outside=pixel(try BeautyRenderer.apply(input,settings:eyes,masks:masks(black)))
  #expect(zip(outside,original).allSatisfy {abs($0-$1)<0.0001})
 }
}

@Test func beautyEyeMaskExcludesEyelidsAndMissingEye() throws {
 let context=CIContext(),extent=CGRect(x:0,y:0,width:128,height:128)
 let input=CIImage(color:CIColor(red:0.4,green:0.3,blue:0.25)).cropped(to:extent)
 let cg=try #require(context.createCGImage(input,from:extent))
 let source=try #require(MaskBitmapSource(image:cg,maximumDimension:128))
 let points=[CGPoint(x:30,y:70),CGPoint(x:40,y:75),CGPoint(x:50,y:70),CGPoint(x:40,y:65)]
 let face=BeautyMaskFace(box:CGRect(x:15,y:15,width:98,height:98),contour:[],leftEye:CGRect(x:30,y:65,width:20,height:10),rightEye:nil,leftEyePoints:points,rightEyePoints:[],leftBrow:nil,rightBrow:nil,leftBrowPoints:[],rightBrowPoints:[],lips:nil,outerLipPoints:[],innerLipPoints:[],toothRegion:[],nose:nil,down:CGPoint(x:0,y:-1),cheekColor:nil)
 var timings=BeautyAnalysisTimings()
 let output=try BeautyMaskPipeline.generate(source:source,faces:[face],diagnostics:false,profile:false,timings:&timings)
 let mask=CIImage(cgImage:try #require(output.eyes))
 func at(_ x:Int,_ y:Int)->Float {
  var p=[Float](repeating:0,count:4)
  context.render(mask,toBitmap:&p,rowBytes:16,bounds:CGRect(x:x,y:y,width:1,height:1),format:.RGBAf,colorSpace:CGColorSpace(name:CGColorSpace.extendedLinearSRGB)!)
  return p[0]
 }
 #expect(at(40,70)>0.5)
 // All four are inside/near the former expanded ellipse but outside the eye opening.
 for (x,y) in [(40,76),(40,63),(27,70),(53,70),(85,70)] {#expect(at(x,y)<0.001)}
}
