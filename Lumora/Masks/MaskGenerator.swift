import Foundation
import CoreGraphics
import CoreImage
import ImageIO
import UniformTypeIdentifiers
import Vision

enum MaskGenerationError: LocalizedError {
    case noForeground, noPerson, noFace, noSky, noSkin, encodingFailed

    var errorDescription: String? {
        switch self {
        case .noForeground: "Vision n’a détecté aucun sujet distinct dans cette photographie."
        case .noPerson: "Vision n’a détecté aucune personne dans cette photographie."
        case .noFace: "Vision n’a détecté aucun visage dans cette photographie."
        case .noSky: "Lumora n’a détecté aucune zone de ciel suffisamment fiable dans cette photographie."
        case .noSkin: "Lumora a besoin d’au moins un visage visible pour identifier les teintes de peau de cette photographie."
        case .encodingFailed: "Le masque détecté n’a pas pu être enregistré."
        }
    }
}

/// Runs Vision away from the main actor and returns a portable mask embedded in EditState.
actor MaskGenerator {
    private let context = CIContext(options: [.cacheIntermediates: false])

    func generate(_ kind: SmartMaskKind, from image: CGImage) async throws -> GeneratedMask {
        try Task.checkCancellation()
        if kind == .sky {
            guard let bitmap = SkyMaskGenerator.makeMask(from: image) else {
                throw MaskGenerationError.noSky
            }
            return try encoded(CIImage(cgImage: bitmap), kind: kind)
        }
        let handler = ImageRequestHandler(image, orientation: .up)
        if kind == .face || kind == .skin {
            let faces = try await handler.perform(DetectFaceRectanglesRequest())
            try Task.checkCancellation()
            guard !faces.isEmpty else {
                throw kind == .skin ? MaskGenerationError.noSkin : MaskGenerationError.noFace
            }
            if kind == .skin {
                let regions = faces.map { $0.boundingBox.verticallyFlipped().cgRect }
                guard let bitmap = SkinMaskGenerator.makeMask(from: image, faceRegions: regions) else {
                    throw MaskGenerationError.noSkin
                }
                let extent = CGRect(x: 0, y: 0, width: bitmap.width, height: bitmap.height)
                let softened = CIImage(cgImage: bitmap)
                    .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 1.2])
                    .cropped(to: extent)
                return try encoded(softened, kind: kind)
            } else {
                guard let mask = Self.faceMask(faces, imageSize: CGSize(width: image.width, height: image.height))
                else { throw MaskGenerationError.encodingFailed }
                return try encoded(mask, kind: kind)
            }
        }

        let result: InstanceMaskObservation?
        switch kind {
        case .subject, .background:
            result = try await handler.perform(GenerateForegroundInstanceMaskRequest())
        case .person:
            result = try await handler.perform(GeneratePersonInstanceMaskRequest())
        case .face, .sky, .skin:
            preconditionFailure("Ce masque est traité avant la segmentation d’instances.")
        }
        try Task.checkCancellation()
        guard let observation = result, !observation.allInstances.isEmpty else {
            throw kind == .person ? MaskGenerationError.noPerson : MaskGenerationError.noForeground
        }
        let buffer = try observation.generateScaledMask(
            for: observation.allInstances, scaledToImageFrom: handler
        )
        var mask = CIImage(cvPixelBuffer: buffer)
        if kind == .background { mask = mask.applyingFilter("CIColorInvert") }
        return try encoded(mask, kind: kind)
    }

    private func encoded(_ mask: CIImage, kind: SmartMaskKind) throws -> GeneratedMask {
        let extent = mask.extent.integral
        guard let gray = CGColorSpace(name: CGColorSpace.linearGray),
              let bitmap = context.createCGImage(mask, from: extent, format: .L8, colorSpace: gray)
        else { throw MaskGenerationError.encodingFailed }

        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data, UTType.png.identifier as CFString, 1, nil
        ) else { throw MaskGenerationError.encodingFailed }
        CGImageDestinationAddImage(destination, bitmap, nil)
        guard CGImageDestinationFinalize(destination) else { throw MaskGenerationError.encodingFailed }
        try Task.checkCancellation()
        return GeneratedMask(kind: kind, pngData: data as Data,
                             width: bitmap.width, height: bitmap.height).validated
    }

    /// Face detection yields rectangles rather than semantic mattes. Convert every rectangle into
    /// a slightly enlarged, feathered ellipse and combine them with a lightening blend.
    private static func faceMask(_ faces: [FaceObservation], imageSize: CGSize) -> CIImage? {
        let longestSide = max(imageSize.width, imageSize.height)
        guard longestSide > 0 else { return nil }
        let scale = min(1, 2_048 / longestSide)
        let size = CGSize(width: max(1, (imageSize.width * scale).rounded()),
                          height: max(1, (imageSize.height * scale).rounded()))
        let width = Int(size.width), height = Int(size.height)
        guard let gray = CGColorSpace(name: CGColorSpace.linearGray),
              let bitmap = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                     bytesPerRow: width, space: gray,
                                     bitmapInfo: CGImageAlphaInfo.none.rawValue),
              let gradient = CGGradient(colorsSpace: gray,
                                        colors: [CGColor(gray: 1, alpha: 1),
                                                 CGColor(gray: 1, alpha: 1),
                                                 CGColor(gray: 0, alpha: 1)] as CFArray,
                                        locations: [0, 0.78, 1])
        else { return nil }

        bitmap.setFillColor(CGColor(gray: 0, alpha: 1))
        bitmap.fill(CGRect(origin: .zero, size: size))
        bitmap.setBlendMode(.lighten)
        for face in faces {
            var rect = face.boundingBox.toImageCoordinates(size, origin: .lowerLeft)
            rect = rect.insetBy(dx: -rect.width * 0.18, dy: -rect.height * 0.28)
            rect = rect.offsetBy(dx: 0, dy: rect.height * 0.04)
            guard rect.width > 0, rect.height > 0 else { continue }
            bitmap.saveGState()
            bitmap.translateBy(x: rect.midX, y: rect.midY)
            bitmap.scaleBy(x: rect.width / 2, y: rect.height / 2)
            bitmap.addEllipse(in: CGRect(x: -1, y: -1, width: 2, height: 2))
            bitmap.clip()
            bitmap.drawRadialGradient(gradient, startCenter: .zero, startRadius: 0,
                                      endCenter: .zero, endRadius: 1, options: [])
            bitmap.restoreGState()
        }
        guard let image = bitmap.makeImage() else { return nil }
        return CIImage(cgImage: image)
    }
}
