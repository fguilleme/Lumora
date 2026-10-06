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
        app.launchArguments += ["-AppleLanguages", "(en)"]
        app.launch()
        openDocument(app)

        let exposure = app.buttons["parameter-exposure"]
        XCTAssertTrue(exposure.waitForExistence(timeout: 10))
        let ruler = app.descendants(matching: .any).matching(identifier: "adjustment-ruler").firstMatch
        XCTAssertTrue(ruler.waitForExistence(timeout: 5))
        let canvas = app.descendants(matching: .any).matching(identifier: "photo-canvas").firstMatch

        let auto = app.buttons["auto-light"]
        XCTAssertTrue(auto.isHittable)
        let autoReset = app.buttons["auto-reset"]
        if autoReset.exists { autoReset.tap() }
        auto.tap()
        let autoStatus = app.staticTexts["auto-status-light"]
        let autoApplied = NSPredicate(format: "label == %@", "Auto base")
        expectation(for: autoApplied, evaluatedWith: autoStatus)
        waitForExpectations(timeout: 20)
        XCTAssertTrue(app.buttons["arrow.uturn.backward"].isEnabled)
        app.buttons["arrow.uturn.backward"].tap()

        app.buttons["adjustment-reset"].tap()
        let initial = ruler.value as? String
        canvas.pinch(withScale: 1.25, velocity: 1.0)
        canvas.swipeUp(velocity: .slow)
        XCTAssertEqual(ruler.value as? String, initial, "Photo zoom and pan must not adjust the selected parameter")
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
        let originalCanvas = canvas.frame
        let disclosure = app.buttons["curve-card-collapse"]
        XCTAssertTrue(disclosure.waitForExistence(timeout: 5))
        if disclosure.label == "Expand curves" { disclosure.tap() }
        let curveControls = app.descendants(matching: .any).matching(identifier: "curve-controls-scroll").firstMatch
        XCTAssertTrue(curveControls.waitForExistence(timeout: 8))
        curveControls.coordinate(withNormalizedOffset: CGVector(dx: 0.50, dy: 0.68)).tap()
        XCTAssertTrue(app.buttons["parameter-input"].exists)
        XCTAssertTrue(app.buttons["parameter-output"].exists)
        XCTAssertTrue(ruler.exists)
        let eyedropper = app.buttons["curve-eyedropper"]
        XCTAssertTrue(eyedropper.isHittable)
        eyedropper.tap()
        let samplingSurface = app.descendants(matching: .any).matching(identifier: "curve-photo-sampling").firstMatch
        XCTAssertTrue(samplingSurface.waitForExistence(timeout: 5))
        samplingSurface.coordinate(withNormalizedOffset: CGVector(dx: 0.65, dy: 0.45)).tap()
        eyedropper.tap()
        capture("04-curves-overlay-direct-edit", app)
        disclosure.tap()
        XCTAssertEqual(canvas.frame, originalCanvas)
        capture("05-curves-overlay-collapsed", app)
        disclosure.tap()
        XCTAssertFalse(app.buttons["curve-edit-mode"].exists)
        capture("06-curves-overlay-expanded", app)

        app.terminate()
        app.launchArguments = ["-AppleLanguages", "(en)", "--app-store-panel", "Geometry"]
        app.launch()
        openDocument(app)
        let geometryMode = app.segmentedControls["geometry-mode"]
        XCTAssertTrue(geometryMode.waitForExistence(timeout: 8))
        let geometryCanvasFrame = canvas.frame
        let geometryCanvasValue = canvas.value as? String
        let undoBeforeModeChange = app.buttons["Undo"].isEnabled
        geometryMode.buttons["Adjustments"].tap()
        XCTAssertEqual(canvas.frame, geometryCanvasFrame)
        XCTAssertEqual(canvas.value as? String, geometryCanvasValue)
        XCTAssertEqual(app.buttons["Undo"].isEnabled, undoBeforeModeChange)
        XCTAssertTrue(app.buttons["parameter-straighten"].exists)
        capture("07-geometry-adjustments", app)

        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(app.buttons["controls-side-switch"].waitForExistence(timeout: 10))
        XCTAssertGreaterThan(canvas.frame.width, 300)
        capture("08-landscape-geometry", app)
        XCUIDevice.shared.orientation = .portrait
    }

    @MainActor func testCurvesGeometryAndLandscapeFinishing() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "--app-store-panel", "Curves"]
        app.launch()
        openDocument(app)

        let canvas = app.descendants(matching: .any).matching(identifier: "photo-canvas").firstMatch
        let originalCanvas = canvas.frame
        let disclosure = app.buttons["curve-card-collapse"]
        XCTAssertTrue(disclosure.waitForExistence(timeout: 8))
        if disclosure.label == "Expand curves" { disclosure.tap() }
        let curveControls = app.descendants(matching: .any).matching(identifier: "curve-controls-scroll").firstMatch
        XCTAssertTrue(curveControls.waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["parameter-input"].exists)
        XCTAssertTrue(app.buttons["parameter-output"].exists)
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "adjustment-ruler").firstMatch.exists)

        let eyedropper = app.buttons["curve-eyedropper"]
        XCTAssertTrue(eyedropper.isHittable)
        eyedropper.tap()
        let samplingSurface = app.descendants(matching: .any).matching(identifier: "curve-photo-sampling").firstMatch
        XCTAssertTrue(samplingSurface.waitForExistence(timeout: 5))
        samplingSurface.coordinate(withNormalizedOffset: CGVector(dx: 0.65, dy: 0.45)).tap()
        eyedropper.tap()
        capture("09-curves-common-ruler-and-eyedropper", app)

        disclosure.tap()
        XCTAssertEqual(canvas.frame, originalCanvas)
        disclosure.tap()
        XCTAssertEqual(canvas.frame, originalCanvas)

        app.terminate()
        app.launchArguments = ["-AppleLanguages", "(en)", "--app-store-panel", "Geometry"]
        app.launch()
        openDocument(app)
        let geometryMode = app.segmentedControls["geometry-mode"]
        XCTAssertTrue(geometryMode.waitForExistence(timeout: 8))
        let geometryCanvasFrame = canvas.frame
        let geometryCanvasValue = canvas.value as? String
        let undoBeforeModeChange = app.buttons["Undo"].isEnabled
        geometryMode.buttons["Adjustments"].tap()
        XCTAssertEqual(canvas.frame, geometryCanvasFrame)
        XCTAssertEqual(canvas.value as? String, geometryCanvasValue)
        XCTAssertEqual(app.buttons["Undo"].isEnabled, undoBeforeModeChange)
        XCTAssertTrue(app.buttons["parameter-straighten"].exists)
        capture("10-geometry-adjustments", app)

        XCUIDevice.shared.orientation = .landscapeLeft
        let sideSwitch = app.buttons["controls-side-switch"]
        XCTAssertTrue(sideSwitch.waitForExistence(timeout: 10))
        XCTAssertGreaterThan(canvas.frame.width, 300)
        let canvasOriginBeforeSideSwitch = canvas.frame.minX
        sideSwitch.tap()
        XCTAssertNotEqual(canvas.frame.minX, canvasOriginBeforeSideSwitch)
        capture("11-landscape-geometry", app)
        XCUIDevice.shared.orientation = .portrait
    }
}
