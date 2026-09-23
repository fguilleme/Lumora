import Foundation
import CoreGraphics
import Vision

enum GeometryAnalysisError: LocalizedError {
    case noHorizon
    case noPerspective

    var errorDescription: String? {
        switch self {
        case .noHorizon:
            "Vision found no sufficiently reliable horizon in this photo."
        case .noPerspective:
            "Vision found no sufficiently reliable rectangular structure for perspective correction."
        }
    }
}

/// Runs Vision outside the main actor and returns a correction compatible with GeometrySettings.
actor GeometryAnalyzer {
    func straightenAngle(from image: CGImage) async throws -> Double {
        try Task.checkCancellation()
        let handler = ImageRequestHandler(image, orientation: .up)
        guard let observation = try await handler.perform(DetectHorizonRequest()),
              observation.confidence >= 0.2 else {
            throw GeometryAnalysisError.noHorizon
        }
        try Task.checkCancellation()
        let radians = observation.angle.converted(to: .radians).value
        return GeometryAnalysis.straightenDegrees(horizonRadians: radians)
    }

    func perspectiveCorrection(from image: CGImage) async throws -> GeometryAnalysis.PerspectiveCorrection {
        try Task.checkCancellation()
        var request = DetectRectanglesRequest()
        request.minimumSize = 0.08
        request.minimumConfidence = 0.4
        request.maximumObservations = 16
        request.quadratureToleranceDegrees = 35
        let handler = ImageRequestHandler(image, orientation: .up)
        let observations = try await handler.perform(request)
        try Task.checkCancellation()
        let quadrilaterals = observations.map {
            GeometryAnalysis.Quadrilateral(
                topLeft: CGPoint(x: $0.topLeft.x, y: $0.topLeft.y),
                topRight: CGPoint(x: $0.topRight.x, y: $0.topRight.y),
                bottomRight: CGPoint(x: $0.bottomRight.x, y: $0.bottomRight.y),
                bottomLeft: CGPoint(x: $0.bottomLeft.x, y: $0.bottomLeft.y),
                confidence: Double($0.confidence)
            )
        }
        guard let correction = GeometryAnalysis.perspectiveCorrection(from: quadrilaterals) else {
            throw GeometryAnalysisError.noPerspective
        }
        return correction
    }
}
