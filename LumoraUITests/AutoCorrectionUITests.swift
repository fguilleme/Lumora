import XCTest

final class AutoCorrectionUITests: XCTestCase {
    @MainActor private func panel(_ name:String,_ app:XCUIApplication) {
        let toolbar=app.scrollViews["tools-toolbar"]
        for _ in 0..<8 where !app.buttons[name].isHittable {toolbar.swipeRight()}
        for _ in 0..<8 where !app.buttons[name].isHittable {toolbar.swipeLeft()}
        app.buttons[name].tap()
    }
    @MainActor private func waitApplied(_ module:String,_ app:XCUIApplication) {
        let label=app.staticTexts["auto-status-"+module]
        let predicate=NSPredicate(format:"label == %@","Auto appliqué")
        expectation(for:predicate,evaluatedWith:label)
        expectation(for:NSPredicate(format:"enabled == true"),evaluatedWith:app.buttons["auto-"+module])
        waitForExpectations(timeout:20)
    }
    @MainActor func testAutoControlsUndoCustomAndEquivalentCurve() throws {
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
        panel("Lumière",app)
        let exposure=app.sliders["Exposition"]
        exposure.adjust(toNormalizedSliderPosition:0.65)
        let manual=exposure.value as? String
        XCTAssertGreaterThanOrEqual(app.buttons["auto-light"].frame.height,44)
        app.buttons["auto-light"].tap();waitApplied("light",app)
        let auto=exposure.value as? String
        XCTAssertNotEqual(auto,manual)
        app.buttons["Annuler"].tap();XCTAssertEqual(exposure.value as? String,manual)
        app.buttons["Rétablir"].tap();XCTAssertEqual(exposure.value as? String,auto)
        waitApplied("light",app)
        app.buttons["auto-light"].tap();waitApplied("light",app)
        XCTAssertEqual(exposure.value as? String,auto)
        exposure.adjust(toNormalizedSliderPosition:0.85)
        XCTAssertNotEqual(exposure.value as? String,auto, "The manual gesture must actually change exposure")
        XCTAssertEqual(app.staticTexts["auto-status-light"].label,"Personnalisé")
        app.buttons["auto-light"].tap();waitApplied("light",app)
        XCTAssertEqual(exposure.value as? String,auto)
        let light=XCTAttachment(screenshot:app.screenshot());light.name="Auto Light editable parameters";light.lifetime = .keepAlways;add(light)
        panel("Couleur",app)
        let temperature=app.sliders["Température"]
        temperature.adjust(toNormalizedSliderPosition:0.65)
        let manualColor=temperature.value as? String
        app.buttons["auto-color"].tap();waitApplied("color",app)
        let autoColor=temperature.value as? String
        app.buttons["Annuler"].tap();XCTAssertEqual(temperature.value as? String,manualColor)
        app.buttons["Rétablir"].tap();XCTAssertEqual(temperature.value as? String,autoColor)
        panel("Courbes",app)
        let chart=app.descendants(matching:.any).matching(identifier:"tone-curve-chart").firstMatch
        XCTAssertTrue((chart.value as? String)?.hasPrefix("2 points") == true)
        app.buttons["auto-curve-balanced"].tap();waitApplied("curves",app)
        XCTAssertTrue((chart.value as? String)?.hasPrefix("2 points") == false)
        let count=chart.value as? String
        app.buttons["Annuler"].tap();XCTAssertTrue((chart.value as? String)?.hasPrefix("2 points") == true)
        app.buttons["Rétablir"].tap();XCTAssertEqual(chart.value as? String,count)
        panel("Lumière",app)
        XCTAssertEqual(exposure.value as? String,"0.00")
        panel("Courbes",app)
        app.buttons["auto-curve-natural"].tap();waitApplied("curves",app)
        app.buttons["auto-curve-punchy"].tap();waitApplied("curves",app)
        app.buttons["Annuler"].tap();waitApplied("curves",app)
        XCTAssertTrue(app.buttons["auto-curve-natural"].isSelected)
        app.buttons["Rétablir"].tap();waitApplied("curves",app)
        XCTAssertTrue(app.buttons["auto-curve-punchy"].isSelected)
        let shot=XCTAttachment(screenshot:app.screenshot());shot.name="Auto Curves editable points";shot.lifetime = .keepAlways;add(shot)
        app.terminate();app.launch()
        XCTAssertTrue(canvas.waitForExistence(timeout:20))
        panel("Courbes",app)
        XCTAssertTrue((chart.value as? String)?.hasPrefix("2 points") == false)
    }
}
