import XCTest

final class SimilarityMaskUITests: XCTestCase {
    @MainActor func testSamplingInfluenceToleranceAndPropagation() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(fr)", "-AppleLocale", "fr_FR"]
        app.launch()
        let canvas = app.descendants(matching: .any).matching(identifier: "photo-canvas").firstMatch
        XCTAssertTrue(canvas.waitForExistence(timeout: 20))
        let toolbar = app.scrollViews["tools-toolbar"]
        let masksTab = app.buttons["editor-tab-Masks"]
        for _ in 0..<12 {
            if masksTab.exists {
                let frame = masksTab.frame
                if !frame.isNull && !frame.isInfinite && frame.width > 0 && frame.intersects(app.frame) { break }
            }
            toolbar.swipeLeft()
        }
        masksTab.tap()
        app.buttons["mask-new"].tap()
        let colorSelection = app.buttons["mask-create-similarity"]
        XCTAssertTrue(colorSelection.waitForExistence(timeout: 5)); colorSelection.tap()
        let tolerance = app.buttons["parameter-mask-tolerance"]
        XCTAssertTrue(tolerance.waitForExistence(timeout: 5))
        XCTAssertTrue(tolerance.isHittable)
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let center = app.descendants(matching: .any).matching(identifier: "mask-handle-center").firstMatch
        XCTAssertTrue(center.waitForExistence(timeout: 15))
        let initialFrame = center.frame
        let start = center.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 30, dy: 20)))
        XCTAssertGreaterThan(center.frame.midX, initialFrame.midX + 15)
        app.buttons["arrow.uturn.backward"].tap()
        XCTAssertEqual(center.frame.midX, initialFrame.midX, accuracy: 3)

        tolerance.tap()
        app.buttons["adjustment-value-entry"].tap()
        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap(); field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 8) + "40")
        app.buttons["adjustment-entry-apply"].firstMatch.tap()
        XCTAssertTrue(tolerance.value as? String == "40")
        capture("01-region-reliee", app)
        app.buttons["Tous les pixels similaires"].tap()
        capture("02-tous-les-pixels", app)
        app.buttons["adjustment-reset"].tap()
        XCTAssertTrue(tolerance.value as? String == "25")
        let ruler = app.descendants(matching: .any).matching(identifier: "adjustment-ruler").firstMatch
        XCTAssertTrue(ruler.exists)
        let wheelStart = ruler.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        wheelStart.press(forDuration: 0.1, thenDragTo: wheelStart.withOffset(CGVector(dx: 30, dy: 0)))
        XCTAssertNotEqual(tolerance.value as? String, "25")
        app.buttons["arrow.uturn.backward"].tap()
        XCTAssertEqual(tolerance.value as? String, "25")
    }

    @MainActor private func capture(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
