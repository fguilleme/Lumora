import XCTest

final class CurvePresentationUITests: XCTestCase {
    @MainActor func testChannelButtonsToggleGraphAndDragUsesPhotoCoordinates() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(fr)", "-AppleLocale", "fr_FR", "--app-store-panel", "Curves", "-ui-testing-landscape"]
        app.launch()
        let chart = app.descendants(matching: .any).matching(identifier: "tone-curve-chart").firstMatch
        XCTAssertTrue(chart.waitForExistence(timeout: 20))
        let canvas = app.descendants(matching: .any).matching(identifier: "photo-canvas").firstMatch
        let channelRow = app.descendants(matching: .any).matching(identifier: "curve-channel-controls").firstMatch
        let rgb = app.buttons["curve-channel-rgb"]
        let red = app.buttons["curve-channel-red"]
        let initialGeneration = canvas.value as? String
        XCTAssertFalse(app.buttons["histogram-overlay"].exists)
        let canvasFrame = canvas.frame
        let initialCurve = chart.value as? String
        XCTAssertGreaterThan(channelRow.frame.minY, canvas.frame.maxY)
        for id in ["rgb", "red", "green", "blue"] {
            let button = app.buttons["curve-channel-" + id]
            XCTAssertTrue(button.isHittable)
            XCTAssertGreaterThanOrEqual(button.frame.height, 44)
        }
        capture("01-courbes-au-repos", app)
        rgb.tap()
        XCTAssertFalse(chart.exists)
        XCTAssertTrue(rgb.isSelected)
        XCTAssertEqual(canvas.frame, canvasFrame)
        capture("02-graphe-replie", app)
        rgb.tap()
        XCTAssertTrue(chart.waitForExistence(timeout: 3))
        XCTAssertEqual(chart.value as? String, initialCurve)
        red.tap()
        XCTAssertTrue(chart.exists)
        XCTAssertTrue(red.isSelected)
        red.tap()
        XCTAssertFalse(chart.exists)
        app.buttons["curve-channel-green"].tap()
        XCTAssertTrue(chart.waitForExistence(timeout: 3))
        app.buttons["curve-channel-blue"].tap()
        rgb.tap()
        XCTAssertEqual(chart.value as? String, initialCurve)
        XCTAssertEqual(canvas.value as? String, initialGeneration, "Channel selection and collapsing must not change photographic state")

        let header = app.descendants(matching: .any).matching(identifier: "curve-card-drag-handle").firstMatch
        let before = chart.frame
        let start = header.coordinate(withNormalizedOffset: CGVector(dx: 0.4, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 0, dy: 70)))
        XCTAssertEqual(chart.frame.minY - before.minY, 70, accuracy: 3, "Card should follow the finger in fixed photo coordinates")
        XCTAssertEqual(chart.value as? String, initialCurve)
        XCTAssertEqual(canvas.value as? String, initialGeneration)
        capture("03-panneau-deplace", app)
        // Move back to keep the graph clear of the controls.
        let returnStart = header.coordinate(withNormalizedOffset: CGVector(dx: 0.4, dy: 0.5))
        returnStart.press(forDuration: 0.1, thenDragTo: returnStart.withOffset(CGVector(dx: 0, dy: -70)))
        XCTAssertEqual(chart.frame.minY, before.minY, accuracy: 3)

        // An intermediate point remains directly draggable; one gesture is one Undo.
        chart.coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: 0.45)).tap()
        let beforePointDrag = chart.value as? String
        let point = app.descendants(matching: .any).matching(identifier: "curve-point-1").firstMatch
        XCTAssertTrue(point.isHittable)
        let pointStart = point.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        pointStart.press(forDuration: 0.1, thenDragTo: pointStart.withOffset(CGVector(dx: 20, dy: -15)))
        XCTAssertNotEqual(chart.value as? String, beforePointDrag)
        capture("04-point-deplace", app)
        app.buttons["Annuler"].tap()
        XCTAssertEqual(chart.value as? String, beforePointDrag)

        XCUIDevice.shared.orientation = .landscapeLeft
        expectation(for: NSPredicate { _, _ in app.frame.width > app.frame.height }, evaluatedWith: app)
        waitForExpectations(timeout: 5)
        XCTAssertTrue(red.isHittable)
        red.tap(); red.tap()
        XCTAssertFalse(chart.exists)
        rgb.tap()
        XCTAssertTrue(chart.waitForExistence(timeout: 3))
        app.buttons["controls-side-switch"].tap()
        XCTAssertTrue(rgb.isHittable)
    }

    @MainActor private func capture(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
