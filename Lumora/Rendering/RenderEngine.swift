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
    private var cinematicGlowGPU: CinematicGlowGPU?
    private var depthLensEngine: DepthLensEngine?
    private var depthLensGeometry: GeometrySettings?
    private var depthLensOptics: OpticsSettings?
    private let gpu: Bool
    private var sourceURL: URL?
    private var sources: [PreviewCacheKey: CGImage] = [:]
    private var sourceWidth = 0
    private var sourceHeight = 0
    private var raw = false
    private var opticsAvailability = OpticsAvailability()
    private var lastLUTState: EditState?
    private var lastLUT: Data?
    private var autoCache: (AutoAnalysisKey, AutoProposal)?
    private var coreAutoCache: (CoreAutoCacheKey, CoreImageAutoEngine.Capture)?
    private var autoBaselines: [(AutoBaselineKey, CGImage)] = []
    private var beautyCache: (BeautyAnalysisKey, BeautyMasks)?
    private(set) var autoBaselineBuildCount = 0

    private struct CoreAutoCacheKey: Equatable {
        var url: URL
        var sourceVersion: String
        var optics: OpticsSettings
        var geometry: GeometrySettings
    }
    private struct AutoBaselineKey: Equatable {
        var maximum: Int
        var optics: OpticsSettings
        var geometry: GeometrySettings
        var recipe: CoreImageAutoState
    }
    private struct BeautyAnalysisKey: Equatable {
        var url: URL?
        var width: Int
        var height: Int
        var optics: OpticsSettings
        var geometry: GeometrySettings
    }

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

    func depthLensInferenceCount() -> Int { depthLensEngine?.inferenceCount ?? 0 }

    func clearCaches() {
        cinematicGlowGPU?.releaseFrame()
        depthLensEngine?.invalidate()
        depthLensGeometry = nil; depthLensOptics = nil
        sources.removeAll()
        autoCache = nil
        coreAutoCache = nil
        autoBaselines.removeAll()
        beautyCache = nil
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
        let maximum = quality == .interactive && (state.depthLens?.enabled == true || state.depthLighting?.isActive == true) ? 640 : quality.rawValue
        let key = PreviewCacheKey(maximum: maximum, profileCorrection: state.optics.profileCorrection)
        let hit = sources[key] != nil
        let original = try preview(url: url, maximum: maximum, optics: state.optics)
        try Task.checkCancellation()
        let input = CIImage(cgImage: original)
        let baseline = try previewAutoBaseline(input, state: state, maximum: maximum)
        let image = try adjusted(input, state: state, bypassCreative: bypassCreative, autoBaseline: baseline)
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

    /// Common pre-development input, viewed through the current crop. No Creative FX.
    func autoAnalysis(url: URL, state: EditState, maskID: UUID? = nil, maximum: Int = 512) throws -> AutoAnalysisResult {
        let start = ContinuousClock.now
        let metadata = try url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
        let version = "\(metadata.contentModificationDate?.timeIntervalSince1970 ?? 0)-\(metadata.fileSize ?? 0)"
        let key = AutoAnalysisKey(url: url, version: version, state: state, maskID: maskID, maximum: maximum)
        if let cached = autoCache, cached.0 == key {
            return .init(proposal: cached.1, cacheHit: true, milliseconds: autoMilliseconds(start))
        }
        try Task.checkCancellation()
        let input: CIImage
        if let raw = CIRAWFilter(imageURL: url) {
            raw.isLensCorrectionEnabled = state.optics.profileCorrection && raw.isLensCorrectionSupported
            raw.scaleFactor = Float(min(1, Double(maximum * 2) / max(raw.nativeSize.width, raw.nativeSize.height)))
            guard let decoded = raw.outputImage else { throw PhotoError.unreadable }
            input = decoded
        } else {
            guard let decoded = CIImage(contentsOf: url, options: [.applyOrientationProperty: true]) else { throw PhotoError.unreadable }
            input = decoded
        }
        let prepared: CIImage
        if key.mask != nil { prepared = try adjusted(input, state: key.upstream, bypassCreative: true) }
        else { prepared = GeometryRenderer.apply(try OpticsRenderer.apply(input, settings: state.optics), settings: state.geometry) }
        let matte = try key.mask.map { try MaskRenderer.makeMask($0, extent: prepared.extent) }
        let pixels = AutoAnalysisInput.pixels(prepared, context: context, maximum: maximum, mask: matte)
        try Task.checkCancellation()
        let proposal = AutoProposal(ImageAnalysis.measure(pixels))
        try Task.checkCancellation()
        autoCache = (key, proposal)
        return .init(proposal: proposal, cacheHit: false, milliseconds: autoMilliseconds(start))
    }

    private func autoMilliseconds(_ start: ContinuousClock.Instant) -> Double {
        let duration = start.duration(to: .now)
        return Double(duration.components.seconds) * 1000 + Double(duration.components.attoseconds) / 1e15
    }

    /// Materialize at most two extended-linear half-float preview baselines.
    /// Manual sliders reuse these pixels; export still evaluates the saved recipe
    /// at full resolution rather than upscaling a preview.
    private func previewAutoBaseline(_ input: CIImage, state: EditState, maximum: Int) throws -> CIImage? {
        guard let recipe = state.coreImageAuto else { return nil }
        // A healed image cannot reuse the unhealed Auto baseline. Neutral/disabled
        // corrections keep the existing cache path and its exact pixel identity.
        guard state.beauty.amount == 0 || !state.beauty.corrections.contains(where: { $0.enabled && $0.strength > 0 }) else { return nil }
        let key = AutoBaselineKey(maximum: maximum, optics: state.optics,
                                  geometry: state.geometry, recipe: recipe)
        if let cached = autoBaselines.first(where: { $0.0 == key }) {
            return CIImage(cgImage: cached.1)
        }
        var image = try OpticsRenderer.apply(input, settings: state.optics)
        image = GeometryRenderer.apply(image, settings: state.geometry)
        image = try CoreImageAutoEngine.apply(recipe, to: image)
        guard let space = CGColorSpace(name: CGColorSpace.extendedLinearSRGB),
              let bitmap = context.createCGImage(image, from: image.extent, format: .RGBAh,
                                                 colorSpace: space) else { throw PhotoError.renderFailed }
        autoBaselineBuildCount &+= 1
        autoBaselines.removeAll { $0.0.maximum == maximum }
        autoBaselines.append((key, bitmap))
        if autoBaselines.count > 2 { autoBaselines.removeFirst() }
        return CIImage(cgImage: bitmap)
    }

    /// Auto sees the oriented source after lens/crop geometry, before any manual
    /// development setting. Only this explicit user action runs Apple's analysis.
    func captureCoreImageAuto(url: URL, state: EditState) throws -> (CoreImageAutoEngine.Capture, Bool, Double) {
        let start = ContinuousClock.now
        if sourceURL != url {
            clearCaches()
            sourceURL = url
        }
        let metadata = try url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
        let key = CoreAutoCacheKey(url: url,
            sourceVersion: "\(metadata.contentModificationDate?.timeIntervalSince1970 ?? 0)-\(metadata.fileSize ?? 0)",
            optics: state.optics, geometry: state.geometry)
        if let cached = coreAutoCache, cached.0 == key {
            return (cached.1, true, autoMilliseconds(start))
        }
        try Task.checkCancellation()
        let source: CIImage
        if let rawFilter = CIRAWFilter(imageURL: url) {
            rawFilter.isLensCorrectionEnabled = state.optics.profileCorrection && rawFilter.isLensCorrectionSupported
            rawFilter.scaleFactor = Float(min(1, 2048 / max(rawFilter.nativeSize.width, rawFilter.nativeSize.height)))
            guard let decoded = rawFilter.outputImage else { throw PhotoError.unreadable }
            source = decoded
        } else {
            guard let decoded = CIImage(contentsOf: url, options: [.applyOrientationProperty: true]) else { throw PhotoError.unreadable }
            source = decoded
        }
        let normalized = source.transformed(by: CGAffineTransform(translationX: -source.extent.minX, y: -source.extent.minY))
        let prepared = GeometryRenderer.apply(try OpticsRenderer.apply(normalized, settings: state.optics), settings: state.geometry)
        let scale = min(1, 2048 / max(prepared.extent.width, prepared.extent.height))
        let sample = scale < 1 ? prepared.transformed(by: CGAffineTransform(scaleX: scale, y: scale)) : prepared
        guard let space = CGColorSpace(name: CGColorSpace.extendedLinearSRGB),
              let bitmap = context.createCGImage(sample, from: sample.extent.integral, format: .RGBAh, colorSpace: space)
        else { throw PhotoError.renderFailed }
        try Task.checkCancellation()
        let captured = try CoreImageAutoEngine.capture(CIImage(cgImage: bitmap))
        coreAutoCache = (key, captured)
        return (captured, false, autoMilliseconds(start))
    }

    /// Diagnostics evaluate the unchanged production graph, not a second Auto renderer.
    func autoDiagnosticDevelopment(_ input: CIImage, state: EditState) throws -> CIImage {
        try applyDevelopment(input, state: state)
    }

    /// A single Vision pass is shared by the Beauty panel and subsequent
    /// interactive/HQ renders. The analysis key excludes slider values.
    func beautyAnalysis(url: URL, state: EditState) throws -> BeautyMasks {
        if sourceURL != url { clearCaches(); sourceURL = url }
        let original = try preview(url: url, maximum: 1_024, optics: state.optics)
        return try beautyMasks(for: CIImage(cgImage: original), state: state)
    }

    func prepareManualHealing(url: URL, state: EditState) throws -> ManualHealingAnalysis {
        if sourceURL != url { clearCaches(); sourceURL = url }
        let original = try preview(url: url, maximum: 1_024, optics: state.optics)
        let source = CIImage(cgImage: original)
        var canonical = state; canonical.geometry = GeometrySettings()
        let masks = try beautyMasks(for: source, state: canonical)
        let optical = try OpticsRenderer.apply(source, settings: state.optics)
        // Auto is geometry-dependent; healing remains in canonical coordinates before Auto.
        let developed = state.coreImageAuto == nil ? try applyDevelopment(optical, state: state, deferDetail: true) : optical
        return try ManualHealingAnalysis.prepare(developed, masks: masks, context: context)
    }

    private func beautyMasks(for source: CIImage, state: EditState) throws -> BeautyMasks {
        let key = BeautyAnalysisKey(url: sourceURL,
            width: sourceURL == nil ? Int(source.extent.width) : sourceWidth,
            height: sourceURL == nil ? Int(source.extent.height) : sourceHeight,
            optics: state.optics, geometry: state.geometry)
        if let beautyCache, beautyCache.0 == key { return beautyCache.1 }
        try Task.checkCancellation()
        var prepared = try OpticsRenderer.apply(source, settings: state.optics)
        prepared = GeometryRenderer.apply(prepared, settings: state.geometry)
        let scale = min(1, 1_024 / max(prepared.extent.width, prepared.extent.height))
        if scale < 1 { prepared = prepared.transformed(by: CGAffineTransform(scaleX: scale, y: scale)) }
        guard let color = CGColorSpace(name: CGColorSpace.sRGB),
              let bitmap = context.createCGImage(prepared, from: prepared.extent.integral,
                                                 format: .RGBA8, colorSpace: color)
        else { throw PhotoError.renderFailed }
        let masks = try BeautyFaceAnalysis.analyze(bitmap)
        try Task.checkCancellation()
        beautyCache = (key, masks)
        return masks
    }

    /// Shared adjustment graph for both preview and export. No SwiftUI or bitmap history.
    private func adjusted(_ input: CIImage, state: EditState, bypassCreative: Bool = false,
                          autoBaseline: CIImage? = nil) throws -> CIImage {
        var image: CIImage
        let beautyActive = !state.beauty.isIdentity
        if let autoBaseline {
            image = autoBaseline
            image = try applyDevelopment(image, state: state, deferDetail: beautyActive)
        } else if let auto = state.coreImageAuto {
            image = try OpticsRenderer.apply(input, settings: state.optics)
            image = try ManualHealingRenderer.apply(image, corrections: state.beauty.corrections, amount: state.beauty.amount)
            image = GeometryRenderer.apply(image, settings: state.geometry)
            image = try CoreImageAutoEngine.apply(auto, to: image)
            image = try applyDevelopment(image, state: state, deferDetail: beautyActive)
        } else {
            // Preserve the rendering order of every existing document.
            image = try OpticsRenderer.apply(input, settings: state.optics)
            image = try applyDevelopment(image, state: state, deferDetail: beautyActive)
            image = try ManualHealingRenderer.apply(image, corrections: state.beauty.corrections, amount: state.beauty.amount)
            image = GeometryRenderer.apply(image, settings: state.geometry)
        }
        if beautyActive {
            var frozenV1 = state.beauty
            frozenV1.finishing = nil
            frozenV1.corrections = []
            if !frozenV1.isIdentity || !(state.beauty.finishing?.isIdentity ?? true) {
                let masks = try beautyMasks(for: input, state: state)
                image = try BeautyRenderer.apply(image, settings: frozenV1, masks: masks)
                image = try BeautyV2Renderer.apply(image, settings: state.beauty.finishing ?? .init(),
                                                    masks: masks, amount: state.beauty.amount)
            }
            image = try DetailRenderer.apply(image, settings: state.detail)
            var finishing = state.effects; finishing.grain = 0
            image = try EffectsRenderer.applyFinishing(image, settings: finishing)
        }
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
        if state.depthLens?.enabled == true || state.depthLighting?.isActive == true {
            if depthLensEngine == nil { depthLensEngine = try DepthLensEngine() }
            if depthLensGeometry != state.geometry || depthLensOptics != state.optics {
                depthLensEngine?.invalidate()
                depthLensGeometry = state.geometry; depthLensOptics = state.optics
            }
            if !depthLensEngine!.hasDepth {
                // Identical analysis decode in preview, HQ, and native export.
                let source: CIImage
                if let sourceURL { source = CIImage(cgImage: try preview(url: sourceURL, maximum: 1024, optics: state.optics)) }
                else { source = input }
                let optical = try OpticsRenderer.apply(source, settings: state.optics)
                try depthLensEngine!.estimate(GeometryRenderer.apply(optical, settings: state.geometry))
            }
            if let lighting = state.depthLighting, lighting.isActive {
                image = try depthLensEngine!.applyLighting(image, settings: lighting)
            }
            if let settings = state.depthLens, settings.enabled {
                image = try depthLensEngine!.apply(image, settings: settings)
            } else { depthLensEngine?.releaseFrame() }
        } else { depthLensEngine?.releaseFrame() }
        if state.effects.cinematicGlowIntensity > 0 {
            if cinematicGlowGPU == nil { cinematicGlowGPU = try CinematicGlowGPU() }
            image = try cinematicGlowGPU!.apply(image, intensity: state.effects.cinematicGlowIntensity)
        }
        // Legacy grain is retained on disk but now uses the shared engine, after geometry/detail.
        var grain = state.effects.grainSettings
        image = try FilmGrainEngine.apply(image, settings: grain)
        for layer in state.masks where layer.isVisible && layer.opacity > 0 && layer.adjustments.effects.grain > 0 {
            grain = layer.adjustments.effects.grainSettings
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
    private func applyDevelopment(_ input: CIImage, state: EditState,
                                  deferDetail: Bool = false) throws -> CIImage {
        try DevelopmentRenderer.apply(input, state: state, deferDetail: deferDetail) { colorState in
            if lastLUTState == colorState, let cached = lastLUT { return cached }
            let data = try Self.makeCube(colorState)
            lastLUTState = colorState; lastLUT = data
            return data
        }
    }

    func export(request: ExportRequest, settings: ExportSettings, directory: URL,
                progress: @Sendable (ExportStage) -> Void = { _ in }) throws -> ExportedPhoto {
        try Task.checkCancellation()
        if sourceURL != request.sourceURL { clearCaches(); sourceURL = request.sourceURL }
        let settings = settings.validated
        guard ExportFormat.available.contains(settings.format) else { throw ExportError.unsupportedFormat }
        progress(.decoding)
        let source = CGImageSourceCreateWithURL(request.sourceURL as CFURL, nil)
        let metadata = source.flatMap { CGImageSourceCopyPropertiesAtIndex($0, 0, nil) as? [CFString: Any] } ?? [:]
        let input: CIImage
        if let raw = CIRAWFilter(imageURL: request.sourceURL) {
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
        defer { context.clearCaches(); cinematicGlowGPU?.releaseFrame(); depthLensEngine?.releaseFrame() }
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
        defer { context.clearCaches(); cinematicGlowGPU?.releaseFrame(); depthLensEngine?.releaseFrame() }
        if sourceURL != url { clearCaches(); sourceURL = url }
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
        let source = CGImageSourceCreateWithURL(url as CFURL, nil)
        let properties = source.flatMap { CGImageSourceCopyPropertiesAtIndex($0, 0, nil) as? [CFString: Any] }
        sourceWidth = properties?[kCGImagePropertyPixelWidth] as? Int ?? 0
        sourceHeight = properties?[kCGImagePropertyPixelHeight] as? Int ?? 0
        let rawFilter = CIRAWFilter(imageURL: url)
        raw = rawFilter != nil
        let tiff = properties?[kCGImagePropertyTIFFDictionary] as? [CFString: Any]
        let exif = properties?[kCGImagePropertyExifDictionary] as? [CFString: Any]
        let make = tiff?[kCGImagePropertyTIFFMake] as? String
        let model = tiff?[kCGImagePropertyTIFFModel] as? String
        opticsAvailability.camera = [make, model].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ")
        if opticsAvailability.camera?.isEmpty == true { opticsAvailability.camera = nil }
        opticsAvailability.lens = exif?[kCGImagePropertyExifLensModel] as? String
        opticsAvailability.profileSupported = false
        let result: CGImage
        if let filter = rawFilter {
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
            guard let source else { throw PhotoError.unreadable }
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

    nonisolated static func makeCube(_ state: EditState) throws -> Data {
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
