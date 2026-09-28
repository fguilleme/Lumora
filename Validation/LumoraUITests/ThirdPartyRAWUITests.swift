import XCTest

final class ThirdPartyRAWUITests: XCTestCase {
    @MainActor func testCanonDNGDecodesAsOriginalRAW() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["--raw-ui-validation", "-AppleLanguages", "(fr)", "-AppleLocale", "fr_FR"]
        app.launch()

        let canvas = app.descendants(matching: .any).matching(identifier: "photo-canvas").firstMatch
        XCTAssertTrue(canvas.waitForExistence(timeout: 45))
        let information = app.descendants(matching: .any).matching(identifier: "photo-information").firstMatch
        XCTAssertTrue(information.waitForExistence(timeout: 10))
        XCTAssertTrue(information.label.contains("RAW"), information.label)
        XCTAssertTrue(String(information.label.filter(\.isNumber)).contains("30722048"), information.label)
        XCTAssertFalse(app.alerts.firstMatch.exists)

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Canon DNG — RAW tiers iPhone"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}
