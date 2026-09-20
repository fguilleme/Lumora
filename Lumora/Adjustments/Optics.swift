import Foundation
import CoreImage
import CoreImage.CIFilterBuiltins

struct OpticsSettings: Codable, Sendable, Equatable {
    var profileCorrection = true
    var distortion = 0.0
    var chromaticAberration = 0.0
    var lensVignette = 0.0

    private enum CodingKeys: String, CodingKey { case profileCorrection, distortion, chromaticAberration, lensVignette }
    init() {}
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        profileCorrection = try values.decodeIfPresent(Bool.self, forKey: .profileCorrection) ?? true
        distortion = try values.decodeIfPresent(Double.self, forKey: .distortion) ?? 0
        chromaticAberration = try values.decodeIfPresent(Double.self, forKey: .chromaticAberration) ?? 0
        lensVignette = try values.decodeIfPresent(Double.self, forKey: .lensVignette) ?? 0
        self = validated
    }
    var validated: Self {
        var value = self
        for adjustment in OpticsAdjustment.allCases { value[adjustment] = self[adjustment] }
        return value
    }
    var hasManualCorrections: Bool { distortion != 0 || chromaticAberration != 0 || lensVignette != 0 }
    subscript(_ adjustment: OpticsAdjustment) -> Double {
        get { self[keyPath: adjustment.keyPath] }
        set {
            self[keyPath: adjustment.keyPath] = newValue.isFinite
                ? min(adjustment.range.upperBound, max(adjustment.range.lowerBound, newValue)) : 0
        }
    }
}

enum OpticsAdjustment: String, CaseIterable, Sendable, Identifiable {
    case distortion, chromaticAberration, lensVignette
    var id: String { rawValue }
    var title: String {
        switch self {
        case .distortion: "Distorsion"
        case .chromaticAberration: "Aberration chromatique"
        case .lensVignette: "Vignetage optique"
        }
    }
    var range: ClosedRange<Double> { self == .lensVignette ? 0...100 : -100...100 }
    var keyPath: WritableKeyPath<OpticsSettings, Double> {
        switch self {
        case .distortion: \.distortion
        case .chromaticAberration: \.chromaticAberration
        case .lensVignette: \.lensVignette
        }
    }
}

struct OpticsAvailability: Sendable, Equatable {
    var profileSupported = false
    var camera: String?
    var lens: String?
}

enum OpticsRenderer {
    static func apply(_ input: CIImage, settings: OpticsSettings) throws -> CIImage {
        let settings = settings.validated
        guard settings.hasManualCorrections else { return input }
        let extent = input.extent
        var image = input

        if settings.distortion != 0 {
            let filter = CIFilter.pinchDistortion()
            filter.inputImage = image.clampedToExtent()
            filter.center = CGPoint(x: extent.midX, y: extent.midY)
            filter.radius = Float(hypot(extent.width, extent.height) * 0.52)
            filter.scale = Float(settings.distortion / 100 * 0.28)
            guard let output = filter.outputImage else { throw PhotoError.renderFailed }
            image = output.cropped(to: extent)
        }
        if settings.chromaticAberration != 0 {
            image = try correctChromaticAberration(image, amount: settings.chromaticAberration, extent: extent)
        }
        if settings.lensVignette > 0 {
            let filter = CIFilter.vignette()
            filter.inputImage = image
            filter.intensity = Float(-settings.lensVignette / 100 * 1.35)
            filter.radius = Float(max(extent.width, extent.height) * 0.72)
            guard let output = filter.outputImage else { throw PhotoError.renderFailed }
            image = output.cropped(to: extent)
        }
        return image
    }

    private static func correctChromaticAberration(_ input: CIImage, amount: Double,
                                                    extent: CGRect) throws -> CIImage {
        let delta = amount / 100 * 0.006
        let red = try channel(input, vector: CIVector(x: 1, y: 0, z: 0, w: 0), extent: extent,
                              scale: 1 - delta)
        let green = try channel(input, vector: CIVector(x: 0, y: 1, z: 0, w: 0), extent: extent, scale: 1)
        let blue = try channel(input, vector: CIVector(x: 0, y: 0, z: 1, w: 0), extent: extent,
                               scale: 1 + delta)
        var result = red
        for component in [green, blue] {
            let add = CIFilter.additionCompositing()
            add.inputImage = component
            add.backgroundImage = result
            guard let output = add.outputImage else { throw PhotoError.renderFailed }
            result = output
        }
        let preserveAlpha = CIFilter.sourceInCompositing()
        preserveAlpha.inputImage = result
        preserveAlpha.backgroundImage = input
        guard let output = preserveAlpha.outputImage else { throw PhotoError.renderFailed }
        return output.cropped(to: extent)
    }

    private static func channel(_ input: CIImage, vector: CIVector, extent: CGRect,
                                scale: Double) throws -> CIImage {
        let matrix = CIFilter.colorMatrix()
        matrix.inputImage = input
        matrix.rVector = CIVector(x: vector.x, y: 0, z: 0, w: 0)
        matrix.gVector = CIVector(x: 0, y: vector.y, z: 0, w: 0)
        matrix.bVector = CIVector(x: 0, y: 0, z: vector.z, w: 0)
        matrix.aVector = CIVector(x: 0, y: 0, z: 0, w: 1)
        guard var output = matrix.outputImage else { throw PhotoError.renderFailed }
        if scale != 1 {
            let transform = CGAffineTransform(a: scale, b: 0, c: 0, d: scale,
                                              tx: extent.midX * (1 - scale),
                                              ty: extent.midY * (1 - scale))
            output = output.clampedToExtent().transformed(by: transform)
        }
        return output.cropped(to: extent)
    }
}
