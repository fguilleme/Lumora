import CoreImage
import Foundation
import Testing

@testable import LumoraCore

private func healingInput(_ n: Int = 128) -> CIImage {
  var values = [Float](repeating: 1, count: n * n * 4)
  for y in 0..<n {
    for x in 0..<n {
      let i = (y * n + x) * 4
      let v =
        Float(x) / Float(n) * 1.8 - 0.01 + Float(sin(Double(x) * 1.7) * cos(Double(y) * 1.3)) * 0.01
      values[i] = v
      values[i + 1] = v * 0.8
      values[i + 2] = v * 0.6
    }
  }
  return CIImage(
    bitmapData: values.withUnsafeBytes { Data($0) }, bytesPerRow: n * 16,
    size: CGSize(width: n, height: n), format: .RGBAf,
    colorSpace: CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!)
}
private func healingRead(_ image: CIImage, _ rect: CGRect? = nil) -> [Float] {
  let r = (rect ?? image.extent).integral
  var values = [Float](repeating: 0, count: Int(r.width * r.height) * 4)
  CIContext(options: [.workingColorSpace: CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!])
    .render(
      image, toBitmap: &values, rowBytes: Int(r.width) * 16, bounds: r, format: .RGBAf,
      colorSpace: CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!)
  return values
}
@Test func manualHealingIdentityReconstructionHDRAndLocality() throws {
  let image = healingInput()
  var c = ManualBlemishCorrection(
    targetCenter: .init(x: 0.4, y: 0.5), targetRadius: 0.05, sourceCenter: .init(x: 0.7, y: 0.5))
  #expect(try ManualHealingRenderer.apply(image, corrections: []) === image)
  #expect(try ManualHealingRenderer.apply(image, corrections: [c], amount: 0) === image)
  c.strength = 0
  #expect(try ManualHealingRenderer.apply(image, corrections: [c]) === image)
  c.strength = 100
  let reconstruction = try ManualHealingRenderer.diagnostic(image, correction: c, mode: 6)
  let a = healingRead(image, reconstruction.extent)
  let b = healingRead(reconstruction)
  #expect(zip(a, b).map { abs($0 - $1) }.max()! < 0.002)
  let output = try ManualHealingRenderer.apply(image, corrections: [c])
  let original = healingRead(image)
  let result = healingRead(output)
  #expect(result.allSatisfy { $0.isFinite })
  #expect(result.max()! > 1)
  var outside = Float(0)
  var changed = 0
  for y in 0..<128 {
    for x in 0..<128 {
      let d = hypot(Double(x) + 0.5 - 51.2, Double(y) + 0.5 - 64)
      for k in 0..<3 {
        let i = (y * 128 + x) * 4 + k
        let error = abs(original[i] - result[i])
        if d > 8 { outside = max(outside, error) } else if error > 0.0001 { changed += 1 }
      }
    }
  }
  #expect(outside < 0.002)
  #expect(changed > 0)
  #expect(healingRead(try ManualHealingRenderer.apply(image, corrections: [c])) == result)
}
@Test func manualHealingPersistenceMigrationAndUndo() throws {
  var state = EditState()
  var history = HistoryManager()
  let old = try JSONEncoder().encode(state)
  #expect(try JSONDecoder().decode(EditState.self, from: old).beauty.corrections.isEmpty)
  let c = ManualBlemishCorrection(
    targetCenter: .init(x: 0.4, y: 0.5), targetRadius: 0.01, sourceCenter: .init(x: 0.6, y: 0.5))
  history.begin("create", state: state)
  state.beauty.corrections = [c]
  history.commit(state)
  history.begin("drag source", state: state)
  for i in 1...20 { state.beauty.corrections[0].sourceCenter.x = 0.6 + Double(i) / 1000 }
  history.commit(state)
  #expect(history.undo()?.beauty.corrections[0].sourceCenter == c.sourceCenter)
  #expect(history.undo()?.beauty.corrections.isEmpty == true)
  _ = history.redo()
  let next = history.redo()
  let restored = try #require(next)
  #expect(restored == state)
  #expect(try JSONDecoder().decode(EditState.self, from: JSONEncoder().encode(state)) == state)
  #expect(!state.beauty.isIdentity)
  state.beauty.corrections[0].strength = 0
  #expect(state.beauty.isIdentity)
}
@Test func manualHealingGeometryRoundtripAndRenderedCoordinates() throws {
  let n = 256
  var values = [Float](repeating: 1, count: n * n * 4)
  for y in 0..<n {
    for x in 0..<n {
      let i = (y * n + x) * 4
      values[i] = Float(x) / Float(n)
      values[i + 1] = Float(y) / Float(n)
      values[i + 2] = 0
    }
  }
  let field = CIImage(
    bitmapData: values.withUnsafeBytes { Data($0) }, bytesPerRow: n * 16,
    size: CGSize(width: n, height: n), format: .RGBAf,
    colorSpace: CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!)
  for turn in 0...3 {
    for mirror in [false, true] {
      var s = GeometrySettings()
      s.quarterTurns = turn
      s.flipHorizontal = mirror
      s.cropZoom = 23
      s.cropX = 17
      s.cropY = -29
      s.straighten = 5
      s.perspectiveVertical = 20
      s.perspectiveHorizontal = -13
      let map = HealingGeometry(size: CGSize(width: n, height: n), settings: s)
      let output = GeometryRenderer.apply(field, settings: s)
      #expect(abs(map.outputSize.width - output.extent.width) < 0.001)
      for point in [MaskPoint(x: 0.3, y: 0.4), .init(x: 0.5, y: 0.5), .init(x: 0.6, y: 0.7)] {
        let visible = map.display(point)
        let back = map.canonical(visible)
        #expect(abs(back.x - point.x) < 1e-8)
        #expect(abs(back.y - point.y) < 1e-8)
        let x = floor(visible.x * output.extent.width)
        let y = floor((1 - visible.y) * output.extent.height)
        let sampled = healingRead(output, CGRect(x: x, y: y, width: 1, height: 1))
        #expect(abs(Double(sampled[0]) - point.x) < 0.015)
        #expect(abs(Double(sampled[1]) - point.y) < 0.015)
      }
    }
  }
}
@Test func manualHealingLocalProposalAndOutsideFace() throws {
  let w = 256
  var pixels = [Float](repeating: 1, count: w * w * 4)
  var mask = [Float](repeating: 1, count: w * w)
  for y in 0..<w {
    for x in 0..<w {
      let i = (y * w + x) * 4
      let lesion = Float(exp(-Double((x - 128) * (x - 128) + (y - 128) * (y - 128)) / 18))
      pixels[i] = 0.4 + 0.10 * lesion
      pixels[i + 1] = 0.28 - 0.08 * lesion
      pixels[i + 2] = 0.22 - 0.06 * lesion
      if x < 40 || x > 210 || y < 40 || y > 210 { mask[y * w + x] = 0 }
    }
  }
  let data = ManualHealingAnalysis(
    width: w, height: w, pixels: pixels, skin: mask, faceWidthFraction: 0.65)
  let p = try #require(try data.propose(at: .init(x: 0.51, y: 0.5), existing: []))
  #expect(abs(p.correction.targetCenter.x - 0.5) < 0.015)
  #expect(p.candidates.contains { $0.eligible })
  #expect(try data.propose(at: .init(x: 0.02, y: 0.02), existing: []) == nil)
  let q = try #require(try data.propose(at: .init(x: 0.51, y: 0.5), existing: []))
  #expect(p.correction.sourceCenter == q.correction.sourceCenter)
}
@Test func manualHealingCancellation() async {
  let data = ManualHealingAnalysis(
    width: 256, height: 256,
    pixels: [Float](repeating: 0.3, count: 256 * 256 * 4),
    skin: [Float](repeating: 1, count: 256 * 256), faceWidthFraction: 0.6)
  let task = Task.detached {
    // Delay deliberately so cancellation arrives before the real local search.
    try? await Task.sleep(for: .milliseconds(50))
    return try data.propose(at: .init(x: 0.5, y: 0.5), existing: [])
  }
  task.cancel()
  do {
    _ = try await task.value
    Issue.record("Local search ignored cancellation")
  } catch is CancellationError {} catch { Issue.record("Unexpected error") }
}

@Test func manualHealingStrengthRadiusAndManualSourceResponse() throws {
  let input = healingInput(256)
  let before = healingRead(input)
  var c = ManualBlemishCorrection(
    targetCenter: .init(x: 0.4, y: 0.5), targetRadius: 0.02, sourceCenter: .init(x: 0.65, y: 0.5))
  var previous = 0.0
  for strength in [0.0, 25, 50, 75, 100] {
    c.strength = strength
    let pixels = healingRead(try ManualHealingRenderer.apply(input, corrections: [c]))
    let error = zip(before, pixels).reduce(0.0) { $0 + Double(abs($1.0 - $1.1)) }
    #expect(error + 0.02 >= previous)
    previous = error
  }
  let fixed = c.sourceCenter
  c.targetRadius = 0.04
  let large = healingRead(try ManualHealingRenderer.apply(input, corrections: [c]))
  #expect(c.sourceCenter == fixed)
  c.sourceCenter.x = 0.73
  let moved = healingRead(try ManualHealingRenderer.apply(input, corrections: [c]))
  #expect(large != moved)
  var list = [c]
  for n in 1..<25 {
    var v = c
    v.id = UUID()
    v.targetCenter.x = 0.2 + Double(n % 5) * 0.1
    v.targetCenter.y = 0.2 + Double(n / 5) * 0.1
    list.append(v)
  }
  let snapshot = list
  let all = healingRead(try ManualHealingRenderer.apply(input, corrections: list))
  #expect(all.allSatisfy { $0.isFinite })
  #expect(list == snapshot)
}

@Test func manualHealingPreservesTargetLightingAndExtendedRange() throws {
  let input = healingInput().applyingFilter(
    "CIColorMatrix",
    parameters: [
      "inputRVector": CIVector(x: 4.5, y: 0, z: 0, w: 0),
      "inputGVector": CIVector(x: 0, y: 4.5, z: 0, w: 0),
      "inputBVector": CIVector(x: 0, y: 0, z: 4.5, w: 0),
    ])
  let c = ManualBlemishCorrection(
    targetCenter: .init(x: 0.4, y: 0.5), targetRadius: 0.05, sourceCenter: .init(x: 0.7, y: 0.5))
  let output = try ManualHealingRenderer.apply(input, corrections: [c])
  let pixels = healingRead(output)
  #expect(pixels.allSatisfy { $0.isFinite })
  #expect(pixels.max()! > 7)
  #expect(pixels.min()! < 0)
  let bounds = CGRect(x: 49, y: 62, width: 4, height: 4)
  let a = healingRead(input, bounds)
  let b = healingRead(output, bounds)
  let mean = zip(a, b).reduce(0.0) { $0 + Double($1.1 - $1.0) } / Double(a.count)
  #expect(abs(mean) < 0.08, "Source's much brighter broad illumination must not transfer")
}

@Test func manualHealingResizedPatchTileConsistency() throws {
  let image = healingInput(512)
  for radius in [0.01, 0.02, 0.05] {
    let c = ManualBlemishCorrection(targetCenter: .init(x: 0.4, y: 0.5), targetRadius: radius,
                                  sourceCenter: .init(x: 0.7, y: 0.5))
    let output = try ManualHealingRenderer.apply(image, corrections: [c])
    let full = healingRead(output)
    var maximum: Float = 0
    for x in stride(from: 176, to: 240, by: 4) {
      let rect = CGRect(x: x, y: 224, width: 4, height: 64)
      let tile = healingRead(output, rect)
      for y in 0..<64 { for dx in 0..<4 { for channel in 0..<3 {
        maximum = max(maximum, abs(tile[(y*4+dx)*4+channel]-full[((224+y)*512+x+dx)*4+channel]))
      } } }
    }
    print("Healing tile consistency radius=\(radius): \(maximum)")
    #expect(maximum < 0.002)
  }
}

/// A dark region outside the repaired disk must not be extrapolated into a
/// bright center. This models enlarging a cheek repair toward a hair boundary.
@Test func manualHealingNoBrightExtrapolationFromDistantDarkBoundary() throws {
 let n=512
 var pixels=[Float](repeating:1,count:n*n*4)
 for y in 0..<n {for x in 0..<n {
  let value:Float=x<223 ? 0.02 : 0.45
  for channel in 0..<3 {pixels[(y*n+x)*4+channel]=value}
 }}
 let space=CGColorSpace(name:CGColorSpace.extendedLinearSRGB)!
 let image=CIImage(bitmapData:pixels.withUnsafeBytes{Data($0)},bytesPerRow:n*16,size:.init(width:n,height:n),format:.RGBAf,colorSpace:space)
 let c=ManualBlemishCorrection(targetCenter:.init(x:0.5,y:0.5),targetRadius:0.05,sourceCenter:.init(x:0.7,y:0.5))
 let output=healingRead(try ManualHealingRenderer.apply(image,corrections:[c]))
 var peak:Float=0
 for y in 250..<262 {for x in 250..<262 {peak=max(peak,output[(y*n+x)*4])}}
 print("Distant dark boundary: center peak \(peak), original 0.45")
 #expect(peak<=0.451)
 #expect(output.allSatisfy { $0.isFinite })
}
