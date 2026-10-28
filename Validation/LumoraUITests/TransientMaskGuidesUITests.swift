import XCTest

final class TransientMaskGuidesUITests: XCTestCase {

    @MainActor func testActiveLayerMenuHitArea() throws {
        let app = try launch()
        open("Light", title: "Lumière", app)
        let selector = app.buttons["active-layer"]
        XCTAssertTrue(selector.waitForExistence(timeout: 5))
        let maskName = try XCTUnwrap(selector.value as? String)
        func select(_ title: String, at offset: CGVector) {
            XCTAssertGreaterThanOrEqual(selector.frame.height, 44)
            XCTAssertGreaterThanOrEqual(selector.frame.width, 44)
            selector.coordinate(withNormalizedOffset: offset).tap()
            let item = app.collectionViews.buttons[title].firstMatch
            XCTAssertTrue(item.waitForExistence(timeout: 5))
            item.tap()
            XCTAssertEqual(selector.value as? String, title)
        }
        // The blank padding above/below the label must open the same menu.
        select("Photo entière", at: .init(dx: 0.5, dy: 0.08))
        select(maskName, at: .init(dx: 0.5, dy: 0.92))
        capture("07-mask-selector-portrait", app)
        XCUIDevice.shared.orientation = .landscapeLeft
        expectation(for: NSPredicate { _, _ in
            app.windows.firstMatch.frame.width > app.windows.firstMatch.frame.height
        }, evaluatedWith: app)
        waitForExpectations(timeout: 10)
        select("Photo entière", at: .init(dx: 0.5, dy: 0.08))
        select(maskName, at: .init(dx: 0.5, dy: 0.92))
        app.buttons["controls-side-switch"].tap()
        select("Photo entière", at: .init(dx: 0.5, dy: 0.08))
        select(maskName, at: .init(dx: 0.5, dy: 0.92))
        // Finish the system rotation/side transition before taking evidence.
        RunLoop.current.run(until: Date().addingTimeInterval(1))
        capture("08-mask-selector-landscape", app)
        XCUIDevice.shared.orientation = .portrait
    }

    @MainActor func testRadialGuidesRevealWithoutEditingAndDragStaysVisible() throws {
        let app = try launch()
        open("Light", title: "Lumière", app)
        let center = handle("center", app)
        XCTAssertTrue(center.waitForExistence(timeout: 5))
        assertNoOverlay(app)
        capture("01-radial-light", app)
        let original = center.frame
        enter("0,70", app)
        waitForHidden(center)
        let canvas = photo(app)
        canvas.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(center.waitForExistence(timeout: 5))
        XCTAssertEqual(center.frame.midX, original.midX, accuracy: 1)
        XCTAssertEqual(center.frame.midY, original.midY, accuracy: 1)
        // Revealing guides must not add an Undo entry: this undoes Exposure.
        app.buttons["arrow.uturn.backward"].tap()
        XCTAssertTrue((app.buttons["parameter-exposure"].value as? String)?.hasPrefix("0,00") == true)
        app.buttons["arrow.uturn.forward"].tap()
        revealIfHidden(center, app)
        let before = center.frame
        let start = center.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5))
        start.press(forDuration: 4.2, thenDragTo: start.withOffset(.init(dx: 30, dy: 20)))
        XCTAssertTrue(center.exists)
        XCTAssertGreaterThan(center.frame.midX, before.midX + 20)
        XCTAssertGreaterThan(center.frame.midY, before.midY + 10)
        assertNoOverlay(app)
        capture("02-radial-moved", app)
        app.buttons["arrow.uturn.backward"].tap()
        revealIfHidden(center, app)
        XCTAssertEqual(center.frame.midX, before.midX, accuracy: 2)
        XCTAssertEqual(center.frame.midY, before.midY, accuracy: 2)
        waitForHidden(center)
        capture("03-guides-hidden", app)
        let oldZoom = canvas.value as? String
        canvas.pinch(withScale: 1.5, velocity: 1)
        XCTAssertNotEqual(canvas.value as? String, oldZoom)
        let pan = canvas.coordinate(withNormalizedOffset: .init(dx: 0.25, dy: 0.55))
        pan.press(forDuration: 0.05, thenDragTo: pan.withOffset(.init(dx: 25, dy: 15)))
        XCTAssertFalse(center.exists)
        // Zoom/pan and the previous reveal also create no mask/history edit.
        app.buttons["arrow.uturn.backward"].tap()
        XCTAssertTrue((app.buttons["parameter-exposure"].value as? String)?.hasPrefix("0,00") == true)
        canvas.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(center.waitForExistence(timeout: 5))
        assertNoOverlay(app)
        capture("04-guides-zoom-pan", app)
    }

    @MainActor func testLinearGuidesAndNonGradientMasks() throws {
        let app = try launch()
        app.buttons["mask-new"].tap()
        app.buttons["mask-create-linear"].tap()
        open("Effects", title: "Effets", app)
        let center = handle("center", app)
        XCTAssertTrue(center.waitForExistence(timeout: 5))
        assertNoOverlay(app)
        let original = center.frame
        waitForHidden(center)
        photo(app).coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(center.waitForExistence(timeout: 5))
        XCTAssertEqual(center.frame.midX, original.midX, accuracy: 1)
        XCTAssertEqual(center.frame.midY, original.midY, accuracy: 1)
        XCTAssertTrue(handle("direction", app).exists)
        XCTAssertTrue(handle("feather", app).exists)
        capture("05-linear-effects", app)
        let direction = handle("direction", app)
        let from = direction.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5))
        from.press(forDuration: 0.1, thenDragTo: from.withOffset(.init(dx: -15, dy: 25)))
        XCTAssertTrue(center.exists)
        capture("06-linear-rotated", app)
        open("Masks", title: "Masques", app)
        app.buttons["mask-new"].tap()
        app.buttons["mask-create-brush"].tap()
        open("Color", title: "Couleur", app)
        XCTAssertFalse(center.exists)
        assertNoOverlay(app)
        open("Masks", title: "Masques", app)
        app.buttons["mask-new"].tap()
        app.buttons["mask-create-similarity"].tap()
        open("Effects", title: "Effets", app)
        XCTAssertFalse(center.exists)
        assertNoOverlay(app)
    }

    @MainActor private func launch() throws -> XCUIApplication {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(fr)", "-AppleLocale", "fr_FR",
            "--app-store-image", "DetailFeedback.jpg", "--app-store-panel", "Masks"]
        app.launch()
        XCTAssertTrue(photo(app).waitForExistence(timeout: 40))
        XCTAssertTrue(handle("center", app).waitForExistence(timeout: 10))
        return app
    }

    @MainActor private func photo(_ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: "photo-canvas").firstMatch
    }
    @MainActor private func handle(_ name: String, _ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: "mask-handle-\(name)").firstMatch
    }
    @MainActor private func assertNoOverlay(_ app: XCUIApplication) {
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "mask-red-overlay").firstMatch.exists)
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "mask-outline-overlay").firstMatch.exists)
    }
    @MainActor private func waitForHidden(_ element: XCUIElement) {
        expectation(for: NSPredicate { _, _ in !element.exists }, evaluatedWith: element)
        waitForExpectations(timeout: 8)
    }
    @MainActor private func revealIfHidden(_ element: XCUIElement, _ app: XCUIApplication) {
        if !element.exists { photo(app).coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap() }
        XCTAssertTrue(element.waitForExistence(timeout: 5))
    }
    @MainActor private func enter(_ value: String, _ app: XCUIApplication) {
        app.buttons["adjustment-value-entry"].tap()
        let field = app.alerts.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap(); field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 16) + value)
        app.alerts.buttons["adjustment-entry-apply"].firstMatch.tap()
    }
    @MainActor private func open(_ panel: String, title: String, _ app: XCUIApplication) {
        let toolbar = app.scrollViews["tools-toolbar"]
        let frame = toolbar.frame
        let visible = toolbar.buttons.allElementsBoundByIndex.first {
            $0.identifier.hasPrefix("editor-tab-") && $0.frame.midX >= frame.minX + 5 &&
            $0.frame.midX <= frame.maxX - 5 && $0.isHittable
        }
        guard let visible else { XCTFail("No visible tab"); return }
        visible.press(forDuration: 0.7)
        let menu = app.collectionViews.firstMatch
        let target = menu.buttons[title].firstMatch
        XCTAssertTrue(target.waitForExistence(timeout: 5))
        for _ in 0..<4 { if target.isHittable { break }; menu.swipeUp() }
        target.tap()
        XCTAssertTrue(app.buttons["editor-tab-\(panel)"].isSelected)
    }
    @MainActor private func capture(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
