import Foundation

/// Positions use the post-geometry photo, with a top-left origin. Distance is relative, not metres.
struct DepthLightingSettings: Codable, Sendable, Equatable {
    var enabled = false
    var intensity = 65.0
    var distance = 48.0
    var softness = 55.0
    var warmth = 0.0
    var relief = 80.0
    var lightX = 0.25
    var lightY = 0.28
    var targetX = 0.5
    var targetY = 0.5
    var isActive: Bool { enabled && validated.intensity > 0 }
    var validated: Self {
        var s = self
        func bounded(_ value: Double, _ range: ClosedRange<Double>, _ fallback: Double) -> Double {
            value.isFinite ? min(range.upperBound, max(range.lowerBound, value)) : fallback
        }
        s.intensity = bounded(intensity, 0...100, 65)
        s.distance = bounded(distance, 15...150, 48)
        s.softness = bounded(softness, 20...100, 55)
        s.warmth = bounded(warmth, -100...100, 0)
        s.relief = bounded(relief, 0...100, 80)
        s.lightX = bounded(lightX, 0...1, 0.25); s.lightY = bounded(lightY, 0...1, 0.28)
        s.targetX = bounded(targetX, 0...1, 0.5); s.targetY = bounded(targetY, 0...1, 0.5)
        return s
    }
}
