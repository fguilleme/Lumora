import CoreGraphics

/// Calibrates a chroma model from detected faces, then finds similar plausible skin pixels.
/// Face rectangles use normalized top-left image coordinates.
enum SkinMaskGenerator {
    static func makeMask(from image: CGImage, faceRegions: [CGRect],
                         maximumDimension: Int = 1_024) -> CGImage? {
        guard let source = MaskBitmapSource(image: image, maximumDimension: maximumDimension),
              !faceRegions.isEmpty else { return nil }
        let centers = faceRegions.compactMap { chromaCenter(in: $0, source: source) }
        guard !centers.isEmpty else { return nil }

        var matte = [UInt8](repeating: 0, count: source.width * source.height)
        var selected = 0
        for y in 0..<source.height {
            for x in 0..<source.width {
                let (red, green, blue) = source.rgb(x: x, y: y)
                let sample = yCbCr(red: red, green: green, blue: blue)
                var distance = Float.greatestFiniteMagnitude
                for center in centers {
                    distance = min(distance, hypot(sample.cb - center.cb, sample.cr - center.cr))
                }
                let similarity = 1 - smoothstep(0.045, 0.155, distance)
                let plausible = smoothstep(0.25, 0.32, sample.cb)
                    * (1 - smoothstep(0.53, 0.60, sample.cb))
                    * smoothstep(0.47, 0.52, sample.cr)
                    * (1 - smoothstep(0.72, 0.79, sample.cr))
                let luminanceGate = smoothstep(0.025, 0.10, sample.y)
                    * (1 - smoothstep(0.96, 1, sample.y))
                let value = similarity * plausible * luminanceGate
                let index = y * source.width + x
                matte[index] = UInt8((min(1, value) * 255).rounded())
                if matte[index] > 40 { selected += 1 }
            }
        }
        guard selected >= max(16, source.width * source.height / 1_000) else { return nil }
        return source.grayImage(matte)
    }

    private static func chromaCenter(in normalizedRegion: CGRect,
                                     source: MaskBitmapSource) -> (cb: Float, cr: Float)? {
        let clipped = normalizedRegion.intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
        guard !clipped.isNull, clipped.width > 0, clipped.height > 0 else { return nil }
        let central = clipped.insetBy(dx: clipped.width * 0.22, dy: clipped.height * 0.18)
        let minX = max(0, Int((central.minX * CGFloat(source.width)).rounded(.down)))
        let maxX = min(source.width - 1, Int((central.maxX * CGFloat(source.width)).rounded(.up)))
        let minY = max(0, Int((central.minY * CGFloat(source.height)).rounded(.down)))
        let maxY = min(source.height - 1, Int((central.maxY * CGFloat(source.height)).rounded(.up)))
        guard minX <= maxX, minY <= maxY else { return nil }

        var sumCB: Float = 0, sumCR: Float = 0
        var count = 0
        for y in minY...maxY {
            for x in minX...maxX {
                let (red, green, blue) = source.rgb(x: x, y: y)
                let sample = yCbCr(red: red, green: green, blue: blue)
                guard sample.y > 0.035, sample.y < 0.97,
                      sample.cb > 0.24, sample.cb < 0.61,
                      sample.cr > 0.46, sample.cr < 0.80 else { continue }
                sumCB += sample.cb; sumCR += sample.cr; count += 1
            }
        }
        guard count >= 12 else { return nil }
        return (sumCB / Float(count), sumCR / Float(count))
    }

    private static func yCbCr(red: Float, green: Float, blue: Float)
        -> (y: Float, cb: Float, cr: Float) {
        let y = 0.299 * red + 0.587 * green + 0.114 * blue
        let cb = 0.5 - 0.168736 * red - 0.331264 * green + 0.5 * blue
        let cr = 0.5 + 0.5 * red - 0.418688 * green - 0.081312 * blue
        return (y, cb, cr)
    }

    private static func smoothstep(_ edge0: Float, _ edge1: Float, _ value: Float) -> Float {
        let t = min(1, max(0, (value - edge0) / (edge1 - edge0)))
        return t * t * (3 - 2 * t)
    }
}
