import SwiftUI

/// Editing-only vector overlay. Never part of EditState, the CI graph or exports.
struct DLCCenterOverlay:View {
    let settings:DarkenLightenCenterSettings
    let imageSize:CGSize
    let zoom:CGFloat
    let pan:CGSize
    let onBegin:()->Void
    let onChange:(CGPoint)->Void
    let onEnd:()->Void
    @State private var dragging=false
    @State private var initial=CGPoint.zero
    var body:some View {
        GeometryReader { proxy in
            let viewport=DLCViewport(image:imageSize,view:proxy.size,zoom:zoom,pan:pan)
            let center=viewport.screen(CGPoint(x:settings.centerX,y:settings.centerY))
            let short=min(viewport.imageRect.width,viewport.imageRect.height)
            let radii=settings.radii
            ZStack {
                ForEach([1.0,1-settings.transitionWidth],id:\.self) { scale in
                    Ellipse().stroke(.mint.opacity(scale==1 ? 0.65:0.35),style:StrokeStyle(lineWidth:1,dash:[5,5]))
                        .frame(width:2*radii.width*short*scale,height:2*radii.height*short*scale)
                        .rotationEffect(.degrees(settings.rotation)).position(center)
                        .allowsHitTesting(false).accessibilityHidden(true)
                }
                Image(systemName:"plus.circle.fill").font(.system(size:22))
                    .foregroundStyle(.mint,.black.opacity(0.7))
                    .frame(width:48,height:48).contentShape(Rectangle()).position(center)
                    .gesture(DragGesture(minimumDistance:0).onChanged { value in
                        if !dragging {dragging=true;initial=center;onBegin()}
                        onChange(viewport.normalized(CGPoint(x:initial.x+value.translation.width,y:initial.y+value.translation.height)))
                    }.onEnded { _ in dragging=false;onEnd() })
                    .accessibilityElement().accessibilityLabel("Lighting center")
                    .accessibilityValue(String(format:"X %.3f Y %.3f",settings.centerX,settings.centerY))
                    .accessibilityHint("Drag the handle, or use the precise position sliders in Creative.")
                    .accessibilityIdentifier("creative-dlc-center-handle")
            }.frame(width:proxy.size.width,height:proxy.size.height).clipped()
        }.onDisappear {if dragging {dragging=false;onEnd()}}
    }
}
