import XCTest

final class CurvesInteractionUITests: XCTestCase {
    @MainActor private func openCurves(_ app: XCUIApplication) {
        let canvas = app.descendants(matching: .any).matching(identifier: "photo-canvas").firstMatch
        if !canvas.waitForExistence(timeout: 5) {
            app.buttons["Photos"].tap()
            let photo = app.images.matching(identifier: "PXGGridLayout-Info").firstMatch
            XCTAssertTrue(photo.waitForExistence(timeout: 20)); photo.tap()
            XCTAssertTrue(canvas.waitForExistence(timeout: 30))
        }
        let tools = app.scrollViews["tools-toolbar"]
        for _ in 0..<8 where !app.buttons["Curves"].isHittable { tools.swipeRight() }
        for _ in 0..<8 where !app.buttons["Curves"].isHittable { tools.swipeLeft() }
        app.buttons["Curves"].tap()
    }

    @MainActor private func capture(_ name: String, app: XCUIApplication) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }

    @MainActor func testViewModeScrollEditAndEyedropper() throws {
        continueAfterFailure = false
        let app = XCUIApplication(); app.launch()
        openCurves(app)
        let controls = app.scrollViews["curve-controls-scroll"]
        XCTAssertTrue(controls.waitForExistence(timeout: 5))
        controls.swipeUp()
        controls.swipeUp()
        let chart = app.descendants(matching: .any).matching(identifier: "tone-curve-chart").firstMatch
        XCTAssertTrue(chart.waitForExistence(timeout: 5))
        let before = chart.value as? String
        XCTAssertTrue(before?.contains("Viewing") == true)
        capture("view_mode", app: app)
        for index in 0..<10 {
            let start = chart.coordinate(withNormalizedOffset: CGVector(dx: index.isMultiple(of: 2) ? 0.35 : 0.55, dy: 0.25))
            let end = chart.coordinate(withNormalizedOffset: CGVector(dx: index.isMultiple(of: 2) ? 0.35 : 0.60, dy: 0.85))
            start.press(forDuration: 0.05, thenDragTo: end)
            XCTAssertEqual(chart.value as? String, before)
        }
        controls.swipeUp()
        controls.swipeUp()
        app.buttons["curve-edit-mode"].tap()
        XCTAssertTrue((chart.value as? String)?.contains("Editing") == true)
        capture("edit_mode", app: app)
        let editBefore = chart.value as? String
        // A real tap is required to insert a point.
        let pointCount = Int(editBefore?.components(separatedBy: " ").first ?? "") ?? 0
        chart.coordinate(withNormalizedOffset: CGVector(dx: 0.50, dy: 0.50)).tap()
        XCTAssertTrue((chart.value as? String)?.hasPrefix("\(pointCount + 1) points") == true,
                      "Before: \(editBefore ?? "nil"); after: \(chart.value ?? "nil")")
        let point = app.descendants(matching: .any).matching(identifier: "curve-point-1").firstMatch
        XCTAssertTrue(point.exists)
        point.tap()
        capture("edit_selected_point", app: app)
        let beforeDrag = chart.value as? String
        let dragStart = point.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        dragStart.press(forDuration: 0.05, thenDragTo: dragStart.withOffset(CGVector(dx: 14, dy: -12)))
        let afterDrag = chart.value as? String
        XCTAssertNotEqual(afterDrag, beforeDrag)
        app.buttons["Undo"].tap()
        XCTAssertEqual(chart.value as? String, beforeDrag)
        app.buttons["Redo"].tap()
        XCTAssertEqual(chart.value as? String, afterDrag)
        app.buttons["Undo"].tap()
        XCTAssertEqual(chart.value as? String, beforeDrag)
        let sampleButton = app.buttons["curve-eyedropper"]
        sampleButton.tap()
        XCTAssertTrue(sampleButton.isSelected)
        capture("eyedropper_active", app: app)
        let photo = app.descendants(matching: .any).matching(identifier: "curve-photo-sampling").firstMatch
        XCTAssertTrue(photo.waitForExistence(timeout: 5))
        let beforeSampling = chart.value as? String
        let undoBeforeSampling = app.buttons["Undo"].isEnabled
        photo.coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: 0.5))
            .press(forDuration: 0.05, thenDragTo: photo.coordinate(
                withNormalizedOffset: CGVector(dx: 0.55, dy: 0.5)))
        let value = app.staticTexts["curve-sample-value"]
        XCTAssertTrue(value.waitForExistence(timeout: 10))
        XCTAssertEqual(chart.value as? String, beforeSampling)
        XCTAssertEqual(app.buttons["Undo"].isEnabled, undoBeforeSampling)
        capture("eyedropper_sample", app: app)
        app.buttons["Red"].tap()
        XCTAssertTrue((chart.value as? String)?.hasPrefix("2 points") == true)
        XCTAssertTrue(value.exists)
        app.buttons["curve-add-point"].tap()
        XCTAssertFalse(value.exists)
        XCTAssertTrue((chart.value as? String)?.hasPrefix("3 points") == true)
        app.buttons["curve-delete-point"].tap()
        XCTAssertTrue((chart.value as? String)?.hasPrefix("2 points") == true)
        app.buttons["Undo"].tap()
        XCTAssertTrue((chart.value as? String)?.hasPrefix("3 points") == true)
        app.buttons["Redo"].tap()
        XCTAssertTrue((chart.value as? String)?.hasPrefix("2 points") == true)
        let afterInsertion = chart.value as? String
        chart.coordinate(withNormalizedOffset: CGVector(dx: 0.38, dy: 0.27))
            .press(forDuration: 0.05, thenDragTo: chart.coordinate(
                withNormalizedOffset: CGVector(dx: 0.52, dy: 0.82)))
        XCTAssertEqual(chart.value as? String, afterInsertion)
        if !app.buttons["curve-edit-mode"].isHittable { controls.swipeUp() }
        app.buttons["curve-edit-mode"].tap()
        XCTAssertTrue((chart.value as? String)?.contains("Viewing") == true)
        XCTAssertFalse(photo.exists)
        XCTAssertTrue(controls.exists)
    }

    @MainActor func testEyedropperKeepsCenterSampleAfterZoom() throws {
        continueAfterFailure = false
        let app = XCUIApplication(); app.launch()
        openCurves(app)
        let controls = app.scrollViews["curve-controls-scroll"]
        controls.swipeUp(); controls.swipeUp()
        app.buttons["curve-edit-mode"].tap()
        let eyedropper = app.buttons["curve-eyedropper"]
        eyedropper.tap()
        let surface = app.descendants(matching: .any).matching(identifier: "curve-photo-sampling").firstMatch
        XCTAssertTrue(surface.waitForExistence(timeout: 10))
        func centerSample(horizontalOffset: CGFloat = 0) -> Int {
            let center = surface.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            let target = center.withOffset(CGVector(dx: horizontalOffset, dy: 0))
            target.press(forDuration: 0.05, thenDragTo: target.withOffset(CGVector(dx: 0.5, dy: 0)))
            let label = app.staticTexts["curve-sample-value"]
            XCTAssertTrue(label.waitForExistence(timeout: 5))
            return Int(label.label.filter(\.isNumber)) ?? -1
        }
        let before = centerSample()
        eyedropper.tap()
        let canvas = app.descendants(matching: .any).matching(identifier: "photo-canvas").firstMatch
        canvas.pinch(withScale: 2, velocity: 1)
        XCTAssertFalse((canvas.value as? String)?.contains("Zoom 100") == true)
        eyedropper.tap()
        XCTAssertTrue(surface.waitForExistence(timeout: 10))
        let after = centerSample()
        XCTAssertLessThanOrEqual(abs(after - before), 2)
        eyedropper.tap()
        let center = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        center.press(forDuration: 0.05, thenDragTo: center.withOffset(CGVector(dx: 24, dy: 0)))
        eyedropper.tap()
        XCTAssertTrue(surface.waitForExistence(timeout: 10))
        let afterPan = centerSample(horizontalOffset: 24)
        XCTAssertLessThanOrEqual(abs(afterPan - before), 2)
    }
}
