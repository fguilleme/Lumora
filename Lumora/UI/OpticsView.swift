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
                Toggle("Profil constructeur", isOn: Binding(
                    get: { settings.profileCorrection },
                    set: { enabled in onProfileChange(enabled) }
                ))
                    .disabled(!availability.profileSupported)
                    .accessibilityIdentifier("optics-profile")
                if availability.profileSupported {
                    Label(settings.profileCorrection ? "Correction RAW active" : "Correction RAW désactivée",
                          systemImage: settings.profileCorrection ? "checkmark.seal.fill" : "seal")
                        .font(.caption).foregroundStyle(settings.profileCorrection ? .mint : .secondary)
                } else {
                    Text(isRAW
                         ? "Ce RAW ne publie pas de profil optique compatible avec CIRAWFilter."
                         : "Cette image est déjà développée ; aucun profil constructeur réglable n’est exposé par iOS.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if let camera = availability.camera {
                    Label(camera, systemImage: "camera").font(.caption).foregroundStyle(.secondary)
                }
                if let lens = availability.lens {
                    Label(lens, systemImage: "camera.aperture").font(.caption).foregroundStyle(.secondary)
                }
                Divider().padding(.vertical, 4)
                Text("Corrections manuelles").font(.headline)
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
