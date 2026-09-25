import CoreGraphics
import Foundation

struct BeautyBlemishComponentDiagnostic: Sendable {
    let centerX: Double
    let centerY: Double // analysis bitmap, top-first
    let area: Int
    let compactness: Double
    let eccentricity: Double
    let redOpponentMean: Double
    let redOpponentMax: Double
    let pigmentationConfidence: Double
    let localContrast: Double
    let nearbySimilarComponents: Int
    let featureDistance: Double
    let inflammatorySeedMean: Double
    let acceptanceScore: Double
    let redContribution: Double
    let shapeContribution: Double
    let skinContribution: Double
    let pigmentationPenalty: Double
    let repetitionPenalty: Double
    let featurePenalty: Double
    let sizePenalty: Double
    let reason: String
}

/// One-shot, analysis-resolution detector. Its output is cached with the other
/// Beauty mattes; no component traversal occurs during slider rendering.
enum BeautyBlemishDetector {
    struct Result {
        let matte: CGImage
        let stages: [String: CGImage]
        let components: [BeautyBlemishComponentDiagnostic]
    }

    private struct Component {
        var pixels: [Int] = []
        var centerX = 0.0
        var centerY = 0.0
        var seed = 0.0
        var pigment = 0.0
        var redExcess = 0.0
        var redMax = 0.0
        var localContrast = 0.0
        var skin = 0.0
        var redPeak = 0
        var xx = 0.0
        var yy = 0.0
        var xy = 0.0
        var perimeter = 0
    }

    static func generate(source: MaskBitmapSource, fine: MaskBitmapSource,
                         surround: MaskBitmapSource, broad: MaskBitmapSource,
                         skin: CGImage, features: CGImage, faceWidth: CGFloat,
                         diagnostics: Bool) -> Result? {
        let width = source.width, height = source.height, count = width * height
        guard fine.width == width, surround.width == width, broad.width == width,
              fine.height == height, surround.height == height, broad.height == height,
              skin.width == width, skin.height == height,
              features.width == width, features.height == height,
              let data = skin.dataProvider?.data as Data?,
              let featureData = features.dataProvider?.data as Data? else { return nil }
        let maskBytes = [UInt8](data)
        let featureBytes = [UInt8](featureData)
        guard maskBytes.count >= skin.bytesPerRow * height,
              featureBytes.count >= features.bytesPerRow * height else { return nil }
        var skinWeight = [Float](repeating: 0, count: count)
        var seed = [Float](repeating: 0, count: count)
        var pigment = [Float](repeating: 0, count: count)
        var redExcess = [Float](repeating: 0, count: count)
        var contrast = [Float](repeating: 0, count: count)
        var candidate = [Bool](repeating: false, count: count)
        let minimumSkin: Float = 0.08
        for y in 0..<height {
            for x in 0..<width {
                let i = y * width + x
                let skinValue = Float(maskBytes[y * skin.bytesPerRow + x]) / 255
                skinWeight[i] = skinValue
                guard skinValue > minimumSkin else { continue }
                let c = fine.rgb(x: x, y: y)
                let s = surround.rgb(x: x, y: y)
                let b = broad.rgb(x: x, y: y)
                // Opponent red axis around local skin. A red shift with little
                // broadband darkening is inflammatory; a correlated decrease
                // of R, G and B is more consistent with pigmentation.
                let localRed = (c.red - (c.green + c.blue) * 0.5)
                    - (s.red - (s.green + s.blue) * 0.5)
                let wideRed = (c.red - (c.green + c.blue) * 0.5)
                    - (b.red - (b.green + b.blue) * 0.5)
                let opponent = max(localRed, wideRed * 0.85)
                let deltaR = c.red - b.red
                let deltaG = c.green - b.green
                let deltaB = c.blue - b.blue
                let broadDarkening = max(0, -(deltaR + deltaG + deltaB) / 3)
                let redAdvantage = max(0, deltaR - (deltaG + deltaB) * 0.5)
                let pigmentEvidence = smooth(0.015, 0.085, broadDarkening)
                    * (1 - smooth(0.018, 0.085, redAdvantage))
                let ySurround = 0.2126 * s.red + 0.7152 * s.green + 0.0722 * s.blue
                let yBroad = 0.2126 * b.red + 0.7152 * b.green + 0.0722 * b.blue
                let compact = 1 - smooth(0.04, 0.13, abs(ySurround - yBroad))
                let response = smooth(0.012, 0.055, opponent) * compact
                let inflammation = response * (1 - 0.75 * pigmentEvidence)
                    * pow(skinValue, 0.28)
                redExcess[i] = max(0, opponent)
                contrast[i] = abs((0.2126 * c.red + 0.7152 * c.green + 0.0722 * c.blue)
                    - (0.2126 * b.red + 0.7152 * b.green + 0.0722 * b.blue))
                pigment[i] = pigmentEvidence
                seed[i] = inflammation
                candidate[i] = inflammation > 0.20
            }
        }

        // Eight-connected seed objects, independent of their original chroma
        // versus luminance entry path. This also permits a neighborhood test
        // over *components* instead of an insufficient dark-only blur.
        var labels = [Int32](repeating: -1, count: count)
        var components: [Component] = []
        for i in 0..<count where candidate[i] && labels[i] == -1 {
            let label = Int32(components.count)
            var component = Component()
            var queue = [i]
            labels[i] = label
            var head = 0
            while head < queue.count {
                let p = queue[head]; head += 1
                let x = p % width, y = p / width
                component.pixels.append(p)
                component.centerX += Double(x)
                component.centerY += Double(y)
                component.seed += Double(seed[p])
                component.pigment += Double(pigment[p])
                component.redExcess += Double(redExcess[p])
                if Double(redExcess[p]) > component.redMax {
                    component.redMax = Double(redExcess[p])
                    component.redPeak = p
                }
                component.localContrast += Double(contrast[p])
                component.skin += Double(skinWeight[p])
                component.xx += Double(x * x)
                component.yy += Double(y * y)
                component.xy += Double(x * y)
                if x == 0 || !candidate[p - 1] { component.perimeter += 1 }
                if x + 1 == width || !candidate[p + 1] { component.perimeter += 1 }
                if y == 0 || !candidate[p - width] { component.perimeter += 1 }
                if y + 1 == height || !candidate[p + width] { component.perimeter += 1 }
                for ny in max(0, y - 1)...min(height - 1, y + 1) {
                    for nx in max(0, x - 1)...min(width - 1, x + 1) {
                        let q = ny * width + nx
                        if candidate[q] && labels[q] == -1 {
                            labels[q] = label
                            queue.append(q)
                        }
                    }
                }
            }
            let n = Double(component.pixels.count)
            component.centerX /= n; component.centerY /= n
            component.seed /= n; component.pigment /= n
            component.redExcess /= n
            component.localContrast /= n
            component.skin /= n
            components.append(component)
        }

        let radius = max(4, min(14, Int((faceWidth * 0.027).rounded())))
        let clusterRadius = max(18, Double(faceWidth) * 0.20)
        let maxArea = max(120, Int(faceWidth * faceWidth * 0.003))
        let featureDistance = distanceToFeatures(width: width, height: height,
            bytes: featureBytes, rowBytes: features.bytesPerRow)
        var accepted = [Float](repeating: 0, count: count)
        var grown = [Float](repeating: 0, count: count)
        var clusterPigment = pigment
        var stamp = [Int32](repeating: 0, count: count)
        var generation: Int32 = 0
        var componentDiagnostics: [BeautyBlemishComponentDiagnostic] = []
        for component in components {
            let area = component.pixels.count
            var neighbors = 0
            for other in components where !other.pixels.isEmpty {
                if other.pixels.first == component.pixels.first { continue }
                let dx = other.centerX - component.centerX
                let dy = other.centerY - component.centerY
                let areaRatio = Double(other.pixels.count) / Double(area)
                let redDifference = abs(other.redExcess - component.redExcess)
                if dx * dx + dy * dy < clusterRadius * clusterRadius,
                   areaRatio >= 0.25, areaRatio <= 4,
                   redDifference < 0.025,
                   abs(other.pigment - component.pigment) < 0.35 {
                    neighbors += 1
                }
            }
            let repetition = smooth(4, 10, Float(neighbors))
            let pigmentation = max(Float(component.pigment), repetition * 0.95)
            for p in component.pixels { clusterPigment[p] = max(clusterPigment[p], pigmentation) }
            let n = Double(area)
            let vx = max(0, component.xx / n - component.centerX * component.centerX)
            let vy = max(0, component.yy / n - component.centerY * component.centerY)
            let cov = component.xy / n - component.centerX * component.centerY
            let trace = vx + vy
            let root = sqrt(max(0, (vx - vy) * (vx - vy) + 4 * cov * cov))
            let major = max(1e-8, (trace + root) * 0.5)
            let minor = max(0, (trace - root) * 0.5)
            let eccentricity = sqrt(max(0, 1 - minor / major))
            let compactness = min(1, 4 * Double.pi * n /
                Double(max(1, component.perimeter * component.perimeter)))
            let center = min(count - 1, max(0,
                Int(component.centerY.rounded()) * width + Int(component.centerX.rounded())))
            let redContribution = 0.35 * smooth(0.04, 0.085, Float(component.redMax))
                + 0.35 * Float(component.seed)
            let shapeContribution = 0.15 * Float(compactness)
            let skinContribution = 0.15 * Float(component.skin)
            let pigmentationPenalty = 0.30 * Float(component.pigment)
            let repetitionPenalty = 0.25 * repetition
            let featurePenalty = 0.20 * (1 - smooth(3, 12, featureDistance[center]))
            // Large connected seed objects can contain a true lesion joined to
            // a weak facial edge. Size contributes a small cost, never a veto.
            let sizePenalty = 0.08 * smooth(1, 2, Float(area) / Float(maxArea))
            let tinyPenalty: Float = area == 1 ? 0.08 : 0
            let confidence = max(0, min(1, redContribution + shapeContribution
                + skinContribution - pigmentationPenalty - repetitionPenalty
                - featurePenalty - sizePenalty - tinyPenalty))
            let acceptedComponent = confidence > 0.42
            let reason = acceptedComponent
                ? (area > maxArea ? "accepted_localized_inflammatory_core" : "accepted_combined_score")
                : "combined_score_below_0.42"
            if diagnostics {
                componentDiagnostics.append(BeautyBlemishComponentDiagnostic(
                    centerX: component.centerX, centerY: component.centerY,
                    area: area, compactness: compactness, eccentricity: eccentricity,
                    redOpponentMean: component.redExcess,
                    redOpponentMax: component.redMax,
                    pigmentationConfidence: component.pigment,
                    localContrast: component.localContrast,
                    nearbySimilarComponents: neighbors,
                    featureDistance: Double(featureDistance[center]),
                    inflammatorySeedMean: component.seed,
                    acceptanceScore: Double(confidence),
                    redContribution: Double(redContribution),
                    shapeContribution: Double(shapeContribution),
                    skinContribution: Double(skinContribution),
                    pigmentationPenalty: Double(pigmentationPenalty),
                    repetitionPenalty: Double(repetitionPenalty),
                    featurePenalty: Double(featurePenalty),
                    sizePenalty: Double(sizePenalty + tinyPenalty),
                    reason: reason))
            }
            guard acceptedComponent else { continue }
            generation &+= 1
            var queue: [(Int, Int)] = []
            // The oversized object's inflammatory peak is the accepted seed,
            // not its whole connected skirt. The existing grower is unchanged.
            let acceptedPixels: [Int]
            if area > maxArea {
                let peakX = component.redPeak % width
                let peakY = component.redPeak / width
                let coreRadius = max(3, min(10, Int((faceWidth * 0.025).rounded())))
                let core = component.pixels.filter { p in
                    let dx = p % width - peakX
                    let dy = p / width - peakY
                    return dx * dx + dy * dy <= coreRadius * coreRadius
                        && redExcess[p] >= max(0.05, Float(component.redMax) * 0.65)
                        && seed[p] >= max(0.45, Float(component.seed))
                }
                acceptedPixels = core.isEmpty ? [component.redPeak] : core
            } else {
                acceptedPixels = component.pixels
            }
            for p in acceptedPixels {
                accepted[p] = max(accepted[p], confidence)
                grown[p] = max(grown[p], confidence)
                stamp[p] = generation
                queue.append((p, 0))
            }
            var head = 0
            while head < queue.count {
                let (p, distance) = queue[head]; head += 1
                guard distance < radius else { continue }
                let x = p % width, y = p / width
                for ny in max(0, y - 1)...min(height - 1, y + 1) {
                    for nx in max(0, x - 1)...min(width - 1, x + 1) {
                        let q = ny * width + nx
                        guard stamp[q] != generation, skinWeight[q] > minimumSkin else { continue }
                        stamp[q] = generation
                        // Region affinity is relative to the accepted object's
                        // red opponent vector. The first two pixels can bridge
                        // a low-response center, but never a skin/feature gap.
                        let affinity = min(1, redExcess[q] /
                            max(0.004, Float(component.redExcess) * 0.30))
                        guard affinity > (distance < 2 ? 0.08 : 0.22) else { continue }
                        let nextDistance = distance + 1
                        let falloff = 1 - Float(nextDistance) / Float(radius + 1)
                        let value = confidence * falloff * max(0.25, affinity)
                            * pow(skinWeight[q], 0.25) * (1 - pigment[q] * 0.70)
                        grown[q] = max(grown[q], value)
                        queue.append((q, nextDistance))
                    }
                }
            }
        }

        // The matte remains continuous around the accepted seeds. The small
        // neighborhood average removes raster stair steps without filling a
        // rejected component or crossing a zero-confidence feature boundary.
        var final = grown
        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                let i = y * width + x
                guard grown[i] > 0 else { continue }
                let average = (grown[i] * 4 + grown[i - 1] + grown[i + 1]
                    + grown[i - width] + grown[i + width]) / 8
                final[i] = max(0, min(1, average * skinWeight[i]))
            }
        }
        guard let matte = source.grayImage(bytes(final)) else { return nil }
        var stages: [String: CGImage] = [:]
        if diagnostics {
            stages["inflammatory_seed_confidence"] = source.grayImage(bytes(seed))
            stages["pigmentation_freckle_confidence"] = source.grayImage(bytes(clusterPigment))
            stages["accepted_seeds"] = source.grayImage(bytes(accepted))
            stages["grown_regions"] = source.grayImage(bytes(grown))
            stages["final_soft_matte"] = matte
        }
        return Result(matte: matte, stages: stages,
                      components: componentDiagnostics)
    }

    private static func smooth(_ lo: Float, _ hi: Float, _ value: Float) -> Float {
        let t = max(0, min(1, (value - lo) / (hi - lo)))
        return t * t * (3 - 2 * t)
    }

    private static func bytes(_ values: [Float]) -> [UInt8] {
        values.map { UInt8((max(0, min(1, $0)) * 255).rounded()) }
    }

    private static func distanceToFeatures(width: Int, height: Int,
                                           bytes: [UInt8], rowBytes: Int) -> [Float] {
        var distance = [Float](repeating: 1_000, count: width * height)
        for y in 0..<height {
            for x in 0..<width where bytes[y * rowBytes + x] > 127 {
                distance[y * width + x] = 0
            }
        }
        for y in 0..<height {
            for x in 0..<width {
                let i = y * width + x
                if x > 0 { distance[i] = min(distance[i], distance[i - 1] + 1) }
                if y > 0 { distance[i] = min(distance[i], distance[i - width] + 1) }
                if x > 0 && y > 0 {
                    distance[i] = min(distance[i], distance[i - width - 1] + 1.4142)
                }
                if x + 1 < width && y > 0 {
                    distance[i] = min(distance[i], distance[i - width + 1] + 1.4142)
                }
            }
        }
        for y in (0..<height).reversed() {
            for x in (0..<width).reversed() {
                let i = y * width + x
                if x + 1 < width { distance[i] = min(distance[i], distance[i + 1] + 1) }
                if y + 1 < height { distance[i] = min(distance[i], distance[i + width] + 1) }
                if x + 1 < width && y + 1 < height {
                    distance[i] = min(distance[i], distance[i + width + 1] + 1.4142)
                }
                if x > 0 && y + 1 < height {
                    distance[i] = min(distance[i], distance[i + width - 1] + 1.4142)
                }
            }
        }
        return distance
    }
}
