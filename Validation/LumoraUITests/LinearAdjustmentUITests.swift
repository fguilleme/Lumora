import XCTest

final class LinearAdjustmentUITests: XCTestCase {
    @MainActor private func openDocument(_ app: XCUIApplication) {
        let canvas = app.descendants(matching: .any).matching(identifier: "photo-canvas").firstMatch
        if canvas.waitForExistence(timeout: 8) { return }
        let photos = app.buttons["Photos"]
        XCTAssertTrue(photos.waitForExistence(timeout: 8)); photos.tap()
        let photo = app.images.matching(identifier: "PXGGridLayout-Info").firstMatch
        XCTAssertTrue(photo.waitForExistence(timeout: 20)); photo.tap()
        XCTAssertTrue(canvas.waitForExistence(timeout: 30))
    }

    @MainActor private func selectPanel(_ name: String, in app: XCUIApplication) {
        let toolbar = app.scrollViews["tools-toolbar"]
        let button = app.buttons["editor-tab-\(name)"]
        func visible() -> Bool {
            guard button.exists else { return false }
            let frame = button.frame
            return !frame.isNull && !frame.isInfinite && frame.width > 0 && frame.intersects(app.frame)
        }
        for _ in 0..<12 {
            if visible() { button.tap(); return }
            toolbar.swipeLeft()
        }
        for _ in 0..<12 {
            if visible() { button.tap(); return }
            toolbar.swipeRight()
        }
        XCTFail("Panel unavailable: \(name)")
    }

    @MainActor private func capture(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor func testLinearRulerCurvesOverlayAndLandscape() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launch()
        openDocument(app)

        let exposure = app.buttons["parameter-exposure"]
        XCTAssertTrue(exposure.waitForExistence(timeout: 10))
        let ruler = app.descendants(matching: .any).matching(identifier: "adjustment-ruler").firstMatch
        XCTAssertTrue(ruler.waitForExistence(timeout: 5))
        app.buttons["adjustment-reset"].tap()
        let initial = ruler.value as? String
        ruler.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertEqual(ruler.value as? String, initial, "First contact must not jump")
        let start = ruler.coordinate(withNormalizedOffset: CGVector(dx: 0.54, dy: 0.5))
        start.press(forDuration: 0.12, thenDragTo: ruler.coordinate(withNormalizedOffset: CGVector(dx: 0.50, dy: 0.5)))
        XCTAssertNotEqual(ruler.value as? String, initial)
        XCTAssertTrue(app.buttons["arrow.uturn.backward"].isEnabled)
        capture("01-light-linear-ruler", app)
        app.buttons["adjustment-reset"].tap()

        app.buttons["parameter-contrast"].tap()
        XCTAssertTrue(app.buttons["parameter-contrast"].isSelected)
        app.buttons["adjustment-value-entry"].tap()
        let field = app.alerts.firstMatch.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap(); field.typeText("12")
        let apply = app.alerts.firstMatch.buttons
            .matching(NSPredicate(format: "label == %@ OR label == %@", "Apply", "Appliquer"))
            .firstMatch
        XCTAssertTrue(apply.waitForExistence(timeout: 3)); apply.tap()
        XCTAssertTrue((ruler.value as? String)?.contains("12") == true)
        app.buttons["adjustment-reset"].tap()
        XCTAssertTrue((ruler.value as? String)?.contains("0") == true)

        selectPanel("Color", in: app)
        XCTAssertTrue(app.buttons["parameter-temperature"].waitForExistence(timeout: 5))
        capture("02-color-linear-ruler", app)

        selectPanel("Lighting", in: app)
        XCTAssertTrue(app.buttons["parameter-intensity"].waitForExistence(timeout: 10))
        let lightingToggle = app.switches["depth-lighting-enable"]
        if lightingToggle.exists, (lightingToggle.value as? String) == "0" { lightingToggle.tap() }
        capture("03-lighting-linear-ruler", app)

        selectPanel("Curves", in: app)
        let canvas = app.descendants(matching: .any).matching(identifier: "photo-canvas").firstMatch
        let originalCanvas = canvas.frame
        let chart = app.descendants(matching: .any).matching(identifier: "tone-curve-chart").firstMatch
        XCTAssertTrue(chart.waitForExistence(timeout: 8))
        let before = chart.value as? String
        chart.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertNotEqual(chart.value as? String, before)
        XCTAssertTrue(app.sliders["Input"].exists)
        XCTAssertTrue(app.sliders["Output"].exists)
        capture("04-curves-overlay-direct-edit", app)
        app.buttons["curve-card-collapse"].tap()
        XCTAssertEqual(canvas.frame, originalCanvas)
        capture("05-curves-overlay-collapsed", app)
        app.buttons["curve-card-collapse"].tap()
        XCTAssertFalse(app.buttons["curve-edit-mode"].exists)
        capture("06-curves-overlay-expanded", app)

        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(app.buttons["controls-side-switch"].waitForExistence(timeout: 10))
        XCTAssertGreaterThan(canvas.frame.width, 300)
        capture("07-landscape-curves-overlay", app)
        XCUIDevice.shared.orientation = .portrait
    }
}
