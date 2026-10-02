import CoreImage
import CoreImage.CIFilterBuiltins

enum MaskRenderer {
    static func apply(_ input: CIImage, masks: [LocalMask]) throws -> CIImage {
        var image = input
        for mask in masks.prefix(16).map(\.validated)
            where mask.isVisible && mask.opacity > 0 && !mask.adjustments.isIdentity {
            let matte = try makeMask(mask, extent: image.extent)
            let adjusted = try applyAdjustments(image, state: mask.adjustments)
            let blend = CIFilter.blendWithMask()
            blend.inputImage = adjusted
            blend.backgroundImage = image
            blend.maskImage = matte
            guard let output = blend.outputImage else { throw PhotoError.renderFailed }
            image = output.cropped(to: image.extent)
        }
        return image
    }

    static func makeMask(_ mask: LocalMask, extent: CGRect) throws -> CIImage {
        var result = CIImage(color: .black).cropped(to: extent)
        for component in mask.components {
            // An additive brush eraser edits the accumulated mask, including preceding
            // Vision and gradient components. A subtractive brush still uses its own
            // erased paint as the shape to subtract.
            if case .brush(let rawBrush) = component.shape, component.operation == .add {
                let brush = rawBrush.validated
                let strength = brush.opacity / 100 * brush.flow / 100
                let painted = try brushImage(brush, extent: extent, includeErasing: false)
                result = try maximum(painted, result, extent: extent)
                result = try compositeBrushStrokes(brush.eraseStrokes, onto: result, erasing: true,
                    sizes: brush.eraseStrokeSizes, fallbackSize: brush.size,
                    feather: brush.feather, strength: strength, extent: extent)
                continue
            }
            let shape = try shapeImage(component.shape, extent: extent)
            if component.operation == .add {
                result = try maximum(shape, result, extent: extent)
            } else {
                let invert = CIFilter.colorInvert()
                invert.inputImage = shape
                let minimum = CIFilter.minimumCompositing()
                minimum.inputImage = invert.outputImage; minimum.backgroundImage = result
                guard let output = minimum.outputImage else { throw PhotoError.renderFailed }
                result = output.cropped(to: extent)
            }
        }
        if mask.inverted {
            let invert = CIFilter.colorInvert(); invert.inputImage = result
            guard let output = invert.outputImage else { throw PhotoError.renderFailed }
            result = output.cropped(to: extent)
        }
        if mask.opacity < 100 {
            let factor = CGFloat(mask.opacity / 100)
            let opacity = CIFilter.colorMatrix()
            opacity.inputImage = result
            opacity.rVector = CIVector(x: factor, y: 0, z: 0, w: 0)
            opacity.gVector = CIVector(x: 0, y: factor, z: 0, w: 0)
            opacity.bVector = CIVector(x: 0, y: 0, z: factor, w: 0)
            guard let output = opacity.outputImage else { throw PhotoError.renderFailed }
            result = output.cropped(to: extent)
        }
        return result
    }

    private static func maximum(_ shape: CIImage, _ background: CIImage, extent: CGRect) throws -> CIImage {
        let maximum = CIFilter.maximumCompositing()
        maximum.inputImage = shape; maximum.backgroundImage = background
        guard let output = maximum.outputImage else { throw PhotoError.renderFailed }
        return output.cropped(to: extent)
    }

    /// Produces the editor visualization from the exact composed matte. The matte luminance
    /// becomes red alpha, so brush softness, gradient feathering, subtraction and inversion
    /// are represented exactly as they affect the image.
    static func makeRedOverlay(_ mask: LocalMask, extent: CGRect, opacity: CGFloat = 0.55) throws -> CIImage {
        let matte = try makeMask(mask, extent: extent)
        let matrix = CIFilter.colorMatrix()
        matrix.inputImage = matte
        matrix.rVector = CIVector(x: 0, y: 0, z: 0, w: 0)
        matrix.gVector = CIVector(x: 0, y: 0, z: 0, w: 0)
        matrix.bVector = CIVector(x: 0, y: 0, z: 0, w: 0)
        matrix.aVector = CIVector(x: max(0, min(1, opacity)), y: 0, z: 0, w: 0)
        matrix.biasVector = CIVector(x: 1, y: 0, z: 0, w: 0)
        guard let output = matrix.outputImage else { throw PhotoError.renderFailed }
        return output.cropped(to: extent)
    }

    private static func shapeImage(_ shape: MaskShape, extent: CGRect) throws -> CIImage {
        switch shape {
        case .brush(let brush): return try brushImage(brush.validated, extent: extent)
        case .linear(let linear):
            let value = linear.validated
            let center = CGPoint(x: extent.minX + extent.width * value.center.x,
                                 y: extent.minY + extent.height * (1 - value.center.y))
            let radians = CGFloat(value.angle) * .pi / 180
            let distance = hypot(extent.width, extent.height) * CGFloat(0.08 + value.feather / 100 * 0.42)
            let vector = CGVector(dx: cos(radians) * distance / 2, dy: sin(radians) * distance / 2)
            let gradient = CIFilter.linearGradient()
            gradient.point0 = CGPoint(x: center.x - vector.dx, y: center.y - vector.dy)
            gradient.point1 = CGPoint(x: center.x + vector.dx, y: center.y + vector.dy)
            gradient.color0 = .white; gradient.color1 = .black
            guard let output = gradient.outputImage else { throw PhotoError.renderFailed }
            return output.cropped(to: extent)
        case .radial(let radial):
            let value = radial.validated
            let center = CGPoint(x: extent.minX + extent.width * value.center.x,
                                 y: extent.minY + extent.height * (1 - value.center.y))
            let radiusX = extent.width * value.radiusX
            let radiusY = extent.height * value.radiusY
            let scaleY = radiusY / radiusX
            let unscaledCenter = CGPoint(x: center.x, y: center.y / scaleY)
            let gradient = CIFilter.radialGradient()
            gradient.center = unscaledCenter
            gradient.radius0 = Float(radiusX * CGFloat(1 - value.feather / 100))
            gradient.radius1 = Float(radiusX)
            gradient.color0 = .white; gradient.color1 = .black
            guard let output = gradient.outputImage else { throw PhotoError.renderFailed }
            let transformed = output.transformed(by: CGAffineTransform(scaleX: 1, y: scaleY))
            return transformed.cropped(to: extent)
        case .generated(let generated):
            let value = generated.validated
            guard !value.pngData.isEmpty, let decoded = CIImage(data: value.pngData),
                  decoded.extent.width > 0, decoded.extent.height > 0 else {
                return CIImage(color: .black).cropped(to: extent)
            }
            let normalized = decoded.transformed(by: CGAffineTransform(
                translationX: -decoded.extent.minX, y: -decoded.extent.minY
            ))
            let scaled = normalized.transformed(by: CGAffineTransform(
                scaleX: extent.width / normalized.extent.width,
                y: extent.height / normalized.extent.height
            ))
            return scaled.transformed(by: CGAffineTransform(translationX: extent.minX, y: extent.minY))
                .cropped(to: extent)
        }
    }

    private static func brushImage(_ brush: BrushMask, extent: CGRect, includeErasing: Bool = true) throws -> CIImage {
        var result = CIImage(color: .black).cropped(to: extent)
        let strength = brush.opacity / 100 * brush.flow / 100
        result = try compositeBrushStrokes(brush.strokes, onto: result, erasing: false,
                                           sizes: brush.strokeSizes, fallbackSize: brush.size,
                                           feather: brush.feather, strength: strength, extent: extent)
        if includeErasing {
            result = try compositeBrushStrokes(brush.eraseStrokes, onto: result, erasing: true,
                                               sizes: brush.eraseStrokeSizes, fallbackSize: brush.size,
                                               feather: brush.feather, strength: strength, extent: extent)
        }
        return result
    }

    private static func compositeBrushStrokes(_ strokes: [[MaskPoint]], onto input: CIImage,
                                              erasing: Bool, sizes: [Double], fallbackSize: Double,
                                              feather: Double,
                                              strength: Double, extent: CGRect) throws -> CIImage {
        var result = input
        for (index, stroke) in strokes.enumerated() {
            let size = index < sizes.count ? sizes[index] : fallbackSize
            let radius = min(extent.width, extent.height) * CGFloat(size / 200)
            let inner = radius * CGFloat(1 - feather / 100)
            for point in interpolated(stroke, radius: radius, extent: extent) {
                let gradient = CIFilter.radialGradient()
                gradient.center = CGPoint(x: extent.minX + extent.width * point.x,
                                          y: extent.minY + extent.height * (1 - point.y))
                gradient.radius0 = Float(inner); gradient.radius1 = Float(max(inner + 0.5, radius))
                gradient.color0 = CIColor(red: strength, green: strength, blue: strength)
                gradient.color1 = .black
                guard let dot = gradient.outputImage else { throw PhotoError.renderFailed }
                if erasing {
                    let invert = CIFilter.colorInvert(); invert.inputImage = dot
                    let multiply = CIFilter.multiplyCompositing()
                    multiply.inputImage = invert.outputImage; multiply.backgroundImage = result
                    guard let output = multiply.outputImage else { throw PhotoError.renderFailed }
                    result = output.cropped(to: extent)
                } else {
                    let maximum = CIFilter.maximumCompositing()
                    maximum.inputImage = dot; maximum.backgroundImage = result
                    guard let output = maximum.outputImage else { throw PhotoError.renderFailed }
                    result = output.cropped(to: extent)
                }
            }
        }
        return result
    }

    private static func interpolated(_ points: [MaskPoint], radius: CGFloat, extent: CGRect) -> [MaskPoint] {
        guard let first = points.first else { return [] }
        var output = [first.validated]
        let spacing = max(1, radius * 0.35)
        for point in points.dropFirst() {
            let previous = output.last ?? first
            let dx = (point.x - previous.x) * extent.width
            let dy = (point.y - previous.y) * extent.height
            let count = max(1, Int(ceil(hypot(dx, dy) / spacing)))
            for step in 1...count {
                let t = Double(step) / Double(count)
                output.append(MaskPoint(x: previous.x + (point.x - previous.x) * t,
                                        y: previous.y + (point.y - previous.y) * t).validated)
            }
        }
        return output
    }

    private static func applyAdjustments(_ input: CIImage, state: LocalAdjustmentState) throws -> CIImage {
        let state = state.validated
        var image = input
        if state.temperature != 0 || state.tint != 0 {
            let filter = CIFilter.temperatureAndTint(); filter.inputImage = image
            filter.neutral = CIVector(x: 6500, y: 0)
            filter.targetNeutral = CIVector(x: 6500 + state.temperature * 35, y: state.tint * 0.6)
            guard let output = filter.outputImage else { throw PhotoError.renderFailed }; image = output
        }
        if state.exposure != 0 {
            let filter = CIFilter.exposureAdjust(); filter.inputImage = image; filter.ev = Float(state.exposure)
            guard let output = filter.outputImage else { throw PhotoError.renderFailed }; image = output
        }
        if state.highlights != 0 || state.shadows != 0 {
            let filter = CIFilter.highlightShadowAdjust(); filter.inputImage = image
            filter.highlightAmount = Float(1 + state.highlights / 100)
            filter.shadowAmount = Float(state.shadows / 100)
            guard let output = filter.outputImage else { throw PhotoError.renderFailed }; image = output
        }
        if state.contrast != 0 || state.saturation != 0 {
            let filter = CIFilter.colorControls(); filter.inputImage = image
            filter.contrast = Float(1 + state.contrast / 100)
            filter.saturation = Float(1 + state.saturation / 100)
            guard let output = filter.outputImage else { throw PhotoError.renderFailed }; image = output
        }
        if state.effects.clarity != 0 {
            let filter = CIFilter.unsharpMask(); filter.inputImage = image.clampedToExtent()
            filter.radius = Float(max(1, min(input.extent.width, input.extent.height) / 180))
            filter.intensity = Float(state.effects.clarity / 100 * 0.8)
            guard let output = filter.outputImage else { throw PhotoError.renderFailed }; image = output.cropped(to: input.extent)
        }
        if state.detail.sharpening.amount > 0 {
            let filter = CIFilter.sharpenLuminance(); filter.inputImage = image
            filter.sharpness = Float(state.detail.sharpening.amount / 100 * 1.2)
            guard let output = filter.outputImage else { throw PhotoError.renderFailed }; image = output
        }
        return image.cropped(to: input.extent)
    }
}
