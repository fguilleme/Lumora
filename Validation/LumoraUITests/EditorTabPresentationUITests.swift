import XCTest

final class EditorTabPresentationUITests: XCTestCase {
    @MainActor func testTabsToggleControlsAndExpandPhoto() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(fr)", "-AppleLocale", "fr_FR", "-ui-testing-landscape"]
        app.launch()
        let canvas = app.descendants(matching: .any).matching(identifier: "photo-canvas").firstMatch
        XCTAssertTrue(canvas.waitForExistence(timeout: 20))
        let light = app.buttons["editor-tab-Light"]
        let color = app.buttons["editor-tab-Color"]
        XCTAssertTrue(light.isHittable)
        XCTAssertGreaterThanOrEqual(light.frame.height, 44)
        XCTAssertEqual(color.frame.minY, light.frame.minY, accuracy: 1)
        XCTAssertFalse(light.isSelected)
        let expandedHeight = canvas.frame.height
        let generation = canvas.value as? String
        capture("01-photo-sans-panneau", app)

        light.tap()
        let exposure = app.buttons["parameter-exposure"]
        XCTAssertTrue(exposure.waitForExistence(timeout: 5))
        XCTAssertTrue(exposure.isHittable)
        XCTAssertTrue(light.isSelected)
        XCTAssertLessThan(canvas.frame.height, expandedHeight - 100)
        let exposureValue = exposure.value as? String
        capture("02-lumiere-ouverte", app)
        light.tap()
        XCTAssertFalse(light.isSelected)
        XCTAssertFalse(exposure.isHittable)
        XCTAssertEqual(canvas.frame.height, expandedHeight, accuracy: 2)
        XCTAssertEqual(canvas.value as? String, generation, "Toggling controls must not rerender or change the photo")
        light.tap()
        XCTAssertEqual(exposure.value as? String, exposureValue)
        XCTAssertTrue(exposure.isHittable)

        let curves = app.buttons["editor-tab-Curves"]
        curves.tap()
        XCTAssertTrue(curves.isSelected)
        curves.tap()
        XCTAssertFalse(curves.isSelected)
        XCTAssertEqual(canvas.frame.height, expandedHeight, accuracy: 2)

        XCUIDevice.shared.orientation = .landscapeLeft
        expectation(for: NSPredicate { _, _ in app.frame.width > app.frame.height }, evaluatedWith: app)
        waitForExpectations(timeout: 5)
        light.tap()
        XCTAssertTrue(exposure.isHittable)
        let narrowWidth = canvas.frame.width
        RunLoop.current.run(until: Date().addingTimeInterval(0.6))
        capture("03-paysage-panneau", app)
        let switchSide = app.buttons["controls-side-switch"]
        XCTAssertTrue(switchSide.isHittable)
        switchSide.tap()
        XCTAssertTrue(exposure.isHittable)
        light.tap()
        XCTAssertGreaterThan(canvas.frame.width, narrowWidth + 100)
        XCTAssertFalse(exposure.isHittable)
        capture("04-paysage-photo", app)
        light.tap()
        switchSide.tap() // Restore the previous controls side.

        let toolbar = app.scrollViews["tools-toolbar"]
        let settings = app.buttons["editor-tab-Settings"]
        for _ in 0..<12 {
            if settings.exists && settings.frame.intersects(app.frame) && settings.isHittable { break }
            toolbar.swipeLeft()
        }
        XCTAssertTrue(settings.isHittable)
        settings.tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "editor-full-page").firstMatch.waitForExistence(timeout: 5))
        settings.tap()
        XCTAssertTrue(canvas.waitForExistence(timeout: 5))
        XCTAssertFalse(settings.isSelected)
    }

    @MainActor private func capture(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
