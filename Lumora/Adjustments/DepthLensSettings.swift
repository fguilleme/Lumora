import Foundation

/// Normalized focus coordinates refer to the post-geometry photo, top-left origin.
struct DepthLensSettings: Codable, Sendable, Equatable {
    var enabled = false
    var aperture = 1.4
    var focal = 85.0
    var focusX = 0.5
    var focusY = 0.5
    var validated: Self {
        var s = self
        s.aperture = aperture.isFinite ? min(8, max(1.2, aperture)) : 1.4
        s.focal = [50.0, 85.0, 135.0].contains(focal) ? focal : 85
        s.focusX = focusX.isFinite ? min(1, max(0, focusX)) : 0.5
        s.focusY = focusY.isFinite ? min(1, max(0, focusY)) : 0.5
        return s
    }
}
