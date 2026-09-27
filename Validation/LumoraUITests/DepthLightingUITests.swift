import XCTest

final class DepthLightingUITests: XCTestCase {
    @MainActor func testExperimentalLightingAndFrenchHelp() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["--depth-ui-validation", "-AppleLanguages", "(fr)", "-AppleLocale", "fr_FR"]
        app.launch()
        let canvas = app.descendants(matching: .any).matching(identifier: "photo-canvas").firstMatch
        XCTAssertTrue(canvas.waitForExistence(timeout: 45))
        func openTab(_ name: String) {
            let tab = app.buttons["editor-tab-\(name)"]
            let toolbar = app.scrollViews["tools-toolbar"]
            for _ in 0..<16 {
                if tab.frame.minX >= 0 && tab.frame.maxX <= app.frame.width { break }
                let left = tab.frame.minX < 0
                toolbar.coordinate(withNormalizedOffset: CGVector(dx: left ? 0.3 : 0.7, dy: 0.5))
                    .press(forDuration: 0.1, thenDragTo: toolbar.coordinate(withNormalizedOffset: CGVector(dx: left ? 0.7 : 0.3, dy: 0.5)), withVelocity: .slow, thenHoldForDuration: 0.2)
            }
            XCTAssertTrue(tab.isHittable); tab.tap()
        }
        openTab("Lighting")
        let toggle = app.switches["depth-lighting-enable"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 10))
        XCTAssertEqual(toggle.value as? String, "0")
        XCTAssertTrue(app.staticTexts["Expérimental · désactivé par défaut"].exists)
        toggle.tap()
        let slider = app.sliders["depth-lighting-intensity"]
        XCTAssertTrue(slider.waitForExistence(timeout: 30))
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        for value: CGFloat in [0.2, 0.8, 0.4] { slider.adjust(toNormalizedSliderPosition: value) }
        // Each marker must land under the finger in both directions, independently of rendering.
        for id in ["lighting-source-marker", "lighting-subject-marker"] {
            let marker = app.images[id]
            XCTAssertTrue(marker.waitForExistence(timeout: 10))
            for delta in [CGVector(dx: 75, dy: 55), CGVector(dx: -60, dy: -45)] {
                let start = marker.frame
                let origin = app.coordinate(withNormalizedOffset: .zero)
                let end = CGPoint(x: start.midX + delta.dx, y: start.midY + delta.dy)
                origin.withOffset(CGVector(dx: start.midX, dy: start.midY))
                    .press(forDuration: 0.1, thenDragTo: origin.withOffset(CGVector(dx: end.x, dy: end.y)),
                           withVelocity: .slow, thenHoldForDuration: 0.3)
                XCTAssertEqual(marker.frame.midX, end.x, accuracy: 6, id)
                XCTAssertEqual(marker.frame.midY, end.y, accuracy: 6, id)
            }
        }
        XCTAssertTrue(app.buttons["Annuler"].isEnabled)
        XCTAssertFalse(app.alerts.firstMatch.exists)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Éclairage expérimental — iPhone"; screenshot.lifetime = .keepAlways; add(screenshot)
        toggle.tap()
        XCTAssertEqual(toggle.value as? String, "0")
        openTab("Help")
        let topic = app.buttons["help-topic-lighting"]
        let list = app.scrollViews["editor-full-page"]
        for _ in 0..<10 {
            if topic.exists && topic.isHittable { break }
            list.swipeUp()
        }
        XCTAssertTrue(topic.isHittable); topic.tap()
        XCTAssertTrue(app.scrollViews["help-detail-lighting"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "L’effet est désactivé par défaut")).firstMatch.exists)
        let help = XCTAttachment(screenshot: app.screenshot())
        help.name = "Aide Éclairage — français"; help.lifetime = .keepAlways; add(help)
        app.buttons["help-close"].tap()
        XCTAssertEqual(app.state, .runningForeground)
    }
}
