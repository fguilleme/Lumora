import CoreGraphics
import CoreImage
import Foundation

/// Analysis-space geometry. All coordinates use the same lower-left origin as
/// Vision and Core Image; only MaskBitmapSource's byte access is top-first.
struct BeautyMaskFace {
    let box: CGRect
    let contour: [CGPoint]
    let leftEye: CGRect?
    let rightEye: CGRect?
    let leftEyePoints: [CGPoint]
    let rightEyePoints: [CGPoint]
    let leftBrow: CGRect?
    let rightBrow: CGRect?
    let leftBrowPoints: [CGPoint]
    let rightBrowPoints: [CGPoint]
    let lips: CGRect?
    let outerLipPoints: [CGPoint]
    let innerLipPoints: [CGPoint]
    let toothRegion: [CGPoint]
    let nose: CGRect?
    let down: CGPoint
    let cheekColor: (cb: Float, cr: Float)?
}

struct BeautyMaskDiagnostics {
    let skinBeforeDetailProtection: CGImage?
    let detailProtection: CGImage?
    let faceRegion: CGImage?
    let featureExclusions: CGImage?
    let blemishStages: [String: CGImage]
    let blemishComponents: [BeautyBlemishComponentDiagnostic]
}

/// One GPU/Core Image analysis pass per source/geometry cache miss. Sliders use
/// the cached CGImage mattes, so no analysis or GPU readback occurs per slider.
enum BeautyMaskPipeline {
    private static let workingSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    private static let maskSpace = CGColorSpace(name: CGColorSpace.linearGray)!
    private static let context = CIContext(options: [
        .workingColorSpace: workingSpace,
        .outputColorSpace: workingSpace
    ])

    private static let skinKernel = CreativeMetal.compile("""
    [[ stitchable ]] float4 beautySkinMask(coreimage::sample_t source,
        coreimage::sample_t face, coreimage::sample_t excluded,
        coreimage::sample_t broad, coreimage::sample_t edges, float3 cheek) {
        float3 rgb = unpremultiply(source).rgb;
        float cb = 0.5 - 0.168736 * rgb.r - 0.331264 * rgb.g + 0.5 * rgb.b;
        float cr = 0.5 + 0.5 * rgb.r - 0.418688 * rgb.g - 0.081312 * rgb.b;
        float distance = length(float2(cb - cheek.x, cr - cheek.y));
        // Keep a continuous floor for naturally shaded skin. Geometry and
        // detail protection still reject background/strong non-skin structure.
        float confidence = cheek.z > 0.5 ? mix(0.38, 1.0,
            1.0 - smoothstep(0.08, 0.25, distance)) : 0.0;
        float shape = clamp(unpremultiply(face).r, 0.0, 1.0);
        float exclusions = clamp(unpremultiply(excluded).r, 0.0, 1.0);
        float base = shape * (1.0 - exclusions) * confidence;
        float3 low = unpremultiply(broad).rgb;
        float hf = abs(dot(rgb - low, float3(0.2126, 0.7152, 0.0722)));
        float edge = dot(unpremultiply(edges).rgb, float3(0.2126, 0.7152, 0.0722));
        float risk = max(smoothstep(0.012, 0.085, hf),
                         smoothstep(0.025, 0.16, edge));
        float protection = 1.0 - 0.85 * risk;
        return float4(base * protection, base, protection, 1.0);
    }
    """)
    private static let redChannel = CreativeMetal.compile("""
    [[ stitchable ]] float4 beautyMaskRed(coreimage::sample_t input) {
        float v = unpremultiply(input).r;
        return float4(v, v, v, 1.0);
    }
    """)
    private static let greenChannel = CreativeMetal.compile("""
    [[ stitchable ]] float4 beautyMaskGreen(coreimage::sample_t input) {
        float v = unpremultiply(input).g;
        return float4(v, v, v, 1.0);
    }
    """)
    private static let blueChannel = CreativeMetal.compile("""
    [[ stitchable ]] float4 beautyMaskBlue(coreimage::sample_t input) {
        float v = unpremultiply(input).b;
        return float4(v, v, v, 1.0);
    }
    """)
    private static let linearMaskEncoding = CreativeMetal.compile("""
    [[ stitchable ]] float4 beautyLinearMaskEncoding(coreimage::sample_t input) {
        float v = clamp(unpremultiply(input).r, 0.0, 1.0);
        float encoded = v <= 0.0031308 ? 12.92 * v
                      : 1.055 * pow(v, 1.0 / 2.4) - 0.055;
        return float4(encoded, encoded, encoded, 1.0);
    }
    """)
    private static let maskProduct = CreativeMetal.compile("""
    [[ stitchable ]] float4 beautyMaskProduct(coreimage::sample_t a,
        coreimage::sample_t b) {
        float v = clamp(unpremultiply(a).r * unpremultiply(b).r, 0.0, 1.0);
        return float4(v, v, v, 1.0);
    }
    """)
    private static let teethKernel = CreativeMetal.compile("""
    [[ stitchable ]] float4 beautyTeethMask(coreimage::sample_t source,
        coreimage::sample_t opening) {
        float3 c = unpremultiply(source).rgb;
        float brightness = max(c.r, max(c.g, c.b));
        float saturation = brightness > 0.001 ?
            (brightness - min(c.r, min(c.g, c.b))) / brightness : 1.0;
        float tooth = smoothstep(0.32, 0.54, brightness)
                    * (1.0 - smoothstep(0.20, 0.36, saturation));
        float v = clamp(unpremultiply(opening).r * tooth, 0.0, 1.0);
        return float4(v, v, v, 1.0);
    }
    """)
    private static let blemishCandidate = CreativeMetal.compile("""
    [[ stitchable ]] float4 beautyBlemishCandidate(coreimage::sample_t fine,
        coreimage::sample_t surround, coreimage::sample_t broad) {
        float3 c = unpremultiply(fine).rgb;
        float3 s = unpremultiply(surround).rgb;
        float3 b = unpremultiply(broad).rgb;
        float yc = dot(c, float3(0.2126, 0.7152, 0.0722));
        float ys = dot(s, float3(0.2126, 0.7152, 0.0722));
        float yb = dot(b, float3(0.2126, 0.7152, 0.0722));
        // Two spatial scales distinguish a localized spot from broad shading.
        float compact = 1.0 - smoothstep(0.040, 0.13, abs(ys - yb));
        float redFine = (c.r - 0.5 * (c.g + c.b))
            - (s.r - 0.5 * (s.g + s.b));
        float redWide = (c.r - 0.5 * (c.g + c.b))
            - (b.r - 0.5 * (b.g + b.b));
        float red = smoothstep(0.012, 0.055, max(redFine, redWide * 0.85));
        float dark = smoothstep(0.025, 0.105, max(ys - yc, yb - yc));
        float light = smoothstep(0.035, 0.125, max(yc - ys, yc - yb));
        // Green stores dark-spot density for the repeated-freckle guard.
        float candidate = max(red, max(dark * 0.85, light * 0.55)) * compact;
        return float4(candidate, dark * compact, red, 1.0);
    }
    """)
    private static let blemishKernel = CreativeMetal.compile("""
    [[ stitchable ]] float4 beautyBlemishMask(coreimage::sample_t candidate,
        coreimage::sample_t repeated, coreimage::sample_t skin) {
        float4 c = unpremultiply(candidate);
        float density = clamp(unpremultiply(repeated).g, 0.0, 1.0);
        // Numerous similar dark spots are more likely freckles than isolated
        // blemishes. Red lesions remain eligible in a freckled area.
        float freckleGuard = mix(1.0, 0.06,
            smoothstep(0.015, 0.060, density));
        float skinWeight = clamp(unpremultiply(skin).r, 0.0, 1.0);
        float evidence = c.r * freckleGuard * pow(skinWeight, 0.28);
        float v = smoothstep(0.025, 0.21, evidence);
        return float4(v, v, v, 1.0);
    }
    """)
    // Diagnostic-only decomposition of the detector. These kernels do not
    // participate in production mask construction.
    private static let blemishSignals = CreativeMetal.compile("""
    [[ stitchable ]] float4 beautyBlemishSignals(coreimage::sample_t fine,
        coreimage::sample_t surround, coreimage::sample_t broad) {
        float3 c = unpremultiply(fine).rgb;
        float3 s = unpremultiply(surround).rgb;
        float3 b = unpremultiply(broad).rgb;
        float yc = dot(c, float3(0.2126, 0.7152, 0.0722));
        float ys = dot(s, float3(0.2126, 0.7152, 0.0722));
        float yb = dot(b, float3(0.2126, 0.7152, 0.0722));
        float redFine = (c.r - 0.5 * (c.g + c.b)) - (s.r - 0.5 * (s.g + s.b));
        float redWide = (c.r - 0.5 * (c.g + c.b)) - (b.r - 0.5 * (b.g + b.b));
        float red = smoothstep(0.012, 0.055, max(redFine, redWide * 0.85));
        float dark = smoothstep(0.025, 0.105, max(ys - yc, yb - yc));
        float light = smoothstep(0.035, 0.125, max(yc - ys, yc - yb));
        float compact = 1.0 - smoothstep(0.040, 0.13, abs(ys - yb));
        return float4(red, dark, light, compact);
    }
    """)
    private static let blemishGuard = CreativeMetal.compile("""
    [[ stitchable ]] float4 beautyBlemishGuard(coreimage::sample_t repeated,
        coreimage::sample_t candidate, coreimage::sample_t skin) {
        float density = clamp(unpremultiply(repeated).g, 0.0, 1.0);
        float guard = mix(1.0, 0.06, smoothstep(0.015, 0.060, density));
        float evidence = unpremultiply(candidate).r * guard
            * pow(clamp(unpremultiply(skin).r, 0.0, 1.0), 0.28);
        return float4(1.0 - guard, evidence, density, 1.0);
    }
    """)

    struct Output {
        let skin: CGImage?
        let eyes: CGImage?
        let underEyes: CGImage?
        let teeth: CGImage?
        let blemishes: CGImage?
        let diagnostics: BeautyMaskDiagnostics?
    }

    static func generate(source: MaskBitmapSource, faces: [BeautyMaskFace],
                         diagnostics: Bool, profile: Bool,
                         timings: inout BeautyAnalysisTimings) throws -> Output {
        let clock = ContinuousClock()
        let extent = CGRect(x: 0, y: 0, width: source.width, height: source.height)
        guard let colorImage = sourceImage(source), let skinKernel,
              let redChannel, let maskProduct, let teethKernel,
              let blemishCandidate, let blemishKernel else {
            throw PhotoError.renderFailed
        }
        let color = CIImage(cgImage: colorImage)

        let shapeStart = clock.now
        let shapes = faces.compactMap { face -> CIImage? in
            guard let image = grayCanvas(extent, draw: { ctx in
                ctx.addPath(facePath(face))
                ctx.fillPath()
            }) else { return nil }
            return soften(CIImage(cgImage: image), radius: max(2, face.box.width * 0.015), extent: extent)
        }
        guard shapes.count == faces.count else { throw PhotoError.renderFailed }
        if profile { for shape in shapes { _ = materialize(shape, extent: extent) } }
        timings.geometryRasterMS = milliseconds(shapeStart.duration(to: clock.now))
        try Task.checkCancellation()

        let exclusionsStart = clock.now
        let exclusions = faces.compactMap { face -> CIImage? in
            guard let image = grayCanvas(extent, draw: { ctx in drawExclusions(face, in: ctx) })
            else { return nil }
            return soften(CIImage(cgImage: image), radius: max(1.5, face.box.width * 0.007), extent: extent)
        }
        guard exclusions.count == faces.count,
              let eyesBitmap = grayCanvas(extent, draw: { ctx in
                  for face in faces { drawEyes(face, in: ctx) }
              }),
              let underBitmap = grayCanvas(extent, draw: { ctx in
                  for face in faces { drawUnderEyes(face, in: ctx) }
              }),
              let teethBitmap = grayCanvas(extent, draw: { ctx in
                  for face in faces { drawTeeth(face, in: ctx) }
              }) else { throw PhotoError.renderFailed }
        let eyesImage = soften(CIImage(cgImage: eyesBitmap), radius: 1.7, extent: extent)
        let underImage = soften(CIImage(cgImage: underBitmap), radius: 2.0, extent: extent)
        let opening = CIImage(cgImage: teethBitmap)
        if profile {
            for excluded in exclusions { _ = materialize(excluded, extent: extent) }
            _ = materialize(eyesImage, extent: extent)
            _ = materialize(underImage, extent: extent)
            _ = materialize(opening, extent: extent)
        }
        timings.featureExclusionsMS = milliseconds(exclusionsStart.duration(to: clock.now))


        let detailStart = clock.now
        let broad = color.clampedToExtent().applyingFilter("CIGaussianBlur", parameters: [
            kCIInputRadiusKey: 2.0]).cropped(to: extent)
        // Expand detected high-frequency structure a few pixels so the gaps
        // between beard hairs and around glasses frames are protected too.
        let edges = color.applyingFilter("CIEdges", parameters: [kCIInputIntensityKey: 1.0])
            .applyingFilter("CIMorphologyMaximum", parameters: [kCIInputRadiusKey: 3.0])
            .clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 2.0])
            .cropped(to: extent)
        if profile {
            _ = materialize(broad, extent: extent)
            _ = materialize(edges, extent: extent)
        }
        timings.detailPreparationMS = milliseconds(detailStart.duration(to: clock.now))

        let skinStart = clock.now
        var skinParts: [CIImage] = []
        for (index, face) in faces.enumerated() {
            let cheek = face.cheekColor
            guard let part = skinKernel.apply(extent: extent, arguments: [
                color, shapes[index], exclusions[index], broad, edges,
                CIVector(x: CGFloat(cheek?.cb ?? 0.5), y: CGFloat(cheek?.cr ?? 0.5),
                         z: cheek == nil ? 0 : 1)
            ]) else { throw PhotoError.renderFailed }
            skinParts.append(part)
        }
        let combined = skinParts.dropFirst().reduce(skinParts[0]) {
            $1.applyingFilter("CIMaximumCompositing", parameters: [kCIInputBackgroundImageKey: $0])
        }.cropped(to: extent)
        let unprotected = greenChannel?.apply(extent: extent, arguments: [combined])
        let protection = blueChannel?.apply(extent: extent, arguments: [combined])
        guard let skinImage = redChannel.apply(extent: extent, arguments: [combined])
        else { throw PhotoError.renderFailed }
        let skinCG = materialize(skinImage, extent: extent)
        timings.skinRasterMS = milliseconds(skinStart.duration(to: clock.now))
        guard let skinCG else { throw PhotoError.renderFailed }
        try Task.checkCancellation()


        let compositionStart = clock.now
        guard let underFinal = maskProduct.apply(extent: extent,
                  arguments: [underImage, skinImage]),
              let teethFinal = teethKernel.apply(extent: extent,
                  arguments: [color, opening]) else { throw PhotoError.renderFailed }
        let eyesCG = materialize(eyesImage, extent: extent)
        let underCG = materialize(underFinal, extent: extent)
        let teethCG = materialize(teethFinal, extent: extent)
        timings.finalMaskCompositionMS = milliseconds(compositionStart.duration(to: clock.now))

        let blemishStart = clock.now
        let clamped = color.clampedToExtent()
        let fine = clamped.applyingFilter("CIGaussianBlur", parameters: [
            kCIInputRadiusKey: 1.1]).cropped(to: extent)
        let surround = clamped.applyingFilter("CIGaussianBlur", parameters: [
            kCIInputRadiusKey: 4.0]).cropped(to: extent)
        let wide = clamped.applyingFilter("CIGaussianBlur", parameters: [
            kCIInputRadiusKey: 11.0]).cropped(to: extent)
        let featureImage = exclusions.dropFirst().reduce(exclusions[0]) {
            $1.applyingFilter("CIMaximumCompositing",
                parameters: [kCIInputBackgroundImageKey: $0])
        }.cropped(to: extent)
        guard let fineBitmap = analysisBitmap(fine, extent: extent),
              let surroundBitmap = analysisBitmap(surround, extent: extent),
              let wideBitmap = analysisBitmap(wide, extent: extent),
              let featureCG = materialize(featureImage, extent: extent),
              let result = BeautyBlemishDetector.generate(source: source,
                  fine: fineBitmap, surround: surroundBitmap, broad: wideBitmap,
                  skin: skinCG, features: featureCG,
                  faceWidth: faces.map(\.box.width).sorted()[faces.count / 2],
                  diagnostics: diagnostics) else { throw PhotoError.renderFailed }
        let blemishCG = result.matte
        timings.blemishesMS = milliseconds(blemishStart.duration(to: clock.now))
        timings.skinEyesUnderEyesTeethMS = timings.geometryRasterMS + timings.featureExclusionsMS
            + timings.detailPreparationMS + timings.skinRasterMS + timings.finalMaskCompositionMS
        timings.cgImageConversionsMS = timings.finalMaskCompositionMS
        var blemishStages: [String: CGImage] = [:]
        if diagnostics {
            let candidates = blemishCandidate.apply(extent: extent,
                arguments: [fine, surround, wide])
            let repeated = candidates?.clampedToExtent().applyingFilter("CIGaussianBlur",
                parameters: [kCIInputRadiusKey: 34.0]).cropped(to: extent)
            func save(_ name: String, _ image: CIImage?) {
                if let image, let cg = materialize(image, extent: extent) {
                    blemishStages[name] = cg
                }
            }
            save("skin_confidence", unprotected)
            save("edge_detail_protection", protection)
            if let candidates {
                save("multiscale_candidate", redChannel.apply(extent: extent, arguments: [candidates]))
            }
            blemishStages["final_confidence"] = blemishCG
            if let signals = blemishSignals?.apply(extent: extent,
                arguments: [fine, surround, wide]) {
                save("raw_chroma_anomaly", redChannel.apply(extent: extent, arguments: [signals]))
                save("raw_dark_anomaly", greenChannel?.apply(extent: extent, arguments: [signals]))
                save("raw_light_anomaly", blueChannel?.apply(extent: extent, arguments: [signals]))
            }
            if let candidates, let repeated,
               let guardImage = blemishGuard?.apply(extent: extent,
                arguments: [repeated, candidates, skinImage]) {
                save("repetition_suppression", redChannel.apply(extent: extent, arguments: [guardImage]))
                save("prethreshold_evidence", greenChannel?.apply(extent: extent, arguments: [guardImage]))
                save("repeated_dark_density", blueChannel?.apply(extent: extent, arguments: [guardImage]))
            }
            blemishStages.merge(result.stages) { _, new in new }
        }
        let diagnostic = diagnostics ? BeautyMaskDiagnostics(
            skinBeforeDetailProtection: unprotected.flatMap { materialize($0, extent: extent) },
            detailProtection: protection.flatMap { materialize($0, extent: extent) },
            faceRegion: shapes.first.flatMap { materialize($0, extent: extent) },
            featureExclusions: exclusions.first.flatMap { materialize($0, extent: extent) },
            blemishStages: blemishStages,
            blemishComponents: result.components) : nil
        return Output(skin: skinCG, eyes: eyesCG, underEyes: underCG,
                      teeth: teethCG, blemishes: blemishCG, diagnostics: diagnostic)
    }

    private static func sourceImage(_ source: MaskBitmapSource) -> CGImage? {
        guard let provider = CGDataProvider(data: Data(source.rgba) as CFData) else { return nil }
        return CGImage(width: source.width, height: source.height,
                       bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: source.rowBytes,
                       space: workingSpace, bitmapInfo: CGBitmapInfo(rawValue:
                           CGImageAlphaInfo.premultipliedLast.rawValue |
                           CGBitmapInfo.byteOrder32Big.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: true,
                       intent: .defaultIntent)
    }

    private static func analysisBitmap(_ image: CIImage,
                                       extent: CGRect) -> MaskBitmapSource? {
        guard let cg = context.createCGImage(image, from: extent,
            format: .RGBA8, colorSpace: workingSpace) else { return nil }
        return MaskBitmapSource(image: cg, maximumDimension: 1_024)
    }

    private static func grayCanvas(_ extent: CGRect,
                                   draw: (CGContext) -> Void) -> CGImage? {
        guard let ctx = CGContext(data: nil, width: Int(extent.width), height: Int(extent.height),
                                  bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceGray(),
                                  bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return nil }
        ctx.setFillColor(gray: 0, alpha: 1)
        ctx.fill(extent)
        ctx.setFillColor(gray: 1, alpha: 1)
        ctx.setShouldAntialias(true)
        draw(ctx)
        return ctx.makeImage()
    }

    private static func facePath(_ face: BeautyMaskFace) -> CGPath {
        let box = face.box
        guard face.contour.count >= 6 else {
            return CGPath(roundedRect: box.insetBy(dx: box.width * 0.08,
                                                    dy: box.height * 0.08),
                          cornerWidth: box.width * 0.22,
                          cornerHeight: box.height * 0.20, transform: nil)
        }
        let browTop = [face.leftBrow?.maxY, face.rightBrow?.maxY].compactMap { $0 }.max()
            ?? [face.leftEye?.maxY, face.rightEye?.maxY].compactMap { $0 }.max()
            ?? box.minY + box.height * 0.72
        let top = min(box.maxY - box.height * 0.08,
                      browTop + (box.maxY - browTop) * 0.65)
        let center = CGPoint(x: box.midX, y: box.midY)
        let points = face.contour.map { point in
            CGPoint(x: center.x + (point.x - center.x) * 0.972,
                    y: center.y + (point.y - center.y) * 0.98)
        }
        let first = points[0], last = points[points.count - 1]
        let path = CGMutablePath()
        path.move(to: first)
        for point in points.dropFirst() { path.addLine(to: point) }
        let span = first.x - last.x
        let apex = CGPoint(x: box.midX, y: top)
        path.addCurve(to: apex,
                      control1: CGPoint(x: last.x + span * 0.10,
                                        y: last.y + (top - last.y) * 0.72),
                      control2: CGPoint(x: apex.x - span * 0.12, y: top))
        path.addCurve(to: first,
                      control1: CGPoint(x: apex.x + span * 0.12, y: top),
                      control2: CGPoint(x: first.x - span * 0.10,
                                        y: first.y + (top - first.y) * 0.72))
        path.closeSubpath()
        return path
    }

    private static func drawExclusions(_ face: BeautyMaskFace, in ctx: CGContext) {
        let box = face.box
        for eye in [face.leftEyePoints, face.rightEyePoints] where eye.count >= 3 {
            let center = CGPoint(x: eye.map(\.x).reduce(0, +) / CGFloat(eye.count),
                                 y: eye.map(\.y).reduce(0, +) / CGFloat(eye.count))
            let path = CGMutablePath()
            path.move(to: CGPoint(x: center.x + (eye[0].x - center.x) * 1.16,
                                  y: center.y + (eye[0].y - center.y) * 1.25))
            for point in eye.dropFirst() {
                path.addLine(to: CGPoint(x: center.x + (point.x - center.x) * 1.16,
                                         y: center.y + (point.y - center.y) * 1.25))
            }
            path.closeSubpath()
            ctx.addPath(path)
            ctx.fillPath()
        }
        for brow in [face.leftBrowPoints, face.rightBrowPoints] where brow.count >= 2 {
            ctx.setStrokeColor(gray: 1, alpha: 1)
            ctx.setLineWidth(max(2, box.height * 0.037))
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            ctx.move(to: brow[0])
            for point in brow.dropFirst() { ctx.addLine(to: point) }
            ctx.strokePath()
        }
        if let lips = face.lips {
            ctx.fillEllipse(in: lips.insetBy(dx: -lips.width * 0.12,
                                             dy: -box.height * 0.04))
        }
        if let nose = face.nose {
            let nostrils = CGRect(x: nose.minX - nose.width * 0.15,
                                  y: nose.minY - nose.height * 0.15,
                                  width: nose.width * 1.3, height: nose.height * 0.42)
            ctx.fillEllipse(in: nostrils)
        }
    }

    private static func drawEyes(_ face: BeautyMaskFace, in ctx: CGContext) {
        for eye in [face.leftEye, face.rightEye].compactMap({ $0 }) {
            ctx.fillEllipse(in: eye.insetBy(dx: -eye.width * 0.18,
                                            dy: -eye.width * 0.10))
        }
    }

    private static func drawUnderEyes(_ face: BeautyMaskFace, in ctx: CGContext) {
        for eye in [face.leftEye, face.rightEye].compactMap({ $0 }) {
            let center = CGPoint(x: eye.midX + face.down.x * face.box.height * 0.11,
                                 y: eye.midY + face.down.y * face.box.height * 0.11)
            let tangent = CGPoint(x: -face.down.y, y: face.down.x)
            var transform = CGAffineTransform(translationX: center.x, y: center.y)
                .rotated(by: atan2(tangent.y, tangent.x))
            let rx = max(1, eye.width * 0.82)
            let ry = max(1, face.box.height * 0.085)
            ctx.addPath(CGPath(ellipseIn: CGRect(x: -rx, y: -ry,
                                                width: rx * 2, height: ry * 2),
                               transform: &transform))
            ctx.fillPath()
        }
    }

    private static func drawTeeth(_ face: BeautyMaskFace, in ctx: CGContext) {
        guard let first = face.toothRegion.first else { return }
        let path = CGMutablePath()
        path.move(to: first)
        for point in face.toothRegion.dropFirst() { path.addLine(to: point) }
        path.closeSubpath()
        ctx.addPath(path)
        ctx.fillPath()
    }

    private static func soften(_ input: CIImage, radius: CGFloat,
                               extent: CGRect) -> CIImage {
        input.clampedToExtent().applyingFilter("CIGaussianBlur", parameters: [
            kCIInputRadiusKey: radius]).cropped(to: extent)
    }

    private static func materialize(_ image: CIImage, extent: CGRect) -> CGImage? {
        // The analysis context evaluates kernels in sRGB. Encode the desired
        // linear mask weight before CI converts to linearGray; this preserves
        // the numerical weight read by BeautyRenderer's linear pipeline.
        guard let encoded = linearMaskEncoding?.apply(extent: extent,
                                                       arguments: [image]) else { return nil }
        return context.createCGImage(encoded, from: extent, format: .L8,
                              colorSpace: maskSpace)
    }

    private static func milliseconds(_ duration: Duration) -> Double {
        Double(duration.components.seconds) * 1_000
            + Double(duration.components.attoseconds) / 1e15
    }
}
