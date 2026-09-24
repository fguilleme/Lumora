#if DEBUG
import SwiftUI
import UIKit

enum DebugCompareMode: String, CaseIterable { case a = "A only", b = "B only", split = "Split", halo = "Halo Map" }

struct DebugLabControls: View {
    @Binding var a: DebugToneVariant
    @Binding var b: DebugToneVariant
    @Binding var amount: Int
    @Binding var mode: DebugCompareMode
    @Binding var histogramSide: String
    @Binding var overlay: String
    @Binding var haloLayer: String
    let scene: DebugSceneResult?
    let outputA: DebugToneOutput?
    let outputB: DebugToneOutput?
    let halo: DebugHaloDiagnostics.Result?
    let working: Bool
    let error: String?
    @State private var expanded = false
    @State private var sceneExpanded = false
    @State private var haloExpanded = false

    var body: some View {
        ScrollView {
            VStack(alignment:.leading,spacing:12) {
                Text("Adaptive Tone Lab").font(.headline)
                Text("Debug only · temporary comparison · normal edits and export are unchanged")
                    .font(.caption).foregroundStyle(.secondary)
                Picker("A",selection:$a) {
                    ForEach(DebugToneVariant.allCases) {variant in Text(NSLocalizedString(variant.rawValue, comment: "Debug variant")).tag(variant)}
                }.accessibilityIdentifier("debug-variant-a")
                Picker("B",selection:$b) {
                    ForEach(DebugToneVariant.allCases) {variant in Text(NSLocalizedString(variant.rawValue, comment: "Debug variant")).tag(variant)}
                }.accessibilityIdentifier("debug-variant-b")
                Picker("View",selection:$mode) {
                    ForEach(DebugCompareMode.allCases,id:\.self) {mode in Text(NSLocalizedString(mode.rawValue, comment: "Debug comparison mode")).tag(mode)}
                }.pickerStyle(.segmented)
                HStack {Text("Amount");Slider(value:Binding(get:{Double(amount)},set:{amount=Int($0.rounded())}),in:0...100);Text("\(amount)")}
                Picker("Histogram",selection:$histogramSide) {Text("A").tag("A");Text("B").tag("B")}
                    .pickerStyle(.segmented)
                if working {ProgressView("Computing in Debug Lab…").font(.caption)}
                if !working,outputA != nil,outputB != nil {
                    Text("Comparison ready").font(.caption).foregroundStyle(.secondary)
                        .accessibilityIdentifier("debug-comparison-ready")
                }
                if let error {Text(error).font(.caption).foregroundStyle(.orange)}
                DisclosureGroup("Metrics",isExpanded:$expanded) {
                    metrics("A",outputA);metrics("B",outputB)
                }
                if mode == .halo {
                    Picker("Halo layer",selection:$haloLayer) {
                        ForEach(["Halo Map","Positive luminance difference","Negative luminance difference",
                                 "Strong edges","Suspected bright halos","Suspected dark halos",
                                 "Border anomaly zones"],id:\.self) { Text(NSLocalizedString($0, comment: "Halo layer")).tag($0) }
                    }.accessibilityIdentifier("debug-halo-layer")
                }
                if let halo {
                    DisclosureGroup("Destructiveness / halos",isExpanded:$haloExpanded) {
                        let m=halo.metrics
                        Text(String(format:NSLocalizedString("|ΔY| mean %.3f · P95 %.3f", comment: "Debug metric"),m.meanAbsoluteY,m.p95AbsoluteY))
                        Text(String(format:NSLocalizedString("|ΔC| mean %.3f · P95 %.3f (OKLab)", comment: "Debug metric"),m.meanAbsoluteChroma,m.p95AbsoluteChroma))
                        Text(String(format:NSLocalizedString("changed >2/5/10/20%%: %.1f / %.1f / %.1f / %.1f%%", comment: "Debug metric"),
                                    m.changed2*100,m.changed5*100,m.changed10*100,m.changed20*100))
                        Text(String(format:NSLocalizedString("shadows %.3f · midtones %.3f · highlights %.3f", comment: "Debug metric"),
                                    m.shadows.meanAbsoluteY,m.midtones.meanAbsoluteY,m.highlights.meanAbsoluteY))
                        Text(String(format:NSLocalizedString("subject %@ · %.3f · background %.3f", comment: "Debug metric"),m.subjectSource,
                                    m.subject?.meanAbsoluteY ?? 0,m.background?.meanAbsoluteY ?? 0))
                        Text(String(format:NSLocalizedString("halos bright %d · dark %d · edge contrast %d", comment: "Debug metric"),
                                    m.brightHaloCount,m.darkHaloCount,m.edgeEnhancementCount))
                        Text(String(format:NSLocalizedString("coherent bands bright %d · dark %d · largest %d px", comment: "Debug metric"),
                                    m.brightHaloBands,m.darkHaloBands,m.largestBandPixels))
                        Text(String(format:NSLocalizedString("border asymmetry L/R %.3f · T/B %.3f", comment: "Debug metric"),
                                    m.leftRightExcessAsymmetry,m.topBottomExcessAsymmetry))
                    }.font(.caption2.monospacedDigit())
                        .accessibilityIdentifier("debug-halo-metrics")
                }
                Divider()
                Text("Vision / Scene Analysis").font(.headline)
                if let scene {
                    let analysis=scene.analysis
                    let primary=analysis.candidates.first
                    VStack(alignment:.leading,spacing:5) {
                        Text("Scene: \(analysis.interpretations.first?.name ?? "Unknown")")
                        Text("Subject: \(primary?.source ?? "Unknown") · score \(format(primary?.score ?? 0))")
                        Text("Subject exposure: \(primary.map { format($0.luminance) } ?? "Unknown")")
                        Text("Background / median: \(format(analysis.global.luminance.median))")
                        Text("Dynamic range: \(format(analysis.global.dynamicRangeEV)) EV")
                        Text("Backlight: \(format(analysis.backlightScore))")
                        Text("Highlights: \(analysis.regions.filter{$0.kind=="near-white"}.count) regions")
                        Text("Shadow noise: \(format(analysis.shadowNoiseRisk))")
                        Text("Vision confidence: \(format(analysis.visionConfidence))")
                        if !analysis.saliencyAvailable {Text("Saliency unavailable").foregroundStyle(.orange)}
                    }.font(.caption.monospacedDigit())
                    Picker("Analysis overlay",selection:$overlay) {
                        Text("None").tag("None")
                        ForEach(scene.overlays.keys.sorted(),id:\.self) {Text(NSLocalizedString($0, comment: "Analysis overlay")).tag($0)}
                        Text("Phase 4 Spatial map").tag("Phase 4 Spatial map")
                        Text("Phase 4 Semantic map").tag("Phase 4 Semantic map")
                        Text("Phase 4 Combined map").tag("Phase 4 Combined map")
                        Text("Gain map B").tag("Gain map B")
                    }
                    DisclosureGroup("Details",isExpanded:$sceneExpanded) {
                        Text("Faces: \(analysis.faces.count) · candidates: \(analysis.candidates.count) · tonal regions: \(analysis.regions.count)")
                        ForEach(Array(analysis.candidates.enumerated()),id:\.offset) {_,candidate in
                            Text("\(candidate.source): \(format(candidate.score)) · semantic \(format(candidate.semantic)) · size \(format(candidate.size)) · saliency \(format(candidate.saliency)) · contrast \(format(candidate.contrast))")
                        }
                        ForEach(analysis.interpretations,id:\.name) {item in
                            Text("\(item.name): \(format(item.score)) [\(item.evidence.joined(separator:", "))]")
                        }
                        ForEach(analysis.timingsMS.keys.sorted(),id:\.self) {key in
                            Text("\(key): \(format(analysis.timingsMS[key] ?? 0)) ms")
                        }
                        ForEach(analysis.visionErrors.keys.sorted(),id:\.self) {key in
                            Text("\(key): \(analysis.visionErrors[key] ?? "unknown error")")
                        }
                    }.font(.caption)
                    Button("Copy Scene Analysis JSON") {
                        let encoder=JSONEncoder();encoder.outputFormatting=[.prettyPrinted,.sortedKeys]
                        if let data=try? encoder.encode(analysis) {UIPasteboard.general.string=String(data:data,encoding:.utf8)}
                    }.buttonStyle(.bordered)
                } else {Text("Analysis pending or unavailable").font(.caption).foregroundStyle(.secondary)}
            }.padding(14)
        }
        .accessibilityIdentifier("debug-lab-controls")
    }
    private func metrics(_ label:String,_ output:DebugToneOutput?)->some View {
        VStack(alignment:.leading,spacing:3) {
            Text(label).font(.caption.bold())
            if let output {
                Text(String(format:NSLocalizedString("%@ %.2f ms · prep %.2f ms · %d × %d · %.1f MB · %@", comment: "Debug metric"),output.backend,output.milliseconds,
                            output.preparationMilliseconds,
                            output.image.width,output.image.height,Double(output.allocatedBytes)/1_048_576,
                            NSLocalizedString(output.cacheHit ? "cache hit" : "rendered", comment: "Debug render status")))
                Text(String(format:NSLocalizedString("P95 %.3f · gain >2× %.2f%% · >3× %.2f%% · >4× %.2f%% · max %.2f×", comment: "Debug metric"),
                            output.p95,output.over2*100,output.over3*100,output.over4*100,output.maxGain))
            } else {Text("Pending")}
        }.font(.caption2.monospacedDigit())
    }
    private func format(_ value:Double)->String {String(format:"%.2f",value)}
}

struct DebugLabCanvas: View {
    let original: CGImage
    let a: CGImage?
    let b: CGImage?
    let mode: DebugCompareMode
    let overlay: CGImage?
    @State private var split:CGFloat=0.5
    @State private var zoom:CGFloat=1
    @State private var pan=CGSize.zero
    @GestureState private var magnification:CGFloat=1
    @GestureState private var dragging=CGSize.zero
    var body:some View {
        GeometryReader {geometry in
            let size=geometry.size
            let scale=min(6,max(1,zoom*magnification))
            let offset=CGSize(width:pan.width+dragging.width,height:pan.height+dragging.height)
            ZStack {
                image(a ?? original,size:size)
                    .opacity(mode == .b || mode == .halo ? 0 : 1)
                image(b ?? original,size:size)
                    .opacity(mode == .a ? 0 : 1)
                    .mask(alignment:.leading) {
                        if mode == .split {
                            Rectangle().frame(width:size.width*(1-split)).frame(maxWidth:.infinity,alignment:.trailing)
                        } else {Rectangle()}
                    }
                if let overlay {
                    image(overlay,size:size).allowsHitTesting(false)
                }
            }
            .scaleEffect(scale).offset(offset)
            .frame(width:size.width,height:size.height)
            .clipped()
            .contentShape(Rectangle())
            .simultaneousGesture(MagnifyGesture().updating($magnification){value,state,_ in state=value.magnification}
                .onEnded{value in zoom=min(6,max(1,zoom*value.magnification))})
            .simultaneousGesture(DragGesture(minimumDistance:8).updating($dragging){value,state,_ in
                if zoom>1 {state=value.translation}
            }.onEnded{value in if zoom>1 {pan.width+=value.translation.width;pan.height+=value.translation.height}})
            .simultaneousGesture(TapGesture(count:2).onEnded {zoom=1;pan = .zero})
            if mode == .split {
                Rectangle().fill(.white.opacity(0.8)).frame(width:2,height:size.height)
                    .overlay(alignment:.top) {Text("A  │  B").font(.caption.bold()).padding(5).background(.black.opacity(0.7),in:Capsule()).offset(y:8)}
                    .frame(width:44)
                    .position(x:size.width*split,y:size.height/2)
                    .contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance:0,coordinateSpace:.named("debugCanvas")).onChanged {value in
                        split=min(0.95,max(0.05,value.location.x/size.width))
                    })
                    .accessibilityElement()
                    .accessibilityLabel("Split divider")
                    .accessibilityIdentifier("debug-split-divider")
            }
        }.coordinateSpace(name:"debugCanvas")
        .background(.black)
        .accessibilityElement(children:.contain)
        .accessibilityIdentifier("debug-lab-canvas")
        .accessibilityValue("Zoom \(Int(zoom*100)) percent")
    }
    private func image(_ bitmap:CGImage,size:CGSize)->some View {
        Image(decorative:bitmap,scale:1).resizable().aspectRatio(contentMode:.fit)
            .frame(width:size.width,height:size.height)
    }
}
#endif
