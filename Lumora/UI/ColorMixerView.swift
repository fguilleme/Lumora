import SwiftUI

struct ColorMixerView: View {
    let mixer: ColorMixer
    let onBegin: (String) -> Void
    let onChange: (MixerChannel, MixerAdjustment) -> Void
    let onEnd: () -> Void
    @State private var channel: MixerChannel = .red
    @State private var selectedID = MixerComponent.hue.rawValue

    var body: some View {
        VStack(spacing: 5) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(MixerChannel.allCases) { item in
                        Button {
                            onEnd(); channel = item
                        } label: {
                            VStack(spacing: 4) {
                                Circle().fill(Color(hue: item.center / 360, saturation: 0.8, brightness: 0.95))
                                    .frame(width: 22, height: 22)
                                    .overlay {
                                        if item == channel {
                                            Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(.black)
                                        }
                                    }
                                    .padding(6)
                                    .overlay(Circle().stroke(item == channel ? Color.white : .clear, lineWidth: 1.5))
                                Text(item.title).font(.caption2).foregroundStyle(item == channel ? .primary : .secondary)
                            }.frame(minWidth: 52, minHeight: 50)
                        }
                        .accessibilityLabel(String(format: NSLocalizedString("Range %@", comment: "Color mixer"), item.title))
                        .accessibilityIdentifier("mixer-band-\(item.rawValue)")
                        .accessibilityAddTraits(item == channel ? .isSelected : [])
                    }
                }.padding(.horizontal, 2)
            }
            .dimsDuringAdjustment()
            HStack {
                Text(String(format: NSLocalizedString("Color Mixer · %@", comment: "Color mixer"), channel.title)).font(.subheadline.weight(.medium))
                Spacer()
                Button {
                    onEnd(); onChange(channel, MixerAdjustment())
                } label: { Image(systemName: "arrow.counterclockwise").frame(width: 44, height: 44) }
                    .accessibilityLabel(String(format: NSLocalizedString("Reset %@ range", comment: "Color mixer"), channel.title))
            }
            .dimsDuringAdjustment()
            LinearAdjustmentControl(parameters: parameters, selectedID: $selectedID,
                onBegin: { onBegin("\(channel.title) · \($0.title)") },
                onChange: { parameter, value in
                    guard let component = MixerComponent(rawValue: parameter.id) else { return }
                    var updated = mixer[channel]; updated[component] = value; onChange(channel, updated)
                }, onEnd: onEnd,
                onReset: { parameter in
                    guard let component = MixerComponent(rawValue: parameter.id) else { return }
                    var updated = mixer[channel]; updated[component] = 0; onChange(channel, updated)
                })
                .id(channel)
        }.padding(.horizontal, 14).padding(.bottom, 8)
            .onDisappear(perform: onEnd)
    }
    private var parameters: [LinearAdjustmentParameter] {
        MixerComponent.allCases.map { component in
            LinearAdjustmentParameter(id: component.rawValue, title: component.title,
                value: mixer[channel][component], range: -100...100, step: 1, precision: 0, resetValue: 0)
        }
    }
}
