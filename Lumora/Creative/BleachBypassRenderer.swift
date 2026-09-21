import CoreImage

/// Pointwise, resolution-independent silver-density blend in extended linear sRGB.
/// It creates no texture of its own; Film Grain remains a separate stack effect.
struct BleachBypassRenderer: CreativeEffectRendering {
    private static let kernel = CreativeMetal.compile("""
    float bleachCurve(float y, float contrast, float density, float rolloff, float silver) {
        float t = min(y, 1.0);
        float q = t * (1.0 - t);
        float c = contrast * (silver > 0.5 ? 0.38 : 0.25);
        float d = density * (silver > 0.5 ? 0.14 : 0.06);
        float h = rolloff * (silver > 0.5 ? 0.12 : 0.08);
        // Smooth S separation, density toe and highlight shoulder. The bounds
        // keep the derivative positive on [0,1] at every validated setting.
        float shaped = t + c*q*(2.0*t-1.0)
                         - d*t*(1.0-t)*(1.0-t)
                         - h*t*t*(1.0-t);
        if (y <= 1.0) return max(0.0, shaped);
        // Match the left-hand derivative at 1, then compress extended lights.
        float slope = 1.0 - c + h;
        float excess = y - 1.0;
        return 1.0 + slope*excess/(1.0 + rolloff*0.65*excess);
    }
    [[ stitchable ]] float4 bleachBypass(coreimage::sample_t pixel,
            float4 primary, float3 advanced) {
        float4 c = unpremultiply(pixel);
        float3 original = c.rgb;
        float y = max(0.0, dot(max(original, float3(0.0)), float3(0.2126,0.7152,0.0722)));
        float amount = primary.x, bleach = primary.y, contrast = primary.z;
        float residualSaturation = max(0.0, 1.0 + primary.w*0.7);
        float colorY = bleachCurve(y, contrast, advanced.x, advanced.y, 0.0);
        float silverY = bleachCurve(y, contrast, advanced.x, advanced.y, 1.0);
        // The original color is scaled in linear light, preserving its hue.
        float3 colorLayer = y > 1e-8 ? original * (colorY / y) : float3(0.0);
        float3 silverLayer = float3(silverY);
        float3 mixed = mix(colorLayer, silverLayer, bleach);
        float mixedY = mix(colorY, silverY, bleach);
        mixed = float3(mixedY) + (mixed - mixedY)*residualSaturation;
        float shadowGuard = mix(1.0, smoothstep(0.005,0.22,y), advanced.z);
        c.rgb = mix(original, max(mixed,float3(0.0)), amount*shadowGuard);
        return premultiply(c);
    }
    """)

    func apply(_ image: CIImage, effect: CreativeEffect) throws -> CIImage {
        let s = BleachBypassSettings(effect: effect).validated
        guard s.amount > 0 else { return image }
        guard let output = Self.kernel?.apply(extent: image.extent, arguments: [
            image,
            CIVector(x:s.amount/100, y:s.bleach/100, z:s.contrast/100, w:s.saturation/100),
            CIVector(x:s.blackDensity/100, y:s.highlightRollOff/100, z:s.shadowProtection/100)
        ]) else { throw PhotoError.renderFailed }
        return output
    }
}
