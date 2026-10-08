import XCTest

final class RelightingPhasesUITests:XCTestCase {
    @MainActor func testAdvancedLightingOnDevice() throws {
        continueAfterFailure=false
        XCUIDevice.shared.orientation = .portrait
        let app=XCUIApplication()
        app.launchArguments=["--relight-ui-validation","-AppleLanguages","(fr)","-AppleLocale","fr_FR"]
        app.launch()
        let canvas=app.descendants(matching:.any).matching(identifier:"photo-canvas").firstMatch
        XCTAssertTrue(canvas.waitForExistence(timeout:45))
        let tab=app.buttons["editor-tab-Lighting"], toolbar=app.scrollViews["tools-toolbar"]
        for _ in 0..<16 {
            if tab.exists && tab.frame.minX>=0 && tab.frame.maxX<=app.frame.width {break}
            toolbar.swipeLeft()
        }
        XCTAssertTrue(tab.isHittable);tab.tap()
        let enable=app.switches["depth-lighting-enable"]
        XCTAssertTrue(enable.waitForExistence(timeout:10))
        if enable.value as? String=="0" {enable.tap()}
        capture("01-Legacy-default",app)
        let advanced=app.buttons["depth-lighting-advanced"]
        XCTAssertTrue(advanced.isHittable);advanced.tap()
        let surfaces=app.switches["depth-lighting-surfaces"]
        XCTAssertTrue(surfaces.waitForExistence(timeout:5))
        XCTAssertEqual(surfaces.value as? String,"0")
        surfaces.tap()
        XCTAssertEqual(surfaces.value as? String,"1")
        // First on-device model load can take several seconds; no inference is
        // requested by subsequent ruler gestures (verified by the production probe).
        Thread.sleep(forTimeInterval:6)
        capture("02-Surface-normals",app)
        setValue("original-lighting","75",app)
        capture("03-Original-light75",app)
        setValue("portrait-shading","70",app)
        setValue("shadows","70",app)
        capture("04-Portrait-and-shadows",app)
        let ruler=app.descendants(matching:.any).matching(identifier:"adjustment-ruler").firstMatch
        let previous=ruler.value as? String
        ruler.coordinate(withNormalizedOffset:CGVector(dx:0.45,dy:0.5))
            .press(forDuration:0.05,thenDragTo:ruler.coordinate(withNormalizedOffset:CGVector(dx:0.65,dy:0.5)),withVelocity:.slow,thenHoldForDuration:0.1)
        XCTAssertNotEqual(ruler.value as? String,previous)
        let changed=ruler.value as? String
        app.buttons["arrow.uturn.backward"].tap()
        XCTAssertEqual(ruler.value as? String,previous)
        app.buttons["arrow.uturn.forward"].tap()
        XCTAssertEqual(ruler.value as? String,changed)
        app.buttons["adjustment-reset"].tap()
        XCTAssertTrue((ruler.value as? String)?.hasPrefix("0") == true)
        // A photo gesture must not adjust the active scalar.
        let reset=ruler.value as? String
        canvas.pinch(withScale:1.3,velocity:1)
        XCTAssertEqual(ruler.value as? String,reset)
        canvas.doubleTap()
        capture("05-Advanced-after-reset",app)
        XCUIDevice.shared.orientation = .landscapeLeft
        let landscapeReady=XCTNSPredicateExpectation(predicate:NSPredicate { _,_ in app.frame.width > app.frame.height },object:app)
        XCTAssertEqual(XCTWaiter.wait(for:[landscapeReady],timeout:5),.completed)
        Thread.sleep(forTimeInterval:1)
        XCTAssertTrue(app.buttons["controls-side-switch"].waitForExistence(timeout:5))
        capture("06-Landscape",app)
        app.buttons["controls-side-switch"].tap()
        Thread.sleep(forTimeInterval:1)
        capture("07-Landscape-inverted",app)
        XCUIDevice.shared.orientation = .portrait
    }
    @MainActor func testLandscapeCaptures() throws {
        continueAfterFailure=false
        XCUIDevice.shared.orientation = .portrait
        defer {XCUIDevice.shared.orientation = .portrait}
        Thread.sleep(forTimeInterval:1)
        let app=XCUIApplication()
        app.launchArguments=["--relight-ui-validation","-AppleLanguages","(fr)","-AppleLocale","fr_FR"]
        app.launch()
        let canvas=app.descendants(matching:.any).matching(identifier:"photo-canvas").firstMatch
        XCTAssertTrue(canvas.waitForExistence(timeout:45))
        let tab=app.buttons["editor-tab-Lighting"], toolbar=app.scrollViews["tools-toolbar"]
        for _ in 0..<16 {if tab.exists && tab.frame.minX>=0 && tab.frame.maxX<=app.frame.width {break};toolbar.swipeLeft()}
        XCTAssertTrue(tab.isHittable);tab.tap()
        let enable=app.switches["depth-lighting-enable"]
        if enable.value as? String=="0" {enable.tap()}
        app.buttons["depth-lighting-advanced"].tap()
        let surfaces=app.switches["depth-lighting-surfaces"]
        if surfaces.value as? String=="0" {surfaces.tap()}
        Thread.sleep(forTimeInterval:4)
        XCUIDevice.shared.orientation = .landscapeLeft
        let ready=XCTNSPredicateExpectation(predicate:NSPredicate { _,_ in app.frame.width > app.frame.height },object:app)
        XCTAssertEqual(XCTWaiter.wait(for:[ready],timeout:8),.completed)
        Thread.sleep(forTimeInterval:1.5)
        XCTAssertTrue(canvas.isHittable)
        XCTAssertTrue(app.buttons["controls-side-switch"].isHittable)
        capture("06-Landscape",app)
        app.buttons["controls-side-switch"].tap()
        Thread.sleep(forTimeInterval:1.5)
        XCTAssertTrue(canvas.isHittable)
        capture("07-Landscape-inverted",app)
        XCUIDevice.shared.orientation = .portrait
    }
    @MainActor private func setValue(_ id:String,_ value:String,_ app:XCUIApplication) {
        let button=app.buttons["parameter-"+id]
        let row=app.scrollViews["adjustment-parameters"]
        for _ in 0..<10 {
            if button.exists && button.frame.minX>=0 && button.frame.maxX<=app.frame.width {break}
            if button.exists && button.frame.minX<0 {row.swipeRight()} else {row.swipeLeft()}
        }
        XCTAssertTrue(button.isHittable);button.tap()
        app.buttons["adjustment-value-entry"].tap()
        let field=app.alerts.firstMatch.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout:5))
        field.tap()
        let old=field.value as? String ?? ""
        field.typeText(String(repeating:XCUIKeyboardKey.delete.rawValue,count:old.count)+value)
        let applyButtons=app.alerts.firstMatch.buttons.matching(NSPredicate(format:"label == %@ OR label == %@","Appliquer","Apply")).allElementsBoundByIndex
        XCTAssertFalse(applyButtons.isEmpty)
        applyButtons.last!.tap()
        let closed=XCTNSPredicateExpectation(predicate:NSPredicate(format:"exists == false"),object:app.alerts.firstMatch)
        XCTAssertEqual(XCTWaiter.wait(for:[closed],timeout:5),.completed)
    }
    @MainActor private func capture(_ name:String,_ app:XCUIApplication) {
        let image=XCTAttachment(screenshot:XCUIScreen.main.screenshot());image.name=name;image.lifetime = .keepAlways;add(image)
    }
}
