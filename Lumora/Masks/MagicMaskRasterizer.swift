import Foundation

/// Interpolate SAM's signed scores before thresholding. Thresholding the small
/// mask first discards the subpixel boundary and magnifies its staircase.
enum MagicMaskRasterizer {
    static func coverage(logits: [Float], width: Int, height: Int,
                         contentWidth: Double, contentHeight: Double,
                         outputWidth: Int, outputHeight: Int) -> [UInt8]? {
        guard width > 0, height > 0, logits.count == width * height,
              (1...4096).contains(outputWidth), (1...4096).contains(outputHeight),
              contentWidth.isFinite, contentHeight.isFinite,
              contentWidth > 0, contentWidth <= Double(width),
              contentHeight > 0, contentHeight <= Double(height),
              logits.allSatisfy(\.isFinite) else { return nil }

        let scaleX = Float(contentWidth / Double(outputWidth))
        let scaleY = Float(contentHeight / Double(outputHeight))
        var result = [UInt8](repeating: 0, count: outputWidth * outputHeight)
        for y in 0..<outputHeight {
            let rawY = (Float(y) + 0.5) * scaleY - 0.5
            let py = min(Float(height - 1), max(0, rawY))
            let y0 = Int(py), y1 = min(height - 1, y0 + 1)
            let ty = py - Float(y0)
            for x in 0..<outputWidth {
                let rawX = (Float(x) + 0.5) * scaleX - 0.5
                let px = min(Float(width - 1), max(0, rawX))
                let x0 = Int(px), x1 = min(width - 1, x0 + 1)
                let tx = px - Float(x0)
                let a = logits[y0 * width + x0], b = logits[y0 * width + x1]
                let c = logits[y1 * width + x0], d = logits[y1 * width + x1]
                let top = a + (b - a) * tx
                let bottom = c + (d - c) * tx
                let score = top + (bottom - top) * ty
                // Scale the transition to one output pixel, independently of
                // model confidence and zoom. Flat interiors stay fully opaque.
                let dx = rawX < 0 || rawX > Float(width - 1) ? 0
                    : ((b - a) * (1 - ty) + (d - c) * ty) * scaleX
                let dy = rawY < 0 || rawY > Float(height - 1) ? 0
                    : (bottom - top) * scaleY
                let halfWidth = max(0.00001, (abs(dx) + abs(dy)) * 0.5)
                let t = min(1, max(0, 0.5 + score / (2 * halfWidth)))
                let coverage = t * t * (3 - 2 * t)
                result[y * outputWidth + x] = UInt8((coverage * 255).rounded())
            }
        }
        return result
    }
}
