import Foundation

/// A frozen color-distance field keeps local adjustments from changing their own
/// selection. Moving the influence area never resamples the reference color.
struct SimilarityMask: Codable, Sendable, Equatable {
    var fieldID = UUID()
    var distancePNG = Data()
    var width = 0
    var height = 0
    var reference = MaskPoint(x: 0.5, y: 0.5)
    var red = 0.0, green = 0.0, blue = 0.0
    var influence = RadialGradientMask()
    var tolerance = 25.0
    var connected = true

    var validated: Self {
        var value = self
        value.reference = reference.validated
        value.influence = influence.validated
        value.tolerance = tolerance.isFinite ? min(100, max(0, tolerance)) : 25
        value.red = red.isFinite ? min(1, max(0, red)) : 0
        value.green = green.isFinite ? min(1, max(0, green)) : 0
        value.blue = blue.isFinite ? min(1, max(0, blue)) : 0
        if !(1...2048).contains(width) || !(1...2048).contains(height)
            || distancePNG.count > 8 * 1024 * 1024 {
            value.distancePNG = Data(); value.width = 0; value.height = 0
        }
        return value
    }
}
