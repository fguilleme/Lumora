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
            XCTAssertTrue((overlay.value as? String)?.contains("Clipping activations: \(expectedActivations).") == true,
                          "The mask should be ready during the press; value: \(overlay.value ?? "nil")")
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

    @MainActor func testLandscapeHistogramAnchorsAndCanBeMoved() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-ui-testing-clipping"]
        app.launch()
        let canvas = app.descendants(matching: .any).matching(identifier: "photo-canvas").firstMatch
        if !canvas.waitForExistence(timeout: 5) {
            app.buttons["Photos"].tap()
            let photo = app.images.matching(identifier: "PXGGridLayout-Info").firstMatch
            XCTAssertTrue(photo.waitForExistence(timeout: 20))
            photo.tap()
            XCTAssertTrue(canvas.waitForExistence(timeout: 30))
        }
        let overlay = app.buttons["histogram-overlay"]
        XCTAssertTrue(overlay.waitForExistence(timeout: 10))
        XCTAssertLessThan(overlay.frame.midX, canvas.frame.midX,
                          "The compact histogram should start on the photo's left side")

        overlay.tap()
        XCTAssertEqual(overlay.label, "Collapse RGB histogram")
        XCTAssertEqual(overlay.frame.midX, canvas.frame.midX, accuracy: 3,
                       "The expanded histogram should be centered over the photo")
        let original = overlay.frame
        let start = overlay.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 45, dy: -25)))
        XCTAssertEqual(overlay.label, "Collapse RGB histogram", "Dragging must not toggle the size")
        XCTAssertTrue((overlay.value as? String)?.contains("Clipping activations: 0.") == true,
                      "Dragging must not trigger the held clipping diagnostic")
        if canvas.frame.width - original.width > 60 {
            XCTAssertGreaterThan(overlay.frame.midX, original.midX + 20)
        } else {
            XCTAssertEqual(overlay.frame.midX, original.midX, accuracy: 1,
                           "A full-width histogram has no horizontal room to move")
        }
        XCTAssertLessThan(overlay.frame.midY, original.midY - 3)
        XCTAssertGreaterThanOrEqual(overlay.frame.minX, canvas.frame.minX - 1)
        XCTAssertLessThanOrEqual(overlay.frame.maxX, canvas.frame.maxX + 1)
        let movedCenter = overlay.frame.midX
        capture("Moved expanded histogram in landscape", in: app)

        overlay.tap()
        XCTAssertEqual(overlay.label, "Expand RGB histogram")
        let compactCenter = overlay.frame.midX
        let compactStart = overlay.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        compactStart.press(forDuration: 0.05,
                           thenDragTo: compactStart.withOffset(CGVector(dx: 35, dy: 0)))
        XCTAssertEqual(overlay.label, "Expand RGB histogram")
        XCTAssertEqual(overlay.frame.midX, compactCenter + 35, accuracy: 6,
                       "The compact histogram must follow the finger one-to-one")
        overlay.tap()
        XCTAssertEqual(overlay.frame.midX, movedCenter, accuracy: 3,
                       "The expanded position should survive a size toggle")
    }

    @MainActor private func capture(_ name: String, in app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
