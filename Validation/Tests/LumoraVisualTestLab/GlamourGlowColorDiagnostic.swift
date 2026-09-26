import Foundation
import CoreImage
@testable import LumoraCore

private struct GlowColorSample: Encodable {
    let level: String
    let color: String
    let sourceRGB: [Double]
    let sourceLinearLuminance: Double
    let sourcePerceptualLightness: Double
    let gateWeight: Double
    let haloMeanLuminance: Double
    let haloPeakLuminance: Double
    let haloIntegratedLuminance: Double
    let haloIntegratedRGBEnergy: [Double]
    let sourceChromaticity: [Double]
    let haloChromaticity: [Double]?
    let chromaticityError: Double?
    let haloTooWeakForChromaticityMeasurement: Bool
    let haloEnergyPerSourceY: Double
    var relativeGlowEfficiency: Double? = nil
    let haloRingPixelCount: Int
    let nonFinitePixels: Int
}

extension LumoraVisualTestLab {
    private static let glowColors: [(String, SIMD3<Double>)] = [
        ("Red", SIMD3(1, 0, 0)), ("Green", SIMD3(0, 1, 0)),
        ("Blue", SIMD3(0, 0, 1)), ("Cyan", SIMD3(0, 1, 1)),
        ("Magenta", SIMD3(1, 0, 1)), ("Yellow", SIMD3(1, 1, 0)),
        ("Orange", SIMD3(1, 0.35, 0)), ("White", SIMD3(1, 1, 1))
    ]
    private static func luminance(_ rgb: SIMD3<Double>) -> Double {
        0.2126 * rgb.x + 0.7152 * rgb.y + 0.0722 * rgb.z
    }
    private static func gate(_ y: Double, threshold: Double) -> Double {
        let knee = 0.30 + threshold * 0.55
        let t = min(1, max(0, (sqrt(max(0, y)) - (knee - 0.20)) / 0.45))
        return t * t * (3 - 2 * t)
    }
    private static func chroma(_ rgb: [Double]) -> [Double]? {
        let sum = rgb.reduce(0, +)
        return sum > 1e-8 ? rgb.map { $0 / sum } : nil
    }
    private func diagnosticSource(_ rgb: SIMD3<Double>, size: Int = 384) -> CIImage {
        SyntheticCharts.make(size: size) { x, y in
            hypot(x - 0.5, y - 0.5) < 32.0 / Double(size)
                ? SIMD3(Float(rgb.x), Float(rgb.y), Float(rgb.z)) : SIMD3(repeating: 0)
        }
    }
    private func diagnosticMeasure(_ input: CIImage, _ output: CIImage,
                                   color: String, level: String, threshold: Double,
                                   profile: inout [Double]) -> GlowColorSample {
        let size = Int(input.extent.width)
        let center = gpu.read(input, CGRect(x: size / 2, y: size / 2, width: 1, height: 1))
        let rgb = (0..<3).map { Double(center[$0]) }
        let y = Self.luminance(SIMD3(rgb[0], rgb[1], rgb[2]))
        let pixels = gpu.read(output, input.extent)
        let original = gpu.read(input, input.extent)
        var energy = [Double](repeating: 0, count: 3)
        var integrated = 0.0, peak = 0.0, count = 0, nonFinite = 0
        var bins = [Double](repeating: 0, count: 41), binCounts = [Int](repeating: 0, count: 41)
        for row in 0..<size { for col in 0..<size {
            let index = 4 * (row * size + col)
            if (0..<4).contains(where: { !pixels[index + $0].isFinite }) { nonFinite += 1; continue }
            let radius = hypot(Double(col) + 0.5 - Double(size) / 2,
                               Double(row) + 0.5 - Double(size) / 2)
            guard radius >= 35, radius < 76 else { continue }
            let delta = (0..<3).map { Double(pixels[index + $0] - original[index + $0]) }
            let haloY = Self.luminance(SIMD3(delta[0], delta[1], delta[2]))
            for channel in 0..<3 { energy[channel] += delta[channel] }
            integrated += haloY; peak = max(peak, haloY); count += 1
            let bin = min(40, Int(radius) - 35)
            bins[bin] += haloY; binCounts[bin] += 1
        } }
        profile = zip(bins, binCounts).map { $1 > 0 ? $0 / Double($1) : 0 }
        let sourceChroma = Self.chroma(rgb) ?? [0, 0, 0]
        // Integrated linear luminance below this is too weak for a stable hue ratio.
        let haloChroma = integrated > 1e-6 ? Self.chroma(energy) : nil
        let error = haloChroma.map { zip($0, sourceChroma).map { abs($0 - $1) }.reduce(0, +) / 3 }
        return GlowColorSample(level: level, color: color, sourceRGB: rgb,
            sourceLinearLuminance: y, sourcePerceptualLightness: sqrt(max(0, y)),
            gateWeight: Self.gate(y, threshold: threshold),
            haloMeanLuminance: integrated / Double(max(1, count)),
            haloPeakLuminance: peak, haloIntegratedLuminance: integrated,
            haloIntegratedRGBEnergy: energy, sourceChromaticity: sourceChroma,
            haloChromaticity: haloChroma, chromaticityError: error,
            haloTooWeakForChromaticityMeasurement: haloChroma == nil,
            haloEnergyPerSourceY: integrated / max(y, 1e-12),
            haloRingPixelCount:count, nonFinitePixels: nonFinite)
    }
    private func diagnosticEffect() -> CreativeEffect {
        effect(.glamourGlow, ["amount": 90, "glow": 90, "softness": 65,
                               "threshold": 40, "warmth": 0, "shadowProtection": 0,
                               "highlightProtection": 55])
    }
    func runGlamourGlowColorDiagnostic() throws {
        progress("Glamour Glow equal-luminance color diagnostic")
        let fx = diagnosticEffect(), threshold = 0.4
        let knee = 0.30 + threshold * 0.55
        let commonUnitY = Self.glowColors.map { Self.luminance($0.1) }.min()!
        // The first target fits every pure color within SDR. The middle and high
        // targets require extended-range blue; no pre-render clamping is applied.
        let levels: [(String, Double)] = [("Low SDR", commonUnitY * 0.95),
                                          ("Knee start", pow(knee - 0.14, 2)),
                                          ("Medium", knee * knee),
                                          ("High", pow(knee + 0.30, 2))]
        var equal: [GlowColorSample] = [], peak: [GlowColorSample] = []
        var sheet: [(String, CIImage)] = [], profiles: [(String, [Double])] = []
        for (level, target) in levels {
            var levelSamples: [GlowColorSample] = []
            for (name, unit) in Self.glowColors {
                let rgb = unit * (target / Self.luminance(unit))
                let input = diagnosticSource(rgb), output = try render(input, [fx])
                var profile: [Double] = []
                let sample = diagnosticMeasure(input, output, color: name, level: level,
                                               threshold: threshold, profile: &profile)
                levelSamples.append(sample)
                if level == "Medium" {
                    sheet += [("\(name) source", input), ("\(name) glow", output),
                              ("\(name) delta x20", artifacts.difference(input, output, gain: 20))]
                    let maximum = profile.max() ?? 0
                    profiles.append((name, profile.map { maximum > 1e-12 ? $0 / maximum : 0 }))
                }
            }
            let white = levelSamples.first { $0.color == "White" }!.haloEnergyPerSourceY
            for var sample in levelSamples {
                sample.relativeGlowEfficiency = white > 1e-10
                    ? sample.haloEnergyPerSourceY / white : nil
                equal.append(sample)
            }
        }
        for (name, unit) in Self.glowColors {
            let input = diagnosticSource(unit), output = try render(input, [fx])
            var profile: [Double] = []
            peak.append(diagnosticMeasure(input, output, color: name, level: "RGB peak 1",
                                          threshold: threshold, profile: &profile))
        }
        try artifacts.sheet(sheet, "GlamourGlow/equal_luminance_color_glow.png", cell:256, maxColumns:3)
        try artifacts.plot(profiles, "GlamourGlow/equal_luminance_color_glow_profile.png",
                           title:"Medium Y: normalized halo profile, offset from r=35 px", yRange:0...1, xMaximum:40)
        let gateSeries = Self.glowColors.map { name, _ in
            (name, (0...200).map { Self.gate(Double($0) / 200, threshold:threshold) })
        }
        try artifacts.plot(gateSeries, "GlamourGlow/color_gate_response.png",
                           title:"Analytic gate vs linear luminance Y (all colors)", yRange:0...1, xMaximum:1)
        let neon = try diagnosticNeon(fx:fx, target:levels[1].1)
        try artifacts.sheet(neon, "GlamourGlow/colored_neon_comparison.png", cell:384, maxColumns:5)
        var extended: [GlowColorSample] = []
        for (name, unit) in [("Blue", SIMD3<Double>(0, 0, 1)), ("White", SIMD3<Double>(1, 1, 1))] {
            for amplitude in [1.0, 2.0, 4.0] {
                let input = diagnosticSource(unit * amplitude), output = try render(input, [fx])
                var profile: [Double] = []
                extended.append(diagnosticMeasure(input, output, color:name,
                    level:"RGB peak \(Int(amplitude))", threshold:threshold, profile:&profile))
            }
        }
        let identityInput = diagnosticSource(SIMD3(0.2, 0.4, 0.8))
        let identity = gpu.compare(identityInput, try render(identityInput,
            [effect(.glamourGlow, ["amount":0])]))
        let spread = Dictionary(grouping: equal, by:\.level).mapValues { samples in
            (samples.map(\.sourceLinearLuminance).max() ?? 0) -
            (samples.map(\.sourceLinearLuminance).min() ?? 0)
        }
        var invariant = LabCase(name:"GG_equal_luminance_colored_sources")
        invariant.metrics = ["maxSourceYSpread":spread.values.max() ?? 0,
                             "amountZeroMaxRGBError":identity.maxError,
                             "nonFinitePixels":Double((equal+peak+extended).map(\.nonFinitePixels).reduce(0,+))]
        invariant.check("Equal source luminance", (spread.values.max() ?? 1) < 1e-6,
                        hard:true,"Measured center pixel, per-level max minus min Y < 1e-6.")
        invariant.check("Finite rendered outputs", invariant.metrics["nonFinitePixels"] == 0,
                        hard:true,"All RGBA samples in fixed source/halo regions are finite.")
        invariant.check("Amount zero identity", identity.maxError == 0 && identity.nonFinite == 0,
                        hard:true,"The production pipeline returns the input unchanged.")
        let medium = equal.filter { $0.level == "Medium" }
        let efficiencies = medium.compactMap(\.relativeGlowEfficiency)
        invariant.check("Comparable medium-Y glow energy", efficiencies.allSatisfy { $0 >= 0.75 && $0 <= 1.25 },
                        "Heuristic ±25% relative to White at the same measured Y; no renderer adjustment.")
        let gateSpread = Dictionary(grouping:equal,by:\.level).values.map { samples in
            (samples.map(\.gateWeight).max() ?? 0) - (samples.map(\.gateWeight).min() ?? 0)
        }.max() ?? 0
        invariant.metrics["maxGateSpread"] = gateSpread
        invariant.check("Equal-Y gate weights",gateSpread < 1e-6,
                        "Heuristic: analytic gate evaluated on independently measured source Y values.")
        let profileSpread = zip(profiles.first?.1 ?? [], profiles.last?.1 ?? [])
            .map { abs($0 - $1) }.reduce(0,+) / Double(max(1,profiles.first?.1.count ?? 0))
        invariant.metrics["redWhiteNormalizedProfileMAE"] = profileSpread
        invariant.check("Similar radial shape",profileSpread < 0.05,
                        "Heuristic: mean absolute difference of peak-normalized Red/White annulus profiles.")
        invariant.check("Medium-Y halo hue", medium.allSatisfy { ($0.chromaticityError ?? 1) < 0.08 },
                        "Heuristic mean absolute RGB chromaticity error < 0.08 when halo energy > 1e-6.")
        cases.append(invariant)
        var equalPeak = LabCase(name:"GG_equal_rgb_peak_colored_sources")
        equalPeak.metrics = ["minGate":peak.map(\.gateWeight).min() ?? 0,
                             "maxGate":peak.map(\.gateWeight).max() ?? 0]
        equalPeak.check("Peak-RGB gate distinction", equalPeak.metrics["maxGate"]! > equalPeak.metrics["minGate"]!,
                        "Diagnostic: same channel peak does not mean same Rec.709 luminance.")
        cases.append(equalPeak)
        try artifacts.json(equal, "GlamourGlow/equal_luminance_metrics.json")
        try artifacts.json(peak, "GlamourGlow/equal_rgb_peak_metrics.json")
        try artifacts.json(extended, "GlamourGlow/extended_range_metrics.json")
        try diagnosticReport(equal:equal, peak:peak, extended:extended, spread:spread,
                             identity:identity, knee:knee, settings:fx)
    }
    private func diagnosticNeon(fx: CreativeEffect, target: Double) throws -> [(String, CIImage)] {
        var items: [(String, CIImage)] = []
        for (name, unit) in Self.glowColors.filter({ ["Red","Green","Blue","Orange","White"].contains($0.0) }) {
            let source = unit * (target / Self.luminance(unit))
            let input = SyntheticCharts.make(size:512) { x, y in
                let mortar = abs((y * 17).truncatingRemainder(dividingBy:1) - 0.5) < 0.016
                let seam = abs((x * 9 + (Int(y * 17) % 2 == 0 ? 0 : 0.5)).truncatingRemainder(dividingBy:1) - 0.5) < 0.012
                let wall = 0.012 + 0.009 * y + (mortar || seam ? -0.008 : 0)
                let light = abs(x - 0.5) < 0.006 && y > 0.16 && y < 0.84
                return light ? SIMD3(Float(source.x),Float(source.y),Float(source.z))
                    : SIMD3(repeating:Float(wall))
            }
            items.append(("\(name) original",input))
            items.append(("\(name) glow",try render(input,[fx])))
        }
        return items
    }
    private func diagnosticReport(equal:[GlowColorSample], peak:[GlowColorSample],
                                  extended:[GlowColorSample], spread:[String:Double],
                                  identity:Comparison, knee:Double,
                                  settings:CreativeEffect) throws {
        func f(_ x:Double) -> String { String(format:"%.7g",x) }
        func rgb(_ values:[Double]) -> String { values.map(f).joined(separator:", ") }
        func table(_ rows:[GlowColorSample], efficiency:Bool) -> String {
            var lines=["| Level | Color | source RGB | Y | sqrt(Y) | gate | halo mean Y | halo peak Y | halo integrated Y | halo integrated RGB | energy/Y | relative efficiency | chroma error | weak halo |",
                       "|---|---|---|---:|---:|---:|---:|---:|---:|---|---:|---:|---:|---|"]
            for s in rows {
                lines.append("| \(s.level) | \(s.color) | \(rgb(s.sourceRGB)) | \(f(s.sourceLinearLuminance)) | \(f(s.sourcePerceptualLightness)) | \(f(s.gateWeight)) | \(f(s.haloMeanLuminance)) | \(f(s.haloPeakLuminance)) | \(f(s.haloIntegratedLuminance)) | \(rgb(s.haloIntegratedRGBEnergy)) | \(f(s.haloEnergyPerSourceY)) | \(efficiency ? s.relativeGlowEfficiency.map(f) ?? "—" : "—") | \(s.chromaticityError.map(f) ?? "—") | \(s.haloTooWeakForChromaticityMeasurement) |")
            }
            return lines.joined(separator:"\n")
        }
        let medium = equal.filter { $0.level == "Medium" }
        let poorEfficiency = medium.contains {
            ($0.relativeGlowEfficiency ?? 0) < 0.75 || ($0.relativeGlowEfficiency ?? 0) > 1.25
        }
        let conclusion = poorEfficiency ? "C — MIXED" : "A — TEST ISSUE"
        let old:[(String,SIMD3<Double>)] = [("red",SIMD3(0.95,0.02,0.02)),
             ("green",SIMD3(0.02,0.95,0.02)),("blue",SIMD3(0.02,0.04,0.95)),
             ("orange",SIMD3(0.95,0.32,0.02))]
        let oldRows=old.map { name,c in
            let y=Self.luminance(c)
            return "| \(name) | \(rgb([c.x,c.y,c.z])) | \(f(y)) | \(f(sqrt(y))) | \(f(Self.gate(y,threshold:0.4))) |"
        }.joined(separator:"\n")
        let report="""
        # Glamour Glow — equal-luminance color diagnostic

        Production code was not changed. All outputs use `CreativeStackRenderer.apply` and the actual Glamour Glow Metal kernels in extended linear sRGB / RGBAf.

        Settings: `\(settings.validated.parameters.sorted{$0.key<$1.key}.map{"\($0.key)=\($0.value)"}.joined(separator:", "))`. Fixed source disc radius 32 px in a 384×384 frame; measured halo annulus 35 ≤ radius < 76 px, excluding source. Measured pixel count and integrated RGB are in the JSON alongside this report. The plotted PNGs are SDR display previews; measurement is made before display conversion and preserves RGB values above 1.

        ## Actual equations

        `Y = 0.2126·max(R,0) + 0.7152·max(G,0) + 0.0722·max(B,0)`; `L = sqrt(max(Y,0))`; `knee = 0.30 + threshold·0.55 = \(f(knee))`; `gate = smoothstep(knee−0.20, knee+0.25, L)`. Extraction is `max(RGB,0)·gate`. Three Gaussian fields are combined with weights `0.50/0.32/0.18`; the combined RGB is tinted (neutral Warmth here), scaled by Amount, Glow, shadow and highlight guards, then limited per receiving channel by `max(0,1−RGB)·(2−1.65·highlightProtection)`. Thus the gate is color-independent at equal Y, while final energy may depend on hue through RGB diffusion and per-channel headroom.

        ## Old `GG_color_blue` warning

        The old isolated test compares unequal RGB colors at the same approximate channel peak, using the same threshold 40 and ring ROI `(246,345,20,20)` around a radius 0.13×512 disc. Its `haloMeanLuminance` is the output mean of that ring. Its `haloChromaticityError=1` is an explicit sentinel when summed RGB halo ≤ 1e-10, not a measured hue error. The blue source has `L=0.3185122`, below the gate start of `0.32`, so its gate is exactly zero and the extracted field and halo are black. This is a source-selection/measurement issue, not evidence by itself of a blue-only kernel defect.

        | Old case | RGB | Y | sqrt(Y) | gate |
        |---|---|---:|---:|---:|
        \(oldRows)

        ## Equal linear luminance

        Targets are derived from the real knee: Low SDR = 0.95×minimum unit-color Y = \(f(0.95*Self.glowColors.map{Self.luminance($0.1)}.min()!)), Knee start = (knee−0.14)² = \(f(pow(knee-0.14,2))), Medium = knee² = \(f(knee*knee)), High = (knee+0.30)² = \(f(pow(knee+0.30,2))). Low SDR is the highest practical common SDR pure-color level, but falls below the gate start; Knee start samples the rising gate. At the latter three levels, saturated blue necessarily exceeds RGB=1 in extended linear sRGB. No pre-clamp was applied. Maximum measured within-level Y spread: \(f(spread.values.max() ?? 0)).

        \(table(equal,efficiency:true))

        `energy/Y` is integrated annulus luminance divided by measured center-source Y; `relative efficiency` is that ratio divided by White at the same target. At Low SDR, both White and colors have no halo, so efficiency is omitted. Chromaticity is RGB/sum(RGB); error is mean absolute component difference. Below integrated halo Y=1e-6 it is omitted and `weak halo=true`. Exact source and halo chromaticity vectors plus the annulus pixel count are in the adjacent JSON.

        ## Equal RGB peak (diagnostic contrast)

        \(table(peak,efficiency:false))

        ## Extended range, unclamped sources

        \(table(extended,efficiency:false))

        ## Invariants and interpretation

        Amount=0 max RGB error: \(f(identity.maxError)); non-finite rendered source/halo pixels: \((equal+peak+extended).map(\.nonFinitePixels).reduce(0,+)). The gate curves are identical by construction when compared at the same Y. Medium-Y glow energy uses a documented ±25% quality heuristic against White, not a pass target for the renderer. Medium-Y color outside that tolerance: \(poorEfficiency). Any differences at equal Y would arise downstream of the gate through RGB diffusion/recombination/headroom; none exceeded the heuristic here. Radial profiles are peak-normalized for shape only, not energy.

        [Equal-Y source/glow/difference](GlamourGlow/equal_luminance_color_glow.png) · [radial profiles](GlamourGlow/equal_luminance_color_glow_profile.png) · [gate curves](GlamourGlow/color_gate_response.png) · [neon scene](GlamourGlow/colored_neon_comparison.png).

        ## Conclusion

        **\(conclusion)**. The old blue warning is primarily explained by unequal luminance at equal RGB peak and a chromaticity sentinel on a zero halo. \(poorEfficiency ? "At equal medium luminance a substantial color-dependent output energy remains; the gate itself remains equal, so the dependency lies in RGB diffusion/recombination." : "At equal medium luminance the measured glow energies remain within the documented comparison band; the old warning does not indicate a color-dependent gate.")
        """
        try report.write(to:artifacts.url("GlamourGlowColorDiagnosticReport.md"),atomically:true,encoding:.utf8)
    }
}
