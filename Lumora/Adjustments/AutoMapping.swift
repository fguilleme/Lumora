import Foundation

enum AutoCurveStyle: String, CaseIterable, Codable, Sendable, Identifiable {
    case natural, balanced, punchy
    var id: String { rawValue }
    var title: String { switch self { case .natural: "Naturel"; case .balanced: "Équilibré"; case .punchy: "Soutenu" } }
}
enum AutoModule: String, Sendable { case light, color, curves, global }
struct AutoFitError: Codable, Sendable {
    let mae: Double
    let rmse: Double
    let p95: Double
    let maximum: Double
    init(_ errors: [Double]) {
        let e=errors.map(abs).sorted(),n=Double(max(1,e.count))
        mae=e.reduce(0,+)/n;rmse=sqrt(e.map{$0*$0}.reduce(0,+)/n)
        p95=e.isEmpty ? 0 : e[Int(Double(e.count-1)*0.95)];maximum=e.last ?? 0
    }
    var classification: String {
        maximum == 0 ? "Exact" : maximum < 0.005 ? "Near Exact" : maximum < 0.05 ? "Approximate" : "Poor Approximation"
    }
}
struct AutoCurveFit: Sendable {
    let curve: ToneCurve
    let sdr: AutoFitError
    let hdr: AutoFitError
}
struct AutoLightFit: Sendable {
    let settings: EditState
    let sdr: AutoFitError
    let hdr: AutoFitError
}

enum AutoTonalMapping {
    static func encode(_ x: Double) -> Double { x <= 0.0031308 ? 12.92*x : 1.055*pow(x,1/2.4)-0.055 }
    static func decode(_ x: Double) -> Double { x <= 0.04045 ? x/12.92 : pow((x+0.055)/1.055,2.4) }
    /// Neutral-axis evaluation of the existing development primitives. Color pixels are NOT
    /// claimed equivalent: Light adds a luminance delta, whereas RGB Curves map each channel.
    static func light(_ y: Double, _ s: EditState) -> Double {
        let exposed=y*pow(2,s.exposure)
        let hasTone=Adjustment.light.dropFirst().contains { s[$0] != 0 }
        return hasTone ? decode(TonalResponse.map(min(1,max(0,encode(exposed))),state:s)) : exposed
    }
    static func curve(_ y: Double, _ c: ToneCurve) -> Double {
        c.isIdentity ? y : decode(c.evaluate(encode(y)))
    }
    static func canonical(_ y: Double, intent: AutoCorrectionIntent, style: AutoCurveStyle = .balanced) -> Double {
        let target=light(y,intent.light)
        switch style {
        case .balanced: return target
        case .natural: return 0.5*y+0.5*target
        case .punchy:
            // Strictly increasing bounded log-domain contrast around middle gray.
            return target <= 0 ? target : target*exp(0.08*tanh(log(max(1e-9,target)/0.18)))
        }
    }
    static func fit(intent: AutoCorrectionIntent, style: AutoCurveStyle = .balanced) -> AutoCurveFit {
        fit { canonical($0,intent:intent,style:style) }
    }
    static func fit(light settings: EditState) -> AutoCurveFit { fit { light($0,settings) } }
    static func fit(_ target: (Double)->Double) -> AutoCurveFit {
        let grid=(0...1024).map { Double($0)/1024 }
        let desired=grid.map { min(1,max(0,encode(target(decode($0))))) }
        // Preserve the existing identity bypass, including HDR. Round-off in sRGB
        // encode/decode must not activate a clamping SDR LUT for an identity request.
        if grid.indices.allSatisfy({ abs(desired[$0]-grid[$0]) < 1e-12 }) &&
            [2.0,4,8].allSatisfy({ abs(target($0)-$0) < 1e-12 }) {
            return .init(curve:ToneCurve(),
                         sdr:AutoFitError(grid.map { $0-target($0) }),
                         hdr:AutoFitError(grid.map { let y=1+7*$0;return y-target(y) }))
        }
        var points=[0.0,0.12,0.35,0.65,1.0].map { CurvePoint(x:$0,y:min(1,max(0,encode(target(decode($0)))))) }
        var curve=ToneCurve(points:points)
        // At most ten visible points; minimum spacing is the editor's own constraint.
        while points.count < 10 {
            let candidates=grid.indices.filter { i in points.allSatisfy { abs($0.x-grid[i]) >= ToneCurve.minimumSpacing } }
            guard let i=candidates.max(by:{ abs(curve.evaluate(grid[$0])-desired[$0]) < abs(curve.evaluate(grid[$1])-desired[$1]) }),
                  abs(curve.evaluate(grid[i])-desired[i]) > 0.004 else { break }
            points.append(.init(x:grid[i],y:desired[i]));curve=ToneCurve(points:points)
        }
        let sdr=AutoFitError((0...4096).map { let y=Double($0)/4096;return Self.curve(y,curve)-target(y) })
        let hdr=AutoFitError((0...4096).map { let y=1+7*Double($0)/4096;return Self.curve(y,curve)-target(y) })
        return .init(curve:curve,sdr:sdr,hdr:hdr)
    }
    static func approximate(_ curve: ToneCurve) -> AutoLightFit {
        let grid=(0...256).map { decode(Double($0)/256) }
        let targets=grid.map { Self.curve($0,curve) }
        func loss(_ s: EditState)->Double {
            zip(grid,targets).reduce(0) { let e=light($1.0,s)-$1.1;return $0+e*e }/Double(grid.count)
        }
        var best=EditState(),bestLoss=loss(EditState())
        for scale in [1.0,0.5,0.25,0.125,0.0625,0.03125] {
            for _ in 0..<4 {
                var changed=false
                for parameter in Adjustment.light {
                    for direction in [-1.0,1.0] {
                        var candidate=best
                        candidate[parameter] += direction*scale*(parameter == .exposure ? 1:20)
                        let value=loss(candidate)
                        if value < bestLoss { best=candidate;bestLoss=value;changed=true }
                    }
                }
                if !changed { break }
            }
        }
        return .init(settings:best,
                     sdr:AutoFitError((0...4096).map { let y=Double($0)/4096;return light(y,best)-Self.curve(y,curve) }),
                     hdr:AutoFitError((0...4096).map { let y=1+7*Double($0)/4096;return light(y,best)-Self.curve(y,curve) }))
    }
}

struct AutoProposal: Sendable {
    let analysis: ImageAnalysis
    let intent: AutoCorrectionIntent
    let curves: [AutoCurveStyle: AutoCurveFit]
    init(_ analysis: ImageAnalysis) {
        self.analysis=analysis;let intent=AutoCorrectionIntent(analysis:analysis);self.intent=intent
        curves=Dictionary(uniqueKeysWithValues:AutoCurveStyle.allCases.map { ($0,AutoTonalMapping.fit(intent:intent,style:$0)) })
    }
    /// Explicit replacement of the tonal pair prevents stale provenance and double application,
    /// even after reload. The user can subsequently combine manual Light + Curves freely.
    func applying(_ module: AutoModule, style: AutoCurveStyle = .balanced, to source: EditState) -> EditState {
        var result=source
        if module == .light || module == .global || module == .curves {
            for p in Adjustment.light { result[p] = module == .curves ? 0 : intent.light[p] }
            result.curves.rgb = module == .curves ? curves[style]!.curve : ToneCurve()
        }
        if module == .color || module == .global {
            for p in Adjustment.color { result[p]=intent.color[p] }
        }
        return result
    }
    func matches(_ module: AutoModule, style: AutoCurveStyle = .balanced, state: EditState) -> Bool {
        applying(module,style:style,to:state) == state
    }
}

/// Map the unchanged, confidence-weighted intent to visible production controls.
/// Neutral-ramp central differences (Temperature ±4, Tint ±3), in log chromatic axes:
/// J = [[-.00804569755, -.000426183135], [-.000858241143, .00360074528]].
/// Positive Temperature cools; positive Tint greens. M = -J⁻¹ diag(J) corrects
/// both signs and cancels first-order cross-coupling, retaining the existing
/// diagonal correction strengths rather than fitting a new full-neutralization gain.
/// Calibration/linearity measurements: Auto/WB/renderer_axis_characterization.md.
enum AutoWBMapping {
    static func controls(temperatureIntent: Double, tintIntent: Double) -> (temperature: Double, tint: Double) {
        let temperature = -0.987531890276 * temperatureIntent + 0.052309875438 * tintIntent
        let tint = -0.235379187216 * temperatureIntent - 0.987531890276 * tintIntent
        return (min(16,max(-16,temperature)).rounded(), min(12,max(-12,tint)).rounded())
    }
}
