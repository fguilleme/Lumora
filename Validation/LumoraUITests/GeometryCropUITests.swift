import XCTest

final class GeometryCropUITests: XCTestCase {
    @MainActor func testSocialCropPinchPanAndUndo() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(fr)", "-AppleLocale", "fr_FR",
            "--app-store-image", "DetailFeedback.jpg", "--app-store-panel", "Geometry"]
        app.launch()
        let canvas = app.descendants(matching: .any).matching(identifier: "photo-canvas").firstMatch
        XCTAssertTrue(canvas.waitForExistence(timeout: 20))
        expectation(for: NSPredicate { _, _ in
            (canvas.value as? String)?.contains("%") == true
        }, evaluatedWith: canvas)
        waitForExpectations(timeout: 20)
        let original = canvas.value as? String
        let formats = app.scrollViews["geometry-formats"]
        let portrait = app.buttons["geometry-aspect-fourFive"]
        XCTAssertTrue(portrait.isHittable); portrait.tap()
        XCTAssertTrue((canvas.value as? String)?.contains("Instagram portrait") == true)
        capture("01-instagram-portrait", app)
        let beforePinch = canvas.value as? String
        canvas.pinch(withScale: 1.5, velocity: 1)
        XCTAssertNotEqual(canvas.value as? String, beforePinch)
        capture("02-pincement", app)
        let undo = app.buttons["arrow.uturn.backward"]
        undo.tap()
        XCTAssertEqual(canvas.value as? String, beforePinch, "One pinch must be one Undo")
        canvas.pinch(withScale: 1.5, velocity: 1)
        let beforePan = canvas.value as? String
        let start = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 32, dy: 40)))
        XCTAssertNotEqual(canvas.value as? String, beforePan)
        undo.tap()
        XCTAssertEqual(canvas.value as? String, beforePan, "One pan must be one Undo")
        undo.tap() // Pinch.
        undo.tap() // Format.
        XCTAssertEqual(canvas.value as? String, original)
        let tikTok = app.buttons["geometry-aspect-nineSixteen"]
        if !tikTok.isHittable { formats.swipeLeft() }
        XCTAssertEqual(tikTok.label, "TikTok"); tikTok.tap()
        capture("03-tiktok", app)
        XCTAssertTrue((canvas.value as? String)?.contains("TikTok") == true)
        undo.tap()
        XCTAssertEqual(canvas.value as? String, original)
        let mode = app.segmentedControls["geometry-mode"]
        mode.buttons["Ajustements"].tap()
        XCTAssertTrue(app.buttons["parameter-straighten"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["parameter-straighten"].isHittable)
        mode.buttons["Cadrage"].tap()
        expectation(for: NSPredicate { _, _ in (canvas.value as? String) == original }, evaluatedWith: canvas)
        waitForExpectations(timeout: 20)
        XCUIDevice.shared.orientation = .landscapeLeft
        expectation(for: NSPredicate { _, _ in app.frame.width > app.frame.height }, evaluatedWith: app)
        waitForExpectations(timeout: 5)
        XCTAssertTrue(app.buttons["controls-side-switch"].isHittable)
        app.buttons["controls-side-switch"].tap()
        app.buttons["controls-side-switch"].tap()
    }

    @MainActor private func capture(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
