import SwiftUI

struct DetailView: View {
    let settings: DetailSettings
    let onBegin: (String) -> Void
    let onChange: (DetailAdjustment, Double) -> Void
    let onEnd: () -> Void
    let onReset: (DetailAdjustment) -> Void
    @State private var selectedID = DetailAdjustment.sharpeningAmount.rawValue

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 8) {
                LinearAdjustmentControl(parameters: parameters, selectedID: $selectedID,
                    onBegin: { onBegin($0.title) },
                    onChange: { parameter, value in
                        if let adjustment = DetailAdjustment(rawValue: parameter.id) { onChange(adjustment, value) }
                    }, onEnd: onEnd,
                    onReset: { parameter in
                        if let adjustment = DetailAdjustment(rawValue: parameter.id) { onReset(adjustment) }
                    })
                ForEach(Array(DetailAdjustment.groups.enumerated()), id: \.offset) { index, _ in
                    if let requirement = requirement(for: index) {
                        Text(requirement).font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }.padding(.bottom, 12)
        }
        .accessibilityIdentifier("detail-controls")
    }

    private var parameters: [LinearAdjustmentParameter] {
        DetailAdjustment.groups.flatMap(\.1).map { adjustment in
            LinearAdjustmentParameter(id: adjustment.rawValue, title: adjustment.title,
                value: settings[adjustment], range: adjustment.range, step: adjustment.step,
                precision: adjustment.precision, resetValue: adjustment.defaultValue, isEnabled: isEnabled(adjustment))
        }
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
        case 0 where settings.sharpening.amount == 0:
            String(localized: "Increase Amount to enable sharpening controls.")
        case 1 where settings.noiseReduction.luminance == 0:
            String(localized: "Increase Luminance to enable Detail and Contrast.")
        case 2 where settings.colorNoiseReduction.color == 0:
            String(localized: "Increase Color to enable Detail and Smoothing.")
        default: nil
        }
    }
}
