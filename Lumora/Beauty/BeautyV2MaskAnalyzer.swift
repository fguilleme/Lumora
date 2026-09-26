import CoreGraphics
import Foundation

struct BeautyV2Masks: @unchecked Sendable {
    let lips: CGImage?
    let innerMouth: CGImage?
    let hair: CGImage?
    static let empty = BeautyV2Masks(lips: nil, innerMouth: nil, hair: nil)
}

/// Uses landmarks already found by BeautyFaceAnalysis. No second Vision request.
/// Hair is deferred; production performs no person segmentation.
enum BeautyV2MaskAnalyzer {
    static func generate(source: MaskBitmapSource, faces: [BeautyMaskFace]) -> BeautyV2Masks {
        let lips = canvas(source) { context in
            for face in faces where face.outerLipPoints.count >= 6 {
                let outer = inset(face.outerLipPoints, fraction: 0.95)
                fill(outer, in: context, gray: 1)
                if face.innerLipPoints.count >= 6 {
                    fill(inset(face.innerLipPoints, fraction: 1.10), in: context, gray: 0)
                }
            }
        }
        let mouth = canvas(source) { context in
            for face in faces where face.innerLipPoints.count >= 6 {
                fill(face.innerLipPoints, in: context, gray: 1)
            }
        }
        return BeautyV2Masks(lips: lips, innerMouth: mouth, hair: nil)
    }

    private static func canvas(_ source: MaskBitmapSource,
                               draw: (CGContext) -> Void) -> CGImage? {
        guard let context = CGContext(data: nil, width: source.width, height: source.height,
                                      bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceGray(),
                                      bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return nil }
        context.setFillColor(gray: 0, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: source.width, height: source.height))
        context.setShouldAntialias(true)
        draw(context)
        return context.makeImage()
    }

    private static func inset(_ points: [CGPoint], fraction: CGFloat) -> [CGPoint] {
        guard !points.isEmpty else { return [] }
        let center = CGPoint(x: points.map(\.x).reduce(0, +) / CGFloat(points.count),
                             y: points.map(\.y).reduce(0, +) / CGFloat(points.count))
        return points.map { CGPoint(x: center.x + ($0.x - center.x) * fraction,
                                     y: center.y + ($0.y - center.y) * fraction) }
    }

    private static func fill(_ points: [CGPoint], in context: CGContext, gray: CGFloat) {
        guard let first = points.first, points.count >= 3 else { return }
        let path = CGMutablePath()
        path.move(to: first)
        for point in points.dropFirst() { path.addLine(to: point) }
        path.closeSubpath()
        context.setFillColor(gray: gray, alpha: 1)
        context.addPath(path)
        context.fillPath()
    }

}
