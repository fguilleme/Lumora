import SwiftUI
import UIKit

private enum LightingPreset: String, CaseIterable, Identifiable {
    case studio = "Studio", window = "Window", goldenHour = "Golden Hour", manual = "Manual"
    var id: Self { self }
    var title: LocalizedStringKey {
        switch self {
        case .studio: "Studio"
        case .window: "Window lighting"
        case .goldenHour: "Golden Hour"
        case .manual: "Manual lighting"
        }
    }

    func matches(_ s: DepthLightingSettings) -> Bool {
        guard self != .manual else { return false }
        let r = values(enabled: s.enabled, targetX: s.targetX, targetY: s.targetY)
        return abs(s.intensity-r.intensity)<0.01 && abs(s.distance-r.distance)<0.01
            && abs(s.softness-r.softness)<0.01 && abs(s.relief-r.relief)<0.01
            && abs(s.originalLighting-r.originalLighting)<0.01
            && s.surfaceNormals == r.surfaceNormals && abs(s.portraitShading-r.portraitShading)<0.01
            && abs(s.shadowStrength-r.shadowStrength)<0.01
            && abs(s.azimuth-r.azimuth)<0.01 && abs(s.elevation-r.elevation)<0.01
            && abs(s.red-r.red)<0.001 && abs(s.green-r.green)<0.001 && abs(s.blue-r.blue)<0.001
    }

    func values(enabled: Bool, targetX: Double, targetY: Double) -> DepthLightingSettings {
        var r = DepthLightingSettings(); r.enabled = enabled; r.targetX = targetX; r.targetY = targetY
        switch self {
        case .studio:
            r.intensity=80; r.softness=55; r.distance=0; r.relief=80; r.azimuth = -35; r.elevation=30
            r.red=1; r.green=0.86; r.blue=0.72
        case .window:
            r.intensity=105; r.softness=82; r.distance=10; r.relief=68; r.azimuth = -58; r.elevation=24
            r.red=1; r.green=0.96; r.blue=0.90
        case .goldenHour:
            r.intensity=118; r.softness=70; r.distance=5; r.relief=74; r.azimuth=62; r.elevation=13
            r.red=1; r.green=0.58; r.blue=0.26
        case .manual: break
        }
        return r
    }
}

struct DepthLightingView: View {
    let session: EditorSession
    @Binding var placingSubject: Bool
    @State private var advancedExpanded = false
    @State private var selectedParameter = "intensity"
    private var settings: DepthLightingSettings { session.state.depthLighting ?? .init() }
    private var selectedPreset: LightingPreset { LightingPreset.allCases.first(where: { $0.matches(settings) }) ?? .manual }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Toggle("Lighting", isOn: Binding(get: { settings.enabled }, set: { value in
                        session.changeDepthLighting { $0.enabled = value }
                    }))
                    .font(.caption).controlSize(.small).accessibilityIdentifier("depth-lighting-enable")
                    Spacer(minLength: 8)
                    Button { session.changeDepthLighting { $0 = .init() } } label: {
                        Image(systemName: "arrow.counterclockwise").frame(width: 44, height: 32)
                    }
                    .foregroundStyle(.secondary).accessibilityLabel("Reset lighting")
                    .accessibilityIdentifier("depth-lighting-reset")
                }.frame(minHeight: 34)

                Picker("Lighting preset", selection: Binding(get: { selectedPreset }, set: applyPreset)) {
                    ForEach(LightingPreset.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented).controlSize(.small).disabled(!settings.enabled)
                .accessibilityIdentifier("depth-lighting-preset").padding(.bottom, 2)

                LinearAdjustmentControl(parameters: lightingParameters, selectedID: $selectedParameter,
                    onBegin: { _ in session.beginInteraction(String(localized:"Lighting")) },
                    onChange: { parameter, value in set(parameter.id, value: value) },
                    onEnd: session.finishInteraction,
                    onReset: { parameter in set(parameter.id, value: parameter.resetValue) }) {
                        ColorPicker(selection: colorBinding, supportsOpacity: false) {
                            Image(systemName: "thermometer.medium")
                                .font(.system(size: 19, weight: .medium))
                                .foregroundStyle(colorBinding.wrappedValue)
                                .frame(width: 44, height: 44)
                        }
                        .accessibilityLabel("Temperature")
                        .accessibilityIdentifier("depth-lighting-temperature")
                    }
                    .disabled(!settings.enabled)

                Button { advancedExpanded.toggle() } label: {
                    HStack {
                        Text("Advanced").font(.caption.weight(.semibold))
                        Spacer()
                        Image(systemName:"chevron.down")
                            .font(.caption2.weight(.semibold))
                            .rotationEffect(.degrees(advancedExpanded ? 180 : 0))
                    }.frame(minHeight:40).contentShape(Rectangle())
                }
                .buttonStyle(.plain).disabled(!settings.enabled)
                .accessibilityIdentifier("depth-lighting-advanced")
                if advancedExpanded {
                    Toggle("Detailed surfaces", isOn:Binding(get:{settings.surfaceNormals},set:{ value in
                        session.changeDepthLighting { $0.surfaceNormals=value }
                    })).font(.caption).controlSize(.small)
                        .accessibilityIdentifier("depth-lighting-surfaces")
                        .id("lighting-relief-control")
                }
                }.padding(.horizontal,16).padding(.vertical,4)
            }
            .onChange(of: advancedExpanded) { _, expanded in
                guard expanded else { return }
                withAnimation { proxy.scrollTo("lighting-relief-control", anchor: .bottom) }
            }
        }
        .onAppear { placingSubject = true }
    }

    private func applyPreset(_ preset: LightingPreset) {
        guard preset != .manual else { return }
        let replacement = preset.values(enabled:true,targetX:settings.targetX,targetY:settings.targetY)
        session.changeDepthLighting { $0 = replacement }
    }

    private var colorBinding: Binding<Color> {
        Binding(get:{ Color(red:settings.red,green:settings.green,blue:settings.blue) }, set:{ color in
            var r:CGFloat=1,g:CGFloat=1,b:CGFloat=1,a:CGFloat=1; UIColor(color).getRed(&r,green:&g,blue:&b,alpha:&a)
            session.changeDepthLighting { $0.red=r; $0.green=g; $0.blue=b }
        })
    }

    private var lightingParameters: [LinearAdjustmentParameter] {
        var result = [
            LinearAdjustmentParameter(id:"intensity",title:String(localized:"Intensity"),value:settings.intensity,range:0...200,step:1,precision:0,resetValue:80),
            LinearAdjustmentParameter(id:"softness",title:String(localized:"Softness"),value:settings.softness,range:10...100,step:1,precision:0,resetValue:55),
            LinearAdjustmentParameter(id:"distance",title:String(localized:"Distance"),value:settings.distance,range:0...40,step:1,precision:0,resetValue:0)
        ]
        if advancedExpanded {
            result.append(LinearAdjustmentParameter(id:"relief",title:String(localized:"Surface relief"),value:settings.relief,range:0...100,step:1,precision:0,resetValue:80))
            result.append(LinearAdjustmentParameter(id:"portrait-shading",title:String(localized:"Portrait shading"),value:settings.portraitShading,range:0...100,step:1,precision:0,unit:"%",resetValue:0))
            result.append(LinearAdjustmentParameter(id:"shadows",title:String(localized:"Cast shadows"),value:settings.shadowStrength,range:0...100,step:1,precision:0,unit:"%",resetValue:0))
            result.append(LinearAdjustmentParameter(id:"original-lighting",title:String(localized:"Original light"),value:settings.originalLighting,range:0...100,step:1,precision:0,unit:"%",resetValue:100))
        }
        return result
    }

    private func set(_ id: String, value: Double) {
        session.changeDepthLighting {
            switch id {
            case "intensity": $0.intensity = value
            case "softness": $0.softness = value
            case "distance": $0.distance = value
            case "relief": $0.relief = value
            case "portrait-shading": $0.portraitShading = value
            case "shadows": $0.shadowStrength = value
            case "original-lighting": $0.originalLighting = value
            default: break
            }
        }
    }
}

struct LightingRigOverlay: View {
    static let coordinateSpace = "depth-lighting-canvas"
    let settings: DepthLightingSettings, rect: CGRect
    @Binding var guidesVisible: Bool
    let onBegin:()->Void, onTarget:(MaskPoint)->Void, onAngles:(Double,Double)->Void, onEnd:()->Void
    @State private var draggingTarget=false
    @State private var draggingSource=false
    @State private var hideTask:Task<Void,Never>?

    private var targetPosition:CGPoint { CGPoint(x:rect.minX+rect.width*settings.targetX,y:rect.minY+rect.height*settings.targetY) }
    private var horizontalInset:CGFloat { min(22,rect.width*0.055) }
    private var verticalInset:CGFloat { min(22,rect.height*0.055) }
    private var guideWidth:CGFloat { max(1,rect.width-horizontalInset*2) }
    private var guideHeight:CGFloat { max(1,rect.height-verticalInset*2) }

    var body:some View {
        ZStack {
            Path { $0.move(to:sourcePosition); $0.addLine(to:targetPosition) }
                .stroke(.white.opacity(0.30),style:StrokeStyle(lineWidth:0.7,dash:[2.5,4])).allowsHitTesting(false)
            sourceHandle.highPriorityGesture(sourceGesture).position(sourcePosition)
                .accessibilityLabel("Light position").accessibilityIdentifier("lighting-source-marker")
            targetHandle.highPriorityGesture(targetGesture).position(targetPosition)
                .accessibilityLabel("Subject point").accessibilityIdentifier("lighting-subject-marker")
        }
        .opacity(guidesVisible ? 1:0).allowsHitTesting(guidesVisible)
        .animation(.easeOut(duration:0.25),value:guidesVisible)
        .onAppear { revealGuides() }.onDisappear { hideTask?.cancel() }
        .onChange(of:guidesVisible) { _,visible in if visible { revealGuides() } }
        .onChange(of:settings.targetX) { _,_ in revealGuides() }
        .onChange(of:settings.targetY) { _,_ in revealGuides() }
        .onChange(of:settings.azimuth) { _,_ in revealGuides() }
        .onChange(of:settings.elevation) { _,_ in revealGuides() }
    }

    private var sourceHandle:some View {
        ZStack {
            Circle().fill(.black.opacity(0.22)).frame(width:30,height:30)
            Circle().stroke(lightColor.opacity(0.48),lineWidth:0.7).frame(width:30,height:30)
            Image(systemName:"sun.max").font(.system(size:16,weight:.light)).foregroundStyle(lightColor.opacity(0.76))
        }.frame(width:44,height:44).background(Color.clear).contentShape(Circle()).shadow(color:.black.opacity(0.65),radius:2)
    }
    private var targetHandle:some View {
        ZStack {
            Circle().fill(.black.opacity(0.16)).frame(width:27,height:27)
            Image(systemName:"scope").font(.system(size:26,weight:.light)).foregroundStyle(.mint.opacity(0.58))
            Circle().fill(.mint.opacity(0.72)).frame(width:3,height:3)
        }.frame(width:44,height:44).background(Color.clear).contentShape(Circle()).shadow(color:.black.opacity(0.65),radius:2)
    }

    private var sourceGesture:some Gesture {
        DragGesture(minimumDistance:0,coordinateSpace:.named(Self.coordinateSpace)).onChanged { value in
            revealGuides(whileInteracting:true)
            if !draggingSource { draggingSource=true; onBegin() }
            let h=min(1,max(0,(value.location.x-rect.minX-horizontalInset)/guideWidth))
            let v=min(1,max(0,(rect.maxY-verticalInset-value.location.y)/guideHeight))
            onAngles(Double(h*180-90),Double(v*125-45))
        }.onEnded { _ in draggingSource=false; onEnd(); revealGuides() }
    }
    private var targetGesture:some Gesture {
        DragGesture(minimumDistance:0,coordinateSpace:.named(Self.coordinateSpace)).onChanged { value in
            revealGuides(whileInteracting:true)
            if !draggingTarget { draggingTarget=true; onBegin() }
            guard rect.width>0,rect.height>0 else{return}
            onTarget(normalizedTarget(value.location))
        }.onEnded { value in
            if rect.width>0,rect.height>0 { onTarget(normalizedTarget(value.location)) }
            draggingTarget=false; onEnd(); revealGuides()
        }
    }

    private func normalizedTarget(_ point:CGPoint)->MaskPoint {
        MaskPoint(x:min(1,max(0,(point.x-rect.minX)/rect.width)),
                  y:min(1,max(0,(point.y-rect.minY)/rect.height)))
    }

    private var sourcePosition:CGPoint {
        let h=CGFloat((settings.azimuth+90)/180),v=CGFloat((settings.elevation+45)/125)
        return CGPoint(x:rect.minX+horizontalInset+guideWidth*h,y:rect.maxY-verticalInset-guideHeight*v)
    }
    private var lightColor:Color { Color(red:settings.red,green:settings.green,blue:settings.blue) }
    private func revealGuides(whileInteracting:Bool=false) {
        hideTask?.cancel(); guidesVisible=true
        guard !whileInteracting else{return}
        hideTask=Task { @MainActor in
            try? await Task.sleep(for:.seconds(3.5)); guard !Task.isCancelled else{return}; guidesVisible=false
        }
    }
}
