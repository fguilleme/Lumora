import Foundation
import CoreImage
import CoreImage.CIFilterBuiltins
import Metal
import ImageIO
import UniformTypeIdentifiers

struct RenderResult: Sendable {
    let image: CGImage
    let original: CGImage
    let histogram: Histogram
    let milliseconds: Double
    let cacheHit: Bool
    let gpu: Bool
    let sourceWidth: Int
    let sourceHeight: Int
    let isRAW: Bool
    let optics: OpticsAvailability
}

enum PreviewQuality: Int, Sendable { case interactive = 960, high = 2048 }

/// Serial GPU owner. No UI state and no full-resolution decode on slider events.
actor RenderEngine {
    private struct PreviewCacheKey: Hashable { let maximum: Int; let profileCorrection: Bool }
    private let context: CIContext
    private let gpu: Bool
    private var sourceURL: URL?
    private var sources: [PreviewCacheKey: CGImage] = [:]
    private var sourceWidth = 0
    private var sourceHeight = 0
    private var raw = false
    private var opticsAvailability = OpticsAvailability()
    private var lastLUTState: EditState?
    private var lastLUT: Data?

    init() {
        let options: [CIContextOption: Any] = [
            .workingColorSpace: CGColorSpace(name: CGColorSpace.extendedLinearSRGB) as Any,
            .cacheIntermediates: false
        ]
        if let device = MTLCreateSystemDefaultDevice() {
            context = CIContext(mtlDevice: device, options: options)
            gpu = true
        } else {
            context = CIContext(options: options.merging([.useSoftwareRenderer: true]) { _, new in new })
            gpu = false
        }
    }

    func clearCaches() {
        sources.removeAll()
        lastLUT = nil
        lastLUTState = nil
        opticsAvailability = OpticsAvailability()
        context.clearCaches()
    }

    func render(url: URL, state: EditState, quality: PreviewQuality, bypassCreative: Bool = false) throws -> RenderResult {
        try Task.checkCancellation()
        let start = ContinuousClock.now
        if sourceURL != url {
            clearCaches()
            sourceURL = url
        }
        let key = PreviewCacheKey(maximum: quality.rawValue, profileCorrection: state.optics.profileCorrection)
        let hit = sources[key] != nil
        let original = try preview(url: url, maximum: quality.rawValue, optics: state.optics)
        try Task.checkCancellation()
        let image = try adjusted(CIImage(cgImage: original), state: state, bypassCreative: bypassCreative)
        try Task.checkCancellation()
        guard let space = CGColorSpace(name: CGColorSpace.displayP3),
              let result = context.createCGImage(image, from: image.extent, format: .RGBA8, colorSpace: space)
        else { throw PhotoError.renderFailed }
        try Task.checkCancellation()
        let histogram = Histogram.compute(result)
        let duration = start.duration(to: .now)
        let milliseconds = Double(duration.components.seconds) * 1000 + Double(duration.components.attoseconds) / 1e15
        return RenderResult(image: result, original: original, histogram: histogram, milliseconds: milliseconds,
                            cacheHit: hit, gpu: gpu, sourceWidth: sourceWidth, sourceHeight: sourceHeight,
                            isRAW: raw, optics: opticsAvailability)
    }

    /// Shared adjustment graph for both preview and export. No SwiftUI or bitmap history.
    private func adjusted(_ input: CIImage, state: EditState, bypassCreative: Bool = false) throws -> CIImage {
        var image = try OpticsRenderer.apply(input, settings: state.optics)
        image = try applyDevelopment(image, state: state)
        image = GeometryRenderer.apply(image, settings: state.geometry)
        for layer in state.masks.prefix(16).map(\.validated)
            where layer.isVisible && layer.opacity > 0 && !layer.adjustments.isIdentity {
            let matte = try MaskRenderer.makeMask(layer, extent: image.extent)
            let developed = try applyDevelopment(image, state: layer.adjustments.editState)
            let blend = CIFilter.blendWithMask()
            blend.inputImage = developed
            blend.backgroundImage = image
            blend.maskImage = matte
            guard let output = blend.outputImage else { throw PhotoError.renderFailed }
            image = output.cropped(to: image.extent)
        }
        // Legacy grain is retained on disk but now uses the shared engine, after geometry/detail.
        var grain = FilmGrainSettings(); grain.amount = state.effects.grain
        image = try FilmGrainEngine.apply(image, settings: grain)
        for layer in state.masks where layer.isVisible && layer.opacity > 0 && layer.adjustments.effects.grain > 0 {
            grain.amount = layer.adjustments.effects.grain
            let output = try FilmGrainEngine.apply(image, settings: grain)
            let blend = CIFilter.blendWithMask()
            blend.inputImage = output; blend.backgroundImage = image
            blend.maskImage = try MaskRenderer.makeMask(layer, extent: image.extent)
            guard let mixed = blend.outputImage else { throw PhotoError.renderFailed }
            image = mixed.cropped(to: image.extent)
        }
        if !bypassCreative {
            image = try CreativeStackRenderer.apply(image, stack: state.creative, masks: state.masks)
        }
        return image
    }

    /// Applies the photographic controls carried by either the full-frame base layer
    /// or a masked adjustment layer. Spatial document transforms stay outside this graph.
    private func applyDevelopment(_ input: CIImage, state: EditState) throws -> CIImage {
        var image = input
        if state.temperature != 0 || state.tint != 0 {
            let filter = CIFilter.temperatureAndTint()
            filter.inputImage = image
            // Source is already developed at its as-shot WB, including RAW. Apply a relative adaptation once.
            filter.neutral = CIVector(x: 6500, y: 0)
            filter.targetNeutral = CIVector(x: 6500 + state.temperature * 35, y: state.tint * 0.6)
            guard let output = filter.outputImage else { throw PhotoError.renderFailed }
            image = output
        }
        if state.exposure != 0 {
            let filter = CIFilter.exposureAdjust()
            filter.inputImage = image
            filter.ev = Float(state.exposure)
            guard let output = filter.outputImage else { throw PhotoError.renderFailed }
            image = output
        }
        var colorState = state
        colorState.temperature = 0; colorState.tint = 0; colorState.exposure = 0
        colorState.effects = EffectsSettings()
        colorState.detail = DetailSettings()
        colorState.optics = OpticsSettings()
        colorState.geometry = GeometrySettings()
        colorState.masks = []
        colorState.creative = CreativeEffectStack()
        if colorState != EditState() {
            let data: Data
            if lastLUTState == colorState, let cached = lastLUT { data = cached }
            else {
                data = try makeCube(colorState)
                lastLUTState = colorState; lastLUT = data
            }
            guard let space = CGColorSpace(name: CGColorSpace.sRGB),
                  let filter = CIFilter(name: "CIColorCubeWithColorSpace", parameters: [
                    kCIInputImageKey: image, "inputCubeDimension": 32,
                    "inputCubeData": data, "inputColorSpace": space
                  ]), let output = filter.outputImage else { throw PhotoError.renderFailed }
            image = output
        }
        image = try EffectsRenderer.applyBeforeDetail(image, settings: state.effects)
        image = try DetailRenderer.apply(image, settings: state.detail)
        var finishing = state.effects; finishing.grain = 0
        image = try EffectsRenderer.applyFinishing(image, settings: finishing)
        return image
    }

    func export(request: ExportRequest, settings: ExportSettings, directory: URL,
                progress: @Sendable (ExportStage) -> Void = { _ in }) throws -> ExportedPhoto {
        try Task.checkCancellation()
        let settings = settings.validated
        guard ExportFormat.available.contains(settings.format) else { throw ExportError.unsupportedFormat }
        progress(.decoding)
        guard let source = CGImageSourceCreateWithURL(request.sourceURL as CFURL, nil) else { throw PhotoError.unreadable }
        let metadata = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] ?? [:]
        let type = CGImageSourceGetType(source).flatMap { UTType($0 as String) }
        let input: CIImage
        if type?.conforms(to: .rawImage) == true {
            guard let raw = CIRAWFilter(imageURL: request.sourceURL) else { throw PhotoError.unreadable }
            raw.isLensCorrectionEnabled = request.state.optics.profileCorrection && raw.isLensCorrectionSupported
            if let maximum = settings.maximumDimension {
                raw.scaleFactor = Float(min(1, Double(maximum) / max(raw.nativeSize.width, raw.nativeSize.height)))
            }
            guard let output = raw.outputImage else { throw PhotoError.unreadable }
            input = output
        } else {
            guard let decoded = CIImage(contentsOf: request.sourceURL, options: [.applyOrientationProperty: true]) else { throw PhotoError.unreadable }
            input = decoded
        }
        defer { context.clearCaches() }
        try Task.checkCancellation()
        var image = input.transformed(by: CGAffineTransform(translationX: -input.extent.minX, y: -input.extent.minY))
        progress(.rendering)
        image = try adjusted(image, state: request.state.validated)
        let dimensions = settings.dimensions(width: Int(image.extent.width), height: Int(image.extent.height))
        if dimensions.width != Int(image.extent.width) || dimensions.height != Int(image.extent.height) {
            let scale = CIFilter.lanczosScaleTransform()
            scale.inputImage = image
            scale.scale = Float(Double(dimensions.height) / image.extent.height)
            scale.aspectRatio = Float((Double(dimensions.width) / image.extent.width) / (Double(dimensions.height) / image.extent.height))
            guard let output = scale.outputImage else { throw PhotoError.renderFailed }
            image = output.cropped(to: CGRect(x: 0, y: 0, width: dimensions.width, height: dimensions.height))
        }
        let bounds = CGRect(x: 0, y: 0, width: dimensions.width, height: dimensions.height)
        // JPEG cannot carry alpha. Composite on white explicitly rather than encoding undefined transparent pixels.
        if settings.format == .jpeg {
            image = image.composited(over: CIImage(color: CIColor(red: 1, green: 1, blue: 1)).cropped(to: bounds))
        }
        try Task.checkCancellation()
        guard let space = settings.colorSpace.cgColorSpace,
              let bitmap = context.createCGImage(image, from: bounds, format: .RGBA8, colorSpace: space)
        else { throw PhotoError.renderFailed }
        try Task.checkCancellation()
        progress(.encoding)
        // Unique output directory and staging file: never overwrite the original or expose a partial export.
        let folder = directory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let staging = folder.appendingPathComponent("render.partial")
        let output = folder.appendingPathComponent("Lumora." + settings.format.filenameExtension)
        do {
            guard let destination = CGImageDestinationCreateWithURL(staging as CFURL, settings.format.type.identifier as CFString, 1, nil) else {
                throw ExportError.encodingFailed
            }
            let properties = ExportMetadata.properties(source: metadata, settings: settings, width: dimensions.width, height: dimensions.height)
            CGImageDestinationAddImage(destination, bitmap, properties as CFDictionary)
            guard CGImageDestinationFinalize(destination) else { throw ExportError.encodingFailed }
            try Task.checkCancellation()
            try FileManager.default.moveItem(at: staging, to: output)
            let size = try output.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            try Task.checkCancellation()
            progress(.finished)
            return ExportedPhoto(url: output, width: dimensions.width, height: dimensions.height, byteCount: size)
        } catch {
            try? FileManager.default.removeItem(at: folder)
            throw error
        }
    }

    /// Region is normalized in post-geometry coordinates, origin lower-left.
    /// Builds a lazy full-resolution graph and materializes only a bounded output rectangle.
    /// Decoder internals may still decode the full original (notably RAW).
    func renderFullResolutionTile(url: URL, state: EditState, region: CGRect,
                                  maximum: Int = 1024, bypassCreative: Bool = false) throws -> CGImage {
        try Task.checkCancellation()
        guard [region.origin.x, region.origin.y, region.width, region.height].allSatisfy({ $0.isFinite }), region.width > 0, region.height > 0 else { throw PhotoError.renderFailed }
        defer { context.clearCaches() }
        let source: CIImage
        if let rawFilter = CIRAWFilter(imageURL: url) {
            rawFilter.isLensCorrectionEnabled = state.optics.profileCorrection && rawFilter.isLensCorrectionSupported
            guard let decoded = rawFilter.outputImage else { throw PhotoError.unreadable }
            source = decoded
        } else {
            guard let decoded = CIImage(contentsOf: url, options: [.applyOrientationProperty: true]) else { throw PhotoError.unreadable }
            source = decoded
        }
        let normalized = source.transformed(by: CGAffineTransform(translationX: -source.extent.minX, y: -source.extent.minY))
        let graph = try adjusted(normalized, state: state.validated, bypassCreative: bypassCreative)
        let extent = graph.extent
        let limit = CGFloat(min(2048, max(64, maximum)))
        let width = min(limit, max(1, extent.width * region.width))
        let height = min(limit, max(1, extent.height * region.height))
        let x = min(extent.maxX-width, max(extent.minX, extent.minX + region.midX*extent.width-width/2))
        let y = min(extent.maxY-height, max(extent.minY, extent.minY + region.midY*extent.height-height/2))
        let bounds = CGRect(x: x, y: y, width: min(width, extent.width), height: min(height, extent.height)).integral.intersection(extent)
        try Task.checkCancellation()
        guard let space = CGColorSpace(name: CGColorSpace.displayP3),
              let tile = context.createCGImage(graph, from: bounds, format: .RGBA8, colorSpace: space) else { throw PhotoError.renderFailed }
        try Task.checkCancellation()
        return tile
    }

    private func preview(url: URL, maximum: Int, optics: OpticsSettings) throws -> CGImage {
        let key = PreviewCacheKey(maximum: maximum, profileCorrection: optics.profileCorrection)
        if let image = sources[key] { return image }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { throw PhotoError.unreadable }
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        sourceWidth = properties?[kCGImagePropertyPixelWidth] as? Int ?? 0
        sourceHeight = properties?[kCGImagePropertyPixelHeight] as? Int ?? 0
        let type = CGImageSourceGetType(source).flatMap { UTType($0 as String) }
        raw = type?.conforms(to: .rawImage) == true
        let tiff = properties?[kCGImagePropertyTIFFDictionary] as? [CFString: Any]
        let exif = properties?[kCGImagePropertyExifDictionary] as? [CFString: Any]
        let make = tiff?[kCGImagePropertyTIFFMake] as? String
        let model = tiff?[kCGImagePropertyTIFFModel] as? String
        opticsAvailability.camera = [make, model].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ")
        if opticsAvailability.camera?.isEmpty == true { opticsAvailability.camera = nil }
        opticsAvailability.lens = exif?[kCGImagePropertyExifLensModel] as? String
        opticsAvailability.profileSupported = false
        let result: CGImage
        if raw {
            guard let filter = CIRAWFilter(imageURL: url) else { throw PhotoError.unreadable }
            opticsAvailability.profileSupported = filter.isLensCorrectionSupported
            filter.isLensCorrectionEnabled = optics.profileCorrection && filter.isLensCorrectionSupported
            let size = filter.nativeSize
            sourceWidth = Int(size.width); sourceHeight = Int(size.height)
            filter.scaleFactor = Float(min(1, Double(maximum) / max(size.width, size.height)))
            guard let output = filter.outputImage,
                  let space = CGColorSpace(name: CGColorSpace.extendedLinearSRGB),
                  let rendered = context.createCGImage(output, from: output.extent, format: .RGBAh, colorSpace: space)
            else { throw PhotoError.unreadable }
            result = rendered
        } else {
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: maximum,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldCacheImmediately: true
            ]
            guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
            else { throw PhotoError.unreadable }
            result = thumbnail
        }
        try Task.checkCancellation()
        sources[key] = result
        return result
    }

    private func makeCube(_ state: EditState) throws -> Data {
        let dimension = 32
        let grading = state.colorGrading.isIdentity ? nil : GradingTransform(state.colorGrading)
        let curves = state.curves.isIdentity ? nil : CurveLookup(state.curves)
        var values = [Float]()
        values.reserveCapacity(dimension * dimension * dimension * 4)
        for blue in 0..<dimension {
            try Task.checkCancellation()
            for green in 0..<dimension {
                for red in 0..<dimension {
                    var (r, g, b) = TonalResponse.color(Double(red) / 31, Double(green) / 31, Double(blue) / 31, state: state, curves: curves)
                    if let grading { (r, g, b) = grading.apply(r, g, b) }
                    values.append(contentsOf: [Float(r), Float(g), Float(b), 1])
                }
            }
        }
        return values.withUnsafeBytes { Data($0) }
    }
}
