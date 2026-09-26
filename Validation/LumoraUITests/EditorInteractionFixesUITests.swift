import XCTest

final class EditorInteractionFixesUITests: XCTestCase {
    @MainActor private func open() throws -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication(); app.launch()
        let canvas = app.descendants(matching: .any).matching(identifier: "photo-canvas").firstMatch
        if !canvas.waitForExistence(timeout: 5) {
            app.buttons["Photos"].tap()
            let photo = app.images.matching(identifier: "PXGGridLayout-Info").element(boundBy: 1)
            XCTAssertTrue(photo.waitForExistence(timeout: 20)); photo.tap()
            XCTAssertTrue(canvas.waitForExistence(timeout: 30))
        }
        app.buttons["Import and options"].tap(); app.buttons["Reset settings"].tap()
        return app
    }
    @MainActor private func panel(_ name: String, _ app: XCUIApplication) {
        let toolbar = app.scrollViews["tools-toolbar"]
        for _ in 0..<8 where !app.buttons[name].isHittable { toolbar.swipeRight() }
        for _ in 0..<8 where !app.buttons[name].isHittable { toolbar.swipeLeft() }
        app.buttons[name].tap()
    }
    @MainActor func testSinglePhotoTapOpensImageOnlyFullscreenPreview() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = try open()
        let canvas = app.descendants(matching: .any).matching(identifier: "photo-canvas").firstMatch
        let fullscreen = app.descendants(matching: .any).matching(identifier: "fullscreen-photo").firstMatch
        let center = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))

        center.tap()
        XCTAssertTrue(fullscreen.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["histogram-overlay"].isHittable)
        fullscreen.tap()
        XCTAssertFalse(fullscreen.exists)

        center.doubleTap()
        XCTAssertFalse(fullscreen.exists, "The existing double-tap must still reset zoom")
        let histogram = app.buttons["histogram-overlay"]
        XCTAssertTrue(histogram.isHittable, "Histogram frame: \(histogram.frame)")
        histogram.tap()
        XCTAssertFalse(fullscreen.exists, "Tapping the histogram must not open the photo viewer")
        histogram.tap()
        center.press(forDuration: 0.7)
        XCTAssertFalse(fullscreen.exists, "Holding to compare the original must not open full screen")
    }

    @MainActor func testLandscapePhotoTapOpensFullscreenPreview() throws {
        XCUIDevice.shared.orientation = .portrait
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = try open()
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(app.buttons["controls-side-switch"].waitForExistence(timeout: 5))
        let canvas = app.descendants(matching: .any).matching(identifier: "photo-canvas").firstMatch
        let fullscreen = app.descendants(matching: .any).matching(identifier: "fullscreen-photo").firstMatch
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(fullscreen.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["histogram-overlay"].isHittable)
        fullscreen.tap()
        XCTAssertFalse(fullscreen.exists)
    }
    @MainActor func testZoomedMaskHandlesAndBrushNavigation() throws {
        let app = try open()
        app.buttons["Import and options"].tap(); app.buttons["Render metrics"].tap()
        panel("Masks", app)
        app.scrollViews["masks-controls"].buttons["Radial"].tap()
        let canvas = app.descendants(matching: .any).matching(identifier: "photo-canvas").firstMatch
        canvas.pinch(withScale: 2, velocity: 1)
        let handle = app.descendants(matching: .any).matching(identifier: "mask-handle-center").firstMatch
        XCTAssertTrue(handle.waitForExistence(timeout: 5))
        let before = handle.frame.midX
        let start = handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let metrics = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "generation")).firstMatch
        let renderBefore = metrics.label
        start.press(forDuration: 0.5, thenDragTo: start.withOffset(CGVector(dx: 45, dy: 0)))
        XCTAssertEqual(handle.frame.midX - before, 45, accuracy: 5, "Handle drag must not pan the image as well")
        XCTAssertEqual(metrics.label, renderBefore, "Mask editing must not develop the full photograph")
        app.buttons["Undo"].tap(); XCTAssertEqual(handle.frame.midX, before, accuracy: 3)
        app.buttons["Redo"].tap(); XCTAssertEqual(handle.frame.midX - before, 45, accuracy: 5)
        panel("Light", app)
        XCTAssertNotEqual(metrics.label, renderBefore, "Leaving Masks schedules the deferred development")
        app.buttons["Import and options"].tap(); app.buttons["Reset settings"].tap()
        panel("Masks", app); app.scrollViews["masks-controls"].buttons["Brush"].tap()
        let modes = app.segmentedControls["brush-mode"]
        let controls = app.scrollViews["masks-controls"]
        for _ in 0..<12 where !modes.isHittable {
            controls.coordinate(withNormalizedOffset: CGVector(dx: 0.03, dy: 0.85)).press(forDuration: 0.05, thenDragTo: controls.coordinate(withNormalizedOffset: CGVector(dx: 0.03, dy: 0.2)))
        }
        XCTAssertTrue(modes.isHittable)
        let strokeStart = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.35, dy: 0.4))
        let brushRender = metrics.label
        strokeStart.press(forDuration: 0.05, thenDragTo: strokeStart.withOffset(CGVector(dx: 100, dy: 45)))
        XCTAssertEqual(metrics.label, brushRender)
        app.buttons["Undo"].tap(); XCTAssertTrue(app.buttons["Redo"].isEnabled)
        modes.buttons["Pan"].tap()
        let pan = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: 0.65))
        pan.press(forDuration: 0.05, thenDragTo: pan.withOffset(CGVector(dx: -40, dy: 20)))
        XCTAssertTrue(app.buttons["Redo"].isEnabled, "Pan must not record a brush stroke or change edit history")
        app.buttons["Redo"].tap()
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "Mask brush navigation"; shot.lifetime = .keepAlways; add(shot)
        app.buttons["Import and options"].tap(); app.buttons["Render metrics"].tap()
    }
    @MainActor func testBrushDoubleTapResetsZoomWithoutEditingMask() throws {
        let app = try open()
        panel("Masks", app)
        app.scrollViews["masks-controls"].buttons["Brush"].tap()
        let canvas = app.descendants(matching: .any).matching(identifier: "photo-canvas").firstMatch
        let modes = app.segmentedControls["brush-mode"]
        let controls = app.scrollViews["masks-controls"]
        for _ in 0..<12 where !modes.isHittable {
            controls.coordinate(withNormalizedOffset: CGVector(dx: 0.03, dy: 0.85)).press(forDuration: 0.05, thenDragTo: controls.coordinate(withNormalizedOffset: CGVector(dx: 0.03, dy: 0.2)))
        }
        for mode in ["Paint", "Erase", "Pan"] {
            modes.buttons[mode].tap()
            canvas.pinch(withScale: 2, velocity: 1)
            XCTAssertNotEqual(canvas.value as? String, "Zoom 100 %", mode)
            canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).doubleTap()
            XCTAssertEqual(canvas.value as? String, "Zoom 100 %", mode)
        }
        // The only edit must still be creation of the brush mask.
        app.buttons["Undo"].tap()
        XCTAssertTrue(controls.buttons["Brush"].waitForExistence(timeout: 5))
        app.buttons["Redo"].tap()
        let restoredMask = controls.buttons["Pinceau 1"]
        XCTAssertTrue(restoredMask.waitForExistence(timeout: 5))
        restoredMask.tap()
        XCTAssertTrue(modes.waitForExistence(timeout: 5))
    }

    @MainActor func testMaskVisibilityTogglesOverlayOnly() throws {
        let app = try open()
        panel("Masks", app)
        let controls = app.scrollViews["masks-controls"]
        controls.buttons["Radial"].tap()
        let visibility = app.buttons["layer-visibility"]
        XCTAssertTrue(visibility.waitForExistence(timeout: 5))
        XCTAssertTrue(visibility.label.contains("Visible"))
        let canvas = app.descendants(matching: .any).matching(identifier: "photo-canvas").firstMatch
        let filled = canvas.screenshot().pngRepresentation
        visibility.tap()
        XCTAssertTrue(visibility.label.contains("Outline"))
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "mask-handle-center").firstMatch.exists)
        // Allow the asynchronous composed-matte visualization to finish.
        RunLoop.current.run(until: Date().addingTimeInterval(1))
        XCTAssertNotEqual(canvas.screenshot().pngRepresentation, filled)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "Mask contour only"; shot.lifetime = .keepAlways; add(shot)
        visibility.tap()
        XCTAssertTrue(visibility.label.contains("Visible"))
        // Display toggles must not create document history entries.
        app.buttons["Undo"].tap()
        XCTAssertTrue(controls.buttons["Radial"].waitForExistence(timeout: 5))
    }

    @MainActor func testInformationAndDirectCreativeActions() throws {
        let app = try open()
        let info = app.descendants(matching: .any).matching(identifier: "photo-information").firstMatch
        XCTAssertTrue(info.waitForExistence(timeout: 5))
        XCTAssertFalse(info.staticTexts.allElementsBoundByIndex.contains { $0.label.lowercased().hasSuffix(".jpeg") })
        for name in ["Creative", "Optics", "Geometry", "Masks", "Presets"] {
            panel(name, app); XCTAssertFalse(info.exists, name)
        }
        panel("Light", app); XCTAssertTrue(info.exists)
        panel("Creative", app); app.buttons["creative-add"].tap()
        app.buttons.matching(NSPredicate(format: "label == %@ AND NOT (identifier BEGINSWITH %@)", "Low Key", "creative-effect-")).firstMatch.tap()
        let toggle = app.buttons["creative-action-toggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5)); XCTAssertGreaterThanOrEqual(toggle.frame.height, 44)
        XCTAssertFalse(app.buttons["Effect options"].exists)
        toggle.tap(); XCTAssertEqual(toggle.label, "Enable effect"); toggle.tap()
        let effects = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "creative-effect-"))
        let count = effects.count
        app.buttons["creative-action-duplicate"].tap(); XCTAssertEqual(effects.count, count + 1)
        app.buttons["Undo"].tap(); XCTAssertEqual(effects.count, count)
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "Creative direct actions"; shot.lifetime = .keepAlways; add(shot)
        app.buttons["creative-action-delete"].tap(); XCTAssertEqual(effects.count, count - 1)
    }
}
