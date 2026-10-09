import Foundation

enum SimilarityMaskRasterizer {
    /// Four-neighbour propagation cannot jump across a diagonal gap or leave
    /// the ellipse to reach a disconnected island. Distances encode Delta E / 100.
    static func coverage(distances: [UInt8], width: Int, height: Int,
                         seedX: Int, seedY: Int, centerX: Double, centerY: Double,
                         radiusX: Double, radiusY: Double, tolerance: Double,
                         feather: Double, connected: Bool) -> [UInt8]? {
        guard width > 0, height > 0, width <= 2048, height <= 2048,
              distances.count == width * height,
              (0..<width).contains(seedX), (0..<height).contains(seedY),
              [centerX, centerY, radiusX, radiusY, tolerance, feather].allSatisfy(\.isFinite),
              radiusX > 0, radiusY > 0 else { return nil }
        let threshold = (0.5 + min(100, max(0, tolerance)) * 0.6) * 2.55
        let softness = min(threshold, 2.55) // preserve full coverage at the reference color
        let fade = min(1, max(0, feather / 100))
        var candidates = [UInt8](repeating: 0, count: distances.count)
        for y in 0..<height {
            let dy = ((Double(y) + 0.5) / Double(height) - centerY) / radiusY
            for x in 0..<width {
                let dx = ((Double(x) + 0.5) / Double(width) - centerX) / radiusX
                let radius = sqrt(dx * dx + dy * dy)
                let index = y * width + x
                guard radius < 1, Double(distances[index]) <= threshold else { continue }
                let edge = min(1, max(0, (threshold - Double(distances[index])) / softness))
                let spatial = fade > 0 ? min(1, (1 - radius) / fade) : 1
                candidates[index] = UInt8(max(1, (edge * spatial * 255).rounded()))
            }
        }
        guard connected else { return candidates }
        let seed = seedY * width + seedX
        var output = [UInt8](repeating: 0, count: distances.count)
        guard candidates[seed] > 0 else { return output }
        var queue = [Int](); queue.reserveCapacity(width * height / 4)
        queue.append(seed); output[seed] = candidates[seed]
        var head = 0
        while head < queue.count {
            let index = queue[head]; head += 1
            let x = index % width
            func visit(_ next: Int) {
                if candidates[next] > 0 && output[next] == 0 {
                    output[next] = candidates[next]; queue.append(next)
                }
            }
            if x > 0 { visit(index - 1) }
            if x + 1 < width { visit(index + 1) }
            if index >= width { visit(index - width) }
            if index + width < output.count { visit(index + width) }
        }
        return output
    }

    static func lab(red: Float, green: Float, blue: Float) -> SIMD3<Float> {
        func linear(_ v: Float) -> Float { v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
        let r = linear(red), g = linear(green), b = linear(blue)
        func f(_ v: Float) -> Float { v > 0.008856 ? pow(v, 1 / 3) : 7.787 * v + 16 / 116 }
        let x = f((0.4124564 * r + 0.3575761 * g + 0.1804375 * b) / 0.95047)
        let y = f(0.2126729 * r + 0.7151522 * g + 0.0721750 * b)
        let z = f((0.0193339 * r + 0.1191920 * g + 0.9503041 * b) / 1.08883)
        return SIMD3(116 * y - 16, 500 * (x - y), 200 * (y - z))
    }
}
