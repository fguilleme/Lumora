import XCTest

final class GradingPresetUITests:XCTestCase {
    @MainActor func testPresetsCustomHistoryPersistenceAndRapidSwitching() throws {
        continueAfterFailure=false
        let app=XCUIApplication();app.launch()
        let canvas=app.descendants(matching:.any).matching(identifier:"photo-canvas").firstMatch
        if !canvas.waitForExistence(timeout:5) {
            app.buttons["Photos"].tap()
            let photo=app.images.matching(identifier:"PXGGridLayout-Info").element(boundBy:1)
            XCTAssertTrue(photo.waitForExistence(timeout:20));photo.tap();XCTAssertTrue(canvas.waitForExistence(timeout:30))
        }
        func openGrading() {
            let tools=app.scrollViews["tools-toolbar"]
            for _ in 0..<8 where !app.buttons["Color Tools"].isHittable {tools.swipeLeft()}
            app.buttons["Color Tools"].tap();app.buttons["Grading"].tap()
        }
        openGrading()
        let strip=app.scrollViews["grading-preset-strip"],panel=app.scrollViews["color-tools-controls"]
        // Scroll from the gutter: a center swipe can begin on the editable wheel.
        func scrollPanel(up: Bool) {
            panel.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: up ? 0.8 : 0.2))
                .press(forDuration: 0.05, thenDragTo: panel.coordinate(
                    withNormalizedOffset: CGVector(dx: 0.98, dy: up ? 0.2 : 0.8)))
        }
        func select(_ id:String) {
            let button=app.buttons["grading-preset-"+id]
            for _ in 0..<5 where !strip.isHittable {scrollPanel(up: false)}
            for _ in 0..<30 where !button.isHittable {
                let right = button.frame.midX < strip.frame.midX
                strip.coordinate(withNormalizedOffset: CGVector(dx: right ? 0.35 : 0.65, dy: 0.65))
                    .press(forDuration: 0.05, thenDragTo: strip.coordinate(
                        withNormalizedOffset: CGVector(dx: right ? 0.65 : 0.35, dy: 0.65)),
                           withVelocity: .slow, thenHoldForDuration: 0.2)
            }
            XCTAssertTrue(button.isHittable,id);XCTAssertGreaterThanOrEqual(button.frame.height,44);button.tap()
        }
        select("neutral")
        let status=app.staticTexts["grading-preset-status"]
        select("softPortrait");XCTAssertEqual(status.label,"Soft Portrait")
        app.buttons["Undo"].tap();XCTAssertEqual(status.label,"Neutral")
        app.buttons["Redo"].tap();XCTAssertEqual(status.label,"Soft Portrait")
        let luminance=app.sliders["grading-luminance"]
        for _ in 0..<4 where !luminance.isHittable {scrollPanel(up: true)}
        luminance.adjust(toNormalizedSliderPosition:0.65)
        for _ in 0..<4 where !status.isHittable {scrollPanel(up: false)}
        XCTAssertEqual(status.label,"Custom")
        app.buttons["Undo"].tap();XCTAssertEqual(status.label,"Soft Portrait")
        let ids=["warmPortrait","coolPortrait","cinematic","tealWarm","coolCinema","warmCinema","mutedCinema","goldenHour","blueHour","moody","pastel","autumn","bleachGrade","splitWarmCool","neutral"]
        for id in ids {select(id);XCTAssertNotEqual(status.label,"Custom")}
        for _ in 0..<12 {select("softPortrait");select("warmPortrait");select("neutral")}
        select("warmPortrait")
        let screenshot=XCTAttachment(screenshot:app.screenshot());screenshot.name="Grading presets compact";screenshot.lifetime = .keepAlways;add(screenshot)
        XCUIDevice.shared.orientation = .landscapeLeft
        let wide=XCTAttachment(screenshot:app.screenshot());wide.name="Grading presets landscape";wide.lifetime = .keepAlways;add(wide)
        XCUIDevice.shared.orientation = .portrait
        app.terminate();app.launch();XCTAssertTrue(canvas.waitForExistence(timeout:20));openGrading()
        XCTAssertEqual(app.staticTexts["grading-preset-status"].label,"Warm Portrait")
    }
    @MainActor func testLargeLayout() throws {
        continueAfterFailure=false
        let app=XCUIApplication();app.launch()
        let canvas=app.descendants(matching:.any).matching(identifier:"photo-canvas").firstMatch
        if !canvas.waitForExistence(timeout:4) {
            app.buttons["Photos"].tap()
            let photo=app.images.matching(identifier:"PXGGridLayout-Info").element(boundBy:0)
            XCTAssertTrue(photo.waitForExistence(timeout:20));photo.tap();XCTAssertTrue(canvas.waitForExistence(timeout:30))
        }
        let tools=app.scrollViews["tools-toolbar"]
        for _ in 0..<8 where !app.buttons["Color Tools"].isHittable {tools.swipeLeft()}
        app.buttons["Color Tools"].tap();app.buttons["Grading"].tap()
        let neutral=app.buttons["grading-preset-neutral"]
        XCTAssertTrue(neutral.isHittable);XCTAssertGreaterThanOrEqual(neutral.frame.height,44)
        app.buttons["grading-preset-softPortrait"].tap()
        XCTAssertEqual(app.staticTexts["grading-preset-status"].label,"Soft Portrait")
        XCTAssertLessThan(app.buttons["grading-preset-softPortrait"].frame.width,240)
        let screenshot=XCTAttachment(screenshot:app.screenshot());screenshot.name="Grading presets iPad";screenshot.lifetime = .keepAlways;add(screenshot)
    }

}
