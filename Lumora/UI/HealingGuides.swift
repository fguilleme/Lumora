import SwiftUI

struct HealingGuides: View {
  let corrections: [ManualBlemishCorrection]
  let selected: UUID?
  let map: HealingGeometry
  let rect: CGRect
  let onSelect: (UUID) -> Void
  let onBegin: () -> Void
  let onMove: (UUID, Bool, MaskPoint) -> Void
  let onEnd: () -> Void
  @State private var dragging: UUID?
  @State private var draggingSource = false
  @State private var start = MaskPoint(x: 0, y: 0)
  private func screen(_ p: MaskPoint) -> CGPoint {
    let q = map.display(p)
    return CGPoint(x: rect.minX + q.x * rect.width, y: rect.minY + q.y * rect.height)
  }
  var body: some View {
    ZStack {
      if let c=corrections.first(where:{$0.id==selected}) {
        Canvas { context, _ in
          context.drawLayer { layer in
            let strokes=[HealingTargetStroke(points:[c.targetCenter],radius:c.targetRadius,erase:false)]+(c.targetStrokes ?? [])
            for stroke in strokes {
              layer.blendMode=stroke.erase ? .destinationOut : .normal
              var prior=stroke.points.first
              for point in stroke.points {
                let a=prior ?? point
                let dx=(point.x-a.x)*map.inputSize.width,dy=(point.y-a.y)*map.inputSize.height
                let r=stroke.radius*min(map.inputSize.width,map.inputSize.height)
                let count=max(1,Int(ceil(hypot(dx,dy)/max(1,r*0.3))))
                for step in 0...count {
                  let t=Double(step)/Double(count),center=MaskPoint(x:a.x+(point.x-a.x)*t,y:a.y+(point.y-a.y)*t)
                  let path=Path { path in
                    for i in 0...32 {
                      let angle=Double(i)*Double.pi/16
                      let p=screen(.init(x:center.x+cos(angle)*r/map.inputSize.width,y:center.y+sin(angle)*r/map.inputSize.height))
                      if i==0 {path.move(to:p)} else {path.addLine(to:p)}
                    };path.closeSubpath()
                  }
                  layer.fill(path,with:.color(.mint))
                };prior=point
              }
            }
          }
        }.opacity(0.22).allowsHitTesting(false)
      }
      ForEach(corrections) { c in
        if c.id == selected {
          Path { p in
            p.move(to: screen(c.targetCenter))
            p.addLine(to: screen(c.sourceCenter))
          }
          .stroke(.white.opacity(0.65), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
          .allowsHitTesting(false)
          circle(c, source: true)
        }
        circle(c, source: false)
      }
    }.coordinateSpace(name: "healing-guides").allowsHitTesting(true)
  }
  private func circle(_ c: ManualBlemishCorrection, source: Bool) -> some View {
    let center = source ? c.sourceCenter : c.targetCenter
    let r = c.targetRadius * min(map.inputSize.width, map.inputSize.height)
    return ZStack {
      Path { path in
        for i in 0...64 {
          let a = Double(i) * Double.pi / 32
          let p = screen(
            .init(
              x: center.x + cos(a) * r / map.inputSize.width,
              y: center.y + sin(a) * r / map.inputSize.height))
          if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
      }.stroke(source ? Color.orange : Color.mint, lineWidth: c.id == selected ? 1.5 : 1)
        .allowsHitTesting(false)
      Circle().fill(.clear).frame(width: 44, height: 44).contentShape(Circle())
        .overlay {
          Image(systemName: source ? "plus" : "circle.fill").font(.system(size: source ? 10 : 4))
            .foregroundStyle(source ? .orange : .mint).allowsHitTesting(false)
        }
        .position(screen(center))
        .onTapGesture { onSelect(c.id) }
        .highPriorityGesture(
          DragGesture(minimumDistance: 3, coordinateSpace: .named("healing-guides")).onChanged { value in
            if dragging == nil {
              // The 44-point hit areas can overlap at fit zoom. Route to the
              // nearest visible handle, not whichever view is drawn last.
              var candidates = corrections.map { ($0.id, false, $0.targetCenter) }
              if let selected = corrections.first(where: { $0.id == selected }) {
                candidates.append((selected.id, true, selected.sourceCenter))
              }
              let nearest = candidates.min { a, b in
                let pa = screen(a.2), pb = screen(b.2), p = value.startLocation
                return hypot(pa.x-p.x, pa.y-p.y) < hypot(pb.x-p.x, pb.y-p.y)
              } ?? (c.id, source, center)
              dragging = nearest.0; draggingSource = nearest.1
              start = map.display(nearest.2)
              onSelect(nearest.0)
              onBegin()
            }
            onMove(
              dragging ?? c.id, draggingSource,
              .init(
                x: start.x + value.translation.width / rect.width,
                y: start.y + value.translation.height / rect.height))
          }.onEnded { _ in
            dragging = nil
            onEnd()
          }
        )
        .accessibilityLabel(source ? "Correction source" : "Correction target")
        .accessibilityIdentifier(source ? "healing-source-handle" : "healing-target-handle")
    }
  }
}
