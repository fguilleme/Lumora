import CoreImage
import Foundation
import Testing
@testable import LumoraCore

private func areaRead(_ image:CIImage)->[Float] {
 let e=image.extent.integral
 var pixels=[Float](repeating:0,count:Int(e.width*e.height)*4)
 CIContext(options:[.workingColorSpace:CGColorSpace(name:CGColorSpace.extendedLinearSRGB)!]).render(image,toBitmap:&pixels,rowBytes:Int(e.width)*16,bounds:e,format:.RGBAf,colorSpace:CGColorSpace(name:CGColorSpace.extendedLinearSRGB)!)
 return pixels
}
private func areaCorrection()->ManualBlemishCorrection {
 var c=ManualBlemishCorrection(targetCenter:.init(x:0.4,y:0.45),targetRadius:0.05,sourceCenter:.init(x:0.65,y:0.45))
 c.targetStrokes=[.init(points:[.init(x:0.4,y:0.45),.init(x:0.48,y:0.49)],radius:0.025,erase:false),.init(points:[.init(x:0.405,y:0.45)],radius:0.018,erase:true),.init(points:[.init(x:0.405,y:0.45)],radius:0.006,erase:false)]
 return c
}
@Test func healingAreaOrderedStrokesAndNativeResolution() throws {
 let c=areaCorrection(),e=CGRect(x:0,y:0,width:512,height:512)
 let m=try HealingTargetMask.image(c,extent:e),a=areaRead(m)
 var maximum=0.0
 for y in 0..<512 {for x in 0..<512 {
  let point=MaskPoint(x:(Double(x)+0.5)/512,y:(Double(y)+0.5)/512)
  maximum=max(maximum,abs(Double(a[(y*512+x)*4])-HealingTargetMask.value(point,correction:c,size:e.size)))
 }}
 #expect(maximum<0.003)
 #expect(HealingTargetMask.value(.init(x:0.405,y:0.45),correction:c,size:e.size)>0.99)
 #expect(HealingTargetMask.value(.init(x:0.415,y:0.45),correction:c,size:e.size)<0.1)
 let high=try HealingTargetMask.image(c,extent:CGRect(x:0,y:0,width:1024,height:1024)).transformed(by:.init(scaleX:0.5,y:0.5)).cropped(to:e)
 let b=areaRead(high)
 let mae=zip(a,b).reduce(0.0){$0+Double(abs($1.0-$1.1))}/Double(a.count)
 #expect(mae<0.001)
}
@Test func healingAreaPersistenceMigrationHistoryAndTransforms() throws {
 let c=areaCorrection()
 #expect(try JSONDecoder().decode(ManualBlemishCorrection.self,from:JSONEncoder().encode(c))==c)
 var json=try #require(JSONSerialization.jsonObject(with:JSONEncoder().encode(c)) as? [String:Any]);json.removeValue(forKey:"targetStrokes");json.removeValue(forKey:"manualSource");json["version"]=1
 let legacy=try JSONDecoder().decode(ManualBlemishCorrection.self,from:JSONSerialization.data(withJSONObject:json))
 #expect(legacy.targetStrokes == nil && legacy.targetCenter==c.targetCenter)
 var state=EditState(),history=HistoryManager()
 state.beauty.corrections=[legacy];let before=state
 history.begin("Paint Zone",state:state);state.beauty.corrections=[c];history.commit(state)
 let after=state
 let undone=history.undo();state=try #require(undone);#expect(state==before)
 let redone=history.redo();state=try #require(redone);#expect(state==after)
 var moved=c;moved.moveTarget(to:.init(x:0.5,y:0.55));moved.resizeTarget(to:0.025)
 #expect(abs(moved.targetStrokes![0].points[1].x-0.54)<1e-9)
 for rotation in 0...3 {
  var g=GeometrySettings();g.quarterTurns=rotation;g.flipHorizontal=true;g.cropZoom=12;g.perspectiveVertical=14;g.straighten=5
  let map=HealingGeometry(size:.init(width:1200,height:1800),settings:g)
  for stroke in c.targetStrokes! {for p in stroke.points {
   let q=map.canonical(map.display(p));#expect(hypot(q.x-p.x,q.y-p.y)<1e-8)
  }}
 }
}
@Test func healingAreaLocalityMultipleAndIdentity() throws {
 let e=CGRect(x:0,y:0,width:128,height:128)
 let source=CIImage(color:CIColor(red:1.4,green:0.8,blue:0.2)).cropped(to:e)
 var c=areaCorrection();c.strength=100
 let original=areaRead(source),mask=areaRead(try HealingTargetMask.image(c,extent:e))
 let output=areaRead(try ManualHealingRenderer.apply(source,corrections:[c]))
 for i in stride(from:0,to:output.count,by:4) {
  #expect(output[i].isFinite)
  if mask[i]==0 {#expect(abs(output[i]-original[i])<0.002)}
 }
 for count in [1,5,10,25] {
  var corrections=[ManualBlemishCorrection]()
  for i in 0..<count {var next=c;next.moveTarget(to:.init(x:0.2+Double(i%5)*0.12,y:0.2+Double(i/5)*0.12));corrections.append(next)}
  let a=areaRead(try ManualHealingRenderer.apply(source,corrections:corrections)),b=areaRead(try ManualHealingRenderer.apply(source,corrections:corrections))
  #expect(a==b && a.allSatisfy(\.isFinite))
 }
 c.strength=0
 #expect(try ManualHealingRenderer.apply(source,corrections:[c]) === source)
}

@Test func healingResizedTargetPreservesRelativeFeather() throws {
 let extent=CGRect(x:0,y:0,width:1000,height:1000)
 var correction=ManualBlemishCorrection(targetCenter:.init(x:0.5,y:0.5),targetRadius:0.01,sourceCenter:.init(x:0.65,y:0.5))
 var profiles=[[Double]]()
 for radius in [0.01,0.02] {
  correction.resizeTarget(to:radius)
  let pixels=areaRead(try HealingTargetMask.image(correction,extent:extent))
  var profile=[Double]()
  for fraction in [0.6,0.7,0.8,0.9,1.0] {
   let point=MaskPoint(x:0.5+radius*fraction,y:0.5)
   profile.append(HealingTargetMask.value(point,correction:correction,size:extent.size))
  }
  #expect(profile[1]>profile[2] && profile[2]>profile[3])
  #expect(profile[4]<1e-10)
  // Check the actual GPU transition, including pixel-center sampling.
  for x in 500..<Int(500+radius*1000+2) {
   let expected=HealingTargetMask.value(.init(x:(Double(x)+0.5)/1000,y:0.5005),correction:correction,size:extent.size)
   #expect(abs(Double(pixels[(500*1000+x)*4])-expected)<0.003)
  }
  profiles.append(profile)
 }
 #expect(zip(profiles[0],profiles[1]).allSatisfy {abs($0-$1)<1e-10})
}
