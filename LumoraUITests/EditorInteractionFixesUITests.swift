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
        app.buttons["Importer et options"].tap(); app.buttons["Réinitialiser les réglages"].tap()
        return app
    }
    @MainActor private func panel(_ name: String, _ app: XCUIApplication) {
        let toolbar = app.scrollViews["tools-toolbar"]
        for _ in 0..<8 where !app.buttons[name].isHittable { toolbar.swipeRight() }
        for _ in 0..<8 where !app.buttons[name].isHittable { toolbar.swipeLeft() }
        app.buttons[name].tap()
    }
    @MainActor func testZoomedMaskHandlesAndBrushNavigation() throws {
        let app = try open()
        app.buttons["Importer et options"].tap(); app.buttons["Mesures de rendu"].tap()
        panel("Masques", app)
        app.scrollViews["masks-controls"].buttons["Radial"].tap()
        let canvas = app.descendants(matching: .any).matching(identifier: "photo-canvas").firstMatch
        canvas.pinch(withScale: 2, velocity: 1)
        let handle = app.descendants(matching: .any).matching(identifier: "mask-handle-center").firstMatch
        XCTAssertTrue(handle.waitForExistence(timeout: 5))
        let before = handle.frame.midX
        let start = handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let metrics = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "génération")).firstMatch
        let renderBefore = metrics.label
        start.press(forDuration: 0.5, thenDragTo: start.withOffset(CGVector(dx: 45, dy: 0)))
        XCTAssertEqual(handle.frame.midX - before, 45, accuracy: 5, "Handle drag must not pan the image as well")
        XCTAssertEqual(metrics.label, renderBefore, "Mask editing must not develop the full photograph")
        app.buttons["Annuler"].tap(); XCTAssertEqual(handle.frame.midX, before, accuracy: 3)
        app.buttons["Rétablir"].tap(); XCTAssertEqual(handle.frame.midX - before, 45, accuracy: 5)
        panel("Lumière", app)
        XCTAssertNotEqual(metrics.label, renderBefore, "Leaving Masks schedules the deferred development")
        app.buttons["Importer et options"].tap(); app.buttons["Réinitialiser les réglages"].tap()
        panel("Masques", app); app.scrollViews["masks-controls"].buttons["Pinceau"].tap()
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
        app.buttons["Annuler"].tap(); XCTAssertTrue(app.buttons["Rétablir"].isEnabled)
        modes.buttons["Déplacer"].tap()
        let pan = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: 0.65))
        pan.press(forDuration: 0.05, thenDragTo: pan.withOffset(CGVector(dx: -40, dy: 20)))
        XCTAssertTrue(app.buttons["Rétablir"].isEnabled, "Pan must not record a brush stroke or change edit history")
        app.buttons["Rétablir"].tap()
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "Mask brush navigation"; shot.lifetime = .keepAlways; add(shot)
        app.buttons["Importer et options"].tap(); app.buttons["Mesures de rendu"].tap()
    }
    @MainActor func testInformationAndDirectCreativeActions() throws {
        let app = try open()
        let info = app.descendants(matching: .any).matching(identifier: "photo-information").firstMatch
        XCTAssertTrue(info.waitForExistence(timeout: 5))
        XCTAssertFalse(info.staticTexts.allElementsBoundByIndex.contains { $0.label.lowercased().hasSuffix(".jpeg") })
        for name in ["Creative", "Optique", "Géométrie", "Masques", "Presets"] {
            panel(name, app); XCTAssertFalse(info.exists, name)
        }
        panel("Lumière", app); XCTAssertTrue(info.exists)
        panel("Creative", app); app.buttons["creative-add"].tap()
        app.buttons.matching(NSPredicate(format: "label == %@ AND NOT (identifier BEGINSWITH %@)", "Low Key", "creative-effect-")).firstMatch.tap()
        let toggle = app.buttons["creative-action-toggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5)); XCTAssertGreaterThanOrEqual(toggle.frame.height, 44)
        XCTAssertFalse(app.buttons["Options de l’effet"].exists)
        toggle.tap(); XCTAssertEqual(toggle.label, "Activer l’effet"); toggle.tap()
        let effects = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "creative-effect-"))
        let count = effects.count
        app.buttons["creative-action-duplicate"].tap(); XCTAssertEqual(effects.count, count + 1)
        app.buttons["Annuler"].tap(); XCTAssertEqual(effects.count, count)
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "Creative direct actions"; shot.lifetime = .keepAlways; add(shot)
        app.buttons["creative-action-delete"].tap(); XCTAssertEqual(effects.count, count - 1)
    }
}
