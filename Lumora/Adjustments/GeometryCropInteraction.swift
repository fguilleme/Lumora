import Foundation
import CoreGraphics

/// Converts relative image gestures to the existing crop parameters. Image
/// coordinates here start at the top left, matching SwiftUI and CGImage.
enum GeometryCropInteraction {
    static func rect(settings: GeometrySettings, imageSize: CGSize) -> CGRect {
        let settings = settings.validated
        let base = baseSize(settings: settings, imageSize: imageSize)
        let scale = 1 - settings.cropZoom / 100 * 0.8
        let width = max(1, floor(base.width * scale))
        let height = max(1, floor(base.height * scale))
        let availableX = imageSize.width - width, availableY = imageSize.height - height
        let x = floor(availableX * (settings.cropX + 100) / 200)
        let bottomY = floor(availableY * (100 - settings.cropY) / 200)
        return CGRect(x: x, y: imageSize.height - height - bottomY, width: width, height: height)
    }

    static func changed(initial: GeometrySettings, imageSize: CGSize, viewportWidth: CGFloat,
                        magnification: CGFloat, translation: CGSize) -> GeometrySettings {
        guard imageSize.width > 0, imageSize.height > 0, viewportWidth > 0,
              magnification.isFinite, magnification > 0,
              translation.width.isFinite, translation.height.isFinite else { return initial }
        if magnification == 1 && translation == .zero { return initial }
        var value = initial.validated
        let base = baseSize(settings: value, imageSize: imageSize)
        let initialScale = 1 - value.cropZoom / 100 * 0.8
        let initialWidth = max(1, floor(base.width * initialScale))
        let initialHeight = max(1, floor(base.height * initialScale))
        let centerX = (imageSize.width - initialWidth) * (value.cropX + 100) / 200 + initialWidth / 2
        let centerY = (imageSize.height - initialHeight) * (value.cropY + 100) / 200 + initialHeight / 2
        value[.cropZoom] = (1 - initialScale / magnification) / 0.8 * 100
        let newScale = 1 - value.cropZoom / 100 * 0.8
        let width = max(1, floor(base.width * newScale)), height = max(1, floor(base.height * newScale))
        let displayScale = viewportWidth / width
        let x = centerX - translation.width / displayScale - width / 2
        let y = centerY - translation.height / displayScale - height / 2
        // Preserve dormant offsets on a fully covered axis; first contact must
        // not reset a value just because there is no room to pan on that axis.
        if imageSize.width > width { value[.cropX] = x / (imageSize.width - width) * 200 - 100 }
        if imageSize.height > height { value[.cropY] = y / (imageSize.height - height) * 200 - 100 }
        return value
    }

    private static func baseSize(settings: GeometrySettings, imageSize: CGSize) -> CGSize {
        guard let ratio = settings.aspect.ratio else { return imageSize }
        if imageSize.width / imageSize.height > ratio {
            return CGSize(width: imageSize.height * ratio, height: imageSize.height)
        }
        return CGSize(width: imageSize.width, height: imageSize.width / ratio)
    }
}
