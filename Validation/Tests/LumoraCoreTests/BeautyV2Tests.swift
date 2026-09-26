import CoreGraphics
import CoreImage
import Foundation
import Testing
@testable import LumoraCore

@Test func beautyV2LegacyMigrationPresetsAndHistory() throws {
    let oldBeauty = try JSONDecoder().decode(BeautyState.self,
        from: Data("{\"version\":1,\"amount\":100,\"uniformity\":42,\"texture\":-8,\"blemishes\":44,\"darkCircles\":40,\"eyeBrightness\":25,\"eyeDetail\":16,\"teeth\":18}".utf8))
    #expect(oldBeauty.finishing == nil)
    #expect(oldBeauty.validated.finishing == nil)
    for preset in BeautyPreset.allCases {
        #expect(preset.settings.finishing == nil)
        #expect(BeautyPreset.matching(preset.settings) == preset)
    }
    var edit = EditState()
    var history = HistoryManager()
    history.begin("Beauty V2", state: edit)
    var finishing = BeautyV2Settings()
    finishing[.lipColor] = 75
    edit.beauty.finishing = finishing
    history.commit(edit)
    #expect(history.canUndo)
    #expect(history.undo()?.beauty.finishing == nil)
    #expect(history.redo()?.beauty.finishing?.lipColor == 75)
    let restored = try JSONDecoder().decode(EditState.self,
        from: JSONEncoder().encode(edit))
    #expect(restored.beauty.finishing == finishing)
    finishing[.lipColor] = 0
    #expect(finishing.isIdentity)
}

@Test func beautyV2ControlsAreBoundedAndNeutral() throws {
    let image = CIImage(color: CIColor(red: 0.34, green: 0.27, blue: 0.21))
        .cropped(to: CGRect(x: 0, y: 0, width: 32, height: 32))
    for control in BeautyV2Control.allCases {
        var settings = BeautyV2Settings()
        #expect(try BeautyV2Renderer.apply(image, settings: settings,
                                       masks: .empty, amount: 100) === image)
        settings[control] = 300
        #expect(settings[control] == 100)
        settings[control] = -300
        #expect(settings[control] == control.range.lowerBound)
        settings[control] = .nan
        #expect(settings[control] == 0)
    }
}

@Test func beautyV2RendererIsFiniteLocalAndAmountZeroIdentity() throws {
    let width = 64, height = 64
    let space = try #require(CGColorSpace(name: CGColorSpace.extendedLinearSRGB))
    var sourceValues = [Float](repeating: 1, count: width*height*4)
    for pixel in 0..<(width*height) {
        sourceValues[pixel*4] = 1.4
        sourceValues[pixel*4+1] = 1.2
    }
    let input = CIImage(bitmapData: sourceValues.withUnsafeBytes { Data($0) },
        bytesPerRow: width*16, size: CGSize(width: width, height: height),
        format: .RGBAf, colorSpace: space)
    var matte = [UInt8](repeating: 0, count: width * height)
    for y in 16..<48 { for x in 16..<48 { matte[y*width+x] = 255 } }
    let cg = try #require(CGImage(width: width, height: height,
        bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: width,
        space: CGColorSpace(name: CGColorSpace.linearGray)!,
        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
        provider: CGDataProvider(data: Data(matte) as CFData)!, decode: nil,
        shouldInterpolate: false, intent: .defaultIntent))
    let masks = BeautyMasks(faceCount: 1, faceWidthFraction: 0.5, faceRects: [],
        skin: cg, eyes: nil, underEyes: nil, teeth: nil, blemishes: nil,
        v2: BeautyV2Masks(lips: cg, innerMouth: nil, hair: cg))
    var settings = BeautyV2Settings()
    settings.lipBrightness = 100
    settings.skinShine = 100
    settings.faceBalance = 100
    settings.hairLight = 100
    let identity = try BeautyV2Renderer.apply(input, settings: settings,
                                              masks: masks, amount: 0)
    #expect(identity === input)
    let output = try BeautyV2Renderer.apply(input, settings: settings,
                                            masks: masks, amount: 100)
    let context = CIContext()
    var values = [Float](repeating: 0, count: width*height*4)
    values.withUnsafeMutableBytes { bytes in
        context.render(output, toBitmap: bytes.baseAddress!, rowBytes: width*16,
                       bounds: output.extent, format: .RGBAf, colorSpace: space)
    }
    #expect(values.allSatisfy { $0.isFinite })
    #expect(values[(32*width+32)*4] > values[0])
    #expect(abs(values[0]-1.4) < 0.01)
    #expect(values[(32*width+32)*4] > 1.0) // no premature HDR clamp
}

@Test func beautyV2ProductionCompatibilityAndUndo() throws {
    let partial = try JSONDecoder().decode(BeautyV2Settings.self,
        from: Data(#"{"hairLight":87,"hairShine":45,"hairDetail":-30}"#.utf8))
    #expect(partial.isIdentity)
    var state = EditState()
    state.beauty.finishing = partial
    #expect(state.beauty.isIdentity)
    #expect(state.beauty.validated.finishing == partial)
    let restored = try JSONDecoder().decode(EditState.self, from: JSONEncoder().encode(state))
    #expect(restored.beauty.finishing == partial)
    var history = HistoryManager()
    history.begin("Portrait finishing", state: state)
    var finishing = partial
    for control in BeautyV2Control.productionCases { finishing[control] = 42 }
    state.beauty.finishing = finishing
    history.commit(state)
    #expect(history.undo()?.beauty.finishing == partial)
    #expect(history.redo()?.beauty.finishing == finishing)
    #expect(BeautyV2Control.productionCases.count == 5)
    #expect(!BeautyV2Control.productionCases.contains(.lipColor))
    #expect(!BeautyV2Control.productionCases.contains(.hairLight))
}

@Test func beautyV2ProductionIgnoresHairAndPreservesHDR() throws {
    let extent = CGRect(x: 0,y: 0,width: 64,height: 16)
    let space = try #require(CGColorSpace(name: CGColorSpace.extendedLinearSRGB))
    let levels: [Float] = [-0.01,0,0.01,0.18,0.5,1,2,8]
    var pixels = [Float]()
    for _ in 0..<16 { for x in 0..<64 {
        let y = levels[x/8]; pixels += [y,y*0.8,y*0.7,1]
    }}
    let input = CIImage(bitmapData: pixels.withUnsafeBytes { Data($0) }, bytesPerRow: 64*16,
        size: extent.size, format: .RGBAf, colorSpace: space)
    let context = CIContext(options: [.workingColorSpace: space])
    let matte = try #require(context.createCGImage(CIImage(color: .white).cropped(to: extent), from: extent))
    let masks = BeautyMasks(faceCount: 1, faceWidthFraction: 0.5, faceRects: [],
        skin: matte, eyes: nil, underEyes: nil, teeth: nil, blemishes: nil,
        v2: BeautyV2Masks(lips: matte, innerMouth: nil, hair: matte))
    var hair = BeautyV2Settings(); hair.hairLight = 100; hair.hairShine = 100; hair.hairDetail = 100
    #expect(try BeautyV2Renderer.apply(input, settings: hair, masks: masks, amount: 100) === input)
    for control in BeautyV2Control.productionCases {
        for value in [control.range.lowerBound, control.range.upperBound] {
            var settings = BeautyV2Settings(); settings[control] = value
            let output = try BeautyV2Renderer.apply(input, settings: settings, masks: masks, amount: 100)
            var values = [Float](repeating: 0,count: pixels.count)
            values.withUnsafeMutableBytes { context.render(output, toBitmap: $0.baseAddress!,
                rowBytes: 64*16, bounds: extent, format: .RGBAf, colorSpace: space) }
            #expect(values.allSatisfy { $0.isFinite })
            #expect(values[(8*64+63)*4] > 1)
            #expect(try BeautyV2Renderer.apply(input, settings: settings, masks: masks, amount: 0) === input)
        }
    }
}
