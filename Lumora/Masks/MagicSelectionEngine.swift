import CoreGraphics
import CoreImage
import CoreML
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct MagicSelectionPoint: Identifiable, Sendable {
    let id = UUID()
    var location: CGPoint
    var includes: Bool
}

enum MagicSelectionError: LocalizedError {
    case modelMissing, invalidOutput, encodingFailed

    var errorDescription: String? {
        switch self {
        case .modelMissing: String(localized: "The Magic Selection model is unavailable.")
        case .invalidOutput: String(localized: "Magic Selection could not produce a mask.")
        case .encodingFailed: String(localized: "The refined mask could not be saved.")
        }
    }
}

actor MagicSelectionEngine {
    private final class SendableModel: @unchecked Sendable {
        let model: MLModel

        init(_ model: MLModel) {
            self.model = model
        }
    }

    private let source: CGImage
    private let context = CIContext(options: [.cacheIntermediates: false])
    private var encoder: SendableModel?
    private var decoder: SendableModel?
    private var embedding: MLMultiArray?
    private var resizedSize = CGSize.zero
    private var latestMask: MLMultiArray?
    private var latestCandidate = 0

    init(source: CGImage) { self.source = source }

    func prepare() async throws {
        let models = try Self.loadModels()
        let input = try prepareInput()
        let provider = try MLDictionaryFeatureProvider(dictionary: [
            "image_normalized_padded": MLFeatureValue(multiArray: input)
        ])
        let output = try await models.0.model.prediction(from: provider, options: MLPredictionOptions())
        guard let value = output.featureValue(for: "image_embedding")?.multiArrayValue else {
            throw MagicSelectionError.invalidOutput
        }
        encoder = models.0
        decoder = models.1
        embedding = value
    }

    func select(points: [MagicSelectionPoint]) async throws -> CGImage {
        guard let decoder, let embedding else { throw MagicSelectionError.modelMissing }
        let coordinates = try MLMultiArray(shape: [1, 8, 2], dataType: .float32)
        let labels = try MLMultiArray(shape: [1, 8], dataType: .float32)
        for index in 0..<8 { labels[index] = -1 }
        let scale = 1_024.0 / Double(max(source.width, source.height))
        for (index, point) in points.prefix(8).enumerated() {
            coordinates[index * 2] = NSNumber(value: Float(point.location.x * Double(source.width) * scale))
            coordinates[index * 2 + 1] = NSNumber(value: Float(point.location.y * Double(source.height) * scale))
            labels[index] = NSNumber(value: point.includes ? Float(1) : Float(0))
        }
        let prior = try MLMultiArray(shape: [1, 1, 256, 256], dataType: .float32)
        let hasPrior = try MLMultiArray(shape: [1], dataType: .float32)
        hasPrior[0] = 0
        let provider = try MLDictionaryFeatureProvider(dictionary: [
            "image_embedding": MLFeatureValue(multiArray: embedding),
            "point_coords": MLFeatureValue(multiArray: coordinates),
            "point_labels": MLFeatureValue(multiArray: labels),
            "mask_input": MLFeatureValue(multiArray: prior),
            "has_mask_input": MLFeatureValue(multiArray: hasPrior)
        ])
        let output = try await decoder.model.prediction(from: provider, options: MLPredictionOptions())
        guard let masks = output.featureValue(for: "low_res_masks")?.multiArrayValue,
              let scores = output.featureValue(for: "quality_scores")?.multiArrayValue else {
            throw MagicSelectionError.invalidOutput
        }
        let selection = bestCandidate(in: masks, scores: scores, points: points)
        let candidate = selection
        latestMask = masks
        latestCandidate = candidate
        guard let preview = makeMaskImage(masks, candidate: candidate, alpha: true) else {
            throw MagicSelectionError.invalidOutput
        }
        return preview
    }

    func selectedCandidateIndex() -> Int { latestCandidate }

    func selectCandidate(_ index: Int) throws -> CGImage {
        guard let latestMask else { throw MagicSelectionError.invalidOutput }
        let candidate = min(2, max(0, index))
        latestCandidate = candidate
        guard let preview = makeMaskImage(latestMask, candidate: candidate, alpha: true) else {
            throw MagicSelectionError.invalidOutput
        }
        return preview
    }

    func finalizedMask(refineEdges: Bool) throws -> GeneratedMask {
        guard let latestMask,
              let small = makeMaskCIImage(latestMask, candidate: latestCandidate) else {
            throw MagicSelectionError.invalidOutput
        }
        let sourceImage = CIImage(cgImage: source)
        let fullExtent = sourceImage.extent
        let output: CIImage
        if refineEdges, let filter = CIFilter(name: "CIEdgePreserveUpsampleFilter") {
            filter.setValue(sourceImage, forKey: kCIInputImageKey)
            filter.setValue(small, forKey: "inputSmallImage")
            filter.setValue(3.0, forKey: "inputSpatialSigma")
            filter.setValue(0.12, forKey: "inputLumaSigma")
            output = (filter.outputImage ?? scaled(small, to: fullExtent)).cropped(to: fullExtent)
        } else {
            output = scaled(small, to: fullExtent).cropped(to: fullExtent)
        }
        guard let gray = CGColorSpace(name: CGColorSpace.linearGray),
              let image = context.createCGImage(output, from: fullExtent, format: .L8, colorSpace: gray)
        else { throw MagicSelectionError.encodingFailed }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data, UTType.png.identifier as CFString, 1, nil
        ) else { throw MagicSelectionError.encodingFailed }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw MagicSelectionError.encodingFailed }
        return GeneratedMask(kind: .magic, pngData: data as Data,
                             width: image.width, height: image.height).validated
    }

    private func scaled(_ image: CIImage, to extent: CGRect) -> CIImage {
        image.transformed(by: CGAffineTransform(
            scaleX: extent.width / image.extent.width,
            y: extent.height / image.extent.height
        ))
    }

    private func prepareInput() throws -> MLMultiArray {
        let scale = 1_024.0 / Double(max(source.width, source.height))
        let width = Int(Double(source.width) * scale + 0.5)
        let height = Int(Double(source.height) * scale + 0.5)
        resizedSize = CGSize(width: width, height: height)
        let image = CIImage(cgImage: source).transformed(by: CGAffineTransform(
            scaleX: Double(width) / Double(source.width), y: Double(height) / Double(source.height)))
        var rgba = [UInt8](repeating: 0, count: width * height * 4)
        context.render(image, toBitmap: &rgba, rowBytes: width * 4,
                       bounds: CGRect(x: 0, y: 0, width: width, height: height),
                       format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!)
        let array = try MLMultiArray(shape: [1, 3, 1024, 1024], dataType: .float32)
        let pointer = array.dataPointer.assumingMemoryBound(to: Float.self)
        pointer.initialize(repeating: 0, count: 3 * 1024 * 1024)
        let mean: [Float] = [123.675, 116.28, 103.53]
        let deviation: [Float] = [58.395, 57.12, 57.375]
        for y in 0..<height {
            for x in 0..<width {
                let pixel = (y * width + x) * 4
                let plane = y * 1024 + x
                for channel in 0..<3 {
                    pointer[channel * 1024 * 1024 + plane] =
                        (Float(rgba[pixel + channel]) - mean[channel]) / deviation[channel]
                }
            }
        }
        return array
    }

    private func makeMaskCIImage(_ masks: MLMultiArray, candidate: Int) -> CIImage? {
        let width = max(1, min(256, Int(resizedSize.width / 4 + 0.5)))
        let height = max(1, min(256, Int(resizedSize.height / 4 + 0.5)))
        var bytes = [UInt8](repeating: 0, count: width * height)
        for y in 0..<height {
            for x in 0..<width {
                let logit = masks[[0, candidate, y, x] as [NSNumber]].floatValue
                bytes[y * width + x] = logit > 0 ? 255 : 0
            }
        }
        let data = Data(bytes) as CFData
        guard let provider = CGDataProvider(data: data),
              let gray = CGColorSpace(name: CGColorSpace.linearGray),
              let image = CGImage(width: width, height: height, bitsPerComponent: 8,
                                  bitsPerPixel: 8, bytesPerRow: width, space: gray,
                                  bitmapInfo: CGBitmapInfo(rawValue: 0), provider: provider,
                                  decode: nil, shouldInterpolate: true, intent: .defaultIntent)
        else { return nil }
        return CIImage(cgImage: image)
    }

    private func bestCandidate(in masks: MLMultiArray, scores: MLMultiArray,
                               points: [MagicSelectionPoint]) -> Int {
        let width = max(1, min(256, Int(resizedSize.width / 4 + 0.5)))
        let height = max(1, min(256, Int(resizedSize.height / 4 + 0.5)))
        let pixelCount = width * height
        var candidates: [(index: Int, score: Float, coverage: Double, mismatches: Int)] = []

        for candidate in 0..<3 {
            var selected = 0
            for y in 0..<height {
                for x in 0..<width where masks[[0, candidate, y, x] as [NSNumber]].floatValue > 0 {
                    selected += 1
                }
            }
            var mismatches = 0
            for point in points {
                let x = min(width - 1, max(0, Int(point.location.x * Double(width))))
                let y = min(height - 1, max(0, Int(point.location.y * Double(height))))
                let isSelected = masks[[0, candidate, y, x] as [NSNumber]].floatValue > 0
                if isSelected != point.includes { mismatches += 1 }
            }
            candidates.append((candidate, scores[candidate].floatValue,
                               Double(selected) / Double(pixelCount), mismatches))
        }

        let usable = candidates.filter { $0.coverage > 0.0005 && $0.coverage < 0.95 }
        let pool = usable.isEmpty ? candidates : usable
        let fewestMismatches = pool.map(\.mismatches).min() ?? 0
        let coherent = pool.filter { $0.mismatches == fewestMismatches }
        let largestCoverage = coherent.map(\.coverage).max() ?? 0
        // Start with the broadest coherent proposal. The user can switch to either
        // tighter proposal, or remove an unwanted area with a negative point.
        let broad = coherent.filter { $0.coverage >= largestCoverage - 0.03 }
        let chosen = broad.max { $0.score < $1.score }?.index ?? coherent.first?.index ?? 0
        return chosen
    }

    private func makeMaskImage(_ masks: MLMultiArray, candidate: Int, alpha: Bool) -> CGImage? {
        let width = max(1, min(256, Int(resizedSize.width / 4 + 0.5)))
        let height = max(1, min(256, Int(resizedSize.height / 4 + 0.5)))
        var rgba = [UInt8](repeating: 0, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width where masks[[0, candidate, y, x] as [NSNumber]].floatValue > 0 {
                let offset = (y * width + x) * 4
                // Premultiplied alpha: red and alpha must carry the same value.
                rgba[offset] = 132
                rgba[offset + 3] = 132
            }
        }
        guard let provider = CGDataProvider(data: Data(rgba) as CFData),
              let color = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                       bytesPerRow: width * 4, space: color,
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: true,
                       intent: .defaultIntent)
    }

    private static func loadModels() throws -> (SendableModel, SendableModel) {
        let configuration = MLModelConfiguration()
        configuration.computeUnits = .all
        func load(_ name: String) throws -> MLModel {
            if let compiled = Bundle.main.url(forResource: name, withExtension: "mlmodelc") {
                return try MLModel(contentsOf: compiled, configuration: configuration)
            }
            if let package = Bundle.main.url(forResource: name, withExtension: "mlpackage", subdirectory: "Models") {
                return try MLModel(contentsOf: MLModel.compileModel(at: package), configuration: configuration)
            }
            throw MagicSelectionError.modelMissing
        }
        return try (SendableModel(load("MobileSAMEncoder")), SendableModel(load("MobileSAMDecoder")))
    }
}
