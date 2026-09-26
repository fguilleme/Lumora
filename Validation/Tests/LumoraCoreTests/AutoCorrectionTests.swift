import Foundation
import CoreImage
import Testing
@testable import LumoraCore

private func autoPixels(_ colors: [[Float]]) -> [Float] { colors.flatMap { $0 + [1] } }
private func autoRamp(_ gain: Float = 1) -> [Float] {
    (0..<4096).flatMap { i -> [Float] in let x=Float(i)/4095*gain;return [x,x,x,1] }
}
private func autoQuantilePixels(p50:Double,p95:Double,p99:Double)->[Float] {
    let knots:[(Double,Double)]=[(0,0),(0.04,0),(0.5,p50),(0.95,p95),(0.99,p99),(1,p99)]
    return (0..<2048).flatMap { index -> [Float] in
        let probability=Double(index)/2047
        let upper=(1..<knots.count).first{probability<=knots[$0].0} ?? knots.count-1
        let a=knots[upper-1],b=knots[upper],t=(probability-a.0)/max(1e-9,b.0-a.0)
        let value=Float(a.1+(b.1-a.1)*t)
        return [value,value,value,1]
    }
}
@Test func autoDarkForegroundBroadHighlightsDoNotLiftNightOrSilhouette() {
    let portrait=AutoCorrectionIntent(analysis:ImageAnalysis.measure(autoQuantilePixels(p50:0.004,p95:0.96,p99:0.99)))
    let night=AutoCorrectionIntent(analysis:ImageAnalysis.measure(autoQuantilePixels(p50:0.016,p95:0.27,p99:0.95)))
    let silhouette=AutoCorrectionIntent(analysis:ImageAnalysis.measure(autoQuantilePixels(p50:0.009,p95:0.46,p99:0.78)))
    #expect(portrait.scene == .backlit && portrait.exposureShiftEV > 0.2 && portrait.shadowLift > 10)
    #expect(night.scene == .lowKey && night.exposureShiftEV == 0 && night.shadowLift == 3)
    #expect(silhouette.scene == .lowKey && silhouette.exposureShiftEV == 0 && silhouette.shadowLift == 3)
    var previous:AutoCorrectionIntent?
    for delta in [-0.002,-0.001,0,0.001,0.002] {
        let current=AutoCorrectionIntent(analysis:ImageAnalysis.measure(autoQuantilePixels(p50:0.06+delta,p95:0.82+delta,p99:0.98)))
        if let previous {
            #expect(abs(current.exposureShiftEV-previous.exposureShiftEV)<=0.06)
            #expect(abs(current.shadowLift-previous.shadowLift)<=8)
        }
        previous=current
    }
}
@Test func autoRobustStatisticsPreserveHDR() {
    let a=ImageAnalysis.measure(autoRamp(8))
    #expect(abs(a.luminance.median-4)<1e-6)
    #expect(a.hdrFraction>0.8)
    #expect(a.rgb.count==3 && a.luminance.percentiles.count==7)
    #expect(a.nonFinite==0)
    let black=ImageAnalysis.measure(autoPixels(Array(repeating:[0,0,0],count:100)))
    #expect(black.blackFraction==1)
    #expect(AutoCorrectionIntent(analysis:black).exposureShiftEV==0)
}
@Test func autoDeterministicNeutralAndBounds() {
    for gain:Float in [0,0.001,0.05,0.18,0.5,1,2,4,8] {
        let pixels=autoRamp(gain),a=ImageAnalysis.measure(pixels),b=ImageAnalysis.measure(pixels)
        #expect(a==b)
        let intent=AutoCorrectionIntent(analysis:a)
        #expect(intent==AutoCorrectionIntent(analysis:b))
        #expect(intent.temperatureIntent==0 && intent.tintIntent==0)
        for p in Adjustment.allCases {
            #expect(p.range.contains(intent.light[p]) && intent.light[p].isFinite)
            #expect(p.range.contains(intent.color[p]) && intent.color[p].isFinite)
        }
        for style in AutoCurveStyle.allCases {
            let fit=AutoTonalMapping.fit(intent:intent,style:style)
            #expect(fit.curve.points.count<=10)
            var previous = -Double.infinity
            for i in 0...4096 {
                let y=Double(i)*8/4096,value=AutoTonalMapping.canonical(y,intent:intent,style:style)
                #expect(value.isFinite && value+1e-12>=previous)
                previous=value
            }
            let points=fit.curve.points
            for i in 1..<points.count { #expect(points[i].x>points[i-1].x && points[i].y>=points[i-1].y) }
        }
    }
}
@Test func autoIdempotenceOrdersAndNoDoubleCorrection() throws {
    let proposal=AutoProposal(ImageAnalysis.measure(autoRamp(0.2)))
    for module in [AutoModule.light,.color,.curves,.global] {
        let first=proposal.applying(module,to:EditState())
        #expect(proposal.applying(module,to:first)==first)
        var manual=first;manual.exposure=2;manual.temperature=20
        let second=proposal.applying(module,to:manual)
        #expect(proposal.matches(module,state:second))
        let saved=try JSONEncoder().encode(first),loaded=try JSONDecoder().decode(EditState.self,from:saved)
        #expect(loaded==first)
        var history=HistoryManager();var before=EditState();before.exposure = -1;before.temperature=12
        history.begin("Auto",state:before);history.commit(first)
        #expect(history.undo()==before);#expect(history.redo()==first)
    }
    let light=proposal.applying(.light,to:EditState())
    let curves=proposal.applying(.curves,to:light)
    #expect(Adjustment.light.allSatisfy { curves[$0]==0 })
    #expect(curves==proposal.applying(.curves,to:EditState()))
    #expect(proposal.applying(.light,to:curves)==light)
    #expect(proposal.applying(.color,to:light)==proposal.applying(.light,to:proposal.applying(.color,to:EditState())))
    #expect(proposal.applying(.global,to:EditState())==proposal.applying(.color,to:light))
    #expect(proposal.applying(.color,to:curves)==proposal.applying(.curves,to:proposal.applying(.color,to:EditState())))
}
@Test func autoAnalysisKeyInvalidation() {
    let url=URL(fileURLWithPath:"/tmp/photo-A.tiff"),base=EditState()
    let key=AutoAnalysisKey(url:url,version:"1",state:base,maskID:nil)
    var s=base;s.exposure=2;s.temperature=10;s.curves.rgb=ToneCurve(points:[.init(x:0,y:0),.init(x:0.5,y:0.7),.init(x:1,y:1)])
    s.creative.effects=[CreativeEffect(.silverBW)]
    #expect(key==AutoAnalysisKey(url:url,version:"1",state:s,maskID:nil))
    s.geometry.cropZoom=20
    #expect(key != AutoAnalysisKey(url:url,version:"1",state:s,maskID:nil))
    #expect(key != AutoAnalysisKey(url:url,version:"2",state:base,maskID:nil))
    #expect(key != AutoAnalysisKey(url:URL(fileURLWithPath:"/tmp/photo-B.tiff"),version:"1",state:base,maskID:nil))
    s=base;s.optics.distortion=10
    #expect(key != AutoAnalysisKey(url:url,version:"1",state:s,maskID:nil))
}
@Test func autoOutliersAndUniformInputs() {
    let pixels=autoRamp(0.25),a=ImageAnalysis.measure(pixels)
    var corrupted=pixels;corrupted[0]=100;corrupted[1]=100;corrupted[2]=100
    let b=ImageAnalysis.measure(corrupted)
    #expect(abs(a.luminance.median-b.luminance.median)<0.001)
    #expect(abs(AutoCorrectionIntent(analysis:a).exposureShiftEV-AutoCorrectionIntent(analysis:b).exposureShiftEV)<0.02)
    for level:Float in [-0.05,0,0.05,0.18,0.5,0.9,1,2,8] {
        let a=ImageAnalysis.measure(autoPixels(Array(repeating:[level,level,level],count:256)))
        let intent=AutoCorrectionIntent(analysis:a)
        #expect(intent.exposureShiftEV==0 && intent.temperatureIntent==0 && intent.tintIntent==0)
    }
    for color:[Float] in [[0.8,0.25,0.05],[0.1,0.6,0.1],[0.05,0.2,0.8]] {
        let intent=AutoCorrectionIntent(analysis:ImageAnalysis.measure(autoPixels(Array(repeating:color,count:256))))
        #expect(intent.wbConfidence==0 && intent.temperatureIntent==0 && intent.tintIntent==0)
    }
}
@Test func autoCurveRoundTripsAreExplicitlyApproximate() {
    for curve in [ToneCurve(),ToneCurve(points:[.init(x:0,y:0.1),.init(x:0.3,y:0.4),.init(x:0.7,y:0.65),.init(x:1,y:0.85)])] {
        let fit=AutoTonalMapping.approximate(curve),back=AutoTonalMapping.fit(light:fit.settings)
        #expect(fit.sdr.mae.isFinite && fit.hdr.maximum.isFinite && back.sdr.mae.isFinite)
        #expect(Adjustment.light.allSatisfy { $0.range.contains(fit.settings[$0]) })
        if curve.isIdentity { #expect(fit.sdr.maximum==0) }
        else { #expect(fit.sdr.classification != "Exact") }
    }
}

@Test func autoLateAnalysisCannotApplyAcrossDocumentsOrEdits() async throws {
    let id=UUID(),url=URL(fileURLWithPath:"/tmp/auto-A.png")
    let a=AutoRequestContext(request:1,renderGeneration:1,importGeneration:1,documentID:id,sourceURL:url,selectedLayer:nil,state:EditState())
    let pending=Task.detached { try await Task.sleep(for:.milliseconds(30));return a }
    let b=AutoRequestContext(request:2,renderGeneration:2,importGeneration:2,documentID:UUID(),sourceURL:URL(fileURLWithPath:"/tmp/auto-B.png"),selectedLayer:nil,state:EditState())
    #expect(b.permits(b)) // B completes before A.
    let late=try await pending.value
    #expect(!late.permits(b))
    let newerSameImage=AutoRequestContext(request:2,renderGeneration:1,importGeneration:1,documentID:id,sourceURL:url,selectedLayer:nil,state:EditState())
    #expect(!late.permits(newerSameImage))
    let undoBackToEqualState=AutoRequestContext(request:1,renderGeneration:3,importGeneration:1,documentID:id,sourceURL:url,selectedLayer:nil,state:EditState())
    #expect(!late.permits(undoBackToEqualState))
    let switchedLayer=AutoRequestContext(request:1,renderGeneration:1,importGeneration:1,documentID:id,sourceURL:url,selectedLayer:UUID(),state:EditState())
    #expect(!late.permits(switchedLayer))
}

@Test func autoIdentityCurveRetainsExtendedRange() {
    let fit=AutoTonalMapping.fit(light:EditState())
    #expect(fit.curve.isIdentity)
    #expect(AutoTonalMapping.curve(8,fit.curve)==8)
}
