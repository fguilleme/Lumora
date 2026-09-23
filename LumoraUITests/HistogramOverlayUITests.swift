import XCTest

final class HistogramOverlayUITests: XCTestCase {
    @MainActor func testLongPressClippingIsTemporaryInBothHistogramSizes() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments.append("-ui-testing-clipping")
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
        let overlay = app.buttons["histogram-overlay"]
        XCTAssertTrue(overlay.waitForExistence(timeout: 10))
        var expectedActivations = 0
        for expanded in [false, true] {
            let label = expanded ? "Réduire l’histogramme RVB" : "Agrandir l’histogramme RVB"
            XCTAssertEqual(overlay.label, label)
            XCTAssertFalse(app.images["clipping-warning-overlay"].exists)
            overlay.press(forDuration: 1.0)
            expectedActivations += 1
            XCTAssertTrue((overlay.value as? String)?.contains("Activations clipping : \(expectedActivations).") == true,
                          "Le masque doit avoir été préparé pendant l’appui")
            XCTAssertFalse(app.images["clipping-warning-overlay"].exists,
                           "L’overlay doit disparaître au relâchement")
            XCTAssertEqual(overlay.label, label, "L’appui long ne doit pas déclencher le tap")
            if !expanded { overlay.tap() }
        }
    }

    @MainActor func testOverlayExpandsWithoutMovingPhotoAndLeavesOutsideGesturesAlone() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
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
        let overlay = app.buttons["histogram-overlay"]
        XCTAssertTrue(overlay.waitForExistence(timeout: 10))
        XCTAssertEqual(overlay.label, "Agrandir l’histogramme RVB")
        let photoHeight = canvas.frame.height
        let compactWidth = overlay.frame.width
        XCTAssertGreaterThanOrEqual(overlay.frame.height, 44)
        capture("Histogramme compact sur photo", in: app)

        let outside = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.75))
        outside.press(forDuration: 0.05, thenDragTo: canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.7)))
        XCTAssertEqual(overlay.label, "Agrandir l’histogramme RVB")
        overlay.tap()
        XCTAssertEqual(overlay.label, "Réduire l’histogramme RVB")
        XCTAssertGreaterThan(overlay.frame.width, compactWidth * 1.5)
        XCTAssertEqual(canvas.frame.height, photoHeight, accuracy: 1)
        capture("Histogramme agrandi sur photo", in: app)
        overlay.tap()
        XCTAssertEqual(overlay.label, "Agrandir l’histogramme RVB")
        XCTAssertEqual(canvas.frame.height, photoHeight, accuracy: 1)
    }

    @MainActor private func capture(_ name: String, in app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
