import XCTest

final class HistogramOverlayUITests: XCTestCase {
    @MainActor func testLongPressClippingIsTemporaryInBothHistogramSizes() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments.append("-ui-testing-clipping")
        app.launch()
        let canvas = app.descendants(matching: .any).matching(identifier: "photo-canvas").firstMatch
        if !canvas.waitForExistence(timeout: 5) {
            app.buttons["Photos"].tap()
            let photo = app.images.matching(identifier: "PXGGridLayout-Info").element(boundBy: 1)
            XCTAssertTrue(photo.waitForExistence(timeout: 20))
            photo.tap()
            XCTAssertTrue(canvas.waitForExistence(timeout: 30))
        }
        app.buttons["Import and options"].tap()
        app.buttons["Reset settings"].tap()
        let overlay = app.buttons["histogram-overlay"]
        XCTAssertTrue(overlay.waitForExistence(timeout: 10))
        var expectedActivations = 0
        for expanded in [false, true] {
            let label = expanded ? "Collapse RGB histogram" : "Expand RGB histogram"
            XCTAssertEqual(overlay.label, label)
            XCTAssertFalse(app.images["clipping-warning-overlay"].exists)
            overlay.press(forDuration: 1.0)
            expectedActivations += 1
            XCTAssertTrue((overlay.value as? String)?.contains("Activations clipping : \(expectedActivations).") == true,
                          "The mask should be ready during the press")
            XCTAssertFalse(app.images["clipping-warning-overlay"].exists,
                           "The overlay should disappear on release")
            XCTAssertEqual(overlay.label, label, "A long press must not trigger a tap")
            if !expanded { overlay.tap() }
        }
    }

    @MainActor func testOverlayExpandsWithoutMovingPhotoAndLeavesOutsideGesturesAlone() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launch()
        let canvas = app.descendants(matching: .any).matching(identifier: "photo-canvas").firstMatch
        if !canvas.waitForExistence(timeout: 5) {
            app.buttons["Photos"].tap()
            let photo = app.images.matching(identifier: "PXGGridLayout-Info").element(boundBy: 1)
            XCTAssertTrue(photo.waitForExistence(timeout: 20))
            photo.tap()
            XCTAssertTrue(canvas.waitForExistence(timeout: 30))
        }
        app.buttons["Import and options"].tap()
        app.buttons["Reset settings"].tap()
        let overlay = app.buttons["histogram-overlay"]
        XCTAssertTrue(overlay.waitForExistence(timeout: 10))
        XCTAssertEqual(overlay.label, "Expand RGB histogram")
        let photoHeight = canvas.frame.height
        let compactWidth = overlay.frame.width
        XCTAssertGreaterThanOrEqual(overlay.frame.height, 44)
        capture("Compact histogram on photo", in: app)

        let outside = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.75))
        outside.press(forDuration: 0.05, thenDragTo: canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.7)))
        XCTAssertEqual(overlay.label, "Expand RGB histogram")
        overlay.tap()
        XCTAssertEqual(overlay.label, "Collapse RGB histogram")
        XCTAssertGreaterThan(overlay.frame.width, compactWidth * 1.5)
        XCTAssertEqual(canvas.frame.height, photoHeight, accuracy: 1)
        capture("Expanded histogram on photo", in: app)
        overlay.tap()
        XCTAssertEqual(overlay.label, "Expand RGB histogram")
        XCTAssertEqual(canvas.frame.height, photoHeight, accuracy: 1)
    }

    @MainActor private func capture(_ name: String, in app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
