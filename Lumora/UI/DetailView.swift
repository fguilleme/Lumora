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
            LazyVStack(alignment: .leading, spacing: 4) {
                LinearAdjustmentControl(parameters: parameters, selectedID: $selectedID,
                    onBegin: { onBegin($0.title) },
                    onChange: { parameter, value in
                        if let adjustment = DetailAdjustment(rawValue: parameter.id) { onChange(adjustment, value) }
                    }, onEnd: onEnd,
                    onReset: { parameter in
                        if let adjustment = DetailAdjustment(rawValue: parameter.id) { onReset(adjustment) }
                    })
            }.padding(.bottom, 12)
        }
        .accessibilityIdentifier("detail-controls")
    }

    private var parameters: [LinearAdjustmentParameter] {
        DetailAdjustment.groups.flatMap(\.1).map { adjustment in
            LinearAdjustmentParameter(id: adjustment.rawValue, title: adjustment.title,
                value: settings[adjustment], range: adjustment.range, step: adjustment.step,
                precision: adjustment.precision, resetValue: adjustment.defaultValue, isEnabled: isEnabled(adjustment),
                group: adjustment.group == 1 ? "noise-l" : adjustment.group == 2 ? "noise-c" : nil)
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
}
