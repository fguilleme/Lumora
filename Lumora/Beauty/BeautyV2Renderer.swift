import CoreGraphics
import CoreImage
import Foundation

/// Additive V2 graph. Frozen BeautyRenderer kernels remain untouched.
enum BeautyV2Renderer {
    private static let lips = CreativeMetal.compile("""
    [[ stitchable ]] float4 beautyV2Lips(coreimage::sample_t original,
        coreimage::sample_t low, coreimage::sample_t matte, float4 controls) {
        float4 c = unpremultiply(original);
        float3 blurred = unpremultiply(low).rgb;
        float weight = clamp(unpremultiply(matte).r, 0.0, 1.0);
        const float3 lum = float3(0.2126, 0.7152, 0.0722);
        float y = dot(c.rgb, lum);
        float3 chroma = c.rgb - y;
        // A small opponent shift around the original lip color, not a fixed pigment.
        float naturalRed = max(0.0, c.r - 0.5 * (c.g + c.b));
        float3 tint = float3(0.023, -0.008, -0.010)
                    * controls.x * smoothstep(0.0, 0.12, naturalRed);
        tint -= dot(tint, lum);
        float3 adjusted = c.rgb + tint + chroma * (controls.y * 0.22)
                        + c.rgb * (exp2(controls.z * 0.22) - 1.0)
                        + (c.rgb - blurred) * (controls.w * 0.20);
        return premultiply(float4(mix(c.rgb, adjusted, weight), c.a));
    }
    """)
    private static let shine = CreativeMetal.compile("""
    [[ stitchable ]] float4 beautyV2Shine(coreimage::sample_t original,
        coreimage::sample_t local, coreimage::sample_t broad,
        coreimage::sample_t skin, float amount) {
        float4 c = unpremultiply(original);
        const float3 lum = float3(0.2126, 0.7152, 0.0722);
        float localY = dot(unpremultiply(local).rgb, lum);
        float broadY = dot(unpremultiply(broad).rgb, lum);
        float excess = max(0.0, localY - broadY - 0.012);
        float gate = smoothstep(0.32, 0.80, localY);
        float reduction = min(excess * 0.62, 0.11) * gate * amount
                        * clamp(unpremultiply(skin).r, 0.0, 1.0);
        // Subtract low-frequency luminance only; the original high-frequency
        // residual, including pores, is unchanged.
        return premultiply(float4(c.rgb - reduction, c.a));
    }
    """)
    private static let balance = CreativeMetal.compile("""
    [[ stitchable ]] float4 beautyV2FaceBalance(coreimage::sample_t original,
        coreimage::sample_t local, coreimage::sample_t broad,
        coreimage::sample_t skin, float amount) {
        float4 c = unpremultiply(original);
        const float3 lum = float3(0.2126, 0.7152, 0.0722);
        float localY = dot(unpremultiply(local).rgb, lum);
        float broadY = dot(unpremultiply(broad).rgb, lum);
        float gap = broadY - localY;
        float signedGap = amount >= 0.0 ? max(0.0, gap) : min(0.0, gap);
        float correction = clamp(signedGap, -0.09, 0.09) * abs(amount) * 0.48
                         * clamp(unpremultiply(skin).r, 0.0, 1.0);
        return premultiply(float4(c.rgb + correction, c.a));
    }
    """)
    static func apply(_ input: CIImage, settings raw: BeautyV2Settings,
                      masks: BeautyMasks, amount: Double) throws -> CIImage {
        let settings = raw.validated
        let blend = min(1, max(0, amount / 100))
        guard !settings.isIdentity, blend > 0, masks.faceCount > 0 else { return input }
        let faceWidth = max(1, masks.faceWidthFraction * input.extent.width)
        var image = input
        if let matte = masks.v2.lips,
           settings.lipColor != 0 || settings.lipSaturation != 0 ||
           settings.lipBrightness != 0 || settings.lipDetail != 0 {
            let low = gaussian(image, radius: max(0.8, faceWidth * 0.004))
            let soft = gaussian(scaled(matte, to: input.extent),
                                radius: max(0.7, faceWidth * 0.003))
            let controls = CIVector(x: settings.lipColor / 100 * blend,
                                    y: settings.lipSaturation / 100 * blend,
                                    z: settings.lipBrightness / 100 * blend,
                                    w: settings.lipDetail / 100 * blend)
            guard let output = lips?.apply(extent: input.extent,
                                            arguments: [image, low, soft, controls])
            else { throw PhotoError.renderFailed }
            image = output
        }
        if let skin = masks.skin, settings.skinShine > 0 {
            let local = gaussian(image, radius: max(2, faceWidth * 0.015))
            let broad = gaussian(image, radius: max(6, faceWidth * 0.075))
            guard let output = shine?.apply(extent: input.extent,
                arguments: [image, local, broad, scaled(skin, to: input.extent),
                            settings.skinShine / 100 * blend])
            else { throw PhotoError.renderFailed }
            image = output
        }
        if let skin = masks.skin, settings.faceBalance != 0 {
            let local = gaussian(image, radius: max(6, faceWidth * 0.06))
            let broad = gaussian(image, radius: max(18, faceWidth * 0.25))
            guard let output = balance?.apply(extent: input.extent,
                arguments: [image, local, broad, scaled(skin, to: input.extent),
                            settings.faceBalance / 100 * blend])
            else { throw PhotoError.renderFailed }
            image = output
        }
        return image
    }

    private static func gaussian(_ input: CIImage, radius: CGFloat) -> CIImage {
        input.clampedToExtent().applyingFilter("CIGaussianBlur",
            parameters: [kCIInputRadiusKey: radius]).cropped(to: input.extent)
    }
    private static func scaled(_ mask: CGImage, to extent: CGRect) -> CIImage {
        CIImage(cgImage: mask)
            .transformed(by: CGAffineTransform(scaleX: extent.width / CGFloat(mask.width),
                                                y: extent.height / CGFloat(mask.height)))
            .transformed(by: CGAffineTransform(translationX: extent.minX, y: extent.minY))
            .cropped(to: extent)
    }
}
