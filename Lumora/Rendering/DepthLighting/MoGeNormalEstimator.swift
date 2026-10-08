import CoreImage
import CoreML

/// MoGe-2 ViT-S, independently estimated surface orientations. DA2 remains the
/// depth source for Depth Lens and lighting reach. Owned by RenderEngine's actor.
final class MoGeNormalEstimator {
    private var model: MLModel?
    private let modelURL: URL?
    private(set) var inferenceCount = 0

    init(modelURL: URL? = nil) { self.modelURL = modelURL }

    func estimate(_ source: CIImage, context: CIContext) throws -> CIImage {
        try Task.checkCancellation()
        if model == nil {
            #if SWIFT_PACKAGE
            let bundle = Bundle.module
            #else
            let bundle = Bundle.main
            #endif
            let url: URL
            if let modelURL { url = modelURL }
            else if let compiled = bundle.url(forResource: "MoGeNormals", withExtension: "mlmodelc") { url = compiled }
            else if let package = bundle.url(forResource: "MoGeNormals", withExtension: "mlpackage") {
                url = try MLModel.compileModel(at: package)
            } else { throw NSError(domain: "Lumora.Relighting", code: 1,
                userInfo: [NSLocalizedDescriptionKey: String(localized: "Surface lighting model is missing.")]) }
            let configuration = MLModelConfiguration()
            configuration.computeUnits = .all
            model = try MLModel(contentsOf: url, configuration: configuration)
        }
        guard let model,
              let shape = model.modelDescription.inputDescriptionsByName["image"]?.multiArrayConstraint?.shape,
              shape.count == 4, shape[0].intValue == 1, shape[1].intValue == 3 else { throw PhotoError.renderFailed }
        let h = shape[2].intValue, w = shape[3].intValue
        // Aspect-fit with replicated borders; never stretch a portrait's facial geometry.
        let image = source.transformed(by: CGAffineTransform(translationX: -source.extent.minX, y: -source.extent.minY))
        let scale = min(CGFloat(w)/image.extent.width, CGFloat(h)/image.extent.height)
        let fitted = CGRect(x: (CGFloat(w)-image.extent.width*scale)/2,
                            y: (CGFloat(h)-image.extent.height*scale)/2,
                            width: image.extent.width*scale, height: image.extent.height*scale)
        let resized = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            .transformed(by: CGAffineTransform(translationX: fitted.minX, y: fitted.minY)).clampedToExtent()
        var rgba = [Float](repeating: 0, count: w*h*4)
        rgba.withUnsafeMutableBytes { context.render(resized, toBitmap: $0.baseAddress!, rowBytes: w*16,
            bounds: CGRect(x: 0, y: 0, width: w, height: h), format: .RGBAf,
            colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!) }
        let tensor = try MLMultiArray(shape: shape, dataType: .float32)
        let input = tensor.dataPointer.assumingMemoryBound(to: Float.self)
        let strides = tensor.strides.map(\.intValue)
        for y in 0..<h { for x in 0..<w { for c in 0..<3 {
            input[c*strides[1]+y*strides[2]+x*strides[3]] = min(1, max(0, rgba[(y*w+x)*4+c]))
        } } }
        let prediction = try model.prediction(from: MLDictionaryFeatureProvider(dictionary: ["image": tensor]))
        try Task.checkCancellation()
        guard let normals = prediction.featureValue(for: "normal")?.multiArrayValue,
              let mask = prediction.featureValue(for: "mask")?.multiArrayValue,
              normals.shape.map(\.intValue) == [1,h,w,3], mask.shape.map(\.intValue) == [1,h,w] else {
            throw PhotoError.renderFailed
        }
        let ns = normals.strides.map(\.intValue), ms = mask.strides.map(\.intValue)
        func scalar(_ array: MLMultiArray, _ index: Int) -> Float {
            switch array.dataType {
            case .float32: array.dataPointer.assumingMemoryBound(to: Float.self)[index]
            case .float16: Float(Float16(bitPattern: array.dataPointer.assumingMemoryBound(to: UInt16.self)[index]))
            case .double: Float(array.dataPointer.assumingMemoryBound(to: Double.self)[index])
            default: array[index].floatValue
            }
        }
        for y in 0..<h { for x in 0..<w {
            let i = (y*w+x)*4, n = y*ns[1]+x*ns[2]
            let confidence = scalar(mask, y*ms[1]+x*ms[2])
            let nx = scalar(normals,n), ny = scalar(normals,n+ns[3]), nz = scalar(normals,n+2*ns[3])
            let length = sqrt(nx*nx+ny*ny+nz*nz)
            let valid = confidence.isFinite && confidence > 0.5 && length.isFinite && length > 0.1
            // MoGe uses x right/y down/z forward, matching the lighting shader.
            // Encode vectors as premultiplied RGB, with zero alpha for invalid regions.
            rgba[i] = valid ? (nx/length+1)*0.5 : 0
            rgba[i+1] = valid ? (ny/length+1)*0.5 : 0
            rgba[i+2] = valid ? (nz/length+1)*0.5 : 0
            rgba[i+3] = valid ? 1 : 0
        } }
        inferenceCount += 1
        return CIImage(bitmapData: rgba.withUnsafeBytes { Data($0) }, bytesPerRow: w*16,
            size: CGSize(width: w, height: h), format: .RGBAf, colorSpace: nil)
            .cropped(to: fitted).transformed(by: CGAffineTransform(translationX: -fitted.minX, y: -fitted.minY))
    }
}
