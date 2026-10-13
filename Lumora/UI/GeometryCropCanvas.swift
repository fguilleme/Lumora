import SwiftUI

struct GeometryCropCanvas: View {
    let image: CGImage
    let contextImage: CGImage?
    let error: String?
    let settings: GeometrySettings
    let isRendering: Bool
    let onBegin: (String) -> Void
    let onChange: (GeometryAdjustment, Double) -> Void
    let onEnd: () -> Void
    @State private var initialSettings: GeometrySettings?
    @State private var dragging = false
    @State private var pinching = false
    @State private var gestureTranslation = CGSize.zero
    @State private var gestureMagnification: CGFloat = 1

    var body: some View {
        GeometryReader { geometry in
            let source = contextImage ?? image
            let size = CGSize(width: source.width, height: source.height)
            let window = viewport(in: geometry.size, imageSize: size)
            let crop = GeometryCropInteraction.rect(settings: settings, imageSize: size)
            let scale = window.width / crop.width
            ZStack {
                Color.black
                if let contextImage {
                    Image(decorative: contextImage, scale: 1)
                        .resizable()
                        .frame(width: size.width * scale, height: size.height * scale)
                        .position(x: window.midX + (size.width / 2 - crop.midX) * scale,
                                  y: window.midY + (size.height / 2 - crop.midY) * scale)
                    Path { path in
                        path.addRect(CGRect(origin: .zero, size: geometry.size))
                        path.addRect(window)
                    }
                    .fill(.black.opacity(0.55), style: FillStyle(eoFill: true))
                    .allowsHitTesting(false)
                }
                // Use the same transformed context inside and outside while
                // cropping. An older rendered crop would lag behind the finger.
                // Restore the exact production preview once its render finishes.
                if contextImage == nil || (!dragging && !pinching && !isRendering) {
                    Image(decorative: image, scale: 1)
                        .resizable()
                        .frame(width: window.width, height: window.height)
                        .position(x: window.midX, y: window.midY)
                        .allowsHitTesting(false)
                }
                cropGuide(window)
                    .allowsHitTesting(false)
                if contextImage == nil {
                    if let error {
                        Text(error).font(.caption).padding(12)
                            .background(.black.opacity(0.8), in: RoundedRectangle(cornerRadius: 12))
                    } else {
                        AnimatedLoadingMessage("Preparing crop…")
                            .padding(12).background(.black.opacity(0.7), in: Capsule())
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 3)
                .onChanged { value in
                    guard contextImage != nil else { return }
                    begin()
                    dragging = true; gestureTranslation = value.translation
                    update(size: size, window: window)
                }
                .onEnded { value in
                    guard dragging else { return }
                    gestureTranslation = value.translation
                    update(size: size, window: window)
                    dragging = false; finishIfIdle()
                })
            .simultaneousGesture(MagnifyGesture()
                .onChanged { value in
                    guard contextImage != nil else { return }
                    begin()
                    pinching = true; gestureMagnification = value.magnification
                    update(size: size, window: window)
                }
                .onEnded { value in
                    guard pinching else { return }
                    gestureMagnification = value.magnification
                    update(size: size, window: window)
                    pinching = false; finishIfIdle()
                })
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Crop photo")
            .accessibilityHint("Pinch to crop. Drag to position the photo inside the frame.")
            .accessibilityValue(contextImage == nil ? (error ?? String(localized: "Preparing crop…")) : "\(settings.aspect.title) · \(Int(settings.cropZoom.rounded())) % · X \(Int(settings.cropX.rounded())) · Y \(Int(settings.cropY.rounded()))")
            .accessibilityIdentifier("geometry-crop-canvas")
        }
        .onDisappear {
            if initialSettings != nil { onEnd() }
            initialSettings = nil; dragging = false; pinching = false
        }
    }

    private func begin() {
        guard initialSettings == nil else { return }
        initialSettings = settings
        gestureTranslation = .zero; gestureMagnification = 1
        onBegin(String(localized: "Crop"))
    }

    private func update(size: CGSize, window: CGRect) {
        guard let initialSettings else { return }
        let value = GeometryCropInteraction.changed(initial: initialSettings, imageSize: size,
            viewportWidth: window.width, magnification: gestureMagnification, translation: gestureTranslation)
        if value.cropZoom != settings.cropZoom { onChange(.cropZoom, value.cropZoom) }
        if value.cropX != settings.cropX { onChange(.cropX, value.cropX) }
        if value.cropY != settings.cropY { onChange(.cropY, value.cropY) }
    }

    private func finishIfIdle() {
        guard !dragging, !pinching else { return }
        initialSettings = nil; gestureTranslation = .zero; gestureMagnification = 1
        onEnd()
    }

    private func viewport(in canvas: CGSize, imageSize: CGSize) -> CGRect {
        let ratio = settings.aspect.ratio ?? imageSize.width / imageSize.height
        let available = CGSize(width: max(1, canvas.width - 32), height: max(1, canvas.height - 32))
        let width = min(available.width, available.height * ratio)
        let height = width / ratio
        return CGRect(x: (canvas.width - width) / 2, y: (canvas.height - height) / 2,
                      width: width, height: height)
    }

    private func cropGuide(_ rect: CGRect) -> some View {
        Path { path in
            path.addRect(rect)
            for fraction in [CGFloat(1.0 / 3), CGFloat(2.0 / 3)] {
                path.move(to: CGPoint(x: rect.minX + rect.width * fraction, y: rect.minY))
                path.addLine(to: CGPoint(x: rect.minX + rect.width * fraction, y: rect.maxY))
                path.move(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * fraction))
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * fraction))
            }
        }
        .stroke(.white.opacity(0.8), lineWidth: 1)
    }
}
