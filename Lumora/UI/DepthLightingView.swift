import SwiftUI

struct DepthLightingView: View {
    let session: EditorSession
    @Binding var placingSubject: Bool
    private var settings: DepthLightingSettings { session.state.depthLighting ?? .init() }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Label("Experimental · off by default", systemImage: "flask")
                    .font(.caption).foregroundStyle(.secondary)
                Toggle("Enable lighting", isOn: Binding(get: { settings.enabled }, set: { value in
                    session.changeDepthLighting { $0.enabled = value }
                })).accessibilityIdentifier("depth-lighting-enable")
                Text("Choose the subject point, then place the light. Tap the photo or drag a marker.")
                    .font(.caption).foregroundStyle(.secondary)
                Picker("Place", selection: $placingSubject) {
                    Text("Light position").tag(false)
                    Text("Subject point").tag(true)
                }.pickerStyle(.segmented).disabled(!settings.enabled)
                slider("Intensity", id: "intensity", key: \.intensity, range: 0...100, reset: 65)
                slider("Relative distance", id: "distance", key: \.distance, range: 15...150, reset: 48)
                slider("Softness", id: "softness", key: \.softness, range: 20...100, reset: 55)
                slider("Warmth", id: "warmth", key: \.warmth, range: -100...100, reset: 0)
                slider("Surface relief", id: "relief", key: \.relief, range: 0...100, reset: 80)
                Button("Reset") { session.changeDepthLighting { $0 = .init() } }
                    .font(.caption)
                Text("Approximate depth-based lighting. Existing shadows remain; depth errors can affect the sky and subject edges. See Help for limits.")
                    .font(.caption2).foregroundStyle(.secondary)
            }.padding(.horizontal, 22).padding(.bottom, 12)
        }.accessibilityIdentifier("depth-lighting-controls")
    }
    private func slider(_ title: String.LocalizationValue, id: String, key: WritableKeyPath<DepthLightingSettings, Double>,
                        range: ClosedRange<Double>, reset: Double) -> some View {
        AdjustmentSlider(title: String(localized: title), range: range, step: 1, precision: 0,
            accessibilityID: "depth-lighting-\(id)", value: settings[keyPath: key],
            onBegin: { session.beginInteraction(String(localized: "Lighting")) },
            onChange: { value in session.changeDepthLighting { $0[keyPath: key] = value } },
            onEnd: session.finishInteraction,
            onReset: { session.changeDepthLighting { $0[keyPath: key] = reset } })
            .disabled(!settings.enabled)
    }
}

struct LightingMarker: View {
    static let coordinateSpace = "depth-lighting-canvas"
    let point: CGPoint
    let rect: CGRect
    let subject: Bool
    let onBegin: () -> Void
    let onChange: (MaskPoint) -> Void
    let onEnd: () -> Void
    @State private var start: CGPoint?
    var body: some View {
        Image(systemName: subject ? "scope" : "sun.max.fill")
            .font(.system(size: 26)).foregroundStyle(subject ? Color.mint : Color.yellow)
            .shadow(color: .black.opacity(0.65), radius: 2)
            .frame(width: 44, height: 44).contentShape(Rectangle())
            // Measure in the stationary canvas to avoid feedback from the moving marker.
            .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.coordinateSpace)).onChanged { value in
                if start == nil { start = point; onBegin() }
                guard let start, rect.width > 0, rect.height > 0 else { return }
                onChange(MaskPoint(x: min(1, max(0, start.x + value.translation.width/rect.width)),
                                   y: min(1, max(0, start.y + value.translation.height/rect.height))))
            }.onEnded { value in
                if let start, rect.width > 0, rect.height > 0 {
                    onChange(MaskPoint(x: min(1, max(0, start.x + value.translation.width/rect.width)),
                                       y: min(1, max(0, start.y + value.translation.height/rect.height))))
                }
                start = nil; onEnd()
            })
            .position(x: rect.minX + rect.width*point.x, y: rect.minY + rect.height*point.y)
            .accessibilityLabel(subject ? Text("Subject point") : Text("Light position"))
            .accessibilityIdentifier(subject ? "lighting-subject-marker" : "lighting-source-marker")
    }
}
