import XCTest

final class EditorSettingsUITests: XCTestCase {
    @MainActor func testHistogramAndTabVisibilityPersist() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--depth-ui-validation", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        func openSettings() {
            XCTAssertTrue(app.buttons["Import and options"].waitForExistence(timeout: 30))
            app.buttons["Import and options"].tap()
            app.buttons["open-editor-settings"].tap()
            XCTAssertTrue(app.switches["settings-histogram"].waitForExistence(timeout: 10))
        }
        app.launch(); openSettings()
        let histogram = app.switches["settings-histogram"]
        if histogram.value as? String == "1" { histogram.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap() }
        let list = app.collectionViews.firstMatch
        let creative = app.buttons["settings-visible-Creative"]
        for _ in 0..<4 { if creative.exists && creative.frame.minY > 0 && creative.frame.maxY < app.frame.height - 60 { break }; list.swipeUp() }
        XCTAssertTrue(creative.exists)
        if creative.value as? String == "Visible" { creative.tap() }
        XCTAssertTrue(app.buttons["editor-tab-Creative"].waitForNonExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["histogram-overlay"].exists)
        app.terminate(); app.launch(); openSettings()
        XCTAssertEqual(app.switches["settings-histogram"].value as? String, "0")
        XCTAssertTrue(app.buttons["editor-tab-Creative"].waitForNonExistence(timeout: 5))
        let reset = app.buttons["settings-reset"]
        for _ in 0..<15 { if reset.exists && reset.isHittable { break }; app.collectionViews.firstMatch.swipeUp() }
        XCTAssertTrue(reset.isHittable); reset.tap()
        XCTAssertTrue(app.buttons["editor-tab-Creative"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["photo-canvas"].exists)
        app.buttons["editor-tab-Light"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["histogram-overlay"].waitForExistence(timeout: 5))
        openSettings()
        // Return to the first rows and move Light ahead of Creative using the native handle.
        for _ in 0..<15 {
            if app.buttons["settings-visible-Light"].exists && app.buttons["settings-visible-Light"].isHittable && app.buttons["settings-visible-Creative"].isHittable { break }
            app.collectionViews.firstMatch.swipeDown()
        }
        let settingsList = app.collectionViews.firstMatch
        let lightCell = app.cells.containing(.button, identifier: "settings-visible-Light").firstMatch
        let creativeCell = app.cells.containing(.button, identifier: "settings-visible-Creative").firstMatch
        let handle = lightCell.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Reorder'")).firstMatch
        XCTAssertTrue(handle.exists)
        XCTAssertLessThan(handle.frame.maxY, settingsList.frame.maxY)
        let origin = app.coordinate(withNormalizedOffset: .zero)
        let start = origin.withOffset(CGVector(dx: handle.frame.midX, dy: handle.frame.midY))
        let end = origin.withOffset(CGVector(dx: handle.frame.midX, dy: creativeCell.frame.midY - 15))
        start.press(forDuration: 0.5, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 1)
        let reordered = NSPredicate { _, _ in app.buttons["editor-tab-Light"].frame.minX < app.buttons["editor-tab-Creative"].frame.minX }
        expectation(for: reordered, evaluatedWith: app)
        waitForExpectations(timeout: 5)
        app.terminate(); app.launch(); openSettings()
        XCTAssertLessThan(app.buttons["editor-tab-Light"].frame.minX, app.buttons["editor-tab-Creative"].frame.minX)
        for _ in 0..<15 { if reset.exists && reset.isHittable { break }; app.collectionViews.firstMatch.swipeUp() }
        reset.tap()
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "Editor settings"; shot.lifetime = .keepAlways; add(shot)
    }
}
