import Testing
import CoreGraphics
import CoreImage
import ImageIO
import Foundation
@testable import LumoraCore

private func curveSampleChart() throws -> CGImage {
    let red = CIImage(color: CIColor(red: 1, green: 0, blue: 0)).cropped(to: CGRect(x: 0, y: 0, width: 100, height: 100))
    let green = CIImage(color: CIColor(red: 0, green: 1, blue: 0)).cropped(to: CGRect(x: 100, y: 0, width: 100, height: 100))
    let blue = CIImage(color: CIColor(red: 0, green: 0, blue: 1)).cropped(to: CGRect(x: 200, y: 0, width: 100, height: 100))
    let image = red.composited(over: green).composited(over: blue)
    let context = CIContext(options: [.cacheIntermediates: false])
    return try #require(context.createCGImage(image, from: CGRect(x: 0, y: 0, width: 300, height: 100),
        format: .RGBAh, colorSpace: CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!))
}

@Test func curveEyedropperReadsBeforeCurveAndChannels() throws {
    let image = try curveSampleChart()
    var state = EditState()
    var curve = ToneCurve()
    _ = curve.add(x: 0.5, y: 0.9)
    state.curves.red = curve
    let buffer = try CurveSamplingBuffer.prepare(original: image, state: state)
    let red = try #require(buffer.sample(at: MaskPoint(x: 1.0 / 6, y: 0.5)))
    let green = try #require(buffer.sample(at: MaskPoint(x: 0.5, y: 0.5)))
    let blue = try #require(buffer.sample(at: MaskPoint(x: 5.0 / 6, y: 0.5)))
    #expect(red.value(for: .red) > 0.95 && red.value(for: .green) < 0.05)
    #expect(green.value(for: .green) > 0.95 && green.value(for: .blue) < 0.05)
    #expect(blue.value(for: .blue) > 0.95 && blue.value(for: .red) < 0.05)
    #expect(green.value(for: .rgb) > red.value(for: .rgb))
    #expect(red.value(for: .rgb) > blue.value(for: .rgb))
    #expect(buffer.sample(at: MaskPoint(x: -0.1, y: 0.5)) == nil)
}

@Test func curveEyedropperTracksGrayRampAndSecondaryColors() throws {
    let grays: [Double] = [0, 0.18, 0.5, 0.75, 1]
    let colors: [[Float]] = grays.map { [Float($0), Float($0), Float($0)] } + [
        [0, 1, 1], [1, 0, 1], [1, 1, 0]
    ]
    let width = colors.count * 100, height = 100
    var pixels = [Float](repeating: 1, count: width * height * 4)
    for y in 0..<height {
        for x in 0..<width {
            let index = (y * width + x) * 4
            let color = colors[x / 100]
            pixels[index] = color[0]; pixels[index + 1] = color[1]; pixels[index + 2] = color[2]
        }
    }
    let space = CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!
    let data = pixels.withUnsafeBytes { Data($0) }
    let chart = CIImage(bitmapData: data, bytesPerRow: width * 16,
                        size: CGSize(width: width, height: height), format: .RGBAf, colorSpace: space)
    let context = CIContext(options: [.cacheIntermediates: false])
    let image = try #require(context.createCGImage(chart,
        from: CGRect(x: 0, y: 0, width: width, height: height),
        format: .RGBAh, colorSpace: space))
    let buffer = try CurveSamplingBuffer.prepare(original: image, state: EditState())
    for (index, linear) in grays.enumerated() {
        let sample = try #require(buffer.sample(at: MaskPoint(x: (Double(index) + 0.5) / Double(colors.count), y: 0.5)))
        let expected = linear <= 0.0031308 ? 12.92 * linear : 1.055 * pow(linear, 1 / 2.4) - 0.055
        #expect(abs(sample.value(for: .rgb) - expected) < 0.04)
        #expect(abs(sample.red - sample.green) < 0.01)
        #expect(abs(sample.green - sample.blue) < 0.01)
    }
    for index in 5..<8 {
        let sample = try #require(buffer.sample(at: MaskPoint(x: (Double(index) + 0.5) / Double(colors.count), y: 0.5)))
        let channels = [sample.red, sample.green, sample.blue]
        #expect(channels[index - 5] < 0.05)
        #expect(channels[(index - 4) % 3] > 0.95)
        #expect(channels[(index - 3) % 3] > 0.95)
    }
}

@Test func curveEyedropperFollowsGeometry() throws {
    let image = try curveSampleChart()
    let original = try CurveSamplingBuffer.prepare(original: image, state: EditState())
    let left = try #require(original.sample(at: MaskPoint(x: 1.0 / 6, y: 0.5)))
    var flippedState = EditState()
    flippedState.geometry.flipHorizontal = true
    let flipped = try CurveSamplingBuffer.prepare(original: image, state: flippedState)
    let right = try #require(flipped.sample(at: MaskPoint(x: 5.0 / 6, y: 0.5)))
    #expect(abs(left.red - right.red) < 0.01)
    #expect(abs(left.green - right.green) < 0.01)
    #expect(abs(left.blue - right.blue) < 0.01)
    var rotatedState = EditState()
    rotatedState.geometry.quarterTurns = 1
    let rotated = try CurveSamplingBuffer.prepare(original: image, state: rotatedState)
    #expect(rotated.width == 100 && rotated.height == 300)
    let top = try #require(rotated.sample(at: MaskPoint(x: 0.5, y: 1.0 / 6)))
    let bottom = try #require(rotated.sample(at: MaskPoint(x: 0.5, y: 5.0 / 6)))
    #expect(max(top.red, bottom.red) > 0.9)
    #expect(max(top.blue, bottom.blue) > 0.9)
    var croppedState = EditState()
    croppedState.geometry.cropZoom = 60
    croppedState.geometry.cropX = 100
    let cropped = try CurveSamplingBuffer.prepare(original: image, state: croppedState)
    let center = try #require(cropped.sample(at: MaskPoint(x: 0.5, y: 0.5)))
    #expect(center.blue > 0.9)
}

@Test func curveEyedropperSamplesRealCorpusWithoutChangingPixels() throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
    let locations: [(String, String, MaskPoint)] = [
        ("01_portrait_light_skin", "skin", MaskPoint(x: 0.43, y: 0.44)),
        ("01_portrait_light_skin", "hair shadow", MaskPoint(x: 0.35, y: 0.08)),
        ("03_landscape_clouds", "sky", MaskPoint(x: 0.50, y: 0.20)),
        ("03_landscape_clouds", "rocks", MaskPoint(x: 0.25, y: 0.87)),
        ("05_night", "lamp", MaskPoint(x: 0.27, y: 0.25)),
        ("05_night", "pavement", MaskPoint(x: 0.54, y: 0.83)),
        ("07_white_subject", "white", MaskPoint(x: 0.45, y: 0.75)),
        ("07_white_subject", "sky", MaskPoint(x: 0.78, y: 0.24))
    ]
    var rows: [[String: Any]] = []
    var timings: [Double] = []
    var samplingMicroseconds: [Double] = []
    for name in Set(locations.map(\.0)).sorted() {
        let url = root.appendingPathComponent("VisualTestAssets/\(name).png")
        let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        let started = CFAbsoluteTimeGetCurrent()
        let buffer = try CurveSamplingBuffer.prepare(original: image, state: EditState())
        timings.append((CFAbsoluteTimeGetCurrent() - started) * 1000)
        #expect(max(buffer.width, buffer.height) <= 512)
        let samplingStarted = CFAbsoluteTimeGetCurrent()
        var successfulSamples = 0
        for _ in 0..<10_000 where buffer.sample(at: MaskPoint(x: 0.5, y: 0.5)) != nil {
            successfulSamples += 1
        }
        #expect(successfulSamples == 10_000)
        samplingMicroseconds.append((CFAbsoluteTimeGetCurrent() - samplingStarted) * 100)
        for (photo, label, point) in locations where photo == name {
            let sample = try #require(buffer.sample(at: point))
            #expect(sample.red.isFinite && sample.green.isFinite && sample.blue.isFinite)
            #expect((0...1).contains(sample.value(for: .rgb)))
            rows.append(["photo": photo, "label": label, "x": point.x, "y": point.y,
                         "rgb": sample.value(for: .rgb), "r": sample.red,
                         "g": sample.green, "b": sample.blue])
        }
    }
    if let directory = ProcessInfo.processInfo.environment["CURVES_INTERACTION_ARTIFACT_DIR"] {
        let output = URL(fileURLWithPath: directory, isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let data = try JSONSerialization.data(withJSONObject: ["samples": rows,
                                                               "prepareMilliseconds": timings,
                                                               "sampleMicroseconds": samplingMicroseconds],
                                              options: [.prettyPrinted, .sortedKeys])
        try data.write(to: output.appendingPathComponent("eyedropper_samples.json"))
    }
}
