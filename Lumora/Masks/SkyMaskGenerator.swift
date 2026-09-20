import CoreGraphics

/// Produces a conservative sky matte without shipping a machine-learning model.
/// Pixels must look like blue or bright neutral sky and remain connected to the image's upper edge.
enum SkyMaskGenerator {
    static func makeMask(from image: CGImage, maximumDimension: Int = 1_024) -> CGImage? {
        guard let source = MaskBitmapSource(image: image, maximumDimension: maximumDimension) else { return nil }
        let width = source.width, height = source.height

        var likelihood = [Float](repeating: 0, count: width * height)
        for y in 0..<height {
            let verticalPrior = max(0.2, 1 - 0.75 * Float(y) / Float(max(1, height - 1)))
            for x in 0..<width {
                let (red, green, blue) = source.rgb(x: x, y: y)
                let maximum = max(red, green, blue)
                let minimum = min(red, green, blue)
                let saturation = maximum > 0 ? (maximum - minimum) / maximum : 0
                let luminance = 0.2126 * red + 0.7152 * green + 0.0722 * blue
                let blueRed = smoothstep(0.015, 0.18, blue - red)
                let blueGreen = smoothstep(-0.08, 0.10, blue - green)
                let clearSky = blueRed * blueGreen * smoothstep(0.16, 0.65, luminance)
                let neutral = smoothstep(0.52, 0.88, luminance)
                    * (1 - smoothstep(0.05, 0.24, saturation)) * 0.68
                let gradient = localGradient(source, x: x, y: y, luminance: luminance)
                let smoothRegion = 1 - smoothstep(0.05, 0.24, gradient)
                likelihood[y * width + x] = max(clearSky, neutral) * smoothRegion * verticalPrior
            }
        }

        var connected = [Bool](repeating: false, count: width * height)
        var queue = [Int](); queue.reserveCapacity(width * max(1, height / 3))
        let seedRows = max(1, height / 12)
        for y in 0..<seedRows {
            for x in 0..<width {
                let index = y * width + x
                if likelihood[index] >= 0.28 {
                    connected[index] = true
                    queue.append(index)
                }
            }
        }
        var cursor = 0
        while cursor < queue.count {
            let index = queue[cursor]; cursor += 1
            let x = index % width, y = index / width
            if x > 0 {
                let neighbor = index - 1
                if !connected[neighbor], likelihood[neighbor] >= 0.10 {
                    connected[neighbor] = true; queue.append(neighbor)
                }
            }
            if x + 1 < width {
                let neighbor = index + 1
                if !connected[neighbor], likelihood[neighbor] >= 0.10 {
                    connected[neighbor] = true; queue.append(neighbor)
                }
            }
            if y > 0 {
                let neighbor = index - width
                if !connected[neighbor], likelihood[neighbor] >= 0.10 {
                    connected[neighbor] = true; queue.append(neighbor)
                }
            }
            if y + 1 < height {
                let neighbor = index + width
                if !connected[neighbor], likelihood[neighbor] >= 0.10 {
                    connected[neighbor] = true; queue.append(neighbor)
                }
            }
        }

        var matte = [UInt8](repeating: 0, count: width * height)
        var selected = 0
        for index in matte.indices where connected[index] {
            let value = smoothstep(0.08, 0.62, likelihood[index])
            matte[index] = UInt8((min(1, value) * 255).rounded())
            if matte[index] > 24 { selected += 1 }
        }
        guard selected >= max(16, width * height / 500) else { return nil }
        return source.grayImage(matte)
    }

    private static func localGradient(_ source: MaskBitmapSource, x: Int, y: Int,
                                      luminance: Float) -> Float {
        var largest: Float = 0
        for (sampleX, sampleY) in [(min(source.width - 1, x + 1), y),
                                   (x, min(source.height - 1, y + 1))] {
            let (red, green, blue) = source.rgb(x: sampleX, y: sampleY)
            let value = 0.2126 * red + 0.7152 * green + 0.0722 * blue
            largest = max(largest, abs(value - luminance))
        }
        return largest
    }

    private static func smoothstep(_ edge0: Float, _ edge1: Float, _ value: Float) -> Float {
        guard edge0 != edge1 else { return value < edge0 ? 0 : 1 }
        let t = min(1, max(0, (value - edge0) / (edge1 - edge0)))
        return t * t * (3 - 2 * t)
    }
}
