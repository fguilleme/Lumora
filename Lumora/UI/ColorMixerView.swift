import SwiftUI

struct ColorMixerView: View {
    let mixer: ColorMixer
    let onBegin: (String) -> Void
    let onChange: (MixerChannel, MixerAdjustment) -> Void
    let onEnd: () -> Void
    @State private var channel: MixerChannel = .red

    var body: some View {
        VStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(MixerChannel.allCases) { item in
                        Button {
                            onEnd(); channel = item
                        } label: {
                            VStack(spacing: 4) {
                                Circle().fill(Color(hue: item.center / 360, saturation: 0.8, brightness: 0.95))
                                    .frame(width: 26, height: 26)
                                    .overlay {
                                        if item == channel {
                                            Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(.black)
                                        }
                                    }
                                    .padding(6)
                                    .overlay(Circle().stroke(item == channel ? Color.white : .clear, lineWidth: 1.5))
                                Text(item.title).font(.caption2).foregroundStyle(item == channel ? .primary : .secondary)
                            }.frame(minWidth: 62, minHeight: 60)
                        }
                        .accessibilityLabel("Plage \(item.title)")
                        .accessibilityIdentifier("mixer-band-\(item.rawValue)")
                        .accessibilityAddTraits(item == channel ? .isSelected : [])
                    }
                }.padding(.horizontal, 4)
            }
            HStack {
                Text("Mélangeur · \(channel.title)").font(.subheadline.weight(.medium))
                Spacer()
                Button {
                    onEnd(); onChange(channel, MixerAdjustment())
                } label: { Image(systemName: "arrow.counterclockwise").frame(width: 44, height: 44) }
                    .accessibilityLabel("Réinitialiser la plage \(channel.title)")
            }
            ForEach(MixerComponent.allCases) { component in
                AdjustmentSlider(title: component.title, accessibilityID: "mixer-\(component.rawValue)",
                                 value: mixer[channel][component],
                                 onBegin: { onBegin("\(channel.title) · \(component.title)") },
                                 onChange: { value in
                                     var updated = mixer[channel]; updated[component] = value
                                     onChange(channel, updated)
                                 }, onEnd: onEnd,
                                 onReset: {
                                     onEnd()
                                     var updated = mixer[channel]; updated[component] = 0
                                     onChange(channel, updated)
                                 })
            }
            .id(channel)
        }.padding(.horizontal, 20).padding(.bottom, 12)
            .onDisappear(perform: onEnd)
    }
}
