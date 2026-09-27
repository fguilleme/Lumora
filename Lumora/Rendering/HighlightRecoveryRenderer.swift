import CoreImage

/// Float-domain preparation for the bounded color LUT. No per-channel clipping:
/// highlights use a shared RGB gain, and remaining HDR headroom survives the LUT.
enum HighlightRecoveryRenderer {
    private static let recovery = CIColorKernel(source: """
    kernel vec4 recoverHighlights(__sample pixel, float strength) {
        vec4 c = unpremultiply(pixel);
        float peak = max(c.r, max(c.g, c.b));
        if (peak <= 0.0) return pixel;
        float encoded = peak <= 0.0031308 ? 12.92*peak : 1.055*pow(peak, 1.0/2.4)-0.055;
        // A C1 shoulder: identity below 0.8 sRGB, unit slope at the join.
        // Strength zero is exact identity; strength one approaches white asymptotically.
        float excess = max(encoded-0.8, 0.0);
        float mapped = encoded-excess + excess/(1.0+strength*excess/0.2);
        float linear = mapped <= 0.04045 ? mapped/12.92 : pow((mapped+0.055)/1.055,2.4);
        return premultiply(vec4(c.rgb*(linear/peak),c.a));
    }
    """)
    private static let normalize = CIColorKernel(source: """
    kernel vec4 boundedColor(__sample pixel) {
        vec4 c = unpremultiply(pixel);
        float scale = max(1.0,max(c.r,max(c.g,c.b)));
        return premultiply(vec4(c.rgb/scale,c.a));
    }
    """)
    private static let restore = CIColorKernel(source: """
    kernel vec4 restoreHeadroom(__sample mapped, __sample original) {
        vec4 c = unpremultiply(original);
        float scale = max(1.0,max(c.r,max(c.g,c.b)));
        return vec4(mapped.rgb*scale,mapped.a);
    }
    """)
    static func recover(_ image: CIImage, highlights: Double) throws -> CIImage {
        guard highlights < 0 else { return image }
        guard let output = recovery?.apply(extent: image.extent, arguments: [image, min(1, -highlights/100)]) else {
            throw PhotoError.renderFailed
        }
        return output
    }
    static func bounded(_ image: CIImage) throws -> CIImage {
        guard let output = normalize?.apply(extent: image.extent, arguments: [image]) else { throw PhotoError.renderFailed }
        return output
    }
    static func restoring(_ image: CIImage, from original: CIImage) throws -> CIImage {
        guard let output = restore?.apply(extent: image.extent, arguments: [image, original]) else { throw PhotoError.renderFailed }
        return output
    }
}
