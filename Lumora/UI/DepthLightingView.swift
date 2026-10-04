import SwiftUI
import UIKit

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
                Text("Place the target on the face. Move the bulb to set the light side and height.")
                    .font(.caption).foregroundStyle(.secondary)

                slider("Power", id: "intensity", key: \.intensity, range: 0...200, reset: 80)
                slider("Light distance", id: "distance", key: \.distance, range: 0...40, reset: 0)
                slider("Softness", id: "softness", key: \.softness, range: 10...100, reset: 55)
                ColorPicker("Light color", selection: colorBinding, supportsOpacity: false)
                    .disabled(!settings.enabled)
                slider("Surface relief", id: "relief", key: \.relief, range: 0...100, reset: 80)
                Button("Reset") { session.changeDepthLighting { $0 = .init() } }
                    .font(.caption)
                Text("The depth derivatives create a normal map that shapes the added light. Existing shadows remain; depth errors can affect edges and reflective surfaces.")
                    .font(.caption2).foregroundStyle(.secondary)
            }.padding(.horizontal, 22).padding(.bottom, 12)
        }.accessibilityIdentifier("depth-lighting-controls")
        .onAppear { placingSubject = true }
    }

    private var colorBinding: Binding<Color> {
        Binding(get: { Color(red: settings.red, green: settings.green, blue: settings.blue) },
                set: { color in
                    var red: CGFloat = 1, green: CGFloat = 1, blue: CGFloat = 1, alpha: CGFloat = 1
                    UIColor(color).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
                    session.changeDepthLighting {
                        $0.red = red; $0.green = green; $0.blue = blue
                    }
                })
    }

    private func slider(_ title: String.LocalizationValue, id: String,
                        key: WritableKeyPath<DepthLightingSettings, Double>,
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


struct LightingRigOverlay: View {
    static let coordinateSpace = "depth-lighting-canvas"
    let settings: DepthLightingSettings
    let rect: CGRect
    let onBegin: () -> Void
    let onTarget: (MaskPoint) -> Void
    let onAngles: (Double, Double) -> Void
    let onEnd: () -> Void

    @State private var targetStart: CGPoint?
    @State private var draggingLight = false

    private var center: CGPoint {
        CGPoint(x: rect.minX + rect.width * settings.targetX,
                y: rect.minY + rect.height * settings.targetY)
    }
    private var horizontalInset: CGFloat { min(24, rect.width * 0.06) }
    private var verticalInset: CGFloat { min(24, rect.height * 0.06) }
    private var guideWidth: CGFloat { max(1, rect.width - horizontalInset * 2) }
    private var guideHeight: CGFloat { max(1, rect.height - verticalInset * 2) }

    var body: some View {
        ZStack {
            lightBulb
                .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.coordinateSpace))
                    .onChanged { value in
                        if !draggingLight { draggingLight = true; onBegin() }
                        let horizontal = min(1, max(0, (value.location.x - rect.minX - horizontalInset) / guideWidth))
                        let vertical = min(1, max(0, (rect.maxY - verticalInset - value.location.y) / guideHeight))
                        onAngles(Double(horizontal * 180 - 90), Double(vertical * 125 - 45))
                    }.onEnded { _ in draggingLight = false; onEnd() })
                .accessibilityLabel("Light position")
                .accessibilityValue("Side \(Int(settings.azimuth.rounded())) degrees, height \(Int(settings.elevation.rounded())) degrees")

            Image(systemName: "scope")
                .font(.system(size: 25)).foregroundStyle(.mint)
                .shadow(color: .black.opacity(0.7), radius: 2)
                .frame(width: 46, height: 46).contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.coordinateSpace))
                    .onChanged { value in
                        if targetStart == nil { targetStart = center; onBegin() }
                        guard let targetStart, rect.width > 0, rect.height > 0 else { return }
                        onTarget(MaskPoint(
                            x: min(1, max(0, (targetStart.x + value.translation.width - rect.minX)/rect.width)),
                            y: min(1, max(0, (targetStart.y + value.translation.height - rect.minY)/rect.height))))
                    }.onEnded { _ in targetStart = nil; onEnd() })
                .position(center)
                .accessibilityLabel("Subject point")
                .accessibilityIdentifier("lighting-subject-marker")
        }
    }

    private var lightPosition: CGPoint {
        let horizontal = CGFloat((settings.azimuth + 90) / 180)
        let vertical = CGFloat((settings.elevation + 45) / 125)
        return CGPoint(x: rect.minX + horizontalInset + guideWidth * horizontal,
                       y: rect.maxY - verticalInset - guideHeight * vertical)
    }
    private var lightBulb: some View {
        Image(systemName: "lightbulb.fill").font(.system(size: 29, weight: .medium))
            .foregroundStyle(lightColor)
            .shadow(color: .black.opacity(0.85), radius: 2)
            .frame(width: 58, height: 58)
            .contentShape(Circle())
            .position(lightPosition)
    }
    private var lightColor: Color {
        Color(red: settings.red, green: settings.green, blue: settings.blue)
    }
}
