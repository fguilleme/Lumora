import CoreGraphics
import CoreImage
import Foundation

/// All color math runs on extended-linear RGB Core Image surfaces. The only
/// 8-bit data are cached matte weights, never the retouched image.
enum BeautyRenderer {
    private static let frequency = CreativeMetal.compile( """
    [[ stitchable ]] float4 beautyFrequency(coreimage::sample_t original,
        coreimage::sample_t low, coreimage::sample_t broad,
        coreimage::sample_t skin, float2 controls) {
        float4 c = unpremultiply(original);
        float3 l = unpremultiply(low).rgb;
        float3 b = unpremultiply(broad).rgb;
        float3 high = c.rgb - l;
        float3 adjusted = l + controls.x * (b - l) + high * (1.0 + controls.y);
        float weight = clamp(unpremultiply(skin).r, 0.0, 1.0);
        return premultiply(float4(mix(c.rgb, adjusted, weight), c.a));
    }
    """)
    private static let blemish = CreativeMetal.compile( """
    [[ stitchable ]] float4 beautyBlemish(coreimage::sample_t original,
        coreimage::sample_t fine, coreimage::sample_t nearby,
        coreimage::sample_t mask, float amount) {
        float4 c = unpremultiply(original);
        float3 f = unpremultiply(fine).rgb;
        float3 n = unpremultiply(nearby).rgb;
        float weight = clamp(unpremultiply(mask).r * amount, 0.0, 0.92);
        // Transfer only the local low-frequency discrepancy; original pores
        // and hair detail remain in c - f instead of being blurred away.
        float3 correction = clamp(n - f, float3(-0.20), float3(0.20));
        return premultiply(float4(c.rgb + correction * weight, c.a));
    }
    """)
    private static let underEye = CreativeMetal.compile( """
    [[ stitchable ]] float4 beautyUnderEye(coreimage::sample_t original,
        coreimage::sample_t localLow, coreimage::sample_t cheekLow,
        coreimage::sample_t mask, float amount) {
        float4 c = unpremultiply(original);
        float weight = clamp(unpremultiply(mask).r * amount, 0.0, 1.0);
        float3 local = unpremultiply(localLow).rgb;
        float3 cheek = unpremultiply(cheekLow).rgb;
        const float3 lum = float3(0.2126, 0.7152, 0.0722);
        float localY = dot(local, lum), cheekY = dot(cheek, lum);
        // The cheek is a local, image-derived reference, not a prescribed
        // skin color. Retain some hollow by correcting only a fraction of the
        // broad tonal gap; never lift above the nearby cheek level.
        float lift = min(max(cheekY - localY - 0.012, 0.0) * 0.68,
                         min(0.16, max(0.0, cheekY) * 0.35));
        float3 localChroma = local - localY;
        float3 cheekChroma = cheek - cheekY;
        float3 chromaShift = clamp((cheekChroma - localChroma) * 0.30,
                                   float3(-0.045), float3(0.045));
        // The correction is low frequency; all high-frequency detail in the
        // original pixel survives unchanged.
        return premultiply(float4(c.rgb + weight * (float3(lift) + chromaShift), c.a));
    }
    """)
    private static let eyes = CreativeMetal.compile( """
    [[ stitchable ]] float4 beautyEyes(coreimage::sample_t original,
        coreimage::sample_t nearby, coreimage::sample_t mask, float2 controls) {
        float4 c = unpremultiply(original);
        float3 n = unpremultiply(nearby).rgb;
        float weight = clamp(unpremultiply(mask).r, 0.0, 1.0);
        float y = max(0.0, dot(c.rgb, float3(0.2126, 0.7152, 0.0722)));
        // The upper slider range is intentionally strong; black pupils and
        // existing white catchlights stay protected. Gain preserves iris hue.
        float brightnessGate = smoothstep(0.01, 0.12, y)
                             * (1.0-smoothstep(0.65, 1.0, y));
        float brightnessGain = exp2(controls.x * 1.0 * brightnessGate * weight);
        float nearbyY = dot(n, float3(0.2126, 0.7152, 0.0722));
        float detail = clamp((y-nearbyY)/max(y,0.02), -0.5, 0.5);
        float detailGain = 1.0 + detail * controls.y * 1.2 * weight;
        float3 adjusted = c.rgb * brightnessGain * detailGain;
        return premultiply(float4(adjusted, c.a));
    }
    """)
    private static let teeth = CreativeMetal.compile( """
    [[ stitchable ]] float4 beautyTeeth(coreimage::sample_t original,
        coreimage::sample_t mask, float amount) {
        float4 c = unpremultiply(original);
        float weight = clamp(unpremultiply(mask).r * amount, 0.0, 1.0);
        float3 adjusted = c.rgb;
        adjusted.b = mix(c.b, 0.5 * (c.r + c.g), 0.20 * weight);
        adjusted *= 1.0 + 0.07 * weight;
        return premultiply(float4(adjusted, c.a));
    }
    """)

    static func apply(_ input: CIImage, settings raw: BeautyState, masks: BeautyMasks) throws -> CIImage {
        let settings = raw.validated
        guard !settings.isIdentity, masks.faceCount > 0 else { return input }
        let amount = settings.amount / 100
        // A radius tied to face width yields the same spatial frequency in a
        // 960-pixel preview, a 2048-pixel HQ image and full-resolution export.
        let faceWidth = CGFloat(max(1, masks.faceWidthFraction * input.extent.width))
        let radius = min(42, max(1.5, faceWidth * 0.018))
        var image = input
        if let mask = masks.skin, settings.uniformity != 0 || settings.texture != 0 {
            let low = gaussian(input, radius: radius)
            let broad = gaussian(low, radius: radius * 2.5)
            guard let output = frequency?.apply(extent: input.extent, arguments: [
                input, low, broad, scaled(mask, to: input.extent),
                CIVector(x: settings.uniformity / 100 * amount * 0.35,
                         y: settings.texture / 100 * amount * 0.24)
            ]) else { throw PhotoError.renderFailed }
            image = output
        }
        if let mask = masks.blemishes, settings.blemishes > 0 {
            let fine = gaussianClamped(image, radius: max(1, faceWidth * 0.002))
            let nearby = gaussianClamped(image, radius: max(6, faceWidth * 0.028))
            guard let output = blemish?.apply(extent: input.extent, arguments: [
                image, fine, nearby, scaled(mask, to: input.extent),
                settings.blemishes / 100 * amount
            ]) else { throw PhotoError.renderFailed }
            image = output
        }
        if let mask = masks.underEyes, settings.darkCircles > 0 {
            let localLow = gaussianClamped(image, radius: max(3, faceWidth * 0.012))
            let cheekLow = gaussianClamped(image, radius: max(7, faceWidth * 0.035))
                .clampedToExtent()
                .transformed(by: CGAffineTransform(translationX: 0,
                                                    y: faceWidth * 0.11))
                .cropped(to: input.extent)
            let softMask = gaussianClamped(scaled(mask, to: input.extent),
                                           radius: max(1, faceWidth * 0.006))
            guard let output = underEye?.apply(extent: input.extent, arguments: [
                image, localLow, cheekLow, softMask,
                settings.darkCircles / 100 * amount
            ]) else { throw PhotoError.renderFailed }
            image = output
        }
        if let mask = masks.eyes, settings.eyeBrightness > 0 || settings.eyeDetail > 0 {
            let nearby = gaussian(image, radius: max(0.8, faceWidth * 0.003))
            guard let output = eyes?.apply(extent: input.extent, arguments: [
                image, nearby, scaled(mask, to: input.extent),
                CIVector(x: settings.eyeBrightness / 100 * amount,
                         y: settings.eyeDetail / 100 * amount)
            ]) else { throw PhotoError.renderFailed }
            image = output
        }
        if let mask = masks.teeth, settings.teeth > 0 {
            guard let output = teeth?.apply(extent: input.extent, arguments: [
                image, scaled(mask, to: input.extent), settings.teeth / 100 * amount
            ]) else { throw PhotoError.renderFailed }
            image = output
        }
        return image
    }

    /// Exact at neutral settings because no Core Image node is evaluated.
    /// The low/high split itself reconstructs `low + (original - low)`.
    static func reconstructed(_ original: CIImage, radius: CGFloat) throws -> CIImage {
        let low = gaussian(original, radius: radius)
        guard let kernel = CreativeMetal.compile( """
            [[ stitchable ]] float4 beautyReconstruct(coreimage::sample_t original,
                coreimage::sample_t low) {
                float4 c = unpremultiply(original);
                float4 l = unpremultiply(low);
                return premultiply(float4(l.rgb + (c.rgb - l.rgb), c.a));
            }
            """), let result = kernel.apply(extent: original.extent, arguments: [original, low])
        else { throw PhotoError.renderFailed }
        return result
    }

    private static func gaussian(_ image: CIImage, radius: CGFloat) -> CIImage {
        image.applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: radius])
             .cropped(to: image.extent)
    }
    private static func gaussianClamped(_ image: CIImage, radius: CGFloat) -> CIImage {
        image.clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: radius])
            .cropped(to: image.extent)
    }
    private static func scaled(_ mask: CGImage, to extent: CGRect) -> CIImage {
        let image = CIImage(cgImage: mask)
        return image.transformed(by: CGAffineTransform(scaleX: extent.width / CGFloat(mask.width),
                                                       y: extent.height / CGFloat(mask.height)))
                    .transformed(by: CGAffineTransform(translationX: extent.minX, y: extent.minY))
                    .cropped(to: extent)
    }
}
