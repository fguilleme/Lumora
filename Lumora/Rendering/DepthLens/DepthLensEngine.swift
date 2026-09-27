import CoreML
import CoreImage

/// Owned exclusively by RenderEngine. One depth estimate per source/geometry;
/// lens controls never run inference. Model weights and preparation match the device prototype.
final class DepthLensEngine {
    private var model: MLModel?
    private let renderer: DepthLensRenderer
    private var raw: CIImage?
    private var low: Float = 0
    private var high: Float = 1
    private var frame: LensFrame?
    private(set) var inferenceCount = 0
    init() throws { renderer = try DepthLensRenderer(optimized: true) }
    func releaseFrame() { frame = nil }
    func invalidate() { raw = nil; frame = nil }
    var hasDepth: Bool { raw != nil }

    func estimate(_ source: CIImage) throws {
        try Task.checkCancellation()
        if model == nil {
            #if SWIFT_PACKAGE
            let bundle = Bundle.module
            #else
            let bundle = Bundle.main
            #endif
            let url: URL
            if let compiled = bundle.url(forResource: "DA2Small", withExtension: "mlmodelc") { url = compiled }
            else if let package = bundle.url(forResource: "DA2Small", withExtension: "mlpackage") {
                url = try MLModel.compileModel(at: package)
            } else { throw LensError.message(String(localized: "Depth Lens model is missing.")) }
            let configuration = MLModelConfiguration(); configuration.computeUnits = .all
            model = try MLModel(contentsOf: url, configuration: configuration)
        }
        guard let model, let inputName = model.modelDescription.inputDescriptionsByName.keys.first,
              let constraint = model.modelDescription.inputDescriptionsByName[inputName]?.imageConstraint else {
            throw PhotoError.renderFailed
        }
        let w = constraint.pixelsWide, h = constraint.pixelsHigh
        var pixelBuffer: CVPixelBuffer?
        guard CVPixelBufferCreate(kCFAllocatorDefault, w, h, kCVPixelFormatType_32BGRA,
            [kCVPixelBufferIOSurfacePropertiesKey: [:]] as CFDictionary, &pixelBuffer) == kCVReturnSuccess,
              let pixelBuffer else { throw PhotoError.renderFailed }
        let image = source.transformed(by: CGAffineTransform(translationX: -source.extent.minX, y: -source.extent.minY))
        let scale = min(Double(w)/image.extent.width, Double(h)/image.extent.height)
        let rect = CGRect(x: (Double(w)-image.extent.width*scale)/2, y: (Double(h)-image.extent.height*scale)/2,
                          width: image.extent.width*scale, height: image.extent.height*scale)
        let resized = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            .transformed(by: CGAffineTransform(translationX: rect.minX, y: rect.minY)).clampedToExtent()
        renderer.context.render(resized, to: pixelBuffer, bounds: CGRect(x: 0, y: 0, width: w, height: h),
                                colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!)
        let output = try model.prediction(from: MLDictionaryFeatureProvider(dictionary: [inputName: MLFeatureValue(pixelBuffer: pixelBuffer)]))
        try Task.checkCancellation()
        guard let key = output.featureNames.sorted().first,
              let buffer = output.featureValue(for: key)?.imageBufferValue,
              CVPixelBufferGetWidth(buffer) == w, CVPixelBufferGetHeight(buffer) == h,
              CVPixelBufferGetPixelFormatType(buffer) == kCVPixelFormatType_OneComponent16Half else { throw PhotoError.renderFailed }
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        var pixels = [Float](repeating: 0, count: w*h*4)
        var lo = Float.greatestFiniteMagnitude, hi = -Float.greatestFiniteMagnitude
        let base = CVPixelBufferGetBaseAddress(buffer)!, stride = CVPixelBufferGetBytesPerRow(buffer)
        for y in 0..<h {
            let row = base.advanced(by: y*stride).assumingMemoryBound(to: UInt16.self)
            for x in 0..<w {
                let value = Float(Float16(bitPattern: row[x]))
                guard value.isFinite else { throw PhotoError.renderFailed }
                for c in 0..<3 { pixels[(y*w+x)*4+c] = value }; pixels[(y*w+x)*4+3] = 1
                if x >= Int(ceil(rect.minX)), x < Int(floor(rect.maxX)), y >= Int(ceil(rect.minY)), y < Int(floor(rect.maxY)) {
                    lo = min(lo, value); hi = max(hi, value)
                }
            }
        }
        let data = pixels.withUnsafeBytes { Data($0) }
        raw = CIImage(bitmapData: data, bytesPerRow: w*16, size: CGSize(width: w, height: h), format: .RGBAf, colorSpace: nil)
            .cropped(to: rect).transformed(by: CGAffineTransform(translationX: -rect.minX, y: -rect.minY))
        low = lo; high = hi; frame = nil; inferenceCount += 1
    }

    func applyLighting(_ image: CIImage, settings: DepthLightingSettings) throws -> CIImage {
        guard settings.isActive else { return image }
        guard let raw else { throw PhotoError.renderFailed }
        let depth = raw.clampedToExtent().applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 2])
            .cropped(to: raw.extent)
        return try DepthLightingRenderer.apply(image, depth: depth, low: low, high: high, settings: settings)
    }

    func apply(_ image: CIImage, settings: DepthLensSettings) throws -> CIImage {
        guard settings.enabled else { return image }
        guard let raw else { throw PhotoError.renderFailed }
        try Task.checkCancellation()
        let w = Int(image.extent.width.rounded()), h = Int(image.extent.height.rounded())
        if frame?.width != w || frame?.height != h {
            frame = nil
            let aligned = raw.transformed(by: CGAffineTransform(scaleX: image.extent.width/raw.extent.width, y: image.extent.height/raw.extent.height))
            frame = try renderer.prepare(image: image, depth: DepthInput(raw: aligned, provenance: "DA2 Small — aspect preserved"))
        } else { try renderer.updateColor(image, frame: frame!) }
        guard let frame else { throw PhotoError.renderFailed }
        let validated = settings.validated
        var lens = LensSettings(); lens.rawMin = low; lens.rawMax = high
        lens.aperture = Float(validated.aperture); lens.focal = Float(validated.focal)
        // Initialization materializes normalized depth once; cached frames skip this pass.
        if frame.normalizationKey == nil { try renderer.render(frame: frame, settings: lens) }
        lens.focus = try renderer.focus(frame: frame, point: CGPoint(x: validated.focusX, y: validated.focusY))
        try Task.checkCancellation()
        try renderer.render(frame: frame, settings: lens)
        return renderer.image(frame.output).transformed(by: CGAffineTransform(translationX: image.extent.minX, y: image.extent.minY))
    }
}
