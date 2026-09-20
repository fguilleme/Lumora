import CoreGraphics

enum EyeMaskGenerator {
    /// Builds a soft grayscale matte around Vision eye landmarks expressed in image coordinates.
    static func makeMask(imageSize: CGSize, eyeRegions: [[CGPoint]]) -> CGImage? {
        let longestSide = max(imageSize.width, imageSize.height)
        guard longestSide > 0, !eyeRegions.isEmpty else { return nil }
        let scale = min(1, 2_048 / longestSide)
        let outputSize = CGSize(width: max(1, (imageSize.width * scale).rounded()),
                                height: max(1, (imageSize.height * scale).rounded()))
        let width = Int(outputSize.width), height = Int(outputSize.height)
        guard let gray = CGColorSpace(name: CGColorSpace.linearGray),
              let bitmap = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                     bytesPerRow: width, space: gray,
                                     bitmapInfo: CGImageAlphaInfo.none.rawValue),
              let gradient = CGGradient(colorsSpace: gray,
                                        colors: [CGColor(gray: 1, alpha: 1),
                                                 CGColor(gray: 1, alpha: 1),
                                                 CGColor(gray: 0, alpha: 1)] as CFArray,
                                        locations: [0, 0.56, 1])
        else { return nil }

        bitmap.setFillColor(CGColor(gray: 0, alpha: 1))
        bitmap.fill(CGRect(origin: .zero, size: outputSize))
        bitmap.setBlendMode(.lighten)

        var drewEye = false
        for region in eyeRegions where region.count >= 3 {
            let scaled = region.map { CGPoint(x: $0.x * scale, y: $0.y * scale) }
            guard let first = scaled.first else { continue }
            var bounds = CGRect(origin: first, size: .zero)
            for point in scaled.dropFirst() {
                bounds = bounds.union(CGRect(origin: point, size: .zero))
            }
            let horizontalPadding = max(2, bounds.width * 0.28)
            let verticalPadding = max(2, max(bounds.height * 0.85, bounds.width * 0.18))
            let rect = bounds.insetBy(dx: -horizontalPadding, dy: -verticalPadding)
                .intersection(CGRect(origin: .zero, size: outputSize))
            guard rect.width > 1, rect.height > 1 else { continue }

            bitmap.saveGState()
            bitmap.translateBy(x: rect.midX, y: rect.midY)
            bitmap.scaleBy(x: rect.width / 2, y: rect.height / 2)
            bitmap.addEllipse(in: CGRect(x: -1, y: -1, width: 2, height: 2))
            bitmap.clip()
            bitmap.drawRadialGradient(gradient, startCenter: .zero, startRadius: 0,
                                      endCenter: .zero, endRadius: 1, options: [])
            bitmap.restoreGState()
            drewEye = true
        }
        return drewEye ? bitmap.makeImage() : nil
    }
}
