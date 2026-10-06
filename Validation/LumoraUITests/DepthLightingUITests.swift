import XCTest

final class DepthLightingUITests: XCTestCase {
    @MainActor func testPremiumLightingWorkflowAndScreenshots() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["--depth-ui-validation", "-AppleLanguages", "(fr)", "-AppleLocale", "fr_FR"]
        app.launch()

        let canvas = app.descendants(matching: .any).matching(identifier: "photo-canvas").firstMatch
        XCTAssertTrue(canvas.waitForExistence(timeout: 45))
        openTab("Lighting", in: app)

        let toggle = app.switches["depth-lighting-enable"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 10))
        if toggle.value as? String == "0" { toggle.tap() }
        XCTAssertFalse(app.staticTexts["Expérimental · désactivé par défaut"].exists)
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "dérivées")).firstMatch.exists)
        XCTAssertTrue(app.staticTexts["Distance"].exists)

        let initiallyHiddenSource = marker("lighting-source-marker", app: app)
        let initiallyHiddenTarget = marker("lighting-subject-marker", app: app)
        let targetBeforeReveal = initiallyHiddenTarget.frame
        Thread.sleep(forTimeInterval: 5.5)
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.62, dy: 0.45)).tap()
        XCTAssertTrue(initiallyHiddenSource.waitForExistence(timeout: 2))
        XCTAssertTrue(initiallyHiddenSource.isHittable)
        XCTAssertEqual(marker("lighting-subject-marker", app: app).frame.midX, targetBeforeReveal.midX, accuracy: 1)
        XCTAssertEqual(marker("lighting-subject-marker", app: app).frame.midY, targetBeforeReveal.midY, accuracy: 1)

        capturePreset("Studio", name: "01-Studio", app: app, canvas: canvas)
        capturePreset("Fenêtre", name: "02-Fenetre", app: app, canvas: canvas)
        capturePreset("Heure dorée", name: "03-Golden-Hour", app: app, canvas: canvas)

        revealGuides(canvas, app: app)
        dragMarker("lighting-source-marker", by: CGVector(dx: -24, dy: 18), app: app)
        XCTAssertTrue(app.buttons["Manuel"].exists)
        revealGuides(canvas, app: app)
        attach("04-Manuel", app: app)

        let advanced = app.descendants(matching: .any)["depth-lighting-advanced"]
        XCTAssertTrue(advanced.waitForExistence(timeout: 5)); advanced.tap()
        XCTAssertTrue(app.buttons["parameter-relief"].waitForExistence(timeout: 3))
        attach("05-Avance-ouvert", app: app)

        advanced.tap()
        revealGuides(canvas, app: app)

        let source = marker("lighting-source-marker", app: app)
        let target = marker("lighting-subject-marker", app: app)
        XCTAssertTrue(target.isHittable)
        revealGuides(canvas, app: app)
        let zoomBefore = canvas.value as? String
        canvas.pinch(withScale: 1.7, velocity: 1.0)
        XCTAssertNotEqual(canvas.value as? String, zoomBefore)
        XCTAssertTrue(source.exists && target.exists)
        canvas.doubleTap()

        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(app.buttons["controls-side-switch"].waitForExistence(timeout: 5))
        revealGuides(canvas, app: app); attach("06-Paysage-gauche", app: app)
        XCUIDevice.shared.orientation = .landscapeRight
        XCTAssertTrue(canvas.waitForExistence(timeout: 5))
        revealGuides(canvas, app: app); attach("07-Paysage-droite", app: app)

        XCUIDevice.shared.orientation = .portrait
        XCTAssertTrue(app.buttons["depth-lighting-reset"].waitForExistence(timeout: 5))
        let intensity = app.buttons["parameter-intensity"]
        XCTAssertTrue(intensity.waitForExistence(timeout: 5)); intensity.tap()
        let ruler = app.descendants(matching: .any).matching(identifier: "adjustment-ruler").firstMatch
        XCTAssertTrue(ruler.waitForExistence(timeout: 5))
        let previousIntensity = ruler.value as? String
        ruler.coordinate(withNormalizedOffset: CGVector(dx: 0.59, dy: 0.5))
            .press(forDuration: 0.05,
                   thenDragTo: ruler.coordinate(withNormalizedOffset: CGVector(dx: 0.78, dy: 0.5)),
                   withVelocity: .slow, thenHoldForDuration: 0.1)
        XCTAssertNotEqual(ruler.value as? String, previousIntensity)
        XCTAssertFalse(app.alerts.firstMatch.exists)
    }

    @MainActor private func capturePreset(_ label: String, name: String, app: XCUIApplication, canvas: XCUIElement) {
        let button = app.buttons[label]
        XCTAssertTrue(button.waitForExistence(timeout: 5), label)
        button.tap()
        XCTAssertTrue(button.isSelected)
        revealGuides(canvas, app: app)
        Thread.sleep(forTimeInterval: 0.8)
        attach(name, app: app)
    }

    @MainActor private func revealGuides(_ canvas: XCUIElement, app: XCUIApplication) {
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.51, dy: 0.52)).tap()
        let source = marker("lighting-source-marker", app: app)
        XCTAssertTrue(source.waitForExistence(timeout: 2))
        XCTAssertTrue(source.isHittable)
    }

    @MainActor private func dragMarker(_ id: String, by delta: CGVector, app: XCUIApplication) {
        let marker = marker(id, app: app)
        XCTAssertTrue(marker.waitForExistence(timeout: 0.5))
        XCTAssertTrue(marker.isHittable)
        let start = marker.frame
        let origin = app.coordinate(withNormalizedOffset: .zero)
        marker.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.08,
                   thenDragTo: origin.withOffset(CGVector(dx: start.midX + delta.dx, dy: start.midY + delta.dy)),
                   withVelocity: .slow, thenHoldForDuration: 0.15)
        XCTAssertEqual(marker.frame.midX, start.midX + delta.dx, accuracy: 7, id)
        XCTAssertEqual(marker.frame.midY, start.midY + delta.dy, accuracy: 7, id)
    }

    @MainActor private func marker(_ id: String, app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    @MainActor private func attach(_ name: String, app: XCUIApplication) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }

    @MainActor private func openTab(_ name: String, in app: XCUIApplication) {
        let tab = app.buttons["editor-tab-\(name)"]
        let toolbar = app.scrollViews["tools-toolbar"]
        for _ in 0..<16 {
            if tab.frame.minX >= 0 && tab.frame.maxX <= app.frame.width { break }
            let left = tab.frame.minX < 0
            toolbar.coordinate(withNormalizedOffset: CGVector(dx: left ? 0.3 : 0.7, dy: 0.5))
                .press(forDuration: 0.1,
                       thenDragTo: toolbar.coordinate(withNormalizedOffset: CGVector(dx: left ? 0.7 : 0.3, dy: 0.5)),
                       withVelocity: .slow, thenHoldForDuration: 0.2)
        }
        XCTAssertTrue(tab.isHittable); tab.tap()
    }
}
