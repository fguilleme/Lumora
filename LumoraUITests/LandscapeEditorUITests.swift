import XCTest

final class LandscapeEditorUITests: XCTestCase {
    @MainActor func testLandscapeCreativePanel() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launch()
        let creative = app.buttons["Creative"]
        XCTAssertTrue(creative.waitForExistence(timeout: 20))
        creative.tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "creative-controls").firstMatch.exists)
        capture("creative_panel", app)
        XCUIDevice.shared.orientation = .portrait
    }

    @MainActor func testLandscapeHistogramAndSlider() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments += ["-ui-testing-clipping", "-ui-testing-landscape"]
        app.launch()
        let canvas = app.descendants(matching: .any).matching(identifier: "photo-canvas").firstMatch
        XCTAssertTrue(canvas.waitForExistence(timeout: 20))
        let photoFrame = canvas.frame
        let generation = canvas.value as? String
        let histogram = app.buttons["histogram-overlay"]
        XCTAssertTrue(histogram.waitForExistence(timeout: 10))
        let compactWidth = histogram.frame.width
        histogram.tap()
        XCTAssertEqual(histogram.label, "Réduire l’histogramme RVB")
        XCTAssertGreaterThan(histogram.frame.width, compactWidth * 1.5)
        XCTAssertEqual(canvas.frame, photoFrame)
        histogram.press(forDuration: 1)
        XCTAssertTrue((histogram.value as? String)?.contains("Activations clipping : 1.") == true)
        XCTAssertFalse(app.images["clipping-warning-overlay"].exists)
        XCTAssertEqual(canvas.value as? String, generation)

        let exposure = app.sliders["exposure"]
        XCTAssertTrue(exposure.waitForExistence(timeout: 10))
        let initial = exposure.value as? String
        exposure.adjust(toNormalizedSliderPosition: 0.65)
        XCTAssertNotEqual(exposure.value as? String, initial)
        XCTAssertTrue(app.buttons["Annuler"].isEnabled)
        XCUIDevice.shared.orientation = .portrait
    }

    @MainActor func testNewestPhotoAspectInPortraitAndLandscape() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launch()
        let importButton = app.buttons["header-photos"]
        XCTAssertTrue(importButton.waitForExistence(timeout: 20))
        importButton.tap()
        let photo = app.images.matching(identifier: "PXGGridLayout-Info").firstMatch
        XCTAssertTrue(photo.waitForExistence(timeout: 20))
        photo.tap()
        let canvas = app.descendants(matching: .any).matching(identifier: "photo-canvas").firstMatch
        XCTAssertTrue(canvas.waitForExistence(timeout: 30))
        capture("aspect_portrait", app)
        print("ASPECT_PORTRAIT_CANVAS", canvas.frame)
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(app.buttons["controls-side-switch"].waitForExistence(timeout: 10))
        Thread.sleep(forTimeInterval: 0.8)
        capture("aspect_landscape", app)
        print("ASPECT_LANDSCAPE_CANVAS", canvas.frame)
        XCUIDevice.shared.orientation = .portrait
    }

    @MainActor func testLandscapeColumnsSidePreferenceAndRotation() throws {
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
        capture("portrait_non_regression", app)
        let portraitHeight = canvas.frame.height
        print("PORTRAIT_FRAME", canvas.frame)
        let generationBefore = canvas.value as? String
        let undoBefore = app.buttons["Annuler"].isEnabled

        XCUIDevice.shared.orientation = .landscapeLeft
        let controls = app.descendants(matching: .any).matching(identifier: "editor-controls-column").firstMatch
        let side = app.buttons["controls-side-switch"]
        XCTAssertTrue(side.waitForExistence(timeout: 10))
        Thread.sleep(forTimeInterval: 0.8)
        if side.value as? String == "Fin" { side.tap() }
        XCTAssertEqual(side.value as? String, "Début")
        XCTAssertLessThan(controls.frame.midX, canvas.frame.midX)
        XCTAssertGreaterThan(canvas.frame.width, controls.frame.width)
        XCTAssertGreaterThan(canvas.frame.height, 180)
        print("LANDSCAPE_FRAME", canvas.frame, "CONTROLS_FRAME", controls.frame)
        capture("controls_leading", app)
        capture("light_panel", app)
        side.tap()
        XCTAssertEqual(side.value as? String, "Fin")
        XCTAssertGreaterThan(controls.frame.midX, canvas.frame.midX)
        XCTAssertEqual(app.buttons["Annuler"].isEnabled, undoBefore)
        XCTAssertEqual(canvas.value as? String, generationBefore)
        capture("controls_trailing", app)

        selectPanel("Couleur", in: app)
        capture("color_panel", app)
        selectPanel("Colorimétrie", in: app)
        capture("grading_panel", app)
        selectPanel("Effets", in: app)
        capture("effects_panel", app)
        selectPanel("Masques", in: app)
        capture("masks_panel", app)

        app.terminate()
        app.launch()
        XCTAssertTrue(side.waitForExistence(timeout: 20))
        selectPanel("Courbes", in: app)
        let curveChart = app.descendants(matching: .any).matching(identifier: "tone-curve-chart").firstMatch
        let curveScroll = app.scrollViews["curve-controls-scroll"]
        for _ in 0..<4 where !curveChart.isHittable { curveScroll.swipeUp() }
        capture("curves_panel", app)
        XCTAssertTrue(curveChart.exists)
        XCTAssertGreaterThanOrEqual(curveChart.frame.width, 180)
        let editCurve = app.buttons["curve-edit-mode"]
        for _ in 0..<4 where !editCurve.isHittable { curveScroll.swipeDown() }
        XCTAssertTrue(editCurve.isHittable)
        editCurve.tap()
        let firstPoint = app.buttons["curve-point-0"]
        for _ in 0..<4 where !firstPoint.isHittable { curveScroll.swipeUp() }
        XCTAssertTrue(firstPoint.isHittable)
        firstPoint.tap()
        XCUIDevice.shared.orientation = .portrait
        XCTAssertTrue(canvas.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(canvas.frame.height, portraitHeight - 2)
        XCTAssertEqual(editCurve.label, "Terminé")
        XCUIDevice.shared.orientation = .landscapeRight
        XCTAssertTrue(side.waitForExistence(timeout: 10))
        XCTAssertEqual(side.value as? String, "Fin")
        XCTAssertGreaterThan(controls.frame.midX, canvas.frame.midX)
        XCTAssertEqual(canvas.value as? String, generationBefore)
        XCTAssertEqual(editCurve.label, "Terminé")
        for _ in 0..<4 where !editCurve.isHittable { curveScroll.swipeDown() }
        editCurve.tap()
        XCTAssertEqual(editCurve.label, "Modifier")

        app.terminate()
        app.launch()
        XCTAssertTrue(side.waitForExistence(timeout: 10))
        XCTAssertEqual(side.value as? String, "Fin")
        XCUIDevice.shared.orientation = .portrait
    }

    @MainActor private func selectPanel(_ name: String, in app: XCUIApplication) {
        let tools = app.scrollViews["tools-toolbar"]
        let target = app.buttons[name]
        for _ in 0..<12 where !target.isHittable {
            tools.coordinate(withNormalizedOffset: CGVector(dx: 0.78, dy: 0.5))
                .press(forDuration: 0.15, thenDragTo: tools.coordinate(withNormalizedOffset: CGVector(dx: 0.24, dy: 0.5)))
        }
        for _ in 0..<12 where !target.isHittable {
            tools.coordinate(withNormalizedOffset: CGVector(dx: 0.24, dy: 0.5))
                .press(forDuration: 0.15, thenDragTo: tools.coordinate(withNormalizedOffset: CGVector(dx: 0.78, dy: 0.5)))
        }
        XCTAssertTrue(target.isHittable, "Panneau inaccessible : \(name)")
        target.tap()
    }

    @MainActor private func capture(_ name: String, _ app: XCUIApplication) {
        let image = XCTAttachment(screenshot: app.screenshot())
        image.name = name
        image.lifetime = .keepAlways
        add(image)
    }
}
