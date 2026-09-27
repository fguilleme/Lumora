import Testing
import Foundation
import CoreImage
@testable import LumoraCore

@Test func depthLensMigrationRoundTripAndUndo() throws {
    let original = try JSONDecoder().decode(EditState.self, from: Data("{}".utf8))
    #expect(original.depthLens == nil)
    var changed = original
    changed.depthLens = DepthLensSettings(enabled: true, aperture: 2.8, focal: 135, focusX: 0.2, focusY: 0.7)
    #expect(try JSONDecoder().decode(EditState.self, from: JSONEncoder().encode(changed)) == changed)
    var history = HistoryManager()
    history.begin("Depth Lens", state: original); history.commit(changed)
    #expect(history.undo() == original)
    #expect(history.redo() == changed)
}

@Test func depthLensRejectsInvalidSettings() {
    let settings = DepthLensSettings(enabled: true, aperture: .nan, focal: .infinity, focusX: -3, focusY: 4).validated
    #expect(settings.aperture == 1.4 && settings.focal == 85)
    #expect(settings.focusX == 0 && settings.focusY == 1)
}

@Test func depthLensDoesNotTriggerColorCube() throws {
    let image = CIImage(color: CIColor(red: 0.2, green: 0.3, blue: 0.4)).cropped(to: CGRect(x: 0, y: 0, width: 32, height: 32))
    for enabled in [false, true] {
        var state = EditState(); state.depthLens = DepthLensSettings(enabled: enabled)
        var called = false
        _ = try DevelopmentRenderer.apply(image, state: state) { _ in called = true; return Data() }
        #expect(!called)
    }
}
