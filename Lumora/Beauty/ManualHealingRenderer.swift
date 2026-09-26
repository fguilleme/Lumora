import CoreImage
import Foundation

/// GPU local frequency transfer. The immutable input supplies source texture;
/// overlapping corrections never feed back into source selection or sampling.
enum ManualHealingRenderer {
  private static let kernel: CIKernel? = {
    let metal = """
      #include <metal_stdlib>
      #include <CoreImage/CoreImage.h>
      using namespace metal;
      using namespace coreimage;
      extern "C" { namespace coreimage {
      [[ stitchable ]] float4 manualHeal(sampler original, sampler low, sampler previous, sampler targetMask,
          float2 target, float2 source, float radius, float feather, float strength,
          float mode, destination dest) {
          float2 p = dest.coord();
          float mask=targetMask.sample(targetMask.transform(p)).r;
          if (mode == 0.0 && mask <= 0.0)
              return previous.sample(previous.transform(p));
          float4 c = unpremultiply(original.sample(original.transform(p)));
          float3 lt = unpremultiply(low.sample(low.transform(p))).rgb;
          float2 q = p + source - target;
          float3 ls = unpremultiply(low.sample(low.transform(q))).rgb;
          float3 hs = unpremultiply(original.sample(original.transform(q))).rgb - ls;
          // Reconstruct LOW from the immediate boundary with positive Poisson
          // weights. Unlike quadratic extrapolation from distant annuli, this
          // cannot create a brighter/darker extremum than its boundary samples.
          float2 d=(p-target)/radius;
          float radial=length(d);
          float2 z=d/1.05;
          float3 boundarySum=float3(0);
          float weightSum=0.0;
          float targetEnergy=0.0, sourceEnergy=0.0;
          for (int i=0;i<32;++i) {
              float a=float(i)*6.28318530718/32.0;
              float2 u=float2(cos(a),sin(a));
              float2 pt=target+radius*1.05*u;
              float3 v=unpremultiply(low.sample(low.transform(pt))).rgb;
              float2 dz=z-u;
              float weight=1.0/max(dot(dz,dz),0.0001);
              boundarySum+=weight*v;
              weightSum+=weight;
              // Keep the existing texture-energy estimate independent of the
              // LOW reconstruction boundary.
              float energyAngle=float(i%16)*6.28318530718/16.0;
              float2 energyDirection=float2(cos(energyAngle),sin(energyAngle));
              float2 pe=target+radius*(i<16 ? 1.3 : 1.8)*energyDirection;
              float3 le=unpremultiply(low.sample(low.transform(pe))).rgb;
              float ht=dot(unpremultiply(original.sample(original.transform(pe))).rgb-le,float3(.2126,.7152,.0722));
              float2 ps=source+radius*(i<16 ? 0.45 : 0.85)*energyDirection;
              float sh=dot(unpremultiply(original.sample(original.transform(ps))).rgb-unpremultiply(low.sample(low.transform(ps))).rgb,float3(.2126,.7152,.0722));
              targetEnergy+=ht*ht; sourceEnergy+=sh*sh;
          }
          float3 surface=boundarySum/weightSum;
          float blend=smoothstep(0.55,1.0,radial);
          // Preserve the existing smooth join and source-texture transfer.
          float3 repairedLow=mix(surface,lt,blend);
          float textureScale=clamp(sqrt((targetEnergy+0.000001)/(sourceEnergy+0.000001)),0.8,1.25);
          float w = mask*strength;
          float3 prior = unpremultiply(previous.sample(previous.transform(p))).rgb;
          float3 result = mix(prior, repairedLow+hs*textureScale, w);
          if (mode == 1.0) result = lt;
          if (mode == 2.0) result = c.rgb-lt+0.18;
          if (mode == 3.0) result = ls;
          if (mode == 4.0) result = hs+0.18;
          if (mode == 5.0) result = repairedLow;
          if (mode == 7.0) result = hs*textureScale+0.18;
          if (mode == 8.0) result = float3(textureScale);
          if (mode == 6.0) result = lt+(c.rgb-lt);
          return premultiply(float4(result,c.a));
      }
      }}
      """
    return try? CIKernel.kernels(withMetalString: metal).first
  }()

  static func apply(_ input: CIImage, corrections: [ManualBlemishCorrection], amount: Double = 100)
    throws -> CIImage
  {
    guard amount > 0 else { return input }
    var output = input
    for raw in corrections {
      let c = raw.validated
      guard c.enabled, c.strength > 0 else { continue }
      let patch = try diagnostic(input, correction: c, mode: 0, amount: amount, previous: output)
      output = patch
    }
    return output
  }

  /// Modes: composite, low target, high target, low source, high source,
  /// repaired target low, neutral reconstruction. High diagnostics have +0.18.
  static func diagnostic(
    _ input: CIImage, correction raw: ManualBlemishCorrection,
    mode: Int, amount: Double = 100, previous: CIImage? = nil
  ) throws -> CIImage {
    let c = raw.validated
    let e = input.extent
    let r = c.targetRadius * min(e.width, e.height)
    let t = CGPoint(x: e.minX + c.targetCenter.x * e.width, y: e.maxY - c.targetCenter.y * e.height)
    let s = CGPoint(x: e.minX + c.sourceCenter.x * e.width, y: e.maxY - c.sourceCenter.y * e.height)
    let sigma = max(r * 0.3, min(r * 0.6, c.faceWidthFraction * e.width * 0.004))
    let low = input.clampedToExtent().applyingFilter(
      "CIGaussianBlur", parameters: [kCIInputRadiusKey: sigma])
    let patch = HealingTargetMask.bounds(c, extent:e)
    let mask = try HealingTargetMask.image(c, extent:e)
    let ring = CGRect(x: t.x - r * 1.85, y: t.y - r * 1.85, width: r * 3.7, height: r * 3.7)
    // Every output pixel evaluates both complete sampling rings. A small CI
    // tile still needs the entire source ring, not just its translated pixels.
    let sourceRing = CGRect(x: s.x - r * 0.85, y: s.y - r * 0.85,
                            width: r * 1.7, height: r * 1.7)
    guard let kernel,
      let result = kernel.apply(
        extent: mode == 0 ? e : patch,
        roiCallback: { index, rect in
          if index == 2 || index == 3 { return rect }
          let local = patch.intersection(rect)
          if local.isNull { return patch }
          let source = local.offsetBy(dx: s.x - t.x, dy: s.y - t.y)
          return local.union(source).union(ring).union(sourceRing).insetBy(dx: -1, dy: -1)
        },
        arguments: [
          input, low.cropped(to: e), previous ?? input, mask, CIVector(cgPoint: t), CIVector(cgPoint: s),
          r, c.feather,
          c.strength / 100 * min(100, max(0, amount)) / 100, Double(mode),
        ])
    else { throw PhotoError.renderFailed }
    return result.cropped(to: mode == 0 ? e : patch)
  }
}
