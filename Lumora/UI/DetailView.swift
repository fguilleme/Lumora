import SwiftUI

struct DetailView: View {
    let settings: DetailSettings
    let onBegin: (String) -> Void
    let onChange: (DetailAdjustment, Double) -> Void
    let onEnd: () -> Void
    let onReset: (DetailAdjustment) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                ForEach(Array(DetailAdjustment.groups.enumerated()), id: \.offset) { index, group in
                    Text(group.0).font(.headline).foregroundStyle(index == 0 ? .primary : .secondary)
                        .padding(.top, index == 0 ? 2 : 12)
                        .dimsDuringAdjustment()
                    ForEach(group.1) { adjustment in
                        AdjustmentSlider(title: adjustment.title, range: adjustment.range,
                                         step: adjustment.step, precision: adjustment.precision,
                                         accessibilityID: "detail-\(adjustment.rawValue)",
                                         value: settings[adjustment],
                                         onBegin: { onBegin("\(group.0) — \(adjustment.title)") },
                                         onChange: { onChange(adjustment, $0) }, onEnd: onEnd,
                                         onReset: { onReset(adjustment) })
                            .disabled(!isEnabled(adjustment))
                            .opacity(isEnabled(adjustment) ? 1 : 0.35)
                    }
                    if let requirement = requirement(for: index) {
                        Text(requirement).font(.caption2).foregroundStyle(.secondary)
                            .dimsDuringAdjustment()
                    }
                }
            }.padding(.horizontal, 22).padding(.bottom, 12)
        }
        .accessibilityIdentifier("detail-controls")
    }

    private func isEnabled(_ adjustment: DetailAdjustment) -> Bool {
        switch adjustment {
        case .sharpeningRadius, .sharpeningDetail, .sharpeningMasking:
            settings.sharpening.amount > 0
        case .luminanceDetail, .luminanceContrast:
            settings.noiseReduction.luminance > 0
        case .colorDetail, .colorSmoothness:
            settings.colorNoiseReduction.color > 0
        default:
            true
        }
    }

    private func requirement(for group: Int) -> String? {
        switch group {
        case 0 where settings.sharpening.amount == 0: "Increase Amount to enable sharpening controls."
        case 1 where settings.noiseReduction.luminance == 0: "Increase Luminance to enable Detail and Contrast."
        case 2 where settings.colorNoiseReduction.color == 0: "Increase Color to enable Detail and Smoothing."
        default: nil
        }
    }
}
