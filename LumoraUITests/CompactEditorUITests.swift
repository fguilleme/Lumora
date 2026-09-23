import XCTest

final class CompactEditorUITests: XCTestCase {
    @MainActor func testGradingAndCurvesLayout() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launch()
        let canvas = app.descendants(matching: .any).matching(identifier: "photo-canvas").firstMatch
        if !canvas.waitForExistence(timeout: 5) {
            app.buttons["Photos"].tap()
            let photo = app.images.matching(identifier: "PXGGridLayout-Info").firstMatch
            XCTAssertTrue(photo.waitForExistence(timeout: 20))
            photo.tap()
            XCTAssertTrue(canvas.waitForExistence(timeout: 30))
        }
        func panel(_ name: String) {
            let tools = app.scrollViews["tools-toolbar"]
            for _ in 0..<8 where !app.buttons[name].isHittable { tools.swipeRight() }
            for _ in 0..<8 where !app.buttons[name].isHittable { tools.swipeLeft() }
            app.buttons[name].tap()
        }
        func capture(_ name: String) {
            let shot = XCTAttachment(screenshot: app.screenshot())
            shot.name = name; shot.lifetime = .keepAlways; add(shot)
        }
        panel("Color Tools")
        app.buttons["Grading"].tap()
        let preset = app.buttons["grading-preset-softPortrait"]
        XCTAssertTrue(preset.isHittable)
        XCTAssertGreaterThanOrEqual(preset.frame.height, 44)
        XCTAssertLessThanOrEqual(preset.frame.height, 46)
        preset.tap()
        XCTAssertTrue(preset.isSelected)
        XCTAssertTrue(app.buttons["grading-preset-neutral"].isHittable)
        let wheel = app.descendants(matching: .any).matching(identifier: "grading-wheel").firstMatch
        XCTAssertTrue(wheel.isHittable)
        capture("Compact Grading")
        panel("Curves")
        let auto = app.buttons["auto-curves"]
        XCTAssertTrue(auto.isHittable)
        XCTAssertGreaterThanOrEqual(auto.frame.height, 44)
        XCTAssertLessThanOrEqual(auto.frame.height, 46)
        auto.tap()
        for style in ["natural", "balanced", "punchy"] {
            let button = app.buttons["auto-curve-" + style]
            let ready = NSPredicate(format: "enabled == true")
            expectation(for: ready, evaluatedWith: button)
            waitForExpectations(timeout: 30)
            XCTAssertTrue(button.isHittable)
            XCTAssertGreaterThanOrEqual(button.frame.height, 44)
            button.tap()
            expectation(for: NSPredicate(format: "selected == true"), evaluatedWith: button)
            waitForExpectations(timeout: 30)
        }
        let chart = app.descendants(matching: .any).matching(identifier: "tone-curve-chart").firstMatch
        let curveScroll = app.scrollViews["curve-controls-scroll"]
        for _ in 0..<4 where chart.frame.intersection(curveScroll.frame).height < 120 {
            curveScroll.swipeUp()
        }
        XCTAssertTrue(chart.exists)
        XCTAssertGreaterThanOrEqual(chart.frame.intersection(curveScroll.frame).height, 120)
        capture("Compact Auto Curves")
    }
}
