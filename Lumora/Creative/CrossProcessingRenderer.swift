import CoreImage
import Foundation

/// Original analytic channel curves. The two coefficients control a bounded
/// quadratic tilt and a cubic S bend. Their magnitudes keep all seven base
/// curves monotone without a sampled LUT or scene-dependent analysis.
struct CrossProcessingCurve: Sendable {
    let a: SIMD3<Double>
    let b: SIMD3<Double>
    static let styles: [Self] = [
        .init(a: .init(0.045, 0.005, -0.030), b: .init(0.015, 0.025, 0.005)), // Subtle
        .init(a: .init(0.170, 0.035, -0.075), b: .init(0.035, 0.005, -0.015)), // Warm
        .init(a: .init(-0.085, 0.005, 0.160), b: .init(-0.020, 0.025, 0.045)), // Cool
        .init(a: .init(-0.020, 0.015, 0.020), b: .init(0.200, -0.050, -0.180)), // Cyan: shadow-biased, neutral midtones
        .init(a: .init(0.045, 0.150, -0.045), b: .init(0.105, -0.055, 0.115)), // Green/Magenta
        .init(a: .init(0.070, 0.020, -0.055), b: .init(-0.040, 0.030, 0.010)), // Vintage
        .init(a: .init(0.220, -0.025, -0.165), b: .init(0.100, -0.075, 0.070)) // Strong
    ]
}

struct CrossProcessingRenderer: CreativeEffectRendering {
    // One GPU pass. The polynomial's x(1-x) factor fixes both endpoints; its
    // continuation is tangent-matched at 0/1, so negative RGB and HDR are not
    // clipped. Hue vectors are made zero-luminance in linear Rec.709 RGB.
    private static let kernel = CreativeMetal.compile("""
    float cpCore(float x, float y, float a, float b, float shadow, float highlight,
                 float lift, float contrast) {
        float s = 1.0 - smoothstep(0.08, 0.58, y);
        float h = smoothstep(0.42, 0.92, y);
        float bend = x * (1.0 - x);
        float shaping = 0.075 * bend * (shadow * s + highlight * h);
        return x + a * bend + (b + 0.20 * contrast) * bend * (2.0*x - 1.0)
               + shaping + lift * (1.0 + 0.12*shadow) * (1.0-x) * (1.0-x);
    }
    float cpCurve(float x, float y, float a, float b, float shadow, float highlight,
                  float lift, float contrast) {
        if (x < 0.0) {
            float f0 = cpCore(0.0,y,a,b,shadow,highlight,lift,contrast);
            float f1 = cpCore(0.0005,y,a,b,shadow,highlight,lift,contrast);
            return f0 + x * max(0.25, (f1-f0)/0.0005);
        }
        if (x > 1.0) {
            float f1 = cpCore(1.0,y,a,b,shadow,highlight,lift,contrast);
            float f0 = cpCore(0.9995,y,a,b,shadow,highlight,lift,contrast);
            return f1 + (x-1.0) * max(0.25, (f1-f0)/0.0005);
        }
        return cpCore(x,y,a,b,shadow,highlight,lift,contrast);
    }
    [[ stitchable ]] float4 crossProcessing(coreimage::sample_t pixel,
                    float4 a, float4 b, float4 shadow, float4 highlight,
                    float4 controls) {
        float4 c = unpremultiply(pixel);
        float y = dot(c.rgb, float3(0.2126,0.7152,0.0722));
        float zone = clamp(y,0.0,1.0);
        float3 processed;
        processed.r = cpCurve(c.r,zone,a.r,b.r,shadow.r,highlight.r,controls.z,controls.y);
        processed.g = cpCurve(c.g,zone,a.g,b.g,shadow.g,highlight.g,controls.z,controls.y);
        processed.b = cpCurve(c.b,zone,a.b,b.b,shadow.b,highlight.b,controls.z,controls.y);
        // Saturation is radial about the linear-light Rec.709 luminance axis:
        // it preserves processed luminance and the intentional hue direction.
        float newY = dot(processed,float3(0.2126,0.7152,0.0722));
        processed = float3(newY) + (processed-float3(newY)) * controls.w;
        c.rgb = mix(c.rgb,processed,controls.x);
        return premultiply(c);
    }
    """)

    static func opponentHue(_ degrees: Double) -> SIMD3<Double> {
        let r = degrees * .pi / 180
        let raw = SIMD3(cos(r), cos(r - 2 * .pi / 3), cos(r + 2 * .pi / 3))
        let y = raw.x * 0.2126 + raw.y * 0.7152 + raw.z * 0.0722
        return raw - SIMD3(repeating: y)
    }

    func apply(_ image: CIImage, effect: CreativeEffect) throws -> CIImage {
        let s = CrossProcessingSettings(effect: effect)
        guard s.amount > 0, s.styleStrength > 0 else { return image }
        // The intentionally subtle base style remains subtle in its preset;
        // manually pushing Amount to 100 reveals a stronger color response.
        let endpoint = CreativeEndpointGain.multiplier(s.amount,
            atMaximum: Int(s.style.rounded()) == 0 ? 4 : 2)
        let strength = s.styleStrength / 100 * endpoint
        let style = CrossProcessingCurve.styles[min(6, max(0, Int(s.style.rounded())))]
        let a = style.a * strength, b = style.b * strength
        let shadows = Self.opponentHue(s.shadowHue) * (s.shadowStrength / 100 * strength)
        let highlights = Self.opponentHue(s.highlightHue) * (s.highlightStrength / 100 * strength)
        let lift = s.blackLift / 100 * 0.065 * strength
        let contrast = s.contrast / 100 * strength
        let saturation = max(0.1, 1 + s.saturation / 100 * 0.55 * strength)
        guard let result = Self.kernel?.apply(extent: image.extent, arguments: [
            image,
            CIVector(x: a.x, y: a.y, z: a.z, w: 0),
            CIVector(x: b.x, y: b.y, z: b.z, w: 0),
            CIVector(x: shadows.x, y: shadows.y, z: shadows.z, w: 0),
            CIVector(x: highlights.x, y: highlights.y, z: highlights.z, w: 0),
            CIVector(x: s.amount / 100, y: contrast, z: lift, w: saturation)
        ]) else { throw PhotoError.renderFailed }
        return result
    }
}
