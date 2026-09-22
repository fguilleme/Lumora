import Foundation
import CoreImage

struct DarkenLightenCenterSettings: Codable, Equatable, Sendable {
    var amount=100.0, centerX=0.5, centerY=0.5, centerEV=0.0, borderEV=0.0
    var size=45.0, shape=0.0, feather=75.0, rotation=0.0
    init() {}
    init(effect:CreativeEffect) {
        let e=effect.validated
        amount=e["amount"];centerX=e["centerX"];centerY=e["centerY"];centerEV=e["centerEV"];borderEV=e["borderEV"]
        size=e["size"];shape=e["shape"];feather=e["feather"];rotation=e["rotation"]
    }
    var effect:CreativeEffect {
        var e=CreativeEffect(.darkenLightenCenter)
        for (k,v) in [("amount",amount),("centerX",centerX),("centerY",centerY),("centerEV",centerEV),
                      ("borderEV",borderEV),("size",size),("shape",shape),("feather",feather),("rotation",rotation)] {e[k]=v}
        return e
    }
    var validated:Self {Self(effect:effect)}
    /// In units of the image's short side, constant ellipse area at fixed Size.
    var radii:CGSize {let aspect=pow(2,shape/100);return CGSize(width:size/100*aspect,height:size/100/aspect)}
    var transitionWidth:Double {0.15+0.85*feather/100}
}

/// UI geometry only: same aspect-fit, center-based zoom and screen-space pan as PhotoCanvas.
/// Kept pure so coordinate round trips can be checked without SwiftUI or a renderer readback.
struct DLCViewport {
    let imageRect:CGRect
    init(image:CGSize,view:CGSize,zoom:CGFloat=1,pan:CGSize = .zero) {
        let scale=min(view.width/max(1,image.width),view.height/max(1,image.height))*zoom
        let w=image.width*scale,h=image.height*scale
        imageRect=CGRect(x:(view.width-w)/2+pan.width,y:(view.height-h)/2+pan.height,width:w,height:h)
    }
    func screen(_ point:CGPoint)->CGPoint {CGPoint(x:imageRect.minX+point.x*imageRect.width,y:imageRect.minY+point.y*imageRect.height)}
    func normalized(_ point:CGPoint)->CGPoint {CGPoint(x:min(1,max(0,(point.x-imageRect.minX)/max(1e-12,imageRect.width))),y:min(1,max(0,(point.y-imageRect.minY)/max(1e-12,imageRect.height))))}
}

struct DarkenLightenCenterRenderer:CreativeEffectRendering {
    private static let kernel=CreativeMetal.compile("""
    [[ stitchable ]] float4 darkenLightenCenter(coreimage::sample_t pixel, float4 frame, float4 geometry,
                                               float4 exposure, float2 axes, coreimage::destination dest) {
        float shortSide=min(frame.z,frame.w);
        // Top-left normalized image coordinates, including translated CI extents.
        float2 p=float2(dest.coord().x-frame.x-geometry.x*frame.z,
                        frame.y+frame.w-dest.coord().y-geometry.y*frame.w)/shortSide;
        float c=cos(geometry.z),s=sin(geometry.z);
        float2 q=float2(c*p.x+s*p.y,-s*p.x+c*p.y)/axes;
        float d=length(q);
        float t=clamp((d-(1.0-geometry.w))/geometry.w,0.0,1.0);
        float m=1.0-t*t*t*(t*(t*6.0-15.0)+10.0);
        float ev=exposure.y+(exposure.x-exposure.y)*m;
        float gain=1.0+exposure.z*(exp2(ev)-1.0);
        // Linear RGB, including negative/HDR and premultiplied alpha; no clipping.
        return float4(pixel.rgb*gain,pixel.a);
    }
    """)
    func apply(_ image:CIImage,effect:CreativeEffect) throws -> CIImage {
        let s=DarkenLightenCenterSettings(effect:effect)
        guard s.amount>0, s.centerEV != 0 || s.borderEV != 0 else {return image}
        let e=image.extent,r=s.radii
        guard e.width>0,e.height>0,e.width.isFinite,e.height.isFinite else {throw PhotoError.renderFailed}
        // A circle has no rotation. Canonicalization also guarantees bitwise invariance.
        let angle=s.shape==0 ? 0:s.rotation*Double.pi/180
        guard let out=Self.kernel?.apply(extent:e,arguments:[image,
            CIVector(x:e.minX,y:e.minY,z:e.width,w:e.height),
            CIVector(x:s.centerX,y:s.centerY,z:angle,w:s.transitionWidth),
            CIVector(x:s.centerEV,y:s.borderEV,z:s.amount/100,w:0),CIVector(x:r.width,y:r.height)]) else {throw PhotoError.renderFailed}
        return out
    }
}
