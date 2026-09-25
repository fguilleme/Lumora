import CoreImage
import Metal
import CryptoKit
import Foundation

/// Statistics of a fixed-size, extended-linear scene thumbnail. Percentiles are
/// computed on actual luminance, including values above 1; no auto-levels are used.
struct ProContrastSceneStats: Sendable, Equatable {
    let p01: Double, p05: Double, p25: Double, p50: Double
    let p75: Double, p95: Double, p99: Double
    let castRG: Double, castBG: Double
    let confidence: Double, neutralFraction: Double

    var usefulSpan: Double { max(0, p95 - p05) }
    var middleSpan: Double { max(0, p75 - p25) }
    var pivot: Double { min(0.8, max(0.2, p50)) }
    var rangeNeed: Double { min(1, max(0, (0.88 - usefulSpan) / 0.60)) }
    var middleNeed: Double { min(1, max(0, (0.50 - middleSpan) / 0.40)) }
    func strength(_ settings: ProContrastSettings) -> Double {
        min(1.15, rangeNeed * (settings.correctContrast / 100 * 1.05 +
                               settings.dynamicContrast / 100 * middleNeed * 0.75))
    }
}

/// Bounded content-addressed cache. The 128×128 GPU thumbnail is rendered on
/// each request, but quantiles and trimmed chromaticity are reused when upstream
/// pixels are unchanged. A preceding effect, crop or source change changes the
/// thumbnail fingerprint automatically. No full-photo CPU readback occurs.
final class ProContrastAnalyzer: @unchecked Sendable {
    static let shared = ProContrastAnalyzer()
    private let lock = NSLock()
    private let context: CIContext
    private let linear = CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!
    private var cache: [Data: ProContrastSceneStats] = [:]
    private var order: [Data] = []
    private var hits = 0, misses = 0

    private init() {
        let options: [CIContextOption: Any] = [.workingColorSpace: linear,
                                                .workingFormat: CIFormat.RGBAf,
                                                .cacheIntermediates: false]
        if let device = MTLCreateSystemDefaultDevice() {
            context = CIContext(mtlDevice: device, options: options)
        } else { context = CIContext(options: options) }
    }
    func counters() -> (hits: Int, misses: Int) {
        lock.lock(); defer { lock.unlock() }
        return (hits, misses)
    }
    func analyze(_ image: CIImage) -> (ProContrastSceneStats, Bool) {
        let extent = image.extent
        let thumbnail = image.transformed(by: CGAffineTransform(translationX: -extent.minX, y: -extent.minY))
            .transformed(by: CGAffineTransform(scaleX: 128 / extent.width, y: 128 / extent.height))
        var rgba = [Float](repeating: 0, count: 128 * 128 * 4)
        rgba.withUnsafeMutableBytes { bytes in
            context.render(thumbnail, toBitmap: bytes.baseAddress!, rowBytes: 128 * 16,
                           bounds: CGRect(x: 0, y: 0, width: 128, height: 128),
                           format: .RGBAf, colorSpace: linear)
        }
        let key = rgba.withUnsafeBytes { Data(SHA256.hash(data: Data($0))) }
        lock.lock()
        if let stored = cache[key] {
            hits += 1; lock.unlock()
            return (stored, true)
        }
        lock.unlock()
        let stats = Self.measure(rgba)
        lock.lock()
        misses += 1
        if cache[key] == nil {
            cache[key] = stats; order.append(key)
            if order.count > 16 { cache.removeValue(forKey: order.removeFirst()) }
        }
        lock.unlock()
        return (stats, false)
    }
    private static func percentile(_ sorted: [Double], _ fraction: Double) -> Double {
        guard !sorted.isEmpty else { return 0 }
        let position = Double(sorted.count - 1) * fraction
        let low = Int(position), high = min(sorted.count - 1, low + 1)
        return sorted[low] + (sorted[high] - sorted[low]) * (position - Double(low))
    }
    private static func trimmedMedian(_ values: [Double]) -> Double {
        guard values.count >= 16 else { return 0 }
        let sorted = values.sorted(), start = sorted.count / 10, end = sorted.count * 9 / 10
        return percentile(Array(sorted[start..<end]), 0.5)
    }
    private static func measure(_ rgba: [Float]) -> ProContrastSceneStats {
        var luminance: [Double] = [], redGreen: [Double] = [], blueGreen: [Double] = []
        var neutralQuality = 0.0, valid = 0
        luminance.reserveCapacity(128 * 128)
        for i in stride(from: 0, to: rgba.count, by: 4) {
            let r = max(0, Double(rgba[i])), g = max(0, Double(rgba[i+1]))
            let b = max(0, Double(rgba[i+2]))
            guard r.isFinite, g.isFinite, b.isFinite else { continue }
            let y = 0.2126*r + 0.7152*g + 0.0722*b
            luminance.append(y); valid += 1
            guard y >= 0.06, y <= 0.90, min(r,g,b) > 0.02 else { continue }
            let chroma = (max(r,g,b) - min(r,g,b)) / y
            guard chroma < 0.42 else { continue }
            redGreen.append(log(r/g)); blueGreen.append(log(b/g))
            neutralQuality += 1 - chroma/0.42
        }
        luminance.sort()
        let fraction = Double(redGreen.count) / Double(max(1,valid))
        let quality = neutralQuality / Double(max(1,redGreen.count))
        // Ten percent of credible neutral area is enough for a full scene
        // estimate; saturated single-color scenes naturally approach zero.
        let confidence = min(1, fraction / 0.10) * min(1, quality / 0.60)
        return ProContrastSceneStats(
            p01: percentile(luminance,0.01), p05: percentile(luminance,0.05),
            p25: percentile(luminance,0.25), p50: percentile(luminance,0.50),
            p75: percentile(luminance,0.75), p95: percentile(luminance,0.95),
            p99: percentile(luminance,0.99),
            castRG: max(-0.35,min(0.35,trimmedMedian(redGreen))),
            castBG: max(-0.35,min(0.35,trimmedMedian(blueGreen))),
            confidence: confidence, neutralFraction: fraction)
    }
}

/// Global tonal distribution correction, deliberately without a spatial pyramid.
struct ProContrastRenderer: CreativeEffectRendering {
    private static let kernel = CreativeMetal.compile("""
    [[ stitchable ]] float4 proContrast(coreimage::sample_t pixel,
            float4 tone, float4 color, float2 protection) {
        float4 c = unpremultiply(pixel);
        float3 original = c.rgb;
        float y = max(0.0, dot(max(original,float3(0.0)),float3(0.2126,0.7152,0.0722)));
        float pivot = tone.x, strength = tone.y;
        float shadowGuard = mix(1.0, smoothstep(0.0,0.20,y), protection.x);
        float highlightGuard = mix(1.0, 1.0-smoothstep(0.80,1.0,y), protection.y);
        float nextY;
        if (y <= 1.0) {
            nextY = y + strength*(y-pivot)*y*(1.0-y)*shadowGuard*highlightGuard;
        } else {
            float slope = 1.0-strength*(1.0-pivot)*(1.0-protection.y);
            float excess = y-1.0;
            nextY = 1.0+slope*excess/(1.0+0.35*strength*excess);
        }
        float3 tonal = y > 1e-8 ? original * (nextY/y) : original;
        float correction = color.z * color.w;
        float3 gains = exp(float3(-color.x*correction,0.0,-color.y*correction));
        float3 corrected = tonal * gains;
        float correctedY = dot(corrected,float3(0.2126,0.7152,0.0722));
        corrected *= nextY/max(correctedY,1e-8);
        c.rgb = mix(original, corrected, tone.z);
        return premultiply(c);
    }
    """)
    func apply(_ image: CIImage, effect: CreativeEffect) throws -> CIImage {
        let s = ProContrastSettings(effect: effect).validated
        guard s.amount > 0 else { return image }
        let stats = ProContrastAnalyzer.shared.analyze(image).0
        // A fully manual Amount setting should remain visible even when the
        // scene analyzer judges the original contrast already sufficient.
        let manualEndpoint = 0.9 * (CreativeEndpointGain.multiplier(s.amount, atMaximum: 2) - 1)
        let strength = max(stats.strength(s), manualEndpoint)
        guard strength > 0 || s.correctColorCast > 0 else { return image }
        guard let output = Self.kernel?.apply(extent: image.extent, arguments: [
            image,
            CIVector(x:stats.pivot,y:strength,z:s.amount/100,w:0),
            CIVector(x:stats.castRG,y:stats.castBG,z:stats.confidence,w:s.correctColorCast/100),
            CIVector(x:s.shadowProtection/100,y:s.highlightProtection/100)
        ]) else { throw PhotoError.renderFailed }
        return output
    }
}
