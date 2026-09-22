import Foundation

/// Observations only. Values are measured in extended linear sRGB, never SDR-clamped.
struct ImageAnalysis: Codable, Sendable, Equatable {
    struct Distribution: Codable, Sendable, Equatable {
        let mean: Double
        let percentiles: [Double]
        static let probabilities = [0.001, 0.01, 0.05, 0.5, 0.95, 0.99, 0.999]
        init(_ samples: [Double]) {
            let sorted = samples.sorted()
            mean = sorted.isEmpty ? 0 : sorted.reduce(0, +) / Double(sorted.count)
            percentiles = Self.probabilities.map { p in
                guard !sorted.isEmpty else { return 0 }
                let x = Double(sorted.count - 1) * p, i = Int(x)
                return sorted[i] + (sorted[min(i + 1, sorted.count - 1)] - sorted[i]) * (x - Double(i))
            }
        }
        var median: Double { percentiles[3] }
    }
    let luminance: Distribution
    let rgb: [Distribution]
    let saturation: Distribution
    let chroma: Distribution
    let blackFraction: Double
    let whiteFraction: Double
    let hdrFraction: Double
    let dynamicRangeEV: Double
    let neutralRGB: [Double]
    let neutralConfidence: Double
    let count: Int
    let nonFinite: Int

    static func measure(_ pixels: [Float]) -> Self {
        var values = [[Double]](repeating: [], count: 6)
        var neutral = [[Double]](repeating: [], count: 3)
        var black = 0, white = 0, hdr = 0, bad = 0
        for i in stride(from: 0, to: pixels.count - pixels.count % 4, by: 4) {
            guard pixels[i..<i+4].allSatisfy(\.isFinite) else { bad += 1; continue }
            guard pixels[i+3] > 0.01 else { continue }
            let r = Double(pixels[i]), g = Double(pixels[i+1]), b = Double(pixels[i+2])
            let y = 0.2126*r + 0.7152*g + 0.0722*b
            let maximum = max(r,g,b), minimum = min(r,g,b), chroma = maximum-minimum
            let saturation = maximum > 1e-8 ? chroma/maximum : 0
            for (j, value) in [y,r,g,b,saturation,chroma].enumerated() { values[j].append(value) }
            if maximum <= 0.001 { black += 1 }
            if maximum >= 1 { white += 1 }
            if y > 1 { hdr += 1 }
            // Exclude noisy blacks, speculars and strongly colored scene content.
            if y > 0.025 && y < 0.8 && minimum > 0 && maximum < 0.98 && saturation < 0.28 {
                for (j, value) in [r/y,g/y,b/y].enumerated() { neutral[j].append(value) }
            }
        }
        let n = max(1,values[0].count), d = values.map(Distribution.init)
        let candidateCount = neutral[0].count
        let nd = neutral.map(Distribution.init)
        let spread = nd.map { $0.percentiles[4] - $0.percentiles[2] }.max() ?? 0
        let coverage = Double(candidateCount)/Double(n)
        let confidence = min(1,coverage/0.25) * min(1,Double(candidateCount)/64) * max(0,1-spread/0.25)
        return .init(luminance:d[0],rgb:Array(d[1...3]),saturation:d[4],chroma:d[5],
                     blackFraction:Double(black)/Double(n),whiteFraction:Double(white)/Double(n),
                     hdrFraction:Double(hdr)/Double(n),
                     dynamicRangeEV:log2(max(1e-6,d[0].percentiles[5])/max(1e-6,d[0].percentiles[1])),
                     neutralRGB: candidateCount == 0 ? [1,1,1] : nd.map(\.median),
                     neutralConfidence:confidence,count:values[0].count,nonFinite:bad)
    }
}

struct AutoCorrectionIntent: Codable, Sendable, Equatable {
    enum Scene: String, Codable, Sendable { case uniform, lowKey, highKey, backlit, normal, flat }
    let scene: Scene
    let exposureShiftEV: Double
    let shadowLift: Double
    let highlightCompression: Double
    let blackPointIntent: Double
    let whitePointIntent: Double
    let globalContrastIntent: Double
    let temperatureIntent: Double
    let tintIntent: Double
    let saturationIntent: Double
    let vibranceIntent: Double
    let correctionConfidence: Double
    let wbConfidence: Double

    /// Shared, deterministic scene intent from global extended-linear statistics.
    init(analysis a: ImageAnalysis) {
        let p = a.luminance.percentiles, median = p[3], upper = p[4]
        // A dark foreground plus a broad, near-diffuse-white upper tail is different
        // from a night scene with isolated lamps. P95 deliberately ignores the
        // brightest 5%; P99 and endpoint occupancy would overreact to small lights.
        // The 0.01 linear floor keeps the EV separation finite near black.
        let upperSeparationEV = log2((max(0, upper) + 0.01) / (max(0, median) + 0.01))
        let darkForeground = 1 - TonalResponse.smoothstep(0.045, 0.10, median)
        let broadHighlights = TonalResponse.smoothstep(0.68, 0.90, upper)
        let tonalSeparation = TonalResponse.smoothstep(3.0, 4.5, upperSeparationEV)
        let backlitEvidence = darkForeground * broadHighlights * tonalSeparation
        let lowKeyDistribution = median < 0.06 && upper > median * 8
        if upper-p[2] < 0.005 { scene = .uniform }
        else if lowKeyDistribution && backlitEvidence >= 0.5 { scene = .backlit }
        else if lowKeyDistribution { scene = .lowKey }
        else if median > 0.48 { scene = .highKey }
        else if median < 0.12 && upper > 0.65 { scene = .backlit }
        else if a.dynamicRangeEV < 2.2 { scene = .flat }
        else { scene = .normal }
        var ev = 0.0
        if scene != .uniform && scene != .lowKey && scene != .highKey {
            if upper < 0.35 { ev = min(1.5,log2(0.45/max(0.015,upper))*0.65) }
            else if median > 0.32 && upper > 1.2 { ev = max(-1.5,-log2(upper/0.95)*0.65) }
        }
        // Carry the evidence into controls continuously across the scene-label
        // boundary. A half-stop maximum lift is deliberately global and bounded.
        ev = max(ev, 0.5 * backlitEvidence)
        exposureShiftEV = (ev*100).rounded()/100
        let establishedBacklit = TonalResponse.smoothstep(0.055, 0.10, median)
            * TonalResponse.smoothstep(0.65, 0.85, upper)
        let darkSceneShadows = 3 + 13 * max(backlitEvidence, establishedBacklit)
        shadowLift = lowKeyDistribution || (scene == .backlit && median < 0.12)
            ? darkSceneShadows : scene == .normal && p[2]<0.012 && median>0.045 ? 8 : 0
        highlightCompression = scene != .uniform && upper > 0.85 ? -12 : 0
        blackPointIntent = scene == .flat && p[2]>0.035 ? -8 : 0
        whitePointIntent = scene == .flat && upper<0.65 ? 6 : 0
        globalContrastIntent = scene == .flat ? 12 : 0
        // A coherent low-chroma subset, not the scene's average RGB (gray world).
        let n = a.neutralRGB, confidence = a.neutralConfidence
        let temperature = -65*log(max(1e-6,n[0])/max(1e-6,n[2]))
        let tint = 90*log(max(1e-6,n[1])/sqrt(max(1e-12,n[0]*n[2])))
        temperatureIntent = (min(16,max(-16,temperature))*confidence).rounded()
        tintIntent = (min(12,max(-12,tint))*confidence).rounded()
        saturationIntent = a.saturation.percentiles[4] > 0.92 ? -3 : 0
        vibranceIntent = a.saturation.median > 0.06 && a.saturation.median < 0.22 && a.saturation.percentiles[4] < 0.6 ? 5 : 0
        correctionConfidence = min(1,Double(a.count)/4096) * (scene == .uniform ? 0.2 : 0.8)
        wbConfidence = confidence
    }
    var light: EditState {
        var s = EditState();s.exposure=exposureShiftEV;s.shadows=shadowLift;s.highlights=highlightCompression
        s.blacks=blackPointIntent;s.whites=whitePointIntent;s.contrast=globalContrastIntent;return s
    }
    var color: EditState {
        let wb=AutoWBMapping.controls(temperatureIntent:temperatureIntent,tintIntent:tintIntent)
        var s=EditState();s.temperature=wb.temperature;s.tint=wb.tint;s.saturation=saturationIntent;s.vibrance=vibranceIntent;return s
    }
}
