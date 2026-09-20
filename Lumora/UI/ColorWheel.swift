import SwiftUI

/// Reusable hue/saturation wheel; no editor or persistence dependency.
struct ColorWheel: View {
    let hue: Double
    let saturation: Double
    let title: String
    let identifier: String
    let selected: Bool
    let onBegin: () -> Void
    let onChange: (Double, Double) -> Void
    let onEnd: () -> Void
    @State private var interacting = false

    var body: some View {
        GeometryReader { geometry in
            let diameter = min(geometry.size.width, geometry.size.height) - 20
            let radius = diameter / 2
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let point = ColorWheelCoordinates.position(hue: hue, saturation: saturation)
            ZStack {
                Circle().fill(AngularGradient(colors: (0...12).map { Color(hue: Double($0) / 12, saturation: 1, brightness: 1) }, center: .center))
                    .overlay(Circle().fill(RadialGradient(colors: [.white, .white.opacity(0)], center: .center, startRadius: 0, endRadius: radius)))
                    .overlay(Circle().stroke(selected ? Color.white : .white.opacity(0.3), lineWidth: selected ? 2 : 1))
                    .frame(width: diameter, height: diameter)
                    .position(center)
                Circle().stroke(.black.opacity(0.7), lineWidth: 4).overlay(Circle().stroke(.white, lineWidth: 2))
                    .frame(width: 12, height: 12)
                    .position(x: center.x + point.x * radius, y: center.y + point.y * radius)
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                if !interacting { interacting = true; onBegin() }
                guard radius > 0 else { return }
                let selection = ColorWheelCoordinates.value(x: (value.location.x - center.x) / radius,
                                                            y: (value.location.y - center.y) / radius, previousHue: hue)
                onChange(selection.hue, selection.saturation)
            }.onEnded { _ in finish() })
        }
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier(identifier)
        .accessibilityLabel("Roue \(title)")
        .accessibilityValue("Teinte \(Int(hue)) degrés, saturation \(Int(saturation)) pour cent")
        .accessibilityAdjustableAction { direction in
            onChange(hue, min(100, max(0, saturation + (direction == .increment ? 5 : -5))))
        }
        .accessibilityAction(named: "Teinte suivante") { onChange(HSLColor.wrap(hue + 5), saturation) }
        .accessibilityAction(named: "Teinte précédente") { onChange(HSLColor.wrap(hue - 5), saturation) }
        .onDisappear(perform: finish)
    }
    private func finish() {
        if interacting { onEnd(); interacting = false }
    }
}
