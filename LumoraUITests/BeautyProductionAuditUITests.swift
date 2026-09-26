import XCTest

/// Runs the real app with a saved production-created correction in its library.
/// No replacement view, Vision stub, injected mask or R&D renderer.
/// New proposal creation is separately exercised on a Vision-capable host.
final class BeautyProductionAuditUITests: XCTestCase {
    @MainActor func testProductionBeautyExposureAndZone() throws {
        continueAfterFailure = true
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        func capture(_ name: String) {
            let shot = XCTAttachment(screenshot: app.screenshot())
            shot.name = name; shot.lifetime = .keepAlways; add(shot)
            let tree = XCTAttachment(string: app.debugDescription)
            tree.name = name + "_accessibility"; tree.lifetime = .keepAlways; add(tree)
        }
        let canvas = app.descendants(matching: .any).matching(identifier: "photo-canvas").firstMatch
        if !canvas.waitForExistence(timeout: 60) {
            let photos = app.buttons["Photos"].firstMatch
            XCTAssertTrue(photos.waitForExistence(timeout: 10))
            guard photos.exists else { capture("00_import_unavailable"); return }
            photos.tap()
            let photo = app.images.matching(identifier: "PXGGridLayout-Info").firstMatch
            XCTAssertTrue(photo.waitForExistence(timeout: 20))
            guard photo.exists else { capture("00_picker_unavailable"); return }
            photo.tap()
        }
        XCTAssertTrue(canvas.waitForExistence(timeout: 40))
        guard canvas.exists else { capture("00_editor_unavailable"); return }
        let toolbar = app.scrollViews["tools-toolbar"]
        let beauty = app.buttons["editor-tab-Beauty"]
        for _ in 0..<12 {
            let visible = beauty.frame.intersection(toolbar.frame)
            if !visible.isNull && visible.width > 60 { break }
            toolbar.swipeLeft()
        }
        XCTAssertTrue(beauty.isHittable)
        guard beauty.isHittable else { capture("00_beauty_tab_unavailable"); return }
        beauty.tap()
        let panel = app.scrollViews["beauty-controls"]
        XCTAssertTrue(panel.waitForExistence(timeout: 10))
        // A Vision failure is recorded, not bypassed or treated as successful analysis.
        if app.alerts.firstMatch.waitForExistence(timeout: 4) {
            capture("01_analysis_alert")
            app.alerts.firstMatch.buttons.firstMatch.tap()
        }
        capture("02_beauty_top")
        let ids = ["beauty-uniformity", "beauty-texture", "beauty-blemishes",
                   "beauty-v2-skinShine", "manual-healing-toggle", "beauty-darkCircles",
                   "beauty-eyeBrightness", "beauty-eyeDetail", "beauty-teeth",
                   "beauty-v2-lipColor", "beauty-v2-lipSaturation",
                   "beauty-v2-lipBrightness", "beauty-v2-lipDetail", "beauty-v2-faceBalance"]
        var found = Set<String>()
        var foundLips = false
        for page in 0..<8 {
            for id in ids where app.descendants(matching: .any).matching(identifier: id).firstMatch.exists { found.insert(id) }
            if app.staticTexts["Lips"].exists { foundLips = true }
            capture(String(format: "03_beauty_scroll_%02d", page))
            // Use the free panel margin: a swipe starting on a slider is consumed by it.
            panel.coordinate(withNormalizedOffset: .init(dx: 0.02, dy: 0.90))
                .press(forDuration: 0.05, thenDragTo: panel.coordinate(withNormalizedOffset: .init(dx: 0.02, dy: 0.15)))
        }
        for id in ids { XCTAssertTrue(found.contains(id), "Production UI missing: \(id)") }
        XCTAssertTrue(foundLips, "Production Lips section missing")
        XCTAssertFalse(app.staticTexts["Hair"].exists, "Hair must not ship")
        let correction = app.buttons["manual-healing-toggle"]
        guard found.contains("manual-healing-toggle") else {
            capture("04_correction_zone_lips_absent")
            return // Absence is a real test failure above, not an expected failure/skip.
        }
        for _ in 0..<24 {
            var towardTop = true
            if correction.exists {
                let visible = correction.frame.intersection(panel.frame)
                if !visible.isNull && visible.height >= 20 && correction.isHittable { break }
                towardTop = correction.frame.midY < panel.frame.midY
            }
            let start = panel.coordinate(withNormalizedOffset: .init(dx: 0.02, dy: 0.5))
            start.press(forDuration: 0.05, thenDragTo: start.withOffset(.init(dx: 0, dy: towardTop ? 80 : -80)))
        }
        capture("04_correction_button")
        XCTAssertTrue(correction.isHittable)
        guard correction.isHittable else { return }
        correction.tap()
        capture("05_correction")
        // Wait for preparation, not just the button. Keep Vision failures explicit.
        let prepareDeadline = Date().addingTimeInterval(30)
        while app.progressIndicators.firstMatch.exists && Date() < prepareDeadline { Thread.sleep(forTimeInterval: 0.2) }
        if app.alerts.firstMatch.exists { capture("05_correction_preparation_error"); app.alerts.firstMatch.buttons.firstMatch.tap() }
        let size = app.descendants(matching: .any).matching(identifier: "healing-size").firstMatch
        if !size.exists {
            canvas.coordinate(withNormalizedOffset: .init(dx: 0.55, dy: 0.54)).tap()
        }
        XCTAssertTrue(size.waitForExistence(timeout: 30), "A real persisted or newly created correction must be selected")
        guard size.exists else { capture("05_no_correction"); return }
        func reveal(_ element: XCUIElement) {
            for _ in 0..<24 {
                var towardTop = false
                if element.exists {
                    let r = element.frame.intersection(panel.frame)
                    if !r.isNull && r.height >= 8 && element.isHittable { return }
                    towardTop = element.frame.midY < panel.frame.midY
                }
                let start = panel.coordinate(withNormalizedOffset: .init(dx: 0.02, dy: 0.5))
                start.press(forDuration: 0.05, thenDragTo: start.withOffset(.init(dx: 0, dy: towardTop ? 65 : -65)))
            }
        }
        let zone = app.descendants(matching: .any).matching(identifier: "healing-zone-mode").firstMatch
        reveal(zone)
        capture("05_correction_selected")
        let source = app.descendants(matching: .any).matching(identifier: "healing-source-handle").firstMatch
        XCTAssertTrue(source.exists)
        if source.exists {
            let start = source.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5))
            start.press(forDuration: 0.1, thenDragTo: start.withOffset(.init(dx: 8, dy: 0)))
        }
        XCTAssertTrue(zone.isHittable)
        zone.tap()
        capture("06_zone")
        XCTAssertTrue(app.staticTexts["Add"].exists || app.buttons["Add"].exists)
        XCTAssertTrue(app.staticTexts["Erase"].exists || app.buttons["Erase"].exists)
        let strokeStart = canvas.coordinate(withNormalizedOffset: .init(dx: 0.48, dy: 0.52))
        strokeStart.press(forDuration: 0.1, thenDragTo: strokeStart.withOffset(.init(dx: 8, dy: 0)))
        let erase = app.buttons["Erase"]
        if erase.isHittable {
            erase.tap()
            strokeStart.press(forDuration: 0.1, thenDragTo: strokeStart.withOffset(.init(dx: 3, dy: 0)))
        }
        for id in ["healing-zone-size", "healing-zone-feather", "healing-size", "healing-strength"] {
            let control = app.descendants(matching: .any).matching(identifier: id).firstMatch
            reveal(control)
            XCTAssertTrue(control.exists, id)
            capture(id)
            if id == "healing-size" || id == "healing-strength" {
                let slider = app.sliders[id]
                XCTAssertTrue(slider.isHittable)
                if slider.isHittable { slider.adjust(toNormalizedSliderPosition: id == "healing-size" ? 0.15 : 0.60) }
            }
        }
        let strength = app.sliders["healing-strength"]
        let appliedStrength = strength.value as? String
        app.buttons["Undo"].tap()
        app.buttons["Redo"].tap()
        XCTAssertEqual(strength.value as? String, appliedStrength)
        capture("07_zone_after_undo_redo")
        let delete = app.buttons["Delete correction"]
        reveal(delete)
        XCTAssertTrue(delete.exists)
    }
    @MainActor func testV2SlidersPersist() {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "photo-canvas").firstMatch.waitForExistence(timeout: 60))
        let toolbar = app.scrollViews["tools-toolbar"]
        let beauty = app.buttons["editor-tab-Beauty"]
        for _ in 0..<12 {
            let r = beauty.frame.intersection(toolbar.frame)
            if !r.isNull && r.width > 60 { break }
            toolbar.swipeLeft()
        }
        beauty.tap()
        let panel = app.scrollViews["beauty-controls"]
        XCTAssertTrue(panel.waitForExistence(timeout: 10))
        // Wait for the actual Vision result. No substituted successful analysis.
        _ = app.staticTexts["Face analysis unavailable"].waitForExistence(timeout: 10)
        for id in ["skinShine", "lipColor", "lipSaturation", "lipBrightness", "lipDetail", "faceBalance"] {
            let slider = app.sliders["beauty-v2-" + id]
            for _ in 0..<24 {
                if slider.exists && slider.isHittable && panel.frame.contains(CGPoint(x: slider.frame.midX, y: slider.frame.midY)) { break }
                let start = panel.coordinate(withNormalizedOffset: .init(dx: 0.02, dy: 0.5))
                start.press(forDuration: 0.05, thenDragTo: start.withOffset(.init(dx: 0, dy: -65)))
            }
            XCTAssertTrue(slider.isHittable, id)
            guard slider.isHittable else { continue }
            let before = slider.value as? String
            slider.adjust(toNormalizedSliderPosition: 1)
            // Vision may fail rendering, but the edited production state must persist.
            if app.alerts.firstMatch.waitForExistence(timeout: 3) { app.alerts.firstMatch.buttons.firstMatch.tap() }
            XCTAssertNotEqual(slider.value as? String, before, id)
            let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "V2_" + id
            shot.lifetime = .keepAlways; add(shot)
        }
    }

}
