import XCTest

final class XMPHighlightUITests: XCTestCase {
    @MainActor func testImportedVintagePreviewAndExport() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--xmp-highlight-validation", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        let canvas = app.descendants(matching: .any).matching(identifier: "photo-canvas").firstMatch
        XCTAssertTrue(canvas.waitForExistence(timeout: 45))
        XCTAssertTrue(app.buttons["Undo"].isEnabled)
        XCTAssertTrue(app.progressIndicators.firstMatch.waitForNonExistence(timeout: 45))
        XCTAssertFalse(app.alerts.firstMatch.exists)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "Vintage XMP corrected — iPhone"; shot.lifetime = .keepAlways; add(shot)
        app.buttons["Import and options"].tap()
        let export = app.buttons["Export"]
        XCTAssertTrue(export.waitForExistence(timeout: 5)); export.tap()
        let create = app.buttons["export-create"]
        XCTAssertTrue(create.waitForExistence(timeout: 10))
        // Form rows can report hittable while lying below the sheet's visible edge.
        app.swipeUp()
        for _ in 0..<3 {
            if create.frame.maxY < app.frame.maxY-80 && create.frame.minY > 150 { break }
            app.swipeUp()
        }
        XCTAssertTrue(create.isHittable); create.tap()
        app.swipeUp()
        XCTAssertTrue(app.staticTexts["export-result"].waitForExistence(timeout: 45))
        XCTAssertFalse(app.alerts.firstMatch.exists)
        let exported = XCTAttachment(screenshot: app.screenshot())
        exported.name = "Vintage XMP corrected — export"; exported.lifetime = .keepAlways; add(exported)
    }
}
