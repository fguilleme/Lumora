import Foundation
import CoreImage

/// Original Lumora monochrome responses; spectral coefficients operate on a
/// continuous opponent-color basis, not discontinuous HSV sectors or film LUTs.
enum SilverFilmResponse: Int, CaseIterable, Codable, Sendable {
    case neutral, fine, portrait, panchromatic, highContrast, orthochromatic, documentary
    var title: String {
        ["Neutral Silver", "Fine Grain Response", "Portrait Silver", "Classic Panchromatic",
         "High Contrast Film", "Soft Orthochromatic", "Documentary Silver"][rawValue]
    }
    var spectrum: SIMD4<Double> {
        [SIMD4(0.12,0.06,0.025,-0.02), SIMD4(0.08,0.10,-0.04,0.025),
         SIMD4(0.34,0.13,-0.035,0.045), SIMD4(0.04,0.025,0.015,0.01),
         SIMD4(0.14,-0.06,0.045,-0.025), SIMD4(-0.48,0.10,-0.06,0.035),
         SIMD4(-0.08,0.16,0.055,-0.04)][rawValue]
    }
    // Toe exponent, shoulder exponent, shoulder scale. Positive log derivative.
    var tone: SIMD3<Double> {
        [SIMD3(0.13,0.16,0.80), SIMD3(0.09,0.20,0.65), SIMD3(0.07,0.24,0.55),
         SIMD3(0.19,0.18,0.85), SIMD3(0.40,0.26,0.72), SIMD3(0.10,0.22,0.60),
         SIMD3(0.28,0.20,0.95)][rawValue]
    }
}

struct SilverBWSettings: Codable, Sendable, Equatable {
    var amount = 100.0, brightness = 0.0, contrast = 0.0, structure = 0.0
    var filmResponse = 0.0, filterHue = 60.0, filterStrength = 0.0
    var dynamicBrightness = 0.0, softContrast = 0.0, blacks = 0.0, whites = 0.0
    init() {}
    init(effect: CreativeEffect) {
        let e = effect.validated
        amount=e["amount"]; brightness=e["brightness"]; contrast=e["contrast"]; structure=e["structure"]
        filmResponse=e["filmResponse"]; filterHue=e["filterHue"]; filterStrength=e["filterStrength"]
        dynamicBrightness=e["dynamicBrightness"]; softContrast=e["softContrast"]; blacks=e["blacks"]; whites=e["whites"]
    }
    var effect: CreativeEffect {
        var fx = CreativeEffect(.silverBW)
        for (k,v) in [("amount",amount),("brightness",brightness),("contrast",contrast),("structure",structure),
                      ("filmResponse",filmResponse),("filterHue",filterHue),("filterStrength",filterStrength),
                      ("dynamicBrightness",dynamicBrightness),("softContrast",softContrast),("blacks",blacks),("whites",whites)] { fx[k]=v }
        return fx
    }
    var validated: Self { Self(effect:effect) }
}

struct SilverBWRenderer: CreativeEffectRendering {
    private static let conversion = CreativeMetal.compile("""
    float silverLogRatio(float x, float scale) {
        return log((1.0+x/scale)/(1.0+0.18/scale));
    }
    [[ stitchable ]] float4 silverConvert(coreimage::sample_t pixel, float4 spectrum,
                     float3 film, float4 controls, float4 shaping, float2 colorFilter) {
        float4 c=unpremultiply(pixel);
        float3 positive=max(c.rgb,float3(0.0));
        float sum=positive.r+positive.g+positive.b;
        // Normalized opponent chroma tends continuously to zero at black and
        // on neutral colors. First/second circular harmonics distinguish hues.
        float u=(2.0*positive.r-positive.g-positive.b)/(sum+0.000001);
        float v=1.7320508075688772*(positive.g-positive.b)/(sum+0.000001);
        float spectralEV=dot(spectrum,float4(u,v,u*u-v*v,2.0*u*v));
        float filterEV=colorFilter.y*1.05*(u*cos(colorFilter.x)+v*sin(colorFilter.x));
        float density=dot(c.rgb,float3(0.2126,0.7152,0.0722))*exp2(spectralEV+filterEV);
        float x=abs(density)*exp2(controls.x*1.5);
        // Pointwise adaptive brightness; derivative remains positive because
        // |a|/4 < 1. No spatial analysis, blur, halos or CPU readback.
        x*=exp2(controls.y*0.8/(1.0+x/0.35));
        float logGain=film.x*silverLogRatio(x,0.08)-film.y*silverLogRatio(x,film.z)
                    +controls.z*0.24*silverLogRatio(x,0.18)
                    -controls.w*0.16*silverLogRatio(x,0.45)
                    +shaping.x*0.18*silverLogRatio(x,0.04)
                    +shaping.y*0.10*silverLogRatio(x,0.85);
        // Analytic continuation, no SDR clamp. Negative extended RGB follows
        // the odd continuation with the same finite derivative at zero.
        float y=sign(density)*x*exp(logGain);
        return premultiply(float4(y,y,y,c.a));
    }
    """)
    private static let neutralize = CreativeMetal.compile("""
    [[ stitchable ]] float4 silverNeutralize(coreimage::sample_t original, coreimage::sample_t structured) {
        float4 a=unpremultiply(original), b=unpremultiply(structured);
        // Existing structure primitives protect nonnegative luminance. Preserve
        // the analytic negative continuation without changing those primitives.
        float y=a.r<0.0 ? a.r : (b.r+b.g+b.b)/3.0;
        return premultiply(float4(y,y,y,a.a));
    }
    """)
    func apply(_ image: CIImage, effect: CreativeEffect) throws -> CIImage {
        let s=SilverBWSettings(effect:effect)
        guard s.amount>0 else { return image }
        let profile=SilverFilmResponse(rawValue:Int(s.filmResponse.rounded())) ?? .neutral
        let sp=profile.spectrum, t=profile.tone
        guard let monochrome=Self.conversion?.apply(extent:image.extent,arguments:[image,
            CIVector(x:sp.x,y:sp.y,z:sp.z,w:sp.w), CIVector(x:t.x,y:t.y,z:t.z),
            CIVector(x:s.brightness/100,y:s.dynamicBrightness/100,z:s.contrast/100,w:s.softContrast/100),
            CIVector(x:s.blacks/100,y:s.whites/100,z:0,w:0),
            CIVector(x:(s.filterHue.truncatingRemainder(dividingBy:360))*Double.pi/180,y:s.filterStrength/100)])
        else { throw PhotoError.renderFailed }
        var output=monochrome
        if s.structure>0 {
            // Unmodified validated multi-scale primitive, with moderate fixed
            // gains and a photographic radius normalized to the input size.
            var detail=CreativeEffect(.tonalContrast)
            for (key,value) in [("globalAmount",s.structure),("shadows",22.0),("midtones",48.0),
                                ("highlights",28.0),("radius",35.0),("saturation",0.0),
                                ("protectShadows",85.0),("protectHighlights",85.0)] { detail[key]=value }
            let structured=try TonalContrastRenderer().apply(monochrome,effect:detail)
            guard let neutral=Self.neutralize?.apply(extent:image.extent,arguments:[monochrome,structured]) else { throw PhotoError.renderFailed }
            output=neutral
        }
        return try FXBlend.mix(image,output,amount:s.amount/100)
    }
}
