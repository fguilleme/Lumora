import XCTest

final class EditorHelpUITests: XCTestCase {
    @MainActor func testHelpTopicsAreReadOnlyInPortraitAndLandscape() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments.append("-ui-testing-landscape")
        app.launch()

        let canvas = app.descendants(matching: .any).matching(identifier: "photo-canvas").firstMatch
        if !canvas.waitForExistence(timeout: 5) {
            app.buttons["Photos"].tap()
            let photo = app.images.matching(identifier: "PXGGridLayout-Info").firstMatch
            XCTAssertTrue(photo.waitForExistence(timeout: 20))
            photo.tap()
            XCTAssertTrue(canvas.waitForExistence(timeout: 30))
        }
        let generation = canvas.value as? String
        let undoEnabled = app.buttons["Undo"].isEnabled

        let toolbar = app.scrollViews["tools-toolbar"]
        let helpTab = app.buttons["Help"]
        for _ in 0..<12 where !helpTab.isHittable { toolbar.swipeLeft() }
        XCTAssertTrue(helpTab.isHittable)
        helpTab.tap()
        XCTAssertTrue(app.scrollViews["help-controls"].exists)
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "photo-information").firstMatch.exists)
        for topic in ["creative", "light", "color", "curves", "colorTools", "effects",
                      "detail", "optics", "geometry", "masks", "presets"] {
            XCTAssertTrue(app.buttons["help-topic-\(topic)"].exists, topic)
        }

        app.buttons["help-topic-creative"].tap()
        XCTAssertTrue(app.scrollViews["help-detail-creative"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Build an effect stack"].exists)
        app.buttons["help-close"].tap()
        XCTAssertTrue(app.scrollViews["help-controls"].exists)

        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(app.buttons["controls-side-switch"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.scrollViews["help-controls"].exists)
        app.buttons["help-topic-light"].tap()
        XCTAssertTrue(app.scrollViews["help-detail-light"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Six controls"].exists)
        app.buttons["help-close"].tap()

        XCTAssertEqual(canvas.value as? String, generation)
        XCTAssertEqual(app.buttons["Undo"].isEnabled, undoEnabled)
        XCUIDevice.shared.orientation = .portrait
    }
}
