import SwiftUI

struct ManualHealingControls: View {
  let session: EditorSession
  @State private var confirmDelete = false
  @State private var selectedParameterID = "healing-size"
  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        Button("Correction", systemImage: "bandage") { session.toggleHealing() }
          .buttonStyle(.bordered).tint(session.healingActive ? .mint : .secondary)
          .accessibilityAddTraits(session.healingActive ? .isSelected : [])
          .accessibilityIdentifier("manual-healing-toggle")
        if session.healingPreparing { ProgressView().controlSize(.small) }
        Spacer()
        if session.healingActive {
          Button("Done") { session.closeHealing() }.buttonStyle(.bordered)
        }
      }
      if session.healingActive {
        Text("Tap an imperfection. Drag the target or source to adjust.")
          .font(.caption).foregroundStyle(.secondary)
        if let notice = session.healingNotice {
          Text(notice).font(.caption).foregroundStyle(.orange)
        }
        if let c = session.selectedHealing {
          if let map = session.healingGeometry,
             !(0...1).contains(map.display(c.sourceCenter).x) || !(0...1).contains(map.display(c.sourceCenter).y) {
            Button("Bring source into view") {
              session.moveHealing(c.id, source: true, visible: .init(x: 0.5, y: 0.5))
            }
          }
          if c.confidence < 0.45 {
            Text("Check the source: low confidence or manually moved.")
              .font(.caption).foregroundStyle(.orange)
          }
          Toggle(isOn: Binding(get:{session.healingPaintZone},set:{session.endHealingStroke();session.healingPaintZone=$0})) {
            if session.healingPaintZone {
              Label("Finish editing area", systemImage: "checkmark")
            } else {
              Label("Edit correction area", systemImage: "pencil.tip.crop.circle")
            }
          }
            .toggleStyle(.button).accessibilityIdentifier("healing-zone-mode")
          if session.healingPaintZone {
            Picker("Brush operation",selection:Binding(get:{session.healingEraseZone},set:{session.endHealingStroke();session.healingEraseZone=$0})) {
              Text("Add").tag(false);Text("Erase").tag(true)
            }.pickerStyle(.segmented)
            Text("Add paints more of this correction area; Erase removes part of it. Finish editing to move the target or source, or tap another imperfection.").font(.caption)
          }
          LinearAdjustmentControl(parameters: parameters(c), selectedID: $selectedParameterID,
            onBegin: { parameter in
              if parameter.id != "healing-zone-size" { session.beginInteraction(parameter.title) }
            }, onChange: { parameter, value in set(parameter.id, value, correction: c) },
            onEnd: {
              if selectedParameterID != "healing-zone-size" { session.finishInteraction() }
            }, onReset: { parameter in set(parameter.id, parameter.resetValue, correction: c) })
            .padding(.horizontal, -18)
          Button("Delete correction", systemImage: "trash", role: .destructive) {
            session.deleteHealing()
          }
        }
        if !session.state.beauty.corrections.isEmpty {
          Button("Delete all corrections", role: .destructive) {
            if session.state.beauty.corrections.count > 1 {
              confirmDelete = true
            } else {
              session.deleteHealing(all: true)
            }
          }
          .confirmationDialog(
            "Delete all corrections?", isPresented: $confirmDelete, titleVisibility: .visible
          ) {
            Button("Delete all corrections", role: .destructive) {
              session.deleteHealing(all: true)
            }
          }
        }
      }
    }.font(.caption).controlSize(.small)
      .accessibilityElement(children: .contain)
      .accessibilityIdentifier("healing-controls")
      .accessibilityValue(String(session.state.beauty.corrections.count))
      .onChange(of:session.selectedHealing?.id) { _, id in
        if id == nil { session.endHealingStroke(); session.healingPaintZone=false }
      }
  }
  private func parameters(_ correction: ManualBlemishCorrection) -> [LinearAdjustmentParameter] {
    var result: [LinearAdjustmentParameter] = []
    if session.healingPaintZone {
      result += [
        .init(id: "healing-zone-size", title: String(localized: "Brush size"), value: session.healingBrushRadius * 100, range: 0.1...5, step: 0.1, precision: 1, resetValue: 0.6),
        .init(id: "healing-zone-feather", title: String(localized: "Feather"), value: correction.feather * 100, range: 15...90, step: 1, precision: 0, resetValue: 45)
      ]
    }
    result += [
      .init(id: "healing-size", title: String(localized: "Size"), value: correction.targetRadius * 100, range: 0.1...5, step: 0.1, precision: 1, resetValue: 0.8),
      .init(id: "healing-strength", title: String(localized: "Strength"), value: correction.strength, range: 0...100, step: 1, precision: 0, resetValue: 100)
    ]
    return result
  }
  private func set(_ id: String, _ value: Double, correction: ManualBlemishCorrection) {
    switch id {
    case "healing-zone-size": session.healingBrushRadius = value / 100
    case "healing-zone-feather": session.changeHealing(correction.id) { $0.feather = value / 100 }
    case "healing-size": session.changeHealing(correction.id) { $0.resizeTarget(to: value / 100) }
    case "healing-strength": session.changeHealing(correction.id) { $0.strength = value }
    default: break
    }
  }
}
