import CoreImage
import Foundation

/// A homography mirrors GeometryRenderer without changing its rendering math.
/// Input/output points use top-left normalized image coordinates, UI zoom/pan
/// is handled separately by PhotoCanvas.
struct HealingGeometry {
  private var h: [Double]
  private var inverse: [Double]
  let inputSize: CGSize
  let outputSize: CGSize
  init(size: CGSize, settings raw: GeometrySettings) {
    inputSize = size
    let s = raw.validated
    var matrix = [1.0, 0, 0, 0, 1, 0, 0, 0, 1]
    var e = CGRect(origin: .zero, size: size)
    func multiply(_ a: [Double], _ b: [Double]) -> [Double] {
      (0..<9).map { k in (0..<3).reduce(0.0) { $0 + a[(k / 3) * 3 + $1] * b[$1 * 3 + k % 3] } }
    }
    func affine(_ t: CGAffineTransform) {
      matrix = multiply([t.a, t.c, t.tx, t.b, t.d, t.ty, 0, 0, 1], matrix)
    }
    func normalizedTransform(_ t: CGAffineTransform) {
      affine(t)
      e = e.applying(t)
      affine(.init(translationX: -e.minX, y: -e.minY))
      e.origin = .zero
    }
    if !s.isIdentity {
      if s.quarterTurns != 0 {
        normalizedTransform(
          CGAffineTransform(translationX: e.midX, y: e.midY)
            .rotated(by: -CGFloat(s.quarterTurns) * .pi / 2).translatedBy(x: -e.midX, y: -e.midY))
      }
      if s.flipHorizontal || s.flipVertical {
        normalizedTransform(
          CGAffineTransform(translationX: e.midX, y: e.midY)
            .scaledBy(x: s.flipHorizontal ? -1 : 1, y: s.flipVertical ? -1 : 1)
            .translatedBy(x: -e.midX, y: -e.midY))
      }
      if s.perspectiveVertical != 0 || s.perspectiveHorizontal != 0 {
        let v = s.perspectiveVertical / 100 * e.width * 0.22
        let h = s.perspectiveHorizontal / 100 * e.height * 0.22
        let corners = [
          CGPoint(x: max(0, v), y: e.height - max(0, -h)),
          CGPoint(x: e.width - max(0, v), y: e.height - max(0, h)),
          CGPoint(x: max(0, -v), y: max(0, -h)),
          CGPoint(x: e.width - max(0, -v), y: max(0, h)),
        ]
        let blank = CIImage(color: .black).cropped(to: e)
        let filter = CIFilter(
          name: "CIPerspectiveCorrection",
          parameters: [
            kCIInputImageKey: blank,
            "inputTopLeft": CIVector(cgPoint: corners[0]),
            "inputTopRight": CIVector(cgPoint: corners[1]),
            "inputBottomLeft": CIVector(cgPoint: corners[2]),
            "inputBottomRight": CIVector(cgPoint: corners[3]), "inputCrop": true,
          ])
        if let output = filter?.outputImage {
          let oe = output.extent
          let to = [
            CGPoint(x: 0, y: oe.height), CGPoint(x: oe.width, y: oe.height), CGPoint.zero,
            CGPoint(x: oe.width, y: 0),
          ]
          matrix = multiply(Self.fit(corners, to), matrix)
          e = CGRect(origin: .zero, size: oe.size)
        }
      }
      if s.straighten != 0 {
        let angle = s.straighten * .pi / 180
        let scale = max(
          abs(cos(angle)) + e.height / e.width * abs(sin(angle)),
          abs(cos(angle)) + e.width / e.height * abs(sin(angle)))
        affine(
          CGAffineTransform(translationX: e.midX, y: e.midY).rotated(by: -angle)
            .scaledBy(x: scale, y: scale).translatedBy(x: -e.midX, y: -e.midY))
      }
      let sx = 1 + s.perspectiveAspect / 100 * 0.25
      let sy = 1 - s.perspectiveAspect / 100 * 0.25
      let fill = max(1 / sx, 1 / sy) * s.perspectiveScale / 100
      affine(
        CGAffineTransform(
          translationX: e.midX + s.perspectiveOffsetX / 100 * e.width * 0.2,
          y: e.midY + s.perspectiveOffsetY / 100 * e.height * 0.2
        )
        .scaledBy(x: sx * fill, y: sy * fill).translatedBy(x: -e.midX, y: -e.midY))
      var w = e.width
      var h = e.height
      if let ratio = s.aspect.ratio { if w / h > ratio { w = h * ratio } else { h = w / ratio } }
      let z = 1 - s.cropZoom / 100 * 0.8
      w = max(1, floor(w * z))
      h = max(1, floor(h * z))
      let x = floor((e.width - w) * (s.cropX + 100) / 200)
      let y = floor((e.height - h) * (100 - s.cropY) / 200)
      affine(.init(translationX: -x, y: -y))
      e = CGRect(x: 0, y: 0, width: w, height: h)
    }
    h = matrix
    inverse = Self.invert(matrix)
    outputSize = e.size
  }
  func display(_ p: MaskPoint) -> MaskPoint {
    let q = Self.apply(h, CGPoint(x: p.x * inputSize.width, y: (1 - p.y) * inputSize.height))
    return .init(x: q.x / outputSize.width, y: 1 - q.y / outputSize.height)
  }
  func canonical(_ p: MaskPoint) -> MaskPoint {
    let q = Self.apply(
      inverse, CGPoint(x: p.x * outputSize.width, y: (1 - p.y) * outputSize.height))
    return .init(x: q.x / inputSize.width, y: 1 - q.y / inputSize.height)
  }
  static private func apply(_ m: [Double], _ p: CGPoint) -> CGPoint {
    let z = m[6] * p.x + m[7] * p.y + m[8]
    return CGPoint(x: (m[0] * p.x + m[1] * p.y + m[2]) / z, y: (m[3] * p.x + m[4] * p.y + m[5]) / z)
  }
  static private func invert(_ m: [Double]) -> [Double] {
    let a = m[0]
    let b = m[1]
    let c = m[2]
    let d = m[3]
    let e = m[4]
    let f = m[5]
    let g = m[6]
    let h = m[7]
    let i = m[8]
    let v = [
      e * i - f * h, c * h - b * i, b * f - c * e, f * g - d * i, a * i - c * g, c * d - a * f,
      d * h - e * g, b * g - a * h, a * e - b * d,
    ]
    let det = a * v[0] + b * v[3] + c * v[6]
    return v.map { $0 / det }
  }
  static private func fit(_ from: [CGPoint], _ to: [CGPoint]) -> [Double] {
    var rows = [[Double]]()
    for (p, q) in zip(from, to) {
      rows.append([p.x, p.y, 1, 0, 0, 0, -q.x * p.x, -q.x * p.y, q.x])
      rows.append([0, 0, 0, p.x, p.y, 1, -q.y * p.x, -q.y * p.y, q.y])
    }
    for i in 0..<8 {
      let pivot = (i..<8).max { abs(rows[$0][i]) < abs(rows[$1][i]) }!
      rows.swapAt(i, pivot)
      let div = rows[i][i]
      for j in i...8 { rows[i][j] /= div }
      for k in 0..<8 where k != i {
        let f = rows[k][i]
        for j in i...8 { rows[k][j] -= f * rows[i][j] }
      }
    }
    return rows.map { $0[8] } + [1]
  }
}
