import XCTest

final class DetailFeedbackUITests: XCTestCase {
    @MainActor func testBlurBadgesNoiseGroupsAndPersistentMaskSummary() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(fr)", "-AppleLocale", "fr_FR",
            "--app-store-image", "DetailFeedback.jpg", "--app-store-panel", "Detail"]
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "photo-canvas").firstMatch.waitForExistence(timeout: 40))
        let detailTab = app.buttons["editor-tab-Detail"]
        XCTAssertEqual(detailTab.value as? String, "Aucun réglage")
        revealParameter("luminanceNoise", app)
        XCTAssertEqual(app.buttons["parameter-luminanceNoise"].label, "Bruit L")
        capture("01-bruit-l", app)
        revealParameter("colorNoise", app)
        XCTAssertEqual(app.buttons["parameter-colorNoise"].label, "Bruit C")
        capture("02-bruit-c", app)
        XCTAssertFalse(app.buttons["parameter-blur"].exists)
        open("Effects", app)
        let effectsTab = app.buttons["editor-tab-Effects"]
        revealParameter("blur", app)
        app.buttons["parameter-blur"].tap()
        enter("35", app)
        XCTAssertEqual(effectsTab.value as? String, "Réglages appliqués")
        capture("03-flou-global", app)
        app.buttons["arrow.uturn.backward"].tap()
        XCTAssertEqual(effectsTab.value as? String, "Aucun réglage")
        app.buttons["arrow.uturn.forward"].tap()
        XCTAssertEqual(effectsTab.value as? String, "Réglages appliqués")
        app.buttons["adjustment-reset"].tap()
        XCTAssertEqual(effectsTab.value as? String, "Aucun réglage")

        open("Masks", app)
        app.buttons["mask-new"].tap()
        app.buttons["mask-create-radial"].tap()
        open("Effects", app)
        revealParameter("blur", app)
        app.buttons["parameter-blur"].tap()
        enter("40", app)
        open("Masks", app)
        let summary = app.staticTexts["mask-adjustment-summary"]
        XCTAssertTrue(summary.waitForExistence(timeout: 10))
        XCTAssertTrue(summary.label.contains("Flou 40"))
        RunLoop.current.run(until: Date().addingTimeInterval(3))
        XCTAssertTrue(summary.exists && summary.label.contains("Flou 40"))
        capture("04-resume-masque-persistant", app)
        // Mask adjustments remain discoverable after switching tools.
        open("Effects", app)
        XCTAssertEqual(effectsTab.value as? String, "Réglages appliqués")
        revealParameter("blur", app)
        app.buttons["parameter-blur"].tap()
        app.buttons["adjustment-reset"].tap()
        XCTAssertEqual(effectsTab.value as? String, "Aucun réglage")
    }

    @MainActor private func revealParameter(_ id: String, _ app: XCUIApplication) {
        let button = app.buttons["parameter-\(id)"]
        let row = app.scrollViews["adjustment-parameters"].firstMatch
        for _ in 0..<12 {
            if button.exists && button.frame.minX >= row.frame.minX && button.frame.maxX <= row.frame.maxX { return }
            if button.exists && button.frame.midX < row.frame.minX { row.swipeRight() }
            else { row.swipeLeft() }
        }
        XCTFail("Parameter not visible: \(id)")
    }

    @MainActor private func enter(_ value: String, _ app: XCUIApplication) {
        app.buttons["adjustment-value-entry"].tap()
        let field = app.alerts.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 16) + value)
        app.alerts.buttons["adjustment-entry-apply"].firstMatch.tap()
    }

    @MainActor private func open(_ panel: String, _ app: XCUIApplication) {
        let toolbar = app.scrollViews["tools-toolbar"]
        let frame = toolbar.frame
        let visible = toolbar.buttons.allElementsBoundByIndex.first {
            $0.identifier.hasPrefix("editor-tab-") &&
            $0.frame.midX >= frame.minX + 5 && $0.frame.midX <= frame.maxX - 5 && $0.isHittable
        }
        guard let visible else { XCTFail("No visible tab"); return }
        visible.press(forDuration: 0.7)
        // UIKit's context-menu bridge drops SwiftUI identifiers on this OS.
        let title = panel == "Masks" ? "Masques" : panel == "Effects" ? "Effets" : "Détail"
        let menu = app.collectionViews.firstMatch
        let target = menu.buttons[title].firstMatch
        XCTAssertTrue(target.waitForExistence(timeout: 5))
        for _ in 0..<4 {
            if target.isHittable { break }
            menu.swipeUp()
        }
        target.tap()
    }

    @MainActor private func capture(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
