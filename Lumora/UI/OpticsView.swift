import SwiftUI

struct OpticsView: View {
    let settings: OpticsSettings
    let availability: OpticsAvailability
    let isRAW: Bool
    let onProfileChange: (Bool) -> Void
    let onBegin: (String) -> Void
    let onChange: (OpticsAdjustment, Double) -> Void
    let onEnd: () -> Void
    let onReset: (OpticsAdjustment) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Toggle("Manufacturer profile", isOn: Binding(
                    get: { settings.profileCorrection },
                    set: { enabled in onProfileChange(enabled) }
                ))
                    .disabled(!availability.profileSupported)
                    .accessibilityIdentifier("optics-profile")
                if availability.profileSupported {
                    Label(settings.profileCorrection ? "RAW correction on" : "RAW correction off",
                          systemImage: settings.profileCorrection ? "checkmark.seal.fill" : "seal")
                        .font(.caption).foregroundStyle(settings.profileCorrection ? .mint : .secondary)
                } else {
                    Text(isRAW
                         ? "This RAW does not provide a lens profile compatible with CIRAWFilter."
                         : "This image has already been processed; iOS provides no adjustable manufacturer profile.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if let camera = availability.camera {
                    Label(camera, systemImage: "camera").font(.caption).foregroundStyle(.secondary)
                }
                if let lens = availability.lens {
                    Label(lens, systemImage: "camera.aperture").font(.caption).foregroundStyle(.secondary)
                }
                Divider().padding(.vertical, 4)
                Text("Manual corrections").font(.headline)
                ForEach(OpticsAdjustment.allCases) { adjustment in
                    AdjustmentSlider(title: adjustment.title, range: adjustment.range,
                                     accessibilityID: "optics-\(adjustment.rawValue)",
                                     value: settings[adjustment],
                                     onBegin: { onBegin(adjustment.title) },
                                     onChange: { onChange(adjustment, $0) }, onEnd: onEnd,
                                     onReset: { onReset(adjustment) })
                }
            }.padding(.horizontal, 22).padding(.bottom, 12)
        }
        .accessibilityIdentifier("optics-controls")
    }
}
