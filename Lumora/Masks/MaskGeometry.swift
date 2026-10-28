import CoreImage
import CoreGraphics

/// Maps a component's creation frame to the current photo without modifying its
/// editable shape or repeatedly resampling its saved bitmap.
struct MaskGeometry {
    let reference: HealingGeometry
    let current: HealingGeometry
    let unchanged: Bool

    init(sourceSize: CGSize, reference: GeometrySettings, current: GeometrySettings) {
        self.reference = HealingGeometry(size: sourceSize, settings: reference)
        self.current = HealingGeometry(size: sourceSize, settings: current)
        unchanged = reference == current
    }

    func display(_ point: MaskPoint) -> MaskPoint {
        unchanged ? point : current.display(reference.canonical(point))
    }

    func stored(_ point: MaskPoint) -> MaskPoint {
        unchanged ? point : reference.display(current.canonical(point))
    }

    /// Convert the on-screen brush size to the creation frame at the stroke's start.
    func brushSizeScale(at visible: MaskPoint) -> Double {
        guard !unchanged else { return 1 }
        let point = stored(visible)
        let radius = min(reference.outputSize.width, reference.outputSize.height) / 200
        let center = display(point)
        let x = display(MaskPoint(x: point.x + radius / reference.outputSize.width, y: point.y))
        let y = display(MaskPoint(x: point.x, y: point.y + radius / reference.outputSize.height))
        let dx = hypot((x.x - center.x) * current.outputSize.width, (x.y - center.y) * current.outputSize.height)
        let dy = hypot((y.x - center.x) * current.outputSize.width, (y.y - center.y) * current.outputSize.height)
        let scale = sqrt(dx * dy) / (min(current.outputSize.width, current.outputSize.height) / 200)
        return scale.isFinite && scale > 0 ? scale : 1
    }

    func homography(from referenceRect: CGRect, to displayRect: CGRect) -> [Double] {
        let corners = [MaskPoint(x: 0, y: 0), MaskPoint(x: 1, y: 0),
                       MaskPoint(x: 0, y: 1), MaskPoint(x: 1, y: 1)]
        return HealingGeometry.fit(corners.map {
            CGPoint(x: referenceRect.minX + $0.x * referenceRect.width,
                    y: referenceRect.minY + $0.y * referenceRect.height)
        }, corners.map {
            let point = display($0)
            return CGPoint(x: displayRect.minX + point.x * displayRect.width,
                           y: displayRect.minY + point.y * displayRect.height)
        })
    }

    func warp(_ image: CIImage, to extent: CGRect) throws -> CIImage {
        guard !unchanged else { return image }
        func corner(_ x: Double, _ y: Double) -> CIVector {
            let point = display(MaskPoint(x: x, y: y))
            return CIVector(x: extent.minX + point.x * extent.width,
                            y: extent.minY + (1 - point.y) * extent.height)
        }
        let filter = CIFilter(name: "CIPerspectiveTransform", parameters: [
            kCIInputImageKey: image,
            "inputTopLeft": corner(0, 0), "inputTopRight": corner(1, 0),
            "inputBottomLeft": corner(0, 1), "inputBottomRight": corner(1, 1)
        ])
        guard let output = filter?.outputImage else { throw PhotoError.renderFailed }
        return output.composited(over: CIImage(color: .black).cropped(to: extent)).cropped(to: extent)
    }
}

struct MaskRenderGeometry: Equatable, Sendable {
    let sourceSize: CGSize
    let current: GeometrySettings

    func mapping(_ component: MaskComponent) -> MaskGeometry {
        MaskGeometry(sourceSize: sourceSize, reference: component.geometry ?? current, current: current)
    }
}
