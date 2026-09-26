import Foundation

/// Top-left normalized coordinates before Geometry; radius is a fraction of the
/// short image dimension. Sources remain available when a later crop hides them.
struct ManualBlemishCorrection: Codable, Sendable, Equatable, Identifiable {
  var id = UUID()
  var version = 2
  var targetCenter: MaskPoint
  var targetRadius: Double
  var sourceCenter: MaskPoint
  var feather = 0.45
  var strength = 100.0
  var enabled = true
  var confidence = 0.0
  var faceWidthFraction = 0.4
  // Optional fields preserve decoding of all version-1 circular documents.
  var targetStrokes: [HealingTargetStroke]?
  var manualSource: Bool?
  mutating func moveTarget(to point: MaskPoint) {
    let dx=point.x-targetCenter.x, dy=point.y-targetCenter.y
    targetStrokes = targetStrokes?.map { stroke in
      var s=stroke; s.points=s.points.map { .init(x:$0.x+dx,y:$0.y+dy) }; return s
    }
    targetCenter=point
  }
  mutating func resizeTarget(to radius: Double) {
    let scale=radius/max(0.001,targetRadius)
    targetStrokes=targetStrokes?.map { stroke in
      var s=stroke; s.radius *= scale
      s.points=s.points.map { .init(x:targetCenter.x+($0.x-targetCenter.x)*scale,y:targetCenter.y+($0.y-targetCenter.y)*scale) };return s
    }
    targetRadius=radius
  }
  var validated: Self {
    var s = self
    func bound(_ x: Double, _ lo: Double, _ hi: Double) -> Double {
      x.isFinite ? min(hi, max(lo, x)) : lo
    }
    s.targetCenter = targetCenter.validated
    s.sourceCenter = sourceCenter.validated
    s.targetRadius = bound(targetRadius, 0.001, 0.05)
    s.feather = bound(feather, 0.15, 0.9)
    s.strength = bound(strength, 0, 100)
    s.confidence = bound(confidence, 0, 1)
    s.faceWidthFraction = bound(faceWidthFraction, 0.01, 1)
    s.targetStrokes=targetStrokes?.prefix(128).map(\.validated)
    if s.targetStrokes != nil || s.manualSource != nil { s.version=max(2,s.version) }
    return s
  }
}


struct HealingTargetStroke: Codable, Sendable, Equatable {
  var points: [MaskPoint]
  /// Radius in fractions of the canonical short image dimension.
  var radius: Double
  var erase: Bool
  var validated: Self {
    .init(points:Array(points.prefix(4096)).map(\.validated),
      radius:radius.isFinite ? min(0.05,max(0.001,radius)) : 0.005,erase:erase)
  }
}
