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
                    ForEach(group.1) { adjustment in
                        AdjustmentSlider(title: adjustment.title, range: adjustment.range,
                                         step: adjustment.step, precision: adjustment.precision,
                                         accessibilityID: "detail-\(adjustment.rawValue)",
                                         value: settings[adjustment],
                                         onBegin: { onBegin("\(group.0) — \(adjustment.title)") },
                                         onChange: { onChange(adjustment, $0) }, onEnd: onEnd,
                                         onReset: { onReset(adjustment) })
                    }
                }
            }.padding(.horizontal, 22).padding(.bottom, 12)
        }
        .accessibilityIdentifier("detail-controls")
    }
}
