import Foundation
import CoreImage

/// Explicit two-surface input for partial coverage (not refractive/transmissive glass).
/// Colors are straight, scene-linear-convertible images, coverage is scalar, not confidence.
/// A clean background plate is required: depth + alpha cannot recover hidden radiance.
public struct DepthLayers {
    public let foregroundColor: CIImage
    public let coverage: CIImage
    public let backgroundColor: CIImage
    public let backgroundDepth: CIImage
    public init(foregroundColor: CIImage, coverage: CIImage, backgroundColor: CIImage, backgroundDepth: CIImage) {
        self.foregroundColor=foregroundColor;self.coverage=coverage
        self.backgroundColor=backgroundColor;self.backgroundDepth=backgroundDepth
    }
}
public struct DepthInput {
    public let raw: CIImage
    public let confidence: CIImage?
    public let provenance: String
    public let layers: DepthLayers?
    public init(raw: CIImage, confidence: CIImage? = nil, provenance: String, layers: DepthLayers? = nil) {
        self.raw = raw; self.confidence = confidence; self.provenance = provenance
        self.layers=layers
    }
}

/// A provider supplies registered scalar data, never a color-managed photograph.
/// The renderer normalizes calibrated raw min/max on GPU. Convention: 1 near, 0 far.
public protocol DepthProvider {
    func depth(for image: CIImage) throws -> DepthInput
}

public struct ImportedDepthProvider: DepthProvider {
    public let url: URL
    public let confidenceURL: URL?
    public init(url: URL, confidenceURL: URL? = nil) { self.url = url; self.confidenceURL = confidenceURL }
    public func depth(for image: CIImage) throws -> DepthInput {
        let options: [CIImageOption: Any] = [.colorSpace: NSNull(), .applyOrientationProperty: true]
        guard let raw = CIImage(contentsOf: url, options: options) else { throw LensError.message("Depth map illisible") }
        let a = raw.extent.width / raw.extent.height, b = image.extent.width / image.extent.height
        guard abs(a-b) < 0.001 else { throw LensError.message("Depth map non alignée : ratio différent. Préparer une carte recalée, sans recadrage implicite.") }
        var confidence: CIImage?
        if let url = confidenceURL {
            guard let c = CIImage(contentsOf: url, options: options), c.extent.size == raw.extent.size else {
                throw LensError.message("Confidence illisible ou dimensions différentes")
            }
            confidence = c
        }
        return DepthInput(raw: raw, confidence: confidence, provenance: "Imported: \(url.lastPathComponent); no depth model")
    }
}

/// Injection point for a future offline runner. No model, network or inference implementation.
public struct ExternalDepthProvider: DepthProvider {
    private let load: (CIImage) throws -> DepthInput
    public init(load: @escaping (CIImage) throws -> DepthInput) { self.load = load }
    public func depth(for image: CIImage) throws -> DepthInput { try load(image) }
}
public enum LensError: Error, LocalizedError {
    case message(String)
    public var errorDescription: String? { if case .message(let s) = self { return s }; return nil }
}

public struct LensSettings {
    public var focal: Float = 85
    public var aperture: Float = 1.4
    public var focus: Float = 0.55
    /// Radius in pixels at 960px long edge; scaled identically for all render paths.
    public var maxRadius: Float = 40
    public var nearMeters: Float = 1
    public var farMeters: Float = 12
    public var transition: Float = 0.02
    public var edgeTolerance: Float = 0.025
    public var rawMin: Float = 0
    public var rawMax: Float = 1
    public var inverted = false
    public var bloom: Float = 0
    public var blades: UInt32 = 0
    public var samples: UInt32 = 512
    public var debug: UInt32 = 0 // result, original, raw, normalized, confidence, edges, focus, signed CoC
    public init() {}
    public mutating func preset(_ index: Int) {
        let p: [(Float,Float)] = [(50,1.2),(85,1.4),(135,2)]
        (focal, aperture) = p[max(0,min(2,index))]
    }
    public func radius(depth: Float, width: Int, height: Int) -> Float {
        let z = 1 / (1/farMeters + depth * (1/nearMeters - 1/farMeters))
        let s = 1 / (1/farMeters + focus * (1/nearMeters - 1/farMeters))
        let f = focal / 1000
        let diameter = f*f / (aperture * max(0.001,s-f)) * (z-s)/z
        let deadZone = min(1, max(0,(abs(depth-focus)-transition) / max(0.0001,transition)))
        let t = deadZone*deadZone*(3-2*deadZone)
        return min(maxRadius*Float(max(width,height))/960, abs(diameter)*Float(width)/0.036/2)*t
    }
}

/// Coordinates are normalized in image space, top-left origin, independent of zoom/pan.
public struct DepthStroke {
    public var value: SIMD4<Float>
    public init(x: Float, y: Float, radius: Float, delta: Float) { value = SIMD4(x,y,radius,delta) }
}

public enum ImageCoordinates {
    public static func normalized(point: CGPoint, viewport: CGSize, image: CGSize, zoom: CGFloat, pan: CGSize) -> CGPoint? {
        let scale = min(viewport.width/image.width, viewport.height/image.height)*zoom
        let x = (point.x-viewport.width/2-pan.width)/(image.width*scale)+0.5
        let y = (point.y-viewport.height/2-pan.height)/(image.height*scale)+0.5
        guard (0...1).contains(x), (0...1).contains(y) else { return nil }
        return CGPoint(x:x,y:y)
    }
}
