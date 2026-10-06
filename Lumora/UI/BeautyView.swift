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
    @State private var selectedID = "beauty-amount"

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

                LinearAdjustmentControl(parameters: parameters, selectedID: $selectedID,
                    onBegin: { onBegin($0.title) },
                    onChange: { parameter, value in set(parameter.id, value) },
                    onEnd: onEnd,
                    onReset: { parameter in set(parameter.id, parameter.resetValue) })
                    .padding(.horizontal, -18)
                ManualHealingControls(session: session)
                #if DEBUG
                BeautyMaskDebugView(masks: debugMasks)
                #endif
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 14)
        }
        .accessibilityIdentifier("beauty-controls")
    }

    private var parameters: [LinearAdjustmentParameter] {
        let enabled = faceCount != 0 && !isAnalyzing
        let classic = BeautyControl.allCases.map { control in
            LinearAdjustmentParameter(id: "beauty-\(control.rawValue)", title: control.title,
                value: settings[control], range: control.range, step: 1, precision: 0,
                resetValue: control == .amount ? 100 : 0, isEnabled: enabled)
        }
        let finishing = BeautyV2Control.productionCases.map { control in
            LinearAdjustmentParameter(id: "beauty-v2-\(control.rawValue)", title: control.title,
                value: (settings.finishing ?? .init())[control], range: control.range, step: 1,
                precision: 0, resetValue: 0, isEnabled: enabled)
        }
        return classic + finishing
    }
    private func set(_ id: String, _ value: Double) {
        if id.hasPrefix("beauty-v2-"),
           let control = BeautyV2Control(rawValue: String(id.dropFirst("beauty-v2-".count))) {
            onV2Change(control, value)
        } else if let control = BeautyControl(rawValue: String(id.dropFirst("beauty-".count))) {
            onChange(control, value)
        }
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
