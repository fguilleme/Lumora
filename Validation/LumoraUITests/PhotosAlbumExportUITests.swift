import XCTest

final class PhotosAlbumExportUITests: XCTestCase {
    @MainActor func testDirectExportReusesNormalSettingsAfterRelaunch() {
        let app = launch()
        let title = "Lumora direct test " + String(UUID().uuidString.prefix(8))
        openExport(app)
        app.descendants(matching: .any).matching(identifier: "export-format").firstMatch.tap()
        app.buttons["PNG"].firstMatch.tap()
        let originalSize = app.switches["Dimensions originales"].firstMatch
        if originalSize.value as? String == "1" { originalSize.switches.firstMatch.tap() }
        let dimension = app.descendants(matching: .any).matching(identifier: "export-dimension").firstMatch
        XCTAssertTrue(dimension.waitForExistence(timeout: 5))
        dimension.tap()
        app.descendants(matching: .any).matching(identifier: "export-size-1024").firstMatch.tap()
        createFile(app)
        let dimensions = app.staticTexts["export-result"].label.components(separatedBy: " · ").first
        XCTAssertTrue(dimensions?.filter(\.isNumber).hasPrefix("1024") == true)
        let field = app.textFields["export-photos-album"]
        replace(field, with: title)
        field.typeText("\n")
        close(app)
        app.terminate()

        let relaunched = launch()
        relaunched.buttons["header-options"].tap()
        relaunched.buttons["header-option-export-photos"].firstMatch.tap()
        XCTAssertTrue(relaunched.navigationBars["Exporter vers Photos"].waitForExistence(timeout: 5))
        let saved = relaunched.descendants(matching: .any).matching(identifier: "export-photos-saved").firstMatch
        XCTAssertTrue(saved.waitForExistence(timeout: 40))
        XCTAssertTrue(saved.label.contains(title))
        XCTAssertEqual(relaunched.staticTexts["export-result"].label.components(separatedBy: " · ").first, dimensions)
        XCTAssertFalse(relaunched.descendants(matching: .any).matching(identifier: "export-format").firstMatch.exists)
    }

    @MainActor func testSaveToNewAlbumReuseAndRememberDestination() throws {
        let app = launch()
        let title = "Lumora export test " + String(UUID().uuidString.prefix(8))
        print("PHOTOS_EXPORT_TEST_ALBUM=\(title)")
        openExport(app)
        createFile(app)
        let field = app.textFields["export-photos-album"]
        replace(field, with: title)
        field.typeText("\n")
        save(app)
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "export-photos-saved").firstMatch.label.contains(title))
        XCTAssertFalse(app.buttons["export-save-photos"].exists)
        XCTAssertTrue(app.buttons["export-share"].exists)
        capture("01-photos-album-saved", app)
        close(app)
        openExport(app)
        createFile(app)
        XCTAssertEqual(app.textFields["export-photos-album"].value as? String, title)
        save(app)
        close(app)
        openExport(app)
        createFile(app)
        replace(app.textFields["export-photos-album"], with: "")
        app.textFields["export-photos-album"].typeText("\n")
        save(app)
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "export-photos-saved").firstMatch.label, "Enregistré dans Photos")
    }

    @MainActor func testDeniedAlbumAccessPreservesExportForSharing() throws {
        let app = launch()
        openExport(app)
        createFile(app)
        let field = app.textFields["export-photos-album"]
        replace(field, with: "Lumora permission test")
        field.typeText("\n")
        app.buttons["export-save-photos"].tap()
        XCTAssertTrue(app.alerts["Enregistrement dans Photos impossible"].waitForExistence(timeout: 10))
        app.alerts.buttons["OK"].firstMatch.tap()
        XCTAssertTrue(app.buttons["export-share"].exists)
        XCTAssertTrue(app.buttons["export-save-photos"].isEnabled)
        XCTAssertTrue(app.staticTexts["export-result"].exists)
        capture("02-photos-permission-retry", app)
    }

    @MainActor func testSaveToLibraryWithAddOnlyAccess() throws {
        let app = launch()
        openExport(app)
        createFile(app)
        let field = app.textFields["export-photos-album"]
        replace(field, with: "")
        field.typeText("\n")
        save(app)
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "export-photos-saved").firstMatch.label, "Enregistré dans Photos")
        XCTAssertTrue(app.buttons["export-share"].exists)
    }

    @MainActor private func launch() -> XCUIApplication {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(fr)", "-AppleLocale", "fr_FR",
            "--app-store-image", "DetailFeedback.jpg", "--app-store-panel", "Light"]
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "photo-canvas").firstMatch.waitForExistence(timeout: 40))
        return app
    }
    @MainActor private func openExport(_ app: XCUIApplication) {
        app.buttons["header-options"].tap()
        app.buttons["header-option-export"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Exporter"].waitForExistence(timeout: 5))
    }
    @MainActor private func createFile(_ app: XCUIApplication) {
        let form = app.descendants(matching: .any).matching(identifier: "export-options").firstMatch
        let create = app.buttons["export-create"]
        for _ in 0..<5 { if create.isHittable { break }; form.swipeUp() }
        create.tap()
        XCTAssertTrue(app.staticTexts["export-result"].waitForExistence(timeout: 40))
        let field = app.textFields["export-photos-album"]
        for _ in 0..<5 { if field.exists && field.isHittable { break }; form.swipeUp() }
        XCTAssertTrue(field.isHittable)
    }
    @MainActor private func replace(_ field: XCUIElement, with text: String) {
        field.tap()
        let current = field.value as? String ?? ""
        let count = current == field.placeholderValue ? 0 : current.count
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: count) + text)
    }
    @MainActor private func save(_ app: XCUIApplication) {
        let button = app.buttons["export-save-photos"]
        let form = app.descendants(matching: .any).matching(identifier: "export-options").firstMatch
        for _ in 0..<4 { if button.isHittable { break }; form.swipeUp() }
        button.tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "export-photos-saved").firstMatch.waitForExistence(timeout: 30))
    }
    @MainActor private func close(_ app: XCUIApplication) {
        app.navigationBars.buttons["Fermer"].tap()
        XCTAssertTrue(app.buttons["header-options"].waitForExistence(timeout: 5))
    }
    @MainActor private func capture(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
