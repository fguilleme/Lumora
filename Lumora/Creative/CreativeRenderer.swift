import Foundation
import CoreImage
import CoreImage.CIFilterBuiltins

protocol CreativeEffectRendering: Sendable {
    func apply(_ image: CIImage, effect: CreativeEffect) throws -> CIImage
}

/// Adding a renderer requires one registry entry, without changing the stack compositor.
enum CreativeStackRenderer {
    static let renderers: [CreativeEffectKind: any CreativeEffectRendering] = [
        .highKey: KeyEffectRenderer(high: true), .lowKey: KeyEffectRenderer(high: false),
        .grain: GrainEffectRenderer()
    ]
    static func apply(_ input: CIImage, stack: CreativeEffectStack, masks: [AdjustmentLayer]) throws -> CIImage {
        var image = input
        for effect in stack.validated.effects where effect.enabled && effect.opacity > 0 {
            try Task.checkCancellation()
            let mask: CIImage?
            if let id = effect.maskID {
                // Deleted/absent masks never silently broaden an effect to the whole photograph.
                guard let layer = masks.first(where: { $0.id == id }), layer.isVisible, layer.opacity > 0 else { continue }
                mask = try MaskRenderer.makeMask(layer, extent: image.extent)
            } else { mask = nil }
            guard let renderer = renderers[effect.kind] else { continue }
            let output = try renderer.apply(image, effect: effect)
            let mixed = try FXBlend.mix(image, output, amount: effect.opacity / 100)
            if let mask {
                let blend = CIFilter.blendWithMask()
                blend.inputImage = mixed; blend.backgroundImage = image; blend.maskImage = mask
                guard let output = blend.outputImage else { throw PhotoError.renderFailed }
                image = output.cropped(to: input.extent)
            } else { image = mixed }
        }
        return image
    }
}

enum FXBlend {
    static func mix(_ input: CIImage, _ output: CIImage, amount: Double) throws -> CIImage {
        if amount <= 0 { return input }
        if amount >= 1 { return output.cropped(to: input.extent) }
        let filter = CIFilter.dissolveTransition()
        filter.inputImage = input; filter.targetImage = output; filter.time = Float(amount)
        guard let result = filter.outputImage else { throw PhotoError.renderFailed }
        return result.cropped(to: input.extent)
    }
}

struct KeyEffectRenderer: CreativeEffectRendering {
    let high: Bool
    // CIKernel is compiled once and evaluated by the existing Metal-backed CIContext.
    private static let kernel = CreativeMetal.compile( """
    [[ stitchable ]] float4 keyEffect(coreimage::sample_t pixel, float mode, float amount, float dynamic,
                          float contrast, float saturation, float dark, float light) {
        float4 c = unpremultiply(pixel);
        float y = max(0.0, dot(c.rgb, float3(0.2126, 0.7152, 0.0722)));
        float l = clamp(y, 0.0, 1.0);
        float toe = mix(1.0, smoothstep(0.0, 0.12, l), dark);
        float shoulder = mix(1.0, 1.0 - smoothstep(0.65, 1.0, l), light);
        float standard = l * (1.0-l);
        float adaptive = mode > 0.0 ? pow(l, 0.55)*(1.0-l)*(1.0-l) : l*l*sqrt(1.0-l);
        float shift = mix(standard, adaptive, dynamic) * 0.9 * toe * shoulder;
        float target = clamp(l + mode*shift, 0.0, 1.0);
        target += contrast * 0.6 * target * (1.0-target) * (2.0*target-1.0);
        // Preserve hue by scaling linear RGB; protect near-black from large amplification.
        float3 color = c.rgb * ((y + target-l) / max(y, 0.00001));
        color = mix(float3(y + target-l), color, 1.0+saturation*0.6);
        c.rgb = mix(c.rgb, color, amount);
        return premultiply(c);
    }
    """)
    func apply(_ image: CIImage, effect: CreativeEffect) throws -> CIImage {
        guard effect["amount"] > 0 else { return image }
        guard let result = Self.kernel?.apply(extent: image.extent, arguments: [image, high ? 1.0 : -1.0,
            effect["amount"]/100, effect["dynamic"]/100, effect["contrast"]/100,
            effect["saturation"]/100, effect["darkProtection"]/100, effect["lightProtection"]/100])
        else { throw PhotoError.renderFailed }
        return try GlowRenderer.apply(result, radius: effect["glowRadius"],
                                      amount: effect["glow"] * effect["amount"] / 100,
                                      threshold: effect["glowThreshold"])
    }
}

/// Highlight-gated, bounded energy diffusion in linear light. Radius is relative to the full frame.
enum GlowRenderer {
    private static let extract = CreativeMetal.compile( """
    [[ stitchable ]] float4 glowExtract(coreimage::sample_t p, float threshold) {
        float4 c = unpremultiply(p);
        float y = dot(c.rgb, float3(0.2126,0.7152,0.0722));
        float w = smoothstep(threshold, threshold+0.2, y);
        return float4(max(c.rgb, float3(0.0))*w*c.a, c.a);
    }
    """)
    private static let combine = CreativeMetal.compile( """
    [[ stitchable ]] float4 glowCombine(coreimage::sample_t p, coreimage::sample_t bloom, float amount) {
        float4 c = unpremultiply(p);
        float3 headroom = max(float3(0.0), float3(1.0)-c.rgb);
        c.rgb += amount * 0.5 * headroom * (float3(1.0)-exp(-max(bloom.rgb,float3(0.0))));
        return premultiply(c);
    }
    """)
    static func apply(_ input: CIImage, radius: Double, amount: Double, threshold: Double) throws -> CIImage {
        guard amount > 0 else { return input }
        guard let highlights = extract?.apply(extent: input.extent, arguments: [input, threshold/100]) else { throw PhotoError.renderFailed }
        let blur = highlights.clampedToExtent().applyingFilter("CIGaussianBlur", parameters: [
            kCIInputRadiusKey: max(input.extent.width, input.extent.height) * (0.001 + radius/100 * 0.025)
        ]).cropped(to: input.extent)
        guard let result = combine?.apply(extent: input.extent, arguments: [input, blur, amount/100]) else { throw PhotoError.renderFailed }
        return result
    }
}

struct GrainEffectRenderer: CreativeEffectRendering {
    func apply(_ image: CIImage, effect: CreativeEffect) throws -> CIImage {
        try FilmGrainEngine.apply(image, settings: FilmGrainSettings(effect: effect))
    }
}

/// One procedural implementation for legacy grain, Creative FX and future film/B&W renderers.
/// Coordinates are measured on a 3000-unit photographic long edge, independent of render size.
enum FilmGrainEngine {
    private static let kernel = CreativeMetal.compile( """
    float hashCell(float2 p, float seed) {
        uint2 cell = uint2(int2(p));
        uint h = cell.x * 374761393u + cell.y * 668265263u + uint(seed) * 1442695041u;
        h = (h ^ (h >> 13)) * 1274126177u;
        h ^= h >> 16;
        return float(h & 0x00ffffffu) / 8388607.5 - 1.0;
    }
    float field(float2 p, float seed) {
        float2 i=floor(p); float2 f=fract(p); f=f*f*(3.0-2.0*f);
        return mix(mix(hashCell(i,seed),hashCell(i+float2(1.0,0.0),seed),f.x),
                   mix(hashCell(i+float2(0.0,1.0),seed),hashCell(i+float2(1.0,1.0),seed),f.x),f.y);
    }
    float structure(float2 p, float seed, float irregularity, float clump, float footprint) {
        float2 warp=float2(field(p*0.21,seed+13.0),field(p*0.21,seed+29.0));
        p+=warp*irregularity*0.8;
        // Attenuate frequencies smaller than a preview pixel; retain the same cells/seed.
        float fine=1.0/(1.0+footprint*footprint);
        float coarse=1.0/(1.0+footprint*footprint*0.0625);
        return mix(field(p,seed)*fine, field(p*0.25,seed+7.0)*coarse,clump*0.65);
    }
    [[ stitchable ]] float4 filmGrain(coreimage::sample_t pixel, float4 frame, float amount, float size, float hardness,
                          float irregularity, float clump, float softness, float3 response,
                          float chroma, float seed, coreimage::destination dest) {
        float4 c=unpremultiply(pixel);
        float cell=0.7+size*5.3;
        float step=3000.0/max(frame.z,frame.w)/cell;
        float2 p=(dest.coord()-frame.xy)*step;
        float footprint=step*(0.55+softness*1.5);
        float n=structure(p,seed,irregularity,clump,footprint);
        n=n*(1.0+hardness*2.0)/(1.0+hardness*2.0*abs(n));
        // Work in a smooth perceptual lightness domain for restrained, symmetric modulation.
        float3 perceptual=sqrt(max(c.rgb,float3(0.0)));
        float y=clamp(dot(perceptual,float3(0.2126,0.7152,0.0722)),0.0,1.0);
        float s=1.0-smoothstep(0.1,0.5,y); float h=smoothstep(0.5,0.95,y);
        float weight=dot(float3(s,1.0-s-h,h),response);
        float strength=amount*0.16*weight;
        float3 delta=float3(n);
        float tint=structure(p+float2(53.0,17.0),seed+83.0,irregularity,clump,footprint);
        delta+=chroma*0.25*tint*float3(0.65,-0.25,0.55);
        // Bounded modulation vanishes at endpoints; subtract second-order energy bias.
        float3 amplitude=strength*perceptual*(float3(1.0)-clamp(perceptual,0.0,1.0));
        float3 next=perceptual+delta*amplitude;
        c.rgb=max(float3(0.0),next*next-amplitude*amplitude*0.12);
        return premultiply(c);
    }
    """)
    static func apply(_ image: CIImage, settings: FilmGrainSettings) throws -> CIImage {
        let s = settings.validated
        guard s.amount > 0 else { return image }
        let r = image.extent
        guard let output = kernel?.apply(extent: r, arguments: [image,
            CIVector(x: r.minX, y: r.minY, z: r.width, w: r.height),
            s.amount/100, s.size/100, s.hardness/100, s.irregularity/100, s.clumping/100, s.softness/100,
            CIVector(x: s.shadowAmount/100, y: s.midtoneAmount/100, z: s.highlightAmount/100),
            s.monochromatic ? 0 : s.chromaAmount/100, Double(s.seed % 1_000_003)]) else { throw PhotoError.renderFailed }
        return output
    }
}

/// Runtime stitchable Metal compilation is cached once per kernel, outside the render loop.
private enum CreativeMetal {
    static func compile(_ body: String) -> CIColorKernel? {
        let source = "#include <metal_stdlib>\n#include <CoreImage/CoreImage.h>\nusing namespace metal;\nusing namespace coreimage;\n" + body
        do { return try CIKernel.kernels(withMetalString: source).first as? CIColorKernel }
        catch { NSLog("Creative Metal compilation failed: %@", String(describing: error)); return nil }
    }
}
