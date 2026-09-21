import CoreImage

/// Content-gated optical diffusion. Only luminous source energy enters the
/// three-scale field; recombination protects the receiving pixel's shadows and
/// highlight headroom. All images remain in the existing linear-light CI graph.
struct GlamourGlowRenderer: CreativeEffectRendering {
    private static let extract = CreativeMetal.compile("""
    [[ stitchable ]] float4 glamourExtract(coreimage::sample_t pixel, float threshold) {
        float4 c = unpremultiply(pixel);
        float y = max(0.0, dot(max(c.rgb, float3(0.0)), float3(0.2126, 0.7152, 0.0722)));
        float lightness = sqrt(y);
        float knee = 0.30 + threshold * 0.55;
        float weight = smoothstep(knee - 0.20, knee + 0.25, lightness);
        return premultiply(float4(max(c.rgb, float3(0.0)) * weight, c.a));
    }
    """)

    private static let combine = CreativeMetal.compile("""
    [[ stitchable ]] float4 glamourCombine(coreimage::sample_t pixel,
            coreimage::sample_t small, coreimage::sample_t medium,
            coreimage::sample_t large, float4 controls, float2 protection) {
        float4 c = unpremultiply(pixel);
        float3 field = max(float3(0.0), 0.50 * unpremultiply(small).rgb
                        + 0.32 * unpremultiply(medium).rgb
                        + 0.18 * unpremultiply(large).rgb);
        float warmth = controls.z;
        float3 tint = warmth >= 0.0
            ? float3(1.0 + 0.16 * warmth, 1.0 + 0.025 * warmth, 1.0 - 0.13 * warmth)
            : float3(1.0 + 0.11 * warmth, 1.0 - 0.015 * warmth, 1.0 - 0.15 * warmth);
        tint /= dot(tint, float3(0.2126, 0.7152, 0.0722));
        float y = max(0.0, dot(max(c.rgb, float3(0.0)), float3(0.2126, 0.7152, 0.0722)));
        // A little light can reach a protected black neighbor; distant black
        // remains black because the extracted field itself is zero there.
        float shadowGuard = mix(1.0, 0.12 + 0.88 * smoothstep(0.005, 0.22, y), protection.y);
        float highlightGuard = 1.0 - 0.85 * protection.x * smoothstep(0.68, 1.08, y);
        float strength = controls.x * controls.y * shadowGuard * highlightGuard;
        float3 addition = field * tint * strength;
        float3 headroom = max(float3(0.0), float3(1.0) - c.rgb);
        addition = min(addition, headroom * (2.0 - 1.65 * protection.x));
        c.rgb += max(addition, float3(0.0));
        return premultiply(c);
    }
    """)

    func apply(_ image: CIImage, effect: CreativeEffect) throws -> CIImage {
        let settings = GlamourGlowSettings(effect: effect).validated
        guard settings.amount > 0, settings.glow > 0 else { return image }
        guard let highlights = Self.extract?.apply(extent: image.extent,
                                                   arguments: [image, settings.threshold / 100])
        else { throw PhotoError.renderFailed }
        let scale = max(image.extent.width, image.extent.height) / 3000
        let photographicRadius = 1.5 + 8 * settings.softness / 100
        func diffuse(radius: Double, sampling: CGFloat) -> CIImage {
            let source = sampling == 1 ? highlights
                : highlights.transformed(by: CGAffineTransform(scaleX: sampling, y: sampling))
            let blurred = source.clampedToExtent().applyingFilter("CIGaussianBlur", parameters: [
                kCIInputRadiusKey: max(0.4, radius * scale * sampling)
            ]).cropped(to: source.extent)
            return (sampling == 1 ? blurred
                : blurred.transformed(by: CGAffineTransform(scaleX: 1 / sampling, y: 1 / sampling)))
                .cropped(to: image.extent)
        }
        let small = diffuse(radius: photographicRadius, sampling: 1)
        let medium = diffuse(radius: photographicRadius * 3, sampling: 0.5)
        let large = diffuse(radius: photographicRadius * 10, sampling: 0.25)
        guard let output = Self.combine?.apply(extent: image.extent, arguments: [
            image, small, medium, large,
            CIVector(x: settings.amount / 100, y: 0.12 + 0.88 * settings.glow / 100,
                     z: settings.warmth / 100, w: 0),
            CIVector(x: settings.highlightProtection / 100, y: settings.shadowProtection / 100)
        ]) else { throw PhotoError.renderFailed }
        return output
    }
}
