import Foundation

/// The lamp orbits a point on the post-geometry photo. Angles are expressed in degrees;
/// distance is a relative photographic control rather than a value in metres.
struct DepthLightingSettings: Codable, Sendable, Equatable {
    var enabled = false
    var intensity = 80.0
    var distance = 0.0
    var softness = 55.0
    var relief = 80.0
    var azimuth = -35.0
    var elevation = 30.0
    var red = 1.0
    var green = 0.86
    var blue = 0.72
    var targetX = 0.5
    var targetY = 0.5

    var isActive: Bool { enabled && validated.intensity > 0 }

    var validated: Self {
        var s = self
        func bounded(_ value: Double, _ range: ClosedRange<Double>, _ fallback: Double) -> Double {
            value.isFinite ? min(range.upperBound, max(range.lowerBound, value)) : fallback
        }
        s.intensity = bounded(intensity, 0...200, 80)
        s.distance = bounded(distance, 0...40, 0)
        s.softness = bounded(softness, 10...100, 55)
        s.relief = bounded(relief, 0...100, 80)
        s.azimuth = bounded(azimuth, -90...90, -35)
        s.elevation = bounded(elevation, -45...80, 30)
        s.red = bounded(red, 0...1, 1); s.green = bounded(green, 0...1, 0.86)
        s.blue = bounded(blue, 0...1, 0.72)
        s.targetX = bounded(targetX, 0...1, 0.5); s.targetY = bounded(targetY, 0...1, 0.5)
        return s
    }

    private enum CodingKeys: String, CodingKey {
        case enabled, intensity, distance, softness, relief, azimuth, elevation
        case red, green, blue, targetX, targetY
        // V1 migration only.
        case warmth, lightX, lightY
    }

    init() {}

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try values.decodeIfPresent(Bool.self, forKey: .enabled) ?? false
        intensity = try values.decodeIfPresent(Double.self, forKey: .intensity) ?? 80
        distance = try values.decodeIfPresent(Double.self, forKey: .distance) ?? 0
        softness = try values.decodeIfPresent(Double.self, forKey: .softness) ?? 55
        relief = try values.decodeIfPresent(Double.self, forKey: .relief) ?? 80
        targetX = try values.decodeIfPresent(Double.self, forKey: .targetX) ?? 0.5
        targetY = try values.decodeIfPresent(Double.self, forKey: .targetY) ?? 0.5
        if let storedAzimuth = try values.decodeIfPresent(Double.self, forKey: .azimuth) {
            azimuth = storedAzimuth
        } else {
            let lightX = try values.decodeIfPresent(Double.self, forKey: .lightX) ?? 0.25
            azimuth = (lightX - targetX) * 180
        }
        if let storedElevation = try values.decodeIfPresent(Double.self, forKey: .elevation) {
            elevation = storedElevation
        } else {
            let lightY = try values.decodeIfPresent(Double.self, forKey: .lightY) ?? 0.28
            elevation = (targetY - lightY) * 140
        }
        if let storedRed = try values.decodeIfPresent(Double.self, forKey: .red) {
            red = storedRed
            green = try values.decodeIfPresent(Double.self, forKey: .green) ?? 1
            blue = try values.decodeIfPresent(Double.self, forKey: .blue) ?? 1
        } else {
            let warmth = (try values.decodeIfPresent(Double.self, forKey: .warmth) ?? 0) / 100
            red = 1
            green = max(0, 1 - max(0, warmth) * 0.12)
            blue = max(0, 1 - max(0, warmth) * 0.28)
            if warmth < 0 { red = max(0, 1 + warmth * 0.22) }
        }
        self = validated
    }

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(enabled, forKey: .enabled)
        try values.encode(intensity, forKey: .intensity)
        try values.encode(distance, forKey: .distance)
        try values.encode(softness, forKey: .softness)
        try values.encode(relief, forKey: .relief)
        try values.encode(azimuth, forKey: .azimuth)
        try values.encode(elevation, forKey: .elevation)
        try values.encode(red, forKey: .red)
        try values.encode(green, forKey: .green)
        try values.encode(blue, forKey: .blue)
        try values.encode(targetX, forKey: .targetX)
        try values.encode(targetY, forKey: .targetY)
    }
}
