import SwiftUI

struct BeautyView: View {
    let session: EditorSession
    let settings: BeautyState
    let faceCount: Int?
    let isAnalyzing: Bool
    let debugMasks: BeautyMasks?
    let onPreset: (BeautyPreset) -> Void
    let onBegin: (String) -> Void
    let onChange: (BeautyControl, Double) -> Void
    let onV2Change: (BeautyV2Control, Double) -> Void
    let onEnd: () -> Void
    let onReset: () -> Void

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 7) {
                    ForEach(BeautyPreset.allCases) { preset in
                        Button(preset.title) { onPreset(preset) }
                            .buttonStyle(.bordered)
                            .tint(BeautyPreset.matching(settings) == preset ? .mint : .secondary)
                            .accessibilityAddTraits(BeautyPreset.matching(settings) == preset ? .isSelected : [])
                            .disabled(faceCount == 0 || isAnalyzing)
                    }
                    if BeautyPreset.matching(settings) == nil && !settings.isIdentity {
                        Text("Custom").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .controlSize(.small)
                .dimsDuringAdjustment()
                HStack(spacing: 8) {
                    if isAnalyzing { ProgressView().controlSize(.mini) }
                    Text(session.beautyAnalysisError != nil ? String(localized: "Face analysis unavailable") : faceCount == 0 ? String(localized: "No face detected") :
                         faceCount == nil ? String(localized: "Analyzing faces…") :
                         String(localized: "All Faces"))
                    if let faceCount, faceCount > 0 { Text("(\(faceCount))") }
                    Spacer(minLength: 0)
                    Button("Reset Beauty", systemImage: "arrow.counterclockwise", action: onReset)
                        .labelStyle(.iconOnly)
                        .disabled(settings == BeautyState())
                        .accessibilityLabel("Reset Beauty")
                }
                .font(.caption).foregroundStyle(.secondary)
                .dimsDuringAdjustment()

                slider(.amount)
                section("Skin", [.uniformity, .texture, .blemishes])
                v2Section("", [.skinShine])
                ManualHealingControls(session: session)
                section("Eyes", [.darkCircles, .eyeBrightness, .eyeDetail])
                section("Smile", [.teeth])
                v2Section("Lips", [.lipSaturation, .lipBrightness, .lipDetail])
                v2Section("Face", [.faceBalance])
                #if DEBUG
                BeautyMaskDebugView(masks: debugMasks)
                #endif
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 14)
        }
        .accessibilityIdentifier("beauty-controls")
    }

    private func section(_ title: String, _ controls: [BeautyControl]) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(LocalizedStringKey(title)).font(.headline).foregroundStyle(.secondary)
                .padding(.top, 7).dimsDuringAdjustment()
            ForEach(controls) { slider($0) }
        }
    }

    private func v2Section(_ title: String, _ controls: [BeautyV2Control]) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            if !title.isEmpty {
                Text(LocalizedStringKey(title)).font(.headline).foregroundStyle(.secondary)
                    .padding(.top, 7).dimsDuringAdjustment()
            }
            ForEach(controls) { control in
                AdjustmentSlider(title: control.title, range: control.range,
                    accessibilityID: "beauty-v2-\(control.rawValue)",
                    value: (settings.finishing ?? .init())[control],
                    onBegin: { onBegin(control.title) },
                    onChange: { onV2Change(control, $0) }, onEnd: onEnd,
                    onReset: { onV2Change(control, 0) })
                    .disabled(faceCount == 0 || isAnalyzing)
            }
        }
    }

    private func slider(_ control: BeautyControl) -> some View {
        AdjustmentSlider(title: control.title, range: control.range,
                         accessibilityID: "beauty-\(control.rawValue)",
                         value: settings[control],
                         onBegin: { onBegin(control.title) },
                         onChange: { onChange(control, $0) }, onEnd: onEnd,
                         onReset: { onChange(control, control == .amount ? 100 : 0) })
            .disabled(faceCount == 0 || isAnalyzing)
            .opacity(faceCount == 0 ? 0.4 : 1)
    }
}

#if DEBUG
/// Diagnostic masks are displayed by the session only in Debug builds.
private struct BeautyMaskDebugView: View {
    let masks: BeautyMasks?
    @State private var showing = false
    var body: some View {
        Button("Show Beauty Masks", systemImage: "square.3.layers.3d") { showing = true }
            .font(.caption).disabled(masks == nil)
            .sheet(isPresented: $showing) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(maskImages, id: \.0) { item in
                            Text(item.0).font(.headline)
                            Image(uiImage: UIImage(cgImage: item.1))
                                .resizable().aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 250)
                        }
                    }.padding()
                }
            }
            .accessibilityIdentifier("beauty-mask-debug")
    }
    private var maskImages: [(String, CGImage)] {
        guard let masks else { return [] }
        return [("Skin", masks.skin), ("Eyes", masks.eyes),
                ("Under Eyes", masks.underEyes), ("Teeth", masks.teeth),
                ( "Blemishes", masks.blemishes), ("Lips", masks.v2.lips),
                ("Inner Mouth", masks.v2.innerMouth)].compactMap { name, image in
                    image.map { (name, $0) }
                }
    }
}
#endif
