import CoreImage
import Foundation

/// Ordered vector strokes; native-resolution analytic capsules, never a scaled preview bitmap.
enum HealingTargetMask {
  private static let capsule=CreativeMetal.compile("""
  [[ stitchable ]] float4 healingCapsule(coreimage::sample_t previous,float2 a,float2 b,float radius,float feather,float erase,coreimage::destination dest) {
    float2 p=dest.coord(),ab=b-a;
    float t=clamp(dot(p-a,ab)/max(dot(ab,ab),0.000001),0.0,1.0);
    float d=distance(p,a+t*ab)/radius;
    float v=1.0-smoothstep(1.0-feather,1.0,d);
    float m=erase>0.5 ? min(previous.r,1.0-v) : max(previous.r,v);
    return float4(m,m,m,1.0);
  }
  """)
  static func bounds(_ raw:ManualBlemishCorrection, extent:CGRect) -> CGRect {
    let c=raw.validated,side=min(extent.width,extent.height)
    func rect(_ p:MaskPoint,_ r:Double)->CGRect { CGRect(x:extent.minX+p.x*extent.width-r*side,y:extent.maxY-p.y*extent.height-r*side,width:2*r*side,height:2*r*side) }
    var b=rect(c.targetCenter,c.targetRadius)
    for stroke in c.targetStrokes ?? [] where !stroke.erase {for p in stroke.points {b=b.union(rect(p,stroke.radius))}}
    return b.integral.intersection(extent)
  }
  static func image(_ raw:ManualBlemishCorrection,extent:CGRect) throws -> CIImage {
    let c=raw.validated,side=min(extent.width,extent.height)
    var image=CIImage(color:.black).cropped(to:extent)
    let strokes=[HealingTargetStroke(points:[c.targetCenter],radius:c.targetRadius,erase:false)]+(c.targetStrokes ?? [])
    func vector(_ p:MaskPoint)->CIVector {CIVector(x:extent.minX+p.x*extent.width,y:extent.maxY-p.y*extent.height)}
    for stroke in strokes {
      guard let first=stroke.points.first else {continue}
      var prior=first
      for p in stroke.points {
        guard let next=capsule?.apply(extent:extent,arguments:[image,vector(prior),vector(p),stroke.radius*side,c.feather,stroke.erase ? 1.0 : 0.0]) else {throw PhotoError.renderFailed}
        image=next;prior=p
      }
    }
    return image
  }
  /// Identical normalized geometry for bounded CPU patch eligibility checks.
  static func value(_ point:MaskPoint,correction raw:ManualBlemishCorrection,size:CGSize)->Double {
    let c=raw.validated,side=min(size.width,size.height)
    let p=SIMD2(point.x*size.width,point.y*size.height)
    var m=0.0
    for stroke in [HealingTargetStroke(points:[c.targetCenter],radius:c.targetRadius,erase:false)]+(c.targetStrokes ?? []) {
      guard let first=stroke.points.first else {continue};var previous=first
      for end in stroke.points {
        let a=SIMD2(previous.x*size.width,previous.y*size.height),b=SIMD2(end.x*size.width,end.y*size.height),ab=b-a
        let t=min(1,max(0,((p-a).x*ab.x+(p-a).y*ab.y)/max(1e-12,ab.x*ab.x+ab.y*ab.y)))
        let d=hypot((p-a-t*ab).x,(p-a-t*ab).y)/(stroke.radius*side)
        let u=min(1,max(0,(d-(1-c.feather))/c.feather)),v=1-u*u*(3-2*u)
        m=stroke.erase ? min(m,1-v) : max(m,v);previous=end
      }
    };return m
  }
}
