import CoreGraphics
import Foundation
import ImageIO
import Testing
@testable import LumoraCore

@Test func largeRAWWithGlowRequiresExplicitSizeUnderMemoryPressure() throws {
    var state = EditState()
    state.effects.cinematicGlowIntensity = 24
    let budget = ExportMemoryBudget(source: CGSize(width: 4000, height: 6000),
                                    cropped: CGSize(width: 4000, height: 5000),
                                    isRAW: true, state: state)
    let available = 900 * 1_048_576
    do {
        _ = try budget.workingScale(requestedLongEdge: 5000, availableBytes: available)
        Issue.record("The native export should offer a smaller size before allocating textures.")
    } catch let error as ExportError {
        #expect(error.suggestedMaximum == 2048)
    }
    #expect(try budget.workingScale(requestedLongEdge: 2048, availableBytes: available) == 2048.0 / 5000)
    #expect(try budget.workingScale(requestedLongEdge: 5000, availableBytes: 5_000 * 1_048_576) == 1)
}

@Test func tightCropBudgetIncludesTheFullRAWSample() throws {
    let budget = ExportMemoryBudget(source: CGSize(width: 4000, height: 6000),
                                    cropped: CGSize(width: 800, height: 1000),
                                    isRAW: true, state: EditState())
    #expect(try budget.workingScale(requestedLongEdge: 1000, availableBytes: 900 * 1_048_576) == 1)
    do {
        _ = try budget.workingScale(requestedLongEdge: 1000, availableBytes: 200 * 1_048_576)
        Issue.record("A tiny crop still needs to decode its RAW source.")
    } catch let error as ExportError {
        #expect(error.suggestedMaximum == nil)
    }
}

@Test func resizedRAWExportHonorsChosenDimensionsUnderMemoryPressure() async throws {
    guard let path = ProcessInfo.processInfo.environment["LUMORA_RAW_FIXTURE"] else { return }
    let directory = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    var state = EditState()
    state.geometry.aspect = .fourFive
    state.effects.cinematicGlowIntensity = 24
    let request = ExportRequest(sourceURL: URL(fileURLWithPath: path), state: state, name: "RAW export")
    let engine = RenderEngine()
    let available = 900 * 1_048_576

    do {
        _ = try await engine.export(request: request, settings: ExportSettings(), directory: directory,
                                    availableMemoryLimit: available)
        Issue.record("The original size must be rejected with this memory budget.")
    } catch let error as ExportError {
        #expect(error.suggestedMaximum == 2048)
    }
    let photo = try await engine.export(request: request, settings: ExportSettings(maximumDimension: 2048),
                                        directory: directory, availableMemoryLimit: available)
    let source = try #require(CGImageSourceCreateWithURL(photo.url as CFURL, nil))
    let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
    #expect(image.height == 2048)
    #expect(abs(Double(image.width) / Double(image.height) - 0.8) < 0.002)
}
