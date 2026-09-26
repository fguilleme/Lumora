import CoreGraphics
import Foundation
import Vision

struct BeautyMasks: @unchecked Sendable {
    let faceCount: Int
    let faceWidthFraction: CGFloat
    /// Lower-left normalized coordinates, used for diagnostic crops only.
    let faceRects: [CGRect]
    let skin: CGImage?
    let eyes: CGImage?
    let underEyes: CGImage?
    let teeth: CGImage?
    let blemishes: CGImage?
    var v2: BeautyV2Masks = .empty

    static let empty = BeautyMasks(faceCount: 0, faceWidthFraction: 0, faceRects: [],
        skin: nil, eyes: nil, underEyes: nil, teeth: nil, blemishes: nil, v2: .empty)
}

/// Diagnostic timings only; never persisted and never used to select a preset.
struct BeautyAnalysisTimings: Sendable {
    var imagePreparationMS = 0.0
    var visionFaceAndLandmarksMS = 0.0
    var geometryAndColorSamplingMS = 0.0
    var skinEyesUnderEyesTeethMS = 0.0
    var sampledColorSamplingMS = 0.0
    var sampledSkinMaskMS = 0.0
    var sampledEyeMasksMS = 0.0
    var sampledUnderEyeMasksMS = 0.0
    var sampledTeethMaskMS = 0.0
    var blemishesMS = 0.0
    var cgImageConversionsMS = 0.0
    var geometryRasterMS = 0.0
    var featureExclusionsMS = 0.0
    var detailPreparationMS = 0.0
    var skinRasterMS = 0.0
    var finalMaskCompositionMS = 0.0
}

/// Vision runs on RenderEngine's background actor. Masks are temporary and are
/// keyed by source/geometry in that actor, never written into a document.
enum BeautyFaceAnalysis {
    static func analyze(_ image: CGImage,
                        timing: ((BeautyAnalysisTimings) -> Void)? = nil,
                        diagnostics: ((BeautyMaskDiagnostics) -> Void)? = nil) throws -> BeautyMasks {
        let clock = ContinuousClock()
        var timings = BeautyAnalysisTimings()
        try Task.checkCancellation()
        let preparationStart = clock.now
        guard let source = MaskBitmapSource(image: image, maximumDimension: 1_024) else { return .empty }
        timings.imagePreparationMS = milliseconds(preparationStart.duration(to: clock.now))
        let visionStart = clock.now
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        let request = VNDetectFaceLandmarksRequest()
        try handler.perform([request])
        let observations = request.results ?? []
        timings.visionFaceAndLandmarksMS = milliseconds(visionStart.duration(to: clock.now))
        try Task.checkCancellation()
        let geometryStart = clock.now
        let size = CGSize(width: source.width, height: source.height)
        let faces: [BeautyMaskFace] = observations.compactMap { observation in
            guard let landmarks = observation.landmarks else { return nil }
            let normalized = observation.boundingBox
            let box = CGRect(x: normalized.minX * size.width, y: normalized.minY * size.height,
                             width: normalized.width * size.width, height: normalized.height * size.height)
            let reliableLeft = (landmarks.leftEye?.pointCount ?? 0) >= 3
            let reliableRight = (landmarks.rightEye?.pointCount ?? 0) >= 3
            guard box.width >= 24, box.height >= 24,
                  reliableLeft || reliableRight else { return nil }
            func points(_ region: VNFaceLandmarkRegion2D?) -> [CGPoint] {
                guard let region else { return [] }
                return region.normalizedPoints.map { CGPoint(x: box.minX + $0.x * box.width,
                                                              y: box.minY + $0.y * box.height) }
            }
            var left = bounds(points(landmarks.leftEye))
            var right = bounds(points(landmarks.rightEye))
            var leftEyePoints = points(landmarks.leftEye)
            var rightEyePoints = points(landmarks.rightEye)
            var leftBrow = bounds(points(landmarks.leftEyebrow))
            var rightBrow = bounds(points(landmarks.rightEyebrow))
            var leftBrowPoints = points(landmarks.leftEyebrow)
            var rightBrowPoints = points(landmarks.rightEyebrow)
            let outerLipPoints = points(landmarks.outerLips)
            let lips = bounds(outerLipPoints)
            let inner = points(landmarks.innerLips)
            let nose = bounds(points(landmarks.nose))
            // Vision may synthesize bilateral eye landmarks on a true profile.
            // At a strong yaw, retain only the eye geometrically separated from
            // the projected nose; the eye next to the nose is usually occluded.
            if abs(observation.yaw?.doubleValue ?? 0) >= 1.05,
               let leftRect = left, let rightRect = right, let nose {
                let leftSeparation = abs(leftRect.midX - nose.midX)
                let rightSeparation = abs(rightRect.midX - nose.midX)
                if leftSeparation >= rightSeparation {
                    right = nil; rightEyePoints = []
                    rightBrow = nil; rightBrowPoints = []
                } else {
                    left = nil; leftEyePoints = []
                    leftBrow = nil; leftBrowPoints = []
                }
            }
            let eyeCenters = [left, right].compactMap { $0.map { CGPoint(x: $0.midX, y: $0.midY) } }
            let eyeCenter = CGPoint(x: eyeCenters.map(\.x).reduce(0, +) / CGFloat(eyeCenters.count),
                                    y: eyeCenters.map(\.y).reduce(0, +) / CGFloat(eyeCenters.count))
            let noseCenter = nose.map { CGPoint(x: $0.midX, y: $0.midY) }
            let dx = (noseCenter?.x ?? eyeCenter.x) - eyeCenter.x
            let dy = (noseCenter?.y ?? eyeCenter.y - box.height * 0.20) - eyeCenter.y
            let length = max(0.001, hypot(dx, dy))
            let down = CGPoint(x: dx / length, y: dy / length)
            let cheek = cheekChromaticity(source, box: box, eyes: [left, right], lips: lips)
            let toothRegion: [CGPoint]
            if landmarks.confidence >= 0.5, inner.count >= 6,
               let innerBounds = bounds(inner), let lips,
               innerBounds.height > box.height * 0.027,
               innerBounds.width > 0, lips.width > innerBounds.width {
                let horizontalScale = min(1.8, lips.width * 0.82 / innerBounds.width)
                let verticalScale = min(1.45, lips.height * 0.55 / innerBounds.height)
                toothRegion = inner.map { point in
                    CGPoint(x: innerBounds.midX + (point.x - innerBounds.midX) * horizontalScale,
                            y: innerBounds.midY + (point.y - innerBounds.midY) * verticalScale)
                }
            } else { toothRegion = [] }
            return BeautyMaskFace(box: box, contour: points(landmarks.faceContour),
                        leftEye: left, rightEye: right,
                        leftEyePoints: leftEyePoints,
                        rightEyePoints: rightEyePoints,
                        leftBrow: leftBrow, rightBrow: rightBrow,
                        leftBrowPoints: leftBrowPoints,
                        rightBrowPoints: rightBrowPoints,
                        lips: lips, outerLipPoints: outerLipPoints,
                        innerLipPoints: inner, toothRegion: toothRegion,
                        nose: nose, down: down, cheekColor: cheek)
        }
        guard !faces.isEmpty else { return .empty }
        timings.geometryAndColorSamplingMS = milliseconds(geometryStart.duration(to: clock.now))

        let output = try BeautyMaskPipeline.generate(source: source, faces: faces,
            diagnostics: diagnostics != nil, profile: timing != nil,
            timings: &timings)
        let v2 = BeautyV2MaskAnalyzer.generate(source: source, faces: faces)
        let width = faces.map(\.box.width).sorted()[faces.count / 2] / CGFloat(source.width)
        let result = BeautyMasks(faceCount: faces.count, faceWidthFraction: width,
            faceRects: faces.map { CGRect(x: $0.box.minX / CGFloat(source.width),
                                          y: $0.box.minY / CGFloat(source.height),
                                          width: $0.box.width / CGFloat(source.width),
                                          height: $0.box.height / CGFloat(source.height)) },
            skin: output.skin, eyes: output.eyes, underEyes: output.underEyes,
            teeth: output.teeth, blemishes: output.blemishes, v2: v2)
        if let diagnostic = output.diagnostics { diagnostics?(diagnostic) }
        timing?(timings)
        return result
    }

    private static func cheekChromaticity(_ source: MaskBitmapSource, box: CGRect,
                                           eyes: [CGRect?], lips: CGRect?) -> (cb: Float, cr: Float)? {
        let eyeY = eyes.compactMap { $0?.minY }.min() ?? box.midY
        let mouthY = lips?.maxY ?? box.minY + box.height * 0.24
        let low = max(mouthY + box.height * 0.04, box.minY + box.height * 0.31)
        let high = min(eyeY - box.height * 0.04, box.minY + box.height * 0.60)
        guard low < high else { return nil }
        var cb: Float = 0, cr: Float = 0, count: Float = 0
        for y in stride(from: max(0, Int(low)), to: min(source.height, Int(high)), by: 3) {
            for x in stride(from: max(0, Int(box.minX + box.width * 0.19)),
                            to: min(source.width, Int(box.maxX - box.width * 0.19)), by: 3) {
                let (r, g, b) = sceneRGB(source, x: x, y: y)
                guard max(r, max(g, b)) > 0.025 else { continue }
                let color = chromaticity(r, g, b)
                cb += color.cb; cr += color.cr; count += 1
            }
        }
        return count >= 8 ? (cb / count, cr / count) : nil
    }

    private static func chromaticity(_ r: Float, _ g: Float, _ b: Float) -> (cb: Float, cr: Float) {
        (0.5 - 0.168736 * r - 0.331264 * g + 0.5 * b,
         0.5 + 0.5 * r - 0.418688 * g - 0.081312 * b)
    }
    private static func sceneRGB(_ source: MaskBitmapSource, x: Int, y: Int)
        -> (red: Float, green: Float, blue: Float) {
        // MaskBitmapSource's byte rows are top-first. Vision and CIImage use a
        // lower-left origin, so a landmark-space y must be mirrored for color.
        source.rgb(x: x, y: source.height - 1 - y)
    }
    private static func bounds(_ points: [CGPoint]) -> CGRect? {
        guard let first = points.first else { return nil }
        var minX = first.x, maxX = first.x, minY = first.y, maxY = first.y
        for point in points.dropFirst() {
            minX = min(minX, point.x); maxX = max(maxX, point.x)
            minY = min(minY, point.y); maxY = max(maxY, point.y)
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
    private static func milliseconds(_ duration: Duration) -> Double {
        Double(duration.components.seconds) * 1_000 + Double(duration.components.attoseconds) / 1e15
    }
}
