import Foundation
import CoreImage
@testable import LumoraCore

struct LowKeyZone: Codable {
    let name: String
    let lower: Double
    let upper: Double
}

extension LumoraVisualTestLab {
    static let lowKeyZones: [LowKeyZone] = [
        .init(name: "deep-shadows", lower: 0, upper: 0.10),
        .init(name: "shadows", lower: 0.10, upper: 0.30),
        .init(name: "midtones", lower: 0.30, upper: 0.65),
        .init(name: "bright-tones", lower: 0.65, upper: 0.90),
        .init(name: "specular-whites", lower: 0.95, upper: 1)
    ]

    /// Source-luminance classification of the uniform neutral ramp. Signed absolute
    /// change is in linear luminance units, not an absolute-value error metric.
    static func recordLowKeyZones(_ ramp: Comparison, into result: inout LabCase) {
        for zone in lowKeyZones {
            let indices = ramp.transferInput.indices.filter {
                let x = ramp.transferInput[$0]
                return x >= zone.lower && (x < zone.upper || (zone.upper == 1 && x <= 1))
            }
            let count = Double(max(1, indices.count))
            let input = indices.reduce(0.0) { $0 + ramp.transferInput[$1] } / count
            let output = indices.reduce(0.0) { $0 + ramp.transferOutput[$1] } / count
            result.metrics[zone.name + "-sampleCount"] = Double(indices.count)
            result.metrics[zone.name + "-meanInput"] = input
            result.metrics[zone.name + "-meanOutput"] = output
            result.metrics[zone.name + "-absoluteChange"] = output - input
            result.metrics[zone.name + "-relativeChange"] = (output - input) / max(1e-6, input)
        }
    }

    func lowKeyDynamicSweep() throws {
        let chart = MasterChart.generate(size: size)
        let region = chart.regions.first { $0.name == "ramp-full" }!.rect
        let input = chart.image.cropped(to: region)
        // Freeze every field, including the effect identity and all default values.
        let base = effect(.lowKey, ["amount": 60, "dynamic": 0, "contrast": 0,
            "saturation": 0, "darkProtection": 65, "lightProtection": 70,
            "glow": 0, "glowRadius": 30, "glowThreshold": 70]).validated
        try artifacts.json(Self.lowKeyZones, "Reports/LK_dynamic_zones.json")
        var previous: LabCase?
        var absoluteSeries: [(String, [Double])] = []
        var relativeSeries: [(String, [Double])] = []
        var transferSeries: [(String, [Double])] = []
        var sheet: [(String, CIImage)] = [("Input", input)]
        for dynamic in [0.0, 25, 50, 75, 100] {
            var fx = base
            fx["dynamic"] = dynamic
            let id = String(format: "LK_DynamicSweep_%03.0f", dynamic)
            let output = try render(input, [fx])
            let ramp = gpu.compare(input, output, ramp: true)
            var result = LabCase(name: id)
            result.metrics["amount"] = 0.60
            result.metrics["dynamic"] = dynamic / 100
            Self.recordLowKeyZones(ramp, into: &result)
            var normalized = fx
            normalized["dynamic"] = 0
            result.check("Only Dynamic varies", normalized == base, hard: true,
                         "Amount=.60; opacity=1; shadows=.65; lights=.70; contrast/saturation/glow=0; every other field identical.")
            result.check("Finite output", ramp.nonFinite == 0, hard: true, "All RGBA samples must be finite.")
            let differences = zip(ramp.transferInput, ramp.transferOutput).map { $0 - $1 }
            let positiveLoss = differences.map { max(0, $0) }
            let lossSum = positiveLoss.reduce(0, +)
            let centroid = zip(ramp.transferInput, positiveLoss).reduce(0.0) { $0 + $1.0 * $1.1 } / max(1e-12, lossSum)
            result.metrics["darkeningCentroid"] = centroid
            result.metrics["monotonicityViolations"] = Double(ramp.monotonicityViolations)
            result.metrics["nonFinitePixels"] = Double(ramp.nonFinite)
            result.check("Monotone curve / no tonal inversions", ramp.monotonicityViolations == 0, hard: true,
                         "Every adjacent output sample must be nondecreasing, with 1e-6 linear GPU tolerance; no inversion count allowance.")
            result.check("Low Key does not brighten", differences.allSatisfy { $0 >= -1e-6 }, hard: true,
                         "Output <= input + 1e-6 over the entire neutral ramp.")
            // This is a separate preservation observation, not a demand that whites
            // receive more darkening than shadows or a requirement of zero change.
            result.check("Separate specular preservation", abs(result.metrics["specular-whites-relativeChange"]!) < abs(result.metrics["bright-tones-relativeChange"]!),
                         "At fixed lightProtection=.70, [.95,1] may darken less proportionally than [.65,.90]. This does not establish the causal effect of the protection parameter.")
            if let previous {
                for zone in ["deep-shadows", "shadows"] {
                    for measure in ["absoluteChange", "relativeChange"] {
                        let key = zone + "-" + measure
                        result.check("Decreasing shadow action: " + key,
                                     abs(result.metrics[key]!) < abs(previous.metrics[key]!) - 1e-6,
                                     "Compared with the preceding Dynamic step at identical Amount; reduction must exceed 1e-6.")
                    }
                }
                for measure in ["absoluteChange", "relativeChange"] {
                    let key = "bright-tones-" + measure
                    result.check("Increasing bright-tone action: " + measure,
                                 abs(result.metrics[key]!) > abs(previous.metrics[key]!) + 1e-6,
                                 "Compared with the preceding Dynamic step; increase must exceed 1e-6.")
                }
                result.check("Darkening moves toward brighter luminance", centroid > previous.metrics["darkeningCentroid"]! + 1e-6,
                             "Loss-weighted input-luminance centroid over the FULL [0,1] ramp must move right; includes [.90,.95].")
            } else {
                result.notes.append("Dynamic=0 is the reference; progression checks start at Dynamic=.25.")
            }
            result.notes.append("Zones use input linear luminance. AbsoluteChange = mean(output-input), signed linear units. RelativeChange = absoluteChange/mean(input), not mean pixel-wise ratios. [.90,.95] is intentionally excluded from named zones, but included in monotonicity, finiteness, centroid and curves. Near-black relative curve denominator is floored at 1e-6.")
            let label = String(format: "D=%.2f", dynamic / 100)
            absoluteSeries.append((label, differences))
            relativeSeries.append((label, zip(differences, ramp.transferInput).map { $0 / max(1e-6, $1) }))
            transferSeries.append((label, ramp.transferOutput))
            try artifacts.json(fx, "Reports/\(id)_settings.json")
            try artifacts.json(ramp, "Reports/\(id)_ramp.json")
            try artifacts.png(output, "LowKey/\(id).png")
            result.images = ["LowKey/\(id).png"]
            cases.append(result)
            previous = result
            sheet.append((label, output))
        }
        try artifacts.plot(absoluteSeries, "LowKey/dynamic_luminance_absolute.png",
                           title: "Low Key A=.60 | x: linear luminance; y: input-output")
        try artifacts.plot(relativeSeries, "LowKey/dynamic_luminance_relative.png",
                           title: "Low Key A=.60 | x: linear luminance; y: (input-output)/input")
        try artifacts.plot(transferSeries, "LowKey/dynamic_transfer.png",
                           title: "Low Key A=.60 | x: linear input; y: linear output", yRange: 0...1)
        try artifacts.sheet(sheet, "LowKey/dynamic_contact_sheet.png")
        cases[cases.count - 1].images += ["LowKey/dynamic_luminance_absolute.png", "LowKey/dynamic_luminance_relative.png", "LowKey/dynamic_transfer.png", "LowKey/dynamic_contact_sheet.png"]
    }
}
