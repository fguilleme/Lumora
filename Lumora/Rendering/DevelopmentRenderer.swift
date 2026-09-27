import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation

/// Shared development graph for base adjustments, masks, and imported Creative looks.
enum DevelopmentRenderer {
    static func apply(_ input: CIImage, state: EditState, deferDetail: Bool = false,
                      cube: (EditState) throws -> Data) throws -> CIImage {
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
        image = try HighlightRecoveryRenderer.recover(image, highlights: state.highlights)
        var colorState = state
        if colorState.highlights < 0 { colorState.highlights = 0 }
        colorState.temperature = 0; colorState.tint = 0; colorState.exposure = 0
        colorState.effects = EffectsSettings()
        colorState.detail = DetailSettings()
        colorState.beauty = BeautyState()
        colorState.depthLens = nil
        colorState.depthLighting = nil
        colorState.optics = OpticsSettings()
        colorState.geometry = GeometrySettings()
        colorState.coreImageAuto = nil
        colorState.masks = []
        colorState.creative = CreativeEffectStack()
        if colorState != EditState() {
            let extended = image
            image = try HighlightRecoveryRenderer.bounded(image)
            let data = try cube(colorState)
            guard let space = CGColorSpace(name: CGColorSpace.sRGB),
                  let filter = CIFilter(name: "CIColorCubeWithColorSpace", parameters: [
                    kCIInputImageKey: image, "inputCubeDimension": 32,
                    "inputCubeData": data, "inputColorSpace": space
                  ]), let output = filter.outputImage else { throw PhotoError.renderFailed }
            image = try HighlightRecoveryRenderer.restoring(output, from: extended)
        }
        image = try EffectsRenderer.applyBeforeDetail(image, settings: state.effects)
        if deferDetail { return image }
        image = try DetailRenderer.apply(image, settings: state.detail)
        var finishing = state.effects; finishing.grain = 0
        image = try EffectsRenderer.applyFinishing(image, settings: finishing)
        return image
    }
}
