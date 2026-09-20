import Foundation
import CoreGraphics
import CoreImage

enum CropAspect: String, CaseIterable, Codable, Sendable, Identifiable {
    case original, square, fourThree, threeTwo, sixteenNine

    var id: String { rawValue }
    var title: String {
        switch self {
        case .original: "Original"
        case .square: "1:1"
        case .fourThree: "4:3"
        case .threeTwo: "3:2"
        case .sixteenNine: "16:9"
        }
    }
    var ratio: Double? {
        switch self {
        case .original: nil
        case .square: 1
        case .fourThree: 4 / 3
        case .threeTwo: 3 / 2
        case .sixteenNine: 16 / 9
        }
    }
}

struct GeometrySettings: Codable, Sendable, Equatable {
    /// Clockwise quarter turns, normalized to 0...3.
    var quarterTurns = 0
    var straighten = 0.0
    var flipHorizontal = false
    var flipVertical = false
    var aspect = CropAspect.original
    var cropZoom = 0.0
    var cropX = 0.0
    var cropY = 0.0
    var perspectiveVertical = 0.0
    var perspectiveHorizontal = 0.0
    var perspectiveAspect = 0.0
    var perspectiveScale = 100.0
    var perspectiveOffsetX = 0.0
    var perspectiveOffsetY = 0.0

    private enum CodingKeys: String, CodingKey {
        case quarterTurns, straighten, flipHorizontal, flipVertical, aspect, cropZoom, cropX, cropY
        case perspectiveVertical, perspectiveHorizontal, perspectiveAspect, perspectiveScale
        case perspectiveOffsetX, perspectiveOffsetY
    }

    init() {}
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        quarterTurns = try values.decodeIfPresent(Int.self, forKey: .quarterTurns) ?? 0
        straighten = try values.decodeIfPresent(Double.self, forKey: .straighten) ?? 0
        flipHorizontal = try values.decodeIfPresent(Bool.self, forKey: .flipHorizontal) ?? false
        flipVertical = try values.decodeIfPresent(Bool.self, forKey: .flipVertical) ?? false
        aspect = try values.decodeIfPresent(CropAspect.self, forKey: .aspect) ?? .original
        cropZoom = try values.decodeIfPresent(Double.self, forKey: .cropZoom) ?? 0
        cropX = try values.decodeIfPresent(Double.self, forKey: .cropX) ?? 0
        cropY = try values.decodeIfPresent(Double.self, forKey: .cropY) ?? 0
        perspectiveVertical = try values.decodeIfPresent(Double.self, forKey: .perspectiveVertical) ?? 0
        perspectiveHorizontal = try values.decodeIfPresent(Double.self, forKey: .perspectiveHorizontal) ?? 0
        perspectiveAspect = try values.decodeIfPresent(Double.self, forKey: .perspectiveAspect) ?? 0
        perspectiveScale = try values.decodeIfPresent(Double.self, forKey: .perspectiveScale) ?? 100
        perspectiveOffsetX = try values.decodeIfPresent(Double.self, forKey: .perspectiveOffsetX) ?? 0
        perspectiveOffsetY = try values.decodeIfPresent(Double.self, forKey: .perspectiveOffsetY) ?? 0
        self = validated
    }

    var validated: Self {
        var value = self
        value.quarterTurns = ((quarterTurns % 4) + 4) % 4
        for adjustment in GeometryAdjustment.allCases { value[adjustment] = self[adjustment] }
        return value
    }
    var isIdentity: Bool {
        let value = validated
        return value.quarterTurns == 0 && value.straighten == 0 && !value.flipHorizontal
            && !value.flipVertical && value.aspect == .original && value.cropZoom == 0
            && value.cropX == 0 && value.cropY == 0 && value.perspectiveVertical == 0
            && value.perspectiveHorizontal == 0 && value.perspectiveAspect == 0
            && value.perspectiveScale == 100 && value.perspectiveOffsetX == 0 && value.perspectiveOffsetY == 0
    }
    subscript(_ adjustment: GeometryAdjustment) -> Double {
        get { self[keyPath: adjustment.keyPath] }
        set {
            let finiteValue = newValue.isFinite ? newValue : adjustment.defaultValue
            self[keyPath: adjustment.keyPath] = min(adjustment.range.upperBound,
                                                     max(adjustment.range.lowerBound, finiteValue))
        }
    }
}

enum GeometryAdjustment: String, CaseIterable, Sendable, Identifiable {
    case straighten, perspectiveVertical, perspectiveHorizontal, perspectiveAspect, perspectiveScale
    case perspectiveOffsetX, perspectiveOffsetY, cropZoom, cropX, cropY
    var id: String { rawValue }
    var title: String {
        switch self {
        case .straighten: "Redresser"
        case .cropZoom: "Recadrage"
        case .cropX: "Position horizontale"
        case .cropY: "Position verticale"
        case .perspectiveVertical: "Perspective verticale"
        case .perspectiveHorizontal: "Perspective horizontale"
        case .perspectiveAspect: "Aspect"
        case .perspectiveScale: "Échelle"
        case .perspectiveOffsetX: "Décalage X"
        case .perspectiveOffsetY: "Décalage Y"
        }
    }
    var range: ClosedRange<Double> {
        switch self {
        case .straighten: -15...15
        case .cropZoom: 0...80
        case .perspectiveScale: 100...150
        case .cropX, .cropY: -100...100
        case .perspectiveVertical, .perspectiveHorizontal, .perspectiveAspect,
             .perspectiveOffsetX, .perspectiveOffsetY: -100...100
        }
    }
    var defaultValue: Double { self == .perspectiveScale ? 100 : 0 }
    var keyPath: WritableKeyPath<GeometrySettings, Double> {
        switch self {
        case .straighten: \.straighten
        case .cropZoom: \.cropZoom
        case .cropX: \.cropX
        case .cropY: \.cropY
        case .perspectiveVertical: \.perspectiveVertical
        case .perspectiveHorizontal: \.perspectiveHorizontal
        case .perspectiveAspect: \.perspectiveAspect
        case .perspectiveScale: \.perspectiveScale
        case .perspectiveOffsetX: \.perspectiveOffsetX
        case .perspectiveOffsetY: \.perspectiveOffsetY
        }
    }
    static let perspective: [Self] = [.straighten, .perspectiveVertical, .perspectiveHorizontal,
                                      .perspectiveAspect, .perspectiveScale,
                                      .perspectiveOffsetX, .perspectiveOffsetY]
    static let crop: [Self] = [.cropZoom, .cropX, .cropY]
}

enum GeometryAnalysis {
    struct Quadrilateral: Sendable {
        var topLeft: CGPoint
        var topRight: CGPoint
        var bottomRight: CGPoint
        var bottomLeft: CGPoint
        var confidence: Double
    }

    struct PerspectiveCorrection: Sendable, Equatable {
        var vertical: Double
        var horizontal: Double
    }

    static func straightenDegrees(horizonRadians: Double) -> Double {
        guard horizonRadians.isFinite else { return 0 }
        // Vision's angle is the corrective image rotation; GeometryRenderer rotates by -straighten.
        let degrees = -horizonRadians * 180 / .pi
        return min(GeometryAdjustment.straighten.range.upperBound,
                   max(GeometryAdjustment.straighten.range.lowerBound, degrees))
    }

    static func perspectiveCorrection(from quadrilaterals: [Quadrilateral]) -> PerspectiveCorrection? {
        var verticalSum = 0.0, horizontalSum = 0.0, totalWeight = 0.0
        for quad in quadrilaterals {
            let points = [quad.topLeft, quad.topRight, quad.bottomRight, quad.bottomLeft]
            guard points.allSatisfy({ $0.x.isFinite && $0.y.isFinite }), quad.confidence.isFinite else { continue }
            let top = distance(quad.topLeft, quad.topRight)
            let bottom = distance(quad.bottomLeft, quad.bottomRight)
            let left = distance(quad.bottomLeft, quad.topLeft)
            let right = distance(quad.bottomRight, quad.topRight)
            let area = polygonArea(points)
            guard min(top, bottom, left, right) >= 0.04, area >= 0.01 else { continue }
            let weight = max(0, quad.confidence) * area
            guard weight > 0 else { continue }
            // GeometryRenderer changes the opposing edge lengths by 44% at a value of 100.
            verticalSum += (bottom - top) / 0.44 * 100 * weight
            horizontalSum += (left - right) / 0.44 * 100 * weight
            totalWeight += weight
        }
        guard totalWeight > 0 else { return nil }
        let vertical = clampPerspective(verticalSum / totalWeight)
        let horizontal = clampPerspective(horizontalSum / totalWeight)
        guard abs(vertical) >= 1 || abs(horizontal) >= 1 else { return nil }
        return PerspectiveCorrection(vertical: vertical, horizontal: horizontal)
    }

    private static func distance(_ a: CGPoint, _ b: CGPoint) -> Double {
        hypot(Double(b.x - a.x), Double(b.y - a.y))
    }

    private static func polygonArea(_ points: [CGPoint]) -> Double {
        guard points.count == 4 else { return 0 }
        return abs(zip(points, points.dropFirst() + [points[0]]).reduce(0.0) { partial, pair in
            partial + Double(pair.0.x * pair.1.y - pair.1.x * pair.0.y)
        }) / 2
    }

    private static func clampPerspective(_ value: Double) -> Double {
        min(GeometryAdjustment.perspectiveVertical.range.upperBound,
            max(GeometryAdjustment.perspectiveVertical.range.lowerBound, value))
    }
}

enum GeometryPerspectiveCorner: Sendable {
    case topLeft, topRight, bottomRight, bottomLeft
}

enum GeometryDirectManipulation {
    static func perspective(corner: GeometryPerspectiveCorner,
                            normalizedPoint point: CGPoint) -> GeometryAnalysis.PerspectiveCorrection {
        let x = min(1, max(0, Double(point.x)))
        let y = min(1, max(0, Double(point.y)))
        let scale = 100 / 0.22
        let values: (Double, Double) = switch corner {
        case .topLeft: (x * scale, -y * scale)
        case .topRight: ((1 - x) * scale, y * scale)
        case .bottomRight: (-(1 - x) * scale, (1 - y) * scale)
        case .bottomLeft: (-x * scale, -(1 - y) * scale)
        }
        return .init(vertical: clamp(values.0, to: GeometryAdjustment.perspectiveVertical.range),
                     horizontal: clamp(values.1, to: GeometryAdjustment.perspectiveHorizontal.range))
    }

    static func cropPosition(normalizedPoint point: CGPoint) -> (x: Double, y: Double) {
        let x = (min(1, max(0, Double(point.x))) - 0.5) * 200
        let y = (0.5 - min(1, max(0, Double(point.y)))) * 200
        return (x, y)
    }

    static func cropZoom(normalizedY: Double) -> Double {
        let value = (1 - min(1, max(0, normalizedY))) / 0.35 * 100
        return clamp(value, to: GeometryAdjustment.cropZoom.range)
    }

    private static func clamp(_ value: Double, to range: ClosedRange<Double>) -> Double {
        min(range.upperBound, max(range.lowerBound, value))
    }
}

enum GeometryRenderer {
    static func apply(_ input: CIImage, settings: GeometrySettings) -> CIImage {
        let settings = settings.validated
        guard !settings.isIdentity else { return input }
        var image = normalized(input)

        if settings.quarterTurns != 0 {
            let angle = -CGFloat(settings.quarterTurns) * .pi / 2
            image = rotated(image, radians: angle)
        }
        if settings.flipHorizontal || settings.flipVertical {
            let extent = image.extent
            let sx: CGFloat = settings.flipHorizontal ? -1 : 1
            let sy: CGFloat = settings.flipVertical ? -1 : 1
            let transform = CGAffineTransform(translationX: extent.midX, y: extent.midY)
                .scaledBy(x: sx, y: sy)
                .translatedBy(x: -extent.midX, y: -extent.midY)
            image = normalized(image.transformed(by: transform))
        }
        if settings.perspectiveVertical != 0 || settings.perspectiveHorizontal != 0 {
            image = tryPerspective(image, settings: settings)
        }
        if settings.straighten != 0 {
            let extent = image.extent
            let radians = CGFloat(settings.straighten) * .pi / 180
            let sine = abs(sin(radians)), cosine = abs(cos(radians))
            let scale = max(cosine + extent.height / extent.width * sine,
                            cosine + extent.width / extent.height * sine)
            let transform = CGAffineTransform(translationX: extent.midX, y: extent.midY)
                .rotated(by: -radians)
                .scaledBy(x: scale, y: scale)
                .translatedBy(x: -extent.midX, y: -extent.midY)
            image = image.transformed(by: transform).cropped(to: extent)
        }
        if settings.perspectiveAspect != 0 || settings.perspectiveScale != 100
            || settings.perspectiveOffsetX != 0 || settings.perspectiveOffsetY != 0 {
            image = affinePerspective(image, settings: settings)
        }

        let extent = image.extent
        var width = extent.width, height = extent.height
        if let ratio = settings.aspect.ratio {
            if width / height > ratio { width = height * ratio }
            else { height = width / ratio }
        }
        let zoomScale = CGFloat(1 - settings.cropZoom / 100 * 0.8)
        width = max(1, floor(width * zoomScale))
        height = max(1, floor(height * zoomScale))
        let availableX = extent.width - width, availableY = extent.height - height
        let originX = extent.minX + floor(availableX * CGFloat((settings.cropX + 100) / 200))
        // Positive values move the visible crop upward in the editor's coordinate language.
        let originY = extent.minY + floor(availableY * CGFloat((100 - settings.cropY) / 200))
        return normalized(image.cropped(to: CGRect(x: originX, y: originY, width: width, height: height)))
    }

    private static func rotated(_ image: CIImage, radians: CGFloat) -> CIImage {
        let extent = image.extent
        let transform = CGAffineTransform(translationX: extent.midX, y: extent.midY)
            .rotated(by: radians)
            .translatedBy(x: -extent.midX, y: -extent.midY)
        return normalized(image.transformed(by: transform))
    }

    private static func tryPerspective(_ image: CIImage, settings: GeometrySettings) -> CIImage {
        let extent = image.extent
        let vertical = CGFloat(settings.perspectiveVertical / 100) * extent.width * 0.22
        let horizontal = CGFloat(settings.perspectiveHorizontal / 100) * extent.height * 0.22
        let topInset = max(0, vertical), bottomInset = max(0, -vertical)
        let rightInset = max(0, horizontal), leftInset = max(0, -horizontal)
        let topLeft = CIVector(x: extent.minX + topInset, y: extent.maxY - leftInset)
        let topRight = CIVector(x: extent.maxX - topInset, y: extent.maxY - rightInset)
        let bottomLeft = CIVector(x: extent.minX + bottomInset, y: extent.minY + leftInset)
        let bottomRight = CIVector(x: extent.maxX - bottomInset, y: extent.minY + rightInset)
        guard let filter = CIFilter(name: "CIPerspectiveCorrection", parameters: [
            kCIInputImageKey: image, "inputTopLeft": topLeft, "inputTopRight": topRight,
            "inputBottomLeft": bottomLeft, "inputBottomRight": bottomRight,
            "inputCrop": true
        ]), let output = filter.outputImage else { return image }
        return normalized(output)
    }

    private static func affinePerspective(_ image: CIImage, settings: GeometrySettings) -> CIImage {
        let extent = image.extent
        var sx = CGFloat(1 + settings.perspectiveAspect / 100 * 0.25)
        var sy = CGFloat(1 - settings.perspectiveAspect / 100 * 0.25)
        let fill = max(1 / sx, 1 / sy) * CGFloat(settings.perspectiveScale / 100)
        sx *= fill; sy *= fill
        let tx = CGFloat(settings.perspectiveOffsetX / 100) * extent.width * 0.2
        let ty = CGFloat(settings.perspectiveOffsetY / 100) * extent.height * 0.2
        let transform = CGAffineTransform(translationX: extent.midX + tx, y: extent.midY + ty)
            .scaledBy(x: sx, y: sy)
            .translatedBy(x: -extent.midX, y: -extent.midY)
        return image.clampedToExtent().transformed(by: transform).cropped(to: extent)
    }

    private static func normalized(_ image: CIImage) -> CIImage {
        image.transformed(by: CGAffineTransform(translationX: -image.extent.minX, y: -image.extent.minY))
    }
}
