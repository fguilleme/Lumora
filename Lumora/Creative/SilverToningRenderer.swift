import Foundation
import CoreImage

/// Original artistic density responses, not chemical measurements or commercial profiles.
enum SilverToner: Int, CaseIterable, Codable, Sendable {
    case neutral, selenium, sepia, copper, gold, platinum, cool, warm, split
    var title: String { ["Neutral", "Selenium", "Sepia", "Copper", "Gold", "Platinum", "Cool Silver", "Warm Silver", "Split Silver"][rawValue] }
    // Shadow hue, highlight hue, shadow chroma, highlight chroma (RGB hue circle).
    var colors: SIMD4<Double> {
        [SIMD4(0,0,0,0), .init(285,255,0.20,0.008), .init(28,48,0.48,0.09),
         .init(9,33,0.55,0.035), .init(235,265,0.32,0.055), .init(38,50,0.065,0.018),
         .init(195,215,0.20,0.025), .init(40,52,0.18,0.035), .init(220,40,0.38,0.26)][rawValue]
    }
    var densityExponent: Double { [1,1.8,0.65,1.15,0.95,0.55,1.4,0.85,1][rawValue] }
}

struct SilverToningSettings: Codable, Equatable, Sendable {
    var amount=100.0, toner=0.0, strength=50.0, balance=0.0
    var shadowStrength=100.0, highlightStrength=100.0, paperTone=0.0, silverTone=100.0
    var shadowHue=220.0, highlightHue=40.0
    init() {}
    init(effect: CreativeEffect) {
        let e=effect.validated
        amount=e["amount"];toner=e["toner"];strength=e["strength"];balance=e["balance"]
        shadowStrength=e["shadowStrength"];highlightStrength=e["highlightStrength"]
        paperTone=e["paperTone"];silverTone=e["silverTone"];shadowHue=e["shadowHue"];highlightHue=e["highlightHue"]
    }
    var effect: CreativeEffect {
        var e=CreativeEffect(.silverToning)
        for (k,v) in [("amount",amount),("toner",toner),("strength",strength),("balance",balance),
                      ("shadowStrength",shadowStrength),("highlightStrength",highlightStrength),
                      ("paperTone",paperTone),("silverTone",silverTone),("shadowHue",shadowHue),("highlightHue",highlightHue)] { e[k]=v }
        return e
    }
    var validated: Self { Self(effect:effect) }
}

struct SilverToningRenderer: CreativeEffectRendering {
    private static let kernel=CreativeMetal.compile("""
    float3 printDirection(float degrees) {
        float h=degrees*0.017453292519943295;
        float3 v=float3(cos(h),cos(h-2.0943951023931953),cos(h+2.0943951023931953));
        // Project the smooth hue circle onto the constant linear-luminance plane.
        return v-dot(v,float3(0.2126,0.7152,0.0722));
    }
    [[ stitchable ]] float4 silverToning(coreimage::sample_t pixel, float4 colors,
                                          float4 controls, float4 contributions) {
        float4 c=unpremultiply(pixel);
        float y=dot(c.rgb,float3(0.2126,0.7152,0.0722));
        float positive=max(y,0.0);
        float scale=0.18*exp2(controls.y*2.0);
        // D=log2(1+scale/(Y+epsilon)); t=2^-D. Avoid a logarithm at black.
        float t=(positive+0.000001)/(positive+0.000001+scale);
        float shadow=pow(1.0-t,controls.z), highlight=t*t;
        float3 silver=printDirection(colors.x)*colors.z*shadow*contributions.x
                     +printDirection(colors.y)*colors.w*highlight*contributions.y;
        float paperCoordinate=positive/(positive+0.35);
        float3 paper=printDirection(contributions.z<0.0 ? 215.0:45.0)
                     *abs(contributions.z)*0.12*pow(paperCoordinate,4.0);
        // C1 continuation at Y=0: negative-luminance inputs remain unchanged.
        // Preserve existing RGB chroma, alpha and HDR. No gamut clamp or spatial work.
        float amplitude=positive*positive/(positive+0.02);
        float3 delta=amplitude*controls.x*(contributions.w*silver+paper);
        return premultiply(float4(c.rgb+delta*controls.w,c.a));
    }
    """)
    func apply(_ image: CIImage, effect: CreativeEffect) throws -> CIImage {
        let s=SilverToningSettings(effect:effect)
        let toner=SilverToner(rawValue:Int(s.toner.rounded())) ?? .neutral
        guard s.amount>0, s.strength>0, toner != .neutral else { return image }
        var colors=toner.colors
        if toner == .split { colors.x=s.shadowHue;colors.y=s.highlightHue }
        guard let output=Self.kernel?.apply(extent:image.extent,arguments:[image,
            CIVector(x:colors.x,y:colors.y,z:colors.z,w:colors.w),
            CIVector(x:s.strength/100,y:s.balance/100,z:toner.densityExponent,w:s.amount/100),
            CIVector(x:s.shadowStrength/100,y:s.highlightStrength/100,z:s.paperTone/100,w:s.silverTone/100)])
        else { throw PhotoError.renderFailed }
        return output
    }
}
