import Foundation
import CoreImage

struct CreativeXMPRenderer: CreativeEffectRendering {
    private static let cubes = XMPCubeCache()

    func apply(_ image: CIImage, effect: CreativeEffect) throws -> CIImage {
        guard let preset = effect.importedXMP else { return image }
        let developed = try DevelopmentRenderer.apply(image, state: preset.editState) { state in
            let encoder = JSONEncoder(); encoder.outputFormatting = .sortedKeys
            let key = try encoder.encode(state) as NSData
            if let cached = Self.cubes.storage.object(forKey: key) { return cached as Data }
            let data = try RenderEngine.makeCube(state)
            Self.cubes.storage.setObject(data as NSData, forKey: key)
            return data
        }
        return try FilmGrainEngine.apply(developed, settings: preset.grain)
    }
}

/// NSCache supports concurrent lookup/insertion. The reference and configuration never change.
private final class XMPCubeCache: @unchecked Sendable {
    let storage: NSCache<NSData, NSData>
    init() {
        storage = NSCache<NSData, NSData>()
        storage.countLimit = 32
    }
}
