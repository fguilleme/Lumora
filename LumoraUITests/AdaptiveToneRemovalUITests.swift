import XCTest

final class AdaptiveToneRemovalUITests: XCTestCase {
    @MainActor
    func testLightRemainsResponsiveAfterRepeatedEditsAndPanelSwitches() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        let canvas = app.descendants(matching: .any).matching(identifier: "photo-canvas").firstMatch
        if !canvas.waitForExistence(timeout: 5) {
            app.buttons["Photos"].tap()
            let photo = app.images.matching(identifier: "PXGGridLayout-Info").element(boundBy: 1)
            XCTAssertTrue(photo.waitForExistence(timeout: 20))
            photo.tap()
            XCTAssertTrue(canvas.waitForExistence(timeout: 30))
        }
        app.buttons["Importer et options"].tap()
        app.buttons["Réinitialiser les réglages"].tap()
        app.buttons["Lumière"].tap()
        XCTAssertFalse(app.sliders["adaptiveTone"].exists)
        XCTAssertFalse(app.staticTexts["Adaptatif"].exists)
        let exposure = app.sliders["Exposition"]
        XCTAssertTrue(exposure.waitForExistence(timeout: 10))
        for position in [0.42, 0.68, 0.35, 0.55] {
            exposure.adjust(toNormalizedSliderPosition: position)
        }
        app.buttons["Couleur"].tap()
        XCTAssertTrue(app.sliders["Température"].waitForExistence(timeout: 10))
        app.buttons["Lumière"].tap()
        XCTAssertTrue(exposure.waitForExistence(timeout: 10))
        exposure.adjust(toNormalizedSliderPosition: 0.5)
        let deadline = Date().addingTimeInterval(10)
        while app.activityIndicators.count > 0 && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        XCTAssertEqual(app.activityIndicators.count, 0, "The render progress indicator must finish")
        XCTAssertTrue(canvas.exists)
    }
}
