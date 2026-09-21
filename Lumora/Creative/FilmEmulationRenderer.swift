import CoreImage
import Foundation

/// Parametric color-negative/slide response. These original values are the
/// source of truth: no external film profile or LUT is loaded or generated.
struct FilmResponseParameters: Sendable {
    let toe: Double, midSlope: Double, shoulder: Double
    let toeExposure: Double, shoulderExposure: Double
    let toeWidth: Double, shoulderWidth: Double
    let channelSlope: SIMD3<Double>
    let coupling: Double
    let shadowSaturation: Double, midtoneSaturation: Double, highlightSaturation: Double

    static let styles: [Self] = [
        // High-latitude negative: gentle toe and shoulder, restrained chroma.
        .init(toe:0.13,midSlope:1.08,shoulder:0.23,toeExposure:0.075,shoulderExposure:0.70,
              toeWidth:1.10,shoulderWidth:1.30,channelSlope:.init(0.006,0,-0.006),coupling:0.008,
              shadowSaturation:-0.10,midtoneSaturation:0.035,highlightSaturation:-0.13),
        // Creamier shoulder and modest warm layer asymmetry around skin tones.
        .init(toe:0.11,midSlope:1.035,shoulder:0.27,toeExposure:0.075,shoulderExposure:0.58,
              toeWidth:1.15,shoulderWidth:1.45,channelSlope:.init(0.018,0,-0.012),coupling:0.010,
              shadowSaturation:-0.07,midtoneSaturation:0.025,highlightSaturation:-0.17),
        // Punchy chrome response, with a firmer toe and shoulder.
        .init(toe:0.24,midSlope:1.29,shoulder:0.37,toeExposure:0.12,shoulderExposure:0.68,
              toeWidth:0.82,shoulderWidth:0.86,channelSlope:.init(0.010,0,-0.005),coupling:0.010,
              shadowSaturation:0.015,midtoneSaturation:0.18,highlightSaturation:0.045),
        // Reserved palette, cool lower layers, soft high end.
        .init(toe:0.15,midSlope:1.13,shoulder:0.29,toeExposure:0.09,shoulderExposure:0.62,
              toeWidth:1.04,shoulderWidth:1.22,channelSlope:.init(-0.008,0,0.012),coupling:0.022,
              shadowSaturation:-0.18,midtoneSaturation:-0.10,highlightSaturation:-0.24),
        // Low-density print character without adding a veil or lifting pure black.
        .init(toe:-0.065,midSlope:0.91,shoulder:0.23,toeExposure:0.065,shoulderExposure:0.59,
              toeWidth:1.35,shoulderWidth:1.50,channelSlope:.init(0.005,0,-0.004),coupling:0.013,
              shadowSaturation:-0.17,midtoneSaturation:-0.09,highlightSaturation:-0.21),
        // More layer asymmetry, while remaining milder than Cross Processing.
        .init(toe:0.105,midSlope:1.07,shoulder:0.27,toeExposure:0.08,shoulderExposure:0.57,
              toeWidth:1.10,shoulderWidth:1.25,channelSlope:.init(0.025,0.003,-0.022),coupling:0.027,
              shadowSaturation:-0.24,midtoneSaturation:-0.045,highlightSaturation:-0.20),
        // Deliberately narrower latitude and denser shadows than the negative.
        .init(toe:0.31,midSlope:1.34,shoulder:0.46,toeExposure:0.15,shoulderExposure:0.55,
              toeWidth:0.76,shoulderWidth:0.76,channelSlope:.init(0.012,0,-0.009),coupling:0.014,
              shadowSaturation:-0.015,midtoneSaturation:0.135,highlightSaturation:-0.04)
    ]
}

struct FilmEmulationRenderer: CreativeEffectRendering {
    // Exposure is applied before the characteristic response. z=log2(1+x/q)
    // is finite at zero; g(z) integrates a positive, smoothly varying slope:
    // g' = midSlope - toe*sigmoid((toeCenter-z)/toeWidth)
    //               - shoulder*sigmoid((z-shoulderCenter)/shoulderWidth).
    // The softplus differences make g(0)=0. A neutral-midgray anchor keeps
    // film families comparable; HDR follows the same monotone expression.
    private static let kernel = CreativeMetal.compile("""
    float filmSoftplus(float v) { return max(v,0.0) + log(1.0+exp(-abs(v))); }
    float filmRaw(float x, float toe, float mid, float shoulder, float4 geometry) {
        const float q=0.03;
        float z=log2(1.0+x/q);
        float toeTerm=toe*geometry.z*(filmSoftplus((geometry.x-z)/geometry.z)
                                    -filmSoftplus(geometry.x/geometry.z));
        float shoulderTerm=shoulder*geometry.w*(filmSoftplus((z-geometry.y)/geometry.w)
                                              -filmSoftplus(-geometry.y/geometry.w));
        float g=mid*z+toeTerm-shoulderTerm;
        return q*(exp2(g)-1.0);
    }
    float filmCurve(float x, float toe, float mid, float shoulder, float4 geometry) {
        float anchor=0.18/max(0.000001,filmRaw(0.18,toe,mid,shoulder,geometry));
        if (x<=0.0) {
            float baseSlope=mid-toe/(1.0+exp(-geometry.x/geometry.z))
                               -shoulder/(1.0+exp(geometry.y/geometry.w));
            return x*max(0.1,baseSlope)*anchor;
        }
        return filmRaw(x,toe,mid,shoulder,geometry)*anchor;
    }
    [[ stitchable ]] float4 filmEmulation(coreimage::sample_t pixel,
                    float4 tone, float4 geometry, float4 channels,
                    float4 chroma, float4 controls) {
        float4 c=unpremultiply(pixel);
        float3 exposed=c.rgb*controls.y;
        float3 shifted;
        float3 offsets=controls.w>=1.0 ? channels.xyz : float3(0.0);
        shifted.r=filmCurve(exposed.r,tone.x*(1.0+2.0*offsets.r),tone.y+offsets.r,
                             tone.z*(1.0-2.0*offsets.r),geometry);
        shifted.g=filmCurve(exposed.g,tone.x*(1.0+2.0*offsets.g),tone.y+offsets.g,
                             tone.z*(1.0-2.0*offsets.g),geometry);
        shifted.b=filmCurve(exposed.b,tone.x*(1.0+2.0*offsets.b),tone.y+offsets.b,
                             tone.z*(1.0-2.0*offsets.b),geometry);
        // Row-sum-one, diagonally dominant layer crosstalk. Neutral grays
        // remain neutral if the channel responses are equal.
        float k=controls.w>=2.0 ? channels.w : 0.0;
        float3 coupled=shifted+k*float3(shifted.g+shifted.b-2.0*shifted.r,
                                       shifted.r+shifted.b-2.0*shifted.g,
                                       shifted.r+shifted.g-2.0*shifted.b);
        float y=dot(coupled,float3(0.2126,0.7152,0.0722));
        float zone=clamp(y,0.0,1.0);
        float sw=1.0-smoothstep(0.07,0.43,zone);
        float hw=smoothstep(0.56,0.96,zone);
        float mw=max(0.0,1.0-sw-hw);
        float saturation=controls.w>=3.0 ?
            max(0.1,controls.z+chroma.w*(sw*chroma.x+mw*chroma.y+hw*chroma.z)) : 1.0;
        float3 processed=float3(y)+(coupled-float3(y))*saturation;
        c.rgb=mix(c.rgb,processed,controls.x);
        return premultiply(c);
    }
    """)

    func apply(_ image: CIImage, effect: CreativeEffect) throws -> CIImage {
        try applyStages(image,effect:effect,stage:3)
    }

    /// Uses the identical production kernel for lab decomposition; stage 3 is
    /// always used in normal Creative rendering. No separate test renderer.
    func applyStages(_ image:CIImage,effect:CreativeEffect,stage:Int) throws -> CIImage {
        let s=FilmEmulationSettings(effect:effect)
        guard s.amount>0 else{return image}
        if s.filmStrength==0 && s.exposure==0 {return image}
        let p=FilmResponseParameters.styles[min(6,max(0,Int(s.style.rounded())))]
        let strength=s.filmStrength/100
        let toe=p.toe*strength+0.15*s.shadowDensity/100*strength
        let mid=1+(p.midSlope-1)*strength+0.23*s.contrast/100*strength
        let shoulder=max(0,p.shoulder*strength+0.18*s.highlightRollOff/100*strength)
        let q=0.03
        let toeCenter=log2(1+p.toeExposure/q),shoulderCenter=log2(1+p.shoulderExposure/q)
        let color=strength*s.colorResponse/100
        let channel=p.channelSlope*color
        let coupling=p.coupling*color
        let saturation=max(0.1,1+s.saturation/100*0.5*strength)
        guard let result=Self.kernel?.apply(extent:image.extent,arguments:[
            image,
            CIVector(x:toe,y:mid,z:shoulder,w:0),
            CIVector(x:toeCenter,y:shoulderCenter,z:p.toeWidth,w:p.shoulderWidth),
            CIVector(x:channel.x,y:channel.y,z:channel.z,w:coupling),
            CIVector(x:p.shadowSaturation,y:p.midtoneSaturation,z:p.highlightSaturation,w:color),
            CIVector(x:s.amount/100,y:pow(2,s.exposure),z:saturation,w:Double(min(3,max(0,stage))))
        ]) else {throw PhotoError.renderFailed}
        return result
    }
}
