import XCTest

#if DEBUG
final class DebugLabUITests: XCTestCase {
    @MainActor func testIPadLandscapeUsesSideColumns() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app=XCUIApplication()
        app.launch()
        let canvas=app.descendants(matching:.any).matching(identifier:"photo-canvas").firstMatch
        if !canvas.waitForExistence(timeout:8) {
            app.buttons["Photos"].tap()
            let photo=app.images.matching(identifier:"PXGGridLayout-Info").firstMatch
            XCTAssertTrue(photo.waitForExistence(timeout:20))
            photo.tap()
            XCTAssertTrue(canvas.waitForExistence(timeout:30))
        }
        XCUIDevice.shared.orientation = .landscapeLeft
        let side=app.buttons["controls-side-switch"]
        let controls=app.descendants(matching:.any).matching(identifier:"editor-controls-column").firstMatch
        XCTAssertTrue(side.waitForExistence(timeout:10))
        XCTAssertTrue(controls.exists)
        XCTAssertGreaterThan(canvas.frame.width,controls.frame.width)
        XCTAssertGreaterThan(abs(canvas.frame.midX-controls.frame.midX),controls.frame.width*0.5)
        let toolbar=app.scrollViews["tools-toolbar"]
        let debug=app.buttons["Debug"]
        for _ in 0..<16 where !debug.isHittable {toolbar.swipeLeft()}
        XCTAssertTrue(debug.isHittable)
        debug.tap()
        XCTAssertTrue(app.scrollViews["debug-lab-controls"].waitForExistence(timeout:8))
        XCTAssertTrue(app.staticTexts["debug-comparison-ready"].waitForExistence(timeout:45))
        Thread.sleep(forTimeInterval:2)
        print("IPAD_LANDSCAPE_FRAMES",app.frame,canvas.frame,controls.frame)
        let shot=XCTAttachment(screenshot:XCUIScreen.main.screenshot())
        shot.name="DebugLab iPad Landscape"
        shot.lifetime = .keepAlways
        add(shot)
        XCUIDevice.shared.orientation = .portrait
    }

    @MainActor func testDebugLabIsTemporaryAndLandscapeAware() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launch()
        let photo = app.descendants(matching:.any).matching(identifier:"photo-canvas").firstMatch
        if !photo.waitForExistence(timeout:8) {
            app.buttons["Photos"].tap()
            let tile=app.images.matching(identifier:"PXGGridLayout-Info").firstMatch
            XCTAssertTrue(tile.waitForExistence(timeout:20))
            tile.tap()
            XCTAssertTrue(photo.waitForExistence(timeout:30))
        }
        let undo=app.buttons["Undo"].isEnabled
        let toolbar=app.scrollViews["tools-toolbar"]
        let debug=app.buttons["Debug"]
        for _ in 0..<16 where !debug.isHittable {toolbar.swipeLeft()}
        XCTAssertTrue(debug.isHittable)
        debug.tap()
        XCTAssertTrue(app.scrollViews["debug-lab-controls"].waitForExistence(timeout:8))
        let canvas=app.descendants(matching:.any).matching(identifier:"debug-lab-canvas").firstMatch
        let divider=app.descendants(matching:.any).matching(identifier:"debug-split-divider").firstMatch
        XCTAssertTrue(canvas.exists)
        XCTAssertTrue(divider.exists)
        XCTAssertTrue(app.staticTexts["debug-comparison-ready"].waitForExistence(timeout:45))
        let portrait=XCTAttachment(screenshot:XCUIScreen.main.screenshot())
        portrait.name="DebugLab Portrait Split"
        portrait.lifetime = .keepAlways
        add(portrait)
        app.buttons["Halo Map"].tap()
        XCTAssertTrue(app.descendants(matching:.any).matching(identifier:"debug-halo-metrics").firstMatch
            .waitForExistence(timeout:45))
        let halo=XCTAttachment(screenshot:XCUIScreen.main.screenshot())
        halo.name="DebugLab Halo Map"
        halo.lifetime = .keepAlways
        add(halo)
        app.buttons["Split"].tap()
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(app.buttons["controls-side-switch"].waitForExistence(timeout:10))
        XCTAssertTrue(app.scrollViews["debug-lab-controls"].exists)
        Thread.sleep(forTimeInterval:1)
        let landscape=XCTAttachment(screenshot:XCUIScreen.main.screenshot())
        landscape.name="DebugLab Landscape"
        landscape.lifetime = .keepAlways
        add(landscape)
        XCUIDevice.shared.orientation = .portrait
        let left=canvas.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.5))
        let right=canvas.coordinate(withNormalizedOffset:CGVector(dx:0.7,dy:0.5))
        divider.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.5))
            .press(forDuration:0.1,thenDragTo:right)
        canvas.pinch(withScale:2,velocity:1)
        left.press(forDuration:0.1,thenDragTo:right)
        XCTAssertTrue(canvas.exists)
        let light=app.buttons["Light"]
        for _ in 0..<16 where !light.isHittable {toolbar.swipeRight()}
        light.tap()
        XCTAssertFalse(app.scrollViews["debug-lab-controls"].exists)
        XCTAssertTrue(photo.exists)
        XCTAssertEqual(app.buttons["Undo"].isEnabled,undo)
    }
}
#endif
