import SwiftUI

struct ManualHealingControls: View {
  let session: EditorSession
  @State private var confirmDelete = false
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
            AdjustmentSlider(title:String(localized:"Brush size"),range:0.1...5,accessibilityID:"healing-zone-size",value:session.healingBrushRadius*100,
              onBegin:{},onChange:{session.healingBrushRadius=$0/100},onEnd:{},onReset:{session.healingBrushRadius=0.006})
            AdjustmentSlider(title:String(localized:"Feather"),range:15...90,accessibilityID:"healing-zone-feather",value:c.feather*100,
              onBegin:{session.beginInteraction(String(localized:"Feather"))},onChange:{v in session.changeHealing(c.id){$0.feather=v/100}},onEnd:session.finishInteraction,onReset:{session.changeHealing(c.id){$0.feather=0.45}})
            Text("Add paints more of this correction area; Erase removes part of it. Finish editing to move the target or source, or tap another imperfection.").font(.caption)
          }
          AdjustmentSlider(
            title: String(localized: "Size"), range: 0.1...5,
            accessibilityID: "healing-size", value: c.targetRadius * 100,
            onBegin: { session.beginInteraction(String(localized: "Size")) },
            onChange: { v in session.changeHealing(c.id) { $0.resizeTarget(to: v / 100) } },
            onEnd: session.finishInteraction,
            onReset: { session.changeHealing(c.id) { $0.resizeTarget(to: 0.008) } })
          AdjustmentSlider(
            title: String(localized: "Strength"), range: 0...100,
            accessibilityID: "healing-strength", value: c.strength,
            onBegin: { session.beginInteraction(String(localized: "Strength")) },
            onChange: { v in session.changeHealing(c.id) { $0.strength = v } },
            onEnd: session.finishInteraction,
            onReset: { session.changeHealing(c.id) { $0.strength = 100 } })
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
}
