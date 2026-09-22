import SwiftUI

struct GradingPresetSelector: View {
    let grading: ColorGrading
    let apply: (ColorGradingPreset) -> Void
    private var selected: ColorGradingPreset? { ColorGradingPreset.matching(grading) }
    var body: some View {
        VStack(alignment:.leading,spacing:4) {
            HStack {
                presetButton(.neutral)
                Spacer()
                Text(selected?.title ?? String(localized:"Personnalisé"))
                    .font(.caption).foregroundStyle(.secondary)
                    .accessibilityIdentifier("grading-preset-status")
            }
            ScrollView(.horizontal) {
                HStack(alignment:.top,spacing:14) {
                    ForEach(ColorGradingPreset.Family.allCases,id:\.self) { family in
                        VStack(alignment:.leading,spacing:2) {
                            Text(family.title).font(.caption2).foregroundStyle(.secondary)
                            HStack(spacing:6) {
                                ForEach(ColorGradingPreset.allCases.filter{$0.family==family}) { presetButton($0) }
                            }
                        }
                    }
                }
            }.scrollIndicators(.hidden).accessibilityIdentifier("grading-preset-strip")
        }.dimsDuringAdjustment()
    }
    private func presetButton(_ preset:ColorGradingPreset)->some View {
        Button {apply(preset)} label: {
            HStack(spacing:4) {
                if selected==preset {Image(systemName:"checkmark")}
                Text(preset.title).fixedSize()
            }.font(.caption).padding(.horizontal,8).frame(minHeight:44)
        }
        .buttonStyle(.bordered).buttonBorderShape(.capsule)
        .tint(selected==preset ? .mint:.secondary)
        .accessibilityIdentifier("grading-preset-"+preset.id)
        .accessibilityAddTraits(selected==preset ? .isSelected:[])
    }
}
