import XCTest
import UIKit

final class CinematicGlowUITests:XCTestCase {
 @MainActor func testIntensitySliderUndoAndNativeExport() throws {
  continueAfterFailure=false
  let app=XCUIApplication();app.launchArguments=["--glow-ui-validation","-AppleLanguages","(en)","-AppleLocale","en_US"];app.launch()
  let canvas=app.descendants(matching:.any).matching(identifier:"photo-canvas").firstMatch
  XCTAssertTrue(canvas.waitForExistence(timeout:45))
  let toolbar=app.scrollViews["tools-toolbar"]
  toolbar.swipeLeft(velocity:.slow)
  let effects=app.buttons["editor-tab-Effects"]
  XCTAssertTrue(effects.waitForExistence(timeout:10))
  effects.tap()
  let slider=app.sliders["effect-cinematicGlow"]
  XCTAssertTrue(slider.waitForExistence(timeout:10));XCTAssertTrue(slider.isHittable)
  XCTAssertTrue((slider.value as? String ?? "").contains("0"))
  for value:CGFloat in [0,0.4,0.7,1] {
   slider.adjust(toNormalizedSliderPosition:value)
   let shot=XCTAttachment(screenshot:app.screenshot());shot.name="Glow intensity \(Int(value*100))";shot.lifetime = .keepAlways;add(shot)
  }
  for value:CGFloat in [0.1,0.9,0.2,0.8,0.3,0.7,0.4,1] {slider.adjust(toNormalizedSliderPosition:value)}
  XCTAssertTrue(slider.isHittable);XCTAssertEqual(app.state,.runningForeground)
  app.buttons["Undo"].tap();app.buttons["Redo"].tap()
  let springboard=XCUIApplication(bundleIdentifier:"com.apple.springboard")
  let banner=springboard.otherElements["NotificationShortLookView"]
  if banner.exists {banner.swipeUp()}
  let export=app.buttons["Export"]
  for _ in 0..<3 {
   if banner.exists {banner.swipeUp()}
   app.buttons["Import and options"].tap()
   if export.waitForExistence(timeout:3){break}
  }
  XCTAssertTrue(export.exists);export.tap()
  let create=app.buttons["export-create"];XCTAssertTrue(create.waitForExistence(timeout:10))
  app.swipeUp()
  XCTAssertTrue(create.isHittable)
  let before=XCTAttachment(screenshot:app.screenshot());before.name="Export button visible";before.lifetime = .keepAlways;add(before)
  create.tap()
  XCTAssertTrue(app.staticTexts["export-result"].waitForExistence(timeout:35))
  let shot=XCTAttachment(screenshot:app.screenshot());shot.name="Cinematic Glow native export";shot.lifetime = .keepAlways;add(shot)
 }
}
