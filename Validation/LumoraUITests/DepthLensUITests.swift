import XCTest

final class DepthLensUITests: XCTestCase {
    @MainActor func testDepthTabFocusSliderAndUndo() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--depth-ui-validation", "-AppleLanguages", "(fr)", "-AppleLocale", "fr_FR"]
        app.launch()
        let canvas = app.descendants(matching: .any).matching(identifier: "photo-canvas").firstMatch
        XCTAssertTrue(canvas.waitForExistence(timeout: 45))
        let tab = app.buttons["editor-tab-Depth Lens"]
        let toolbar = app.scrollViews["tools-toolbar"]
        for _ in 0..<12 {
            if tab.frame.minX >= 0 && tab.frame.maxX <= app.frame.width { break }
            let left = tab.frame.minX < 0
            toolbar.coordinate(withNormalizedOffset: CGVector(dx: left ? 0.3 : 0.7, dy: 0.5))
                .press(forDuration: 0.1, thenDragTo: toolbar.coordinate(withNormalizedOffset: CGVector(dx: left ? 0.7 : 0.3, dy: 0.5)), withVelocity: .slow, thenHoldForDuration: 0.5)
        }
        XCTAssertTrue(tab.isHittable); tab.tap()
        let toggle = app.switches["depth-lens-enable"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 10)); toggle.tap()
        let slider = app.sliders["depth-lens-aperture"]
        XCTAssertTrue(slider.waitForExistence(timeout: 15))
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.35)).tap()
        for amount: CGFloat in [0.3, 0.8, 0.2] { slider.adjust(toNormalizedSliderPosition: amount) }
        XCTAssertTrue(app.buttons["Annuler"].isEnabled); app.buttons["Annuler"].tap()
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "Depth Lens — français"; shot.lifetime = .keepAlways; add(shot)
        XCTAssertEqual(app.state, .runningForeground)
        XCTAssertFalse(app.alerts.firstMatch.exists)
    }
}
