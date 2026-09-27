import SwiftUI

struct DepthLensView: View {
    let session: EditorSession
    private var settings: DepthLensSettings { session.state.depthLens ?? .init() }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Enable Depth Lens", isOn: Binding(get: { settings.enabled }, set: { enabled in
                    session.changeDepthLens { $0.enabled = enabled }
                })).accessibilityIdentifier("depth-lens-enable")
                Text("Tap the photo to focus. A wider aperture blurs areas away from the focus plane.")
                    .font(.caption).foregroundStyle(.secondary)
                AdjustmentSlider(title: String(localized: "Aperture"), range: 1.2...8, step: 0.1, precision: 1,
                    accessibilityID: "depth-lens-aperture", value: settings.aperture,
                    onBegin: { session.beginInteraction(String(localized: "Depth Lens")) },
                    onChange: { value in session.changeDepthLens { $0.aperture = value } },
                    onEnd: session.finishInteraction,
                    onReset: { session.changeDepthLens { $0.aperture = 1.4 } })
                    .disabled(!settings.enabled)
                Picker("Focal length", selection: Binding(get: { settings.focal }, set: { value in
                    session.changeDepthLens { $0.focal = value }
                })) {
                    Text("50 mm").tag(50.0); Text("85 mm").tag(85.0); Text("135 mm").tag(135.0)
                }.pickerStyle(.segmented).disabled(!settings.enabled)
                HStack {
                    Button("Center focus") { session.changeDepthLens { $0.focusX = 0.5; $0.focusY = 0.5 } }
                        .disabled(!settings.enabled)
                    Spacer()
                    Button("Reset") { session.changeDepthLens { $0 = .init() } }
                }.font(.caption)
                Text("Depth is estimated on device once per photo or geometry change. Hair and transparent objects can have imperfect edges. Increasing the aperture number softens the effect.")
                    .font(.caption2).foregroundStyle(.secondary)
            }.padding(.horizontal, 22).padding(.bottom, 12)
        }.accessibilityIdentifier("depth-lens-controls")
    }
}
