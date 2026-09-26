import Foundation
import CoreImage

/// A frozen Core Image Auto recipe. The source image and its downstream Lumora edits
/// are deliberately absent: reopening a document never reruns Apple's analysis.
struct CoreImageAutoState: Codable, Sendable, Equatable {
    static let engineVersion = 1
    var version = engineVersion
    var osVersion: String
    var filters: [Filter]

    struct Filter: Codable, Sendable, Equatable {
        var name: String
        var parameters: [String: Parameter]
        /// Securely archived Core Image filter, without its input image. Some Auto
        /// filters carry private state not represented by their public inputKeys.
        var archive: Data?
    }

    enum Parameter: Codable, Sendable, Equatable {
        case number(Double)
        case vector([Double])
        case color([Double])
    }
}

enum CoreImageAutoError: Error {
    case unsupportedParameter(String, String)
    case unavailableFilter(String)
    case outputMissing(String)
}

enum CoreImageAutoEngine {
    // Explicit photometric allowlist: an unexpected geometric filter can never
    // alter crop, perspective, orientation or red-eye state.
    static let photometricFilters: Set<String> = [
        "CIColorControls", "CIExposureAdjust", "CIVibrance", "CIHighlightShadowAdjust",
        "CIToneCurve", "CILinearToSRGBToneCurve", "CISRGBToneCurveToLinear",
        "CIColorMatrix", "CIWhitePointAdjust", "CITemperatureAndTint", "CIGammaAdjust",
        "CIColorPolynomial", "CIColorCrossPolynomial", "CIColorClamp", "CIColorInvert",
        "CIFaceBalance"
    ]

    struct Capture {
        var state: CoreImageAutoState
        var returned: [String]
        var excluded: [String]
    }

    static func capture(_ input: CIImage) throws -> Capture {
        let returned = input.autoAdjustmentFilters(options: [.crop: false, .redEye: false,
                                                             .level: true, .enhance: true])
        var selected: [CoreImageAutoState.Filter] = []
        var excluded: [String] = []
        for filter in returned {
            guard photometricFilters.contains(filter.name), CIFilter(name: filter.name) != nil else {
                excluded.append(filter.name)
                continue
            }
            var parameters: [String: CoreImageAutoState.Parameter] = [:]
            var unsupportedKey: String?
            for key in filter.inputKeys where key != kCIInputImageKey {
                guard let value = filter.value(forKey: key) else { continue }
                if let vector = value as? CIVector {
                    parameters[key] = .vector((0..<vector.count).map { Double(vector.value(at: $0)) })
                } else if let color = value as? CIColor {
                    parameters[key] = .color([Double(color.red), Double(color.green), Double(color.blue), Double(color.alpha)])
                } else if let number = value as? NSNumber {
                    parameters[key] = .number(number.doubleValue)
                } else {
                    unsupportedKey = key
                    break
                }
            }
            if let unsupportedKey {
                excluded.append("\(filter.name) (unsupported parameter: \(unsupportedKey))")
                continue
            }
            // Auto normally returns an unbound filter. Never persist source pixels.
            filter.setValue(nil, forKey: kCIInputImageKey)
            let archive = try NSKeyedArchiver.archivedData(withRootObject: filter, requiringSecureCoding: true)
            selected.append(.init(name: filter.name, parameters: parameters, archive: archive))
        }
        return .init(state: CoreImageAutoState(osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
                                             filters: selected),
                     returned: returned.map(\.name), excluded: excluded)
    }

    static func apply(_ recipe: CoreImageAutoState, to input: CIImage) throws -> CIImage {
        var image = input
        for item in recipe.filters {
            guard photometricFilters.contains(item.name) else {
                throw CoreImageAutoError.unavailableFilter(item.name)
            }
            let filter: CIFilter
            if let archive = item.archive {
                guard let restored = try NSKeyedUnarchiver.unarchivedObject(ofClass: CIFilter.self, from: archive),
                      restored.name == item.name else { throw CoreImageAutoError.unavailableFilter(item.name) }
                filter = restored
            } else if let reconstructed = CIFilter(name: item.name) {
                filter = reconstructed
            } else {
                throw CoreImageAutoError.unavailableFilter(item.name)
            }
            filter.setValue(image, forKey: kCIInputImageKey)
            // Archived filters already carry their exact state. The readable
            // parameters are a fallback for older recipes without an archive.
            if item.archive == nil { for (key, parameter) in item.parameters {
                switch parameter {
                case .number(let value): filter.setValue(NSNumber(value: value), forKey: key)
                case .vector(let values): filter.setValue(CIVector(values: values.map { CGFloat($0) }, count: values.count), forKey: key)
                case .color(let values):
                    guard values.count == 4 else { throw CoreImageAutoError.unsupportedParameter(item.name, key) }
                    filter.setValue(CIColor(red: CGFloat(values[0]), green: CGFloat(values[1]),
                                            blue: CGFloat(values[2]), alpha: CGFloat(values[3])), forKey: key)
                }
            } }
            guard let output = filter.outputImage else { throw CoreImageAutoError.outputMissing(item.name) }
            image = output.cropped(to: image.extent)
        }
        return image
    }
}
