import XCTest

final class LocalizationUITests: XCTestCase {
    @MainActor
    func testWelcomeFollowsSelectedSystemLanguage() {
        let french = XCUIApplication()
        french.launchArguments += ["-AppleLanguages", "(fr)", "-AppleLocale", "fr_FR"]
        french.launch()
        XCTAssertTrue(french.staticTexts["La lumière, à votre façon."].waitForExistence(timeout: 10))
        XCTAssertTrue(french.buttons["Bibliothèque"].exists)
        french.terminate()

        let english = XCUIApplication()
        english.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        english.launch()
        XCTAssertTrue(english.staticTexts["Light, your way."].waitForExistence(timeout: 10))
        XCTAssertTrue(english.buttons["Library"].exists)
    }
}
