import CoreImage

/// Reuses the cached Vision/Beauty masks; no colour or texture is synthesized.
struct DepthLightingMaterials {
    let skin: CIImage?
    let eyes: CIImage?
    init(masks: BeautyMasks) {
        skin = masks.skin.map { CIImage(cgImage:$0, options:[.colorSpace:NSNull()]) }
        eyes = masks.eyes.map { CIImage(cgImage:$0, options:[.colorSpace:NSNull()]) }
    }
    init(skin: CIImage?, eyes: CIImage?) { self.skin=skin; self.eyes=eyes }
}
