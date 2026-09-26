import CoreImage
import Foundation

struct HealingCandidate: Sendable {
  var center: MaskPoint
  var score: Double
  var luminance: Double
  var chroma: Double
  var texture: Double
  var edge: Double
  var skin: Double
  var anomaly: Double
  var repetition: Double
  var eligible: Bool
  var highPenalty: Double = 0
  var highRMSRatio: Double = 1
  var orientationMismatch: Double = 0
  var descriptorMS: Double = 0
}
struct HealingProposal: Sendable {
  var correction: ManualBlemishCorrection
  var candidates: [HealingCandidate]
  var targetMS: Double
  var sourceMS: Double
}

/// One immutable reduced linear bitmap and the existing frozen skin mask per
/// tool session. CPU readback happens on entry, never on drag/slider frames.
struct ManualHealingAnalysis: Sendable {
  var width: Int
  var height: Int
  var pixels: [Float]
  var skin: [Float]
  var faceWidthFraction: Double
  var size: CGSize { CGSize(width: width, height: height) }

  static func prepare(_ input: CIImage, masks: BeautyMasks, context: CIContext) throws -> Self {
    let e = input.extent.integral
    let w = Int(e.width)
    let h = Int(e.height)
    let space = CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!
    var rgba = [Float](repeating: 0, count: w * h * 4)
    context.render(
      input, toBitmap: &rgba, rowBytes: w * 16, bounds: e, format: .RGBAf, colorSpace: space)
    var matte = [Float](repeating: 0, count: w * h * 4)
    if let mask = masks.skin {
      let image = CIImage(cgImage: mask).transformed(
        by: CGAffineTransform(
          scaleX: CGFloat(w) / CGFloat(mask.width), y: CGFloat(h) / CGFloat(mask.height)))
      context.render(
        image, toBitmap: &matte, rowBytes: w * 16, bounds: e, format: .RGBAf, colorSpace: space)
    }
    try Task.checkCancellation()
    return Self(
      width: w, height: h, pixels: rgba,
      skin: stride(from: 0, to: matte.count, by: 4).map { matte[$0] },
      faceWidthFraction: Double(masks.faceWidthFraction))
  }
  private func index(_ x: Int, _ y: Int) -> Int {
    min(height - 1, max(0, y)) * width + min(width - 1, max(0, x))
  }
  private func rgb(_ x: Int, _ y: Int) -> SIMD3<Double> {
    let i = index(x, y) * 4
    return SIMD3(Double(pixels[i]), Double(pixels[i + 1]), Double(pixels[i + 2]))
  }
  private func luma(_ c: SIMD3<Double>) -> Double { c.x * 0.2126 + c.y * 0.7152 + c.z * 0.0722 }
  private func point(_ x: Double, _ y: Double) -> MaskPoint {
    .init(x: x / Double(width), y: y / Double(height))
  }
  private struct Stats {
    var mean = SIMD3<Double>.zero
    var y = 0.0, texture = 0.0, edge = 0.0, skin = 0.0, anomaly = 0.0
  }
  private func stats(_ x: Double, _ y: Double, _ r: Double) -> Stats {
    var s = Stats()
    var ys = [Double]()
    var colors = [SIMD3<Double>]()
    var edges = [Double]()
    for j in -2...2 {
      for i in -2...2 where i * i + j * j <= 5 {
        let px = Int(x + Double(i) * r / 2)
        let py = Int(y + Double(j) * r / 2)
        let c = rgb(px, py)
        let v = luma(c)
        s.mean += c
        ys.append(v)
        colors.append(c)
        s.skin += Double(skin[index(px, py)])
        let edge =
          abs(luma(rgb(px + 2, py)) - luma(rgb(px - 2, py)))
          + abs(luma(rgb(px, py + 2)) - luma(rgb(px, py - 2)))
        edges.append(edge)
      }
    }
    let n = Double(ys.count)
    s.mean /= n
    s.y = luma(s.mean)
    s.skin /= n
    s.texture = sqrt(ys.reduce(0) { $0 + pow($1 - s.y, 2) } / n)
    s.edge = edges.max() ?? 0
    for c in colors {
      let d = c - s.mean
      s.anomaly = max(s.anomaly, abs(luma(d)) + abs(d.x - d.y) * 0.7)
    }
    return s
  }
  /// Texture-only descriptor, measured away from the lesion in a target annulus.
  /// Two Laplacian scales and a structure tensor separate energy, scale and direction.
  private struct HighDescriptor {
    var rms: Double
    var scale: Double
    var orientation: Double
    var anisotropy: Double
  }
  private func highDescriptor(_ x: Double, _ y: Double, _ r: Double, annulus: Bool) -> HighDescriptor {
    var e1=0.0, e2=0.0, xx=0.0, yy=0.0, xy=0.0, n=0.0
    let step=max(1, Int(r*0.18))
    for ring in 0..<3 {
      let rho = annulus ? 1.3+Double(ring)*0.25 : 0.25+Double(ring)*0.3
      for a in 0..<24 {
        let angle=Double(a)*Double.pi/12
        let px=Int(x+r*rho*cos(angle)), py=Int(y+r*rho*sin(angle))
        let c=luma(rgb(px,py))
        func high(_ d: Int) -> Double {
          c-(luma(rgb(px+d,py))+luma(rgb(px-d,py))+luma(rgb(px,py+d))+luma(rgb(px,py-d)))/4
        }
        let h1=high(step), h2=high(step*2)
        let gx=(luma(rgb(px+step,py))-luma(rgb(px-step,py)))/2
        let gy=(luma(rgb(px,py+step))-luma(rgb(px,py-step)))/2
        e1+=h1*h1; e2+=h2*h2; xx+=gx*gx; yy+=gy*gy; xy+=gx*gy; n+=1
      }
    }
    return .init(rms:sqrt(e1/n),scale:sqrt((e1+1e-9)/(e2+1e-9)),
      orientation:0.5*atan2(2*xy,xx-yy),anisotropy:hypot(xx-yy,2*xy)/(xx+yy+1e-9))
  }
  func propose(at tap: MaskPoint, existing: [ManualBlemishCorrection]) throws -> HealingProposal? {
    let start = ContinuousClock.now
    let x = tap.x * Double(width)
    let y = tap.y * Double(height)
    guard faceWidthFraction > 0, skin[index(Int(x), Int(y))] > 0.2 else { return nil }
    let face = faceWidthFraction * Double(width)
    let search = max(3, face * 0.028)
    let radius = max(2, face * 0.012)
    let surrounding = stats(x, y, search * 1.5)
    var best = 0.0
    var tx = x
    var ty = y
    for j in -Int(search)...Int(search) {
      try Task.checkCancellation()
      for i in -Int(search)...Int(search) where i * i + j * j <= Int(search * search) {
        let px = Int(x) + i
        let py = Int(y) + j
        guard skin[index(px, py)] > 0.25 else { continue }
        let local = stats(Double(px), Double(py), radius * 0.35)
        let d = local.mean - surrounding.mean
        let contrast = max(0, -luma(d)) + max(0, d.x - d.y) * 0.8
        let score = contrast * exp(-Double(i * i + j * j) / (2 * search * search))
        if score > best {
          best = score
          tx = Double(px)
          ty = Double(py)
        }
      }
    }
    if best < 0.008 {
      tx = x
      ty = y
    }
    let r = radius * min(1.7, max(1, best / 0.035))
    let target = stats(tx, ty, r * 1.5)
    let targetEnd = ContinuousClock.now
    var candidates = [HealingCandidate]()
    let targetHigh = highDescriptor(tx,ty,r,annulus:true)
    for ring in 0..<5 {
      try Task.checkCancellation()
      let distance = r * (2.8 + Double(ring) * 1.2)
      for angle in 0..<24 {
        let a = Double(angle) * Double.pi / 12
        let sx = tx + cos(a) * distance
        let sy = ty + sin(a) * distance
        guard sx > r * 2, sy > r * 2, sx < Double(width) - r * 2, sy < Double(height) - r * 2 else {
          continue
        }
        let s = stats(sx, sy, r * 1.2)
        let descriptorStart=ContinuousClock.now
        let hf=highDescriptor(sx,sy,r,annulus:false)
        let ratio=(hf.rms+0.0001)/(targetHigh.rms+0.0001)
        let orientation=acos(min(1,max(-1,cos(2*(hf.orientation-targetHigh.orientation)))))/2
        let highPenalty=0.035*abs(log(ratio))
          + 0.025*abs(log((hf.scale+0.01)/(targetHigh.scale+0.01)))
          + 0.025*orientation*min(hf.anisotropy,targetHigh.anisotropy)
          + 0.015*abs(hf.anisotropy-targetHigh.anisotropy)
        let descriptorDuration=descriptorStart.duration(to:.now)
        let descriptorMS=Double(descriptorDuration.components.seconds)*1000+Double(descriptorDuration.components.attoseconds)/1e15
        let dy = abs(s.y - target.y)
        let d = s.mean - target.mean
        let dc = sqrt(pow(d.x - d.y, 2) + pow(d.z - d.y, 2))
        let dt = abs(s.texture - target.texture)
        let repetition = existing.reduce(0.0) { n, c in
          let cx = c.sourceCenter.x * Double(width)
          let cy = c.sourceCenter.y * Double(height)
          return n + max(0, 1 - hypot(sx - cx, sy - cy) / (r * 2))
        }
        let score =
          dy * 2 + dc * 1.5 + dt + max(0, s.edge - 0.06) * 2 + s.anomaly * 2 + (1 - s.skin) * 0.25
          + distance / face * 0.15 + repetition * 0.12 + highPenalty
        candidates.append(
          .init(
            center: point(sx, sy), score: score, luminance: dy, chroma: dc, texture: dt,
            edge: s.edge, skin: s.skin, anomaly: s.anomaly, repetition: repetition,
            eligible: s.skin > 0.75 && s.edge < 0.25, highPenalty:highPenalty,
            highRMSRatio:ratio,orientationMismatch:orientation,descriptorMS:descriptorMS))
      }
    }
    candidates.sort { $0.score < $1.score }
    guard let chosen = candidates.first(where: { $0.eligible }) else { return nil }
    let confidence = max(0, min(1, 1 - chosen.score / 0.25))
    let c = ManualBlemishCorrection(
      targetCenter: point(tx, ty), targetRadius: r / Double(min(width, height)),
      sourceCenter: chosen.center, confidence: confidence, faceWidthFraction: faceWidthFraction)
    func ms(_ d: Duration) -> Double {
      Double(d.components.seconds) * 1000 + Double(d.components.attoseconds) / 1e15
    }
    return .init(
      correction: c, candidates: Array(candidates.prefix(24)),
      targetMS: ms(start.duration(to: targetEnd)), sourceMS: ms(targetEnd.duration(to: .now)))
  }
}
