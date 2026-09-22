import XCTest
import UIKit

final class DarkenLightenCenterUITests:XCTestCase {
    @MainActor func testCenterDragUndoZoomPanAndOverlayScope() throws {
        continueAfterFailure=false
        let app=XCUIApplication();app.launch()
        let canvas=app.descendants(matching:.any).matching(identifier:"photo-canvas").firstMatch
        if !canvas.waitForExistence(timeout:5) {
            app.buttons["Photos"].tap()
            let photo=app.images.matching(identifier:"PXGGridLayout-Info").element(boundBy:1)
            XCTAssertTrue(photo.waitForExistence(timeout:20));photo.tap()
            XCTAssertTrue(canvas.waitForExistence(timeout:30))
        }
        app.buttons["Importer et options"].tap();app.buttons["Réinitialiser les réglages"].tap()
        app.buttons["Creative"].tap();app.buttons["creative-add"].tap()
        let option=app.buttons.matching(NSPredicate(format:"label == %@ AND NOT (identifier BEGINSWITH %@)","Darken / Lighten Center","creative-effect-")).firstMatch
        XCTAssertTrue(option.waitForExistence(timeout:5));option.tap()
        let handle=app.descendants(matching:.any).matching(identifier:"creative-dlc-center-handle").firstMatch
        XCTAssertTrue(handle.waitForExistence(timeout:5));XCTAssertTrue(handle.isHittable)
        let initial=try XCTUnwrap(handle.value as? String)
        let start=handle.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.5))
        start.press(forDuration:0.1,thenDragTo:start.withOffset(CGVector(dx:45,dy:-35)))
        let moved=try XCTUnwrap(handle.value as? String);XCTAssertNotEqual(initial,moved)
        app.buttons["Annuler"].tap();XCTAssertEqual(handle.value as? String,initial)
        app.buttons["Rétablir"].tap();XCTAssertEqual(handle.value as? String,moved)
        canvas.pinch(withScale:2,velocity:1)
        let pan=canvas.coordinate(withNormalizedOffset:CGVector(dx:0.8,dy:0.75))
        pan.press(forDuration:0.05,thenDragTo:pan.withOffset(CGVector(dx:-30,dy:20)))
        XCTAssertEqual(handle.value as? String,moved)
        let shot=XCTAttachment(screenshot:app.screenshot());shot.name="DLC center after zoom and pan";shot.lifetime = .keepAlways;add(shot)
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(handle.waitForExistence(timeout:5));XCTAssertEqual(handle.value as? String,moved)
        XCUIDevice.shared.orientation = .portrait
        let toolbar=app.scrollViews["tools-toolbar"]
        for _ in 0..<8 where !app.buttons["Lumière"].isHittable {toolbar.swipeRight()}
        app.buttons["Lumière"].tap();XCTAssertFalse(handle.exists)
        for _ in 0..<8 where !app.buttons["Creative"].isHittable {toolbar.swipeLeft()}
        app.buttons["Creative"].tap();XCTAssertTrue(handle.waitForExistence(timeout:5));XCTAssertEqual(handle.value as? String,moved)
    }
}
