import XCTest

final class MaskGeometryUITests: XCTestCase {
    @MainActor func testMaskFollowsMirrorAndRemainsEditableAfterUndo() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(fr)", "-AppleLocale", "fr_FR", "--app-store-panel", "Geometry"]
        app.launch()
        let canvas = app.descendants(matching: .any).matching(identifier: "photo-canvas").firstMatch
        XCTAssertTrue(canvas.waitForExistence(timeout: 20))
        app.buttons["geometry-reset"].tap()
        open("Masks", app: app)
        app.buttons["mask-new"].tap()
        app.buttons["mask-create-radial"].tap()
        let center = app.descendants(matching: .any).matching(identifier: "mask-handle-center").firstMatch
        XCTAssertTrue(center.waitForExistence(timeout: 10))
        let start = center.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: -45, dy: -25)))
        let selectedLayer = try XCTUnwrap(app.buttons.allElementsBoundByIndex.first { $0.identifier.hasPrefix("mask-") && $0.isSelected })
        let layerID = selectedLayer.identifier
        let original = center.frame
        let photo = canvas.frame
        capture("01-masque-avant-miroir", app)

        open("Geometry", app: app)
        app.buttons["Flip horizontally"].tap()
        open("Masks", app: app)
        app.buttons[layerID].tap()
        expectation(for: NSPredicate { _, _ in
            abs(center.frame.midX - (photo.midX * 2 - original.midX)) < 4
        }, evaluatedWith: center)
        waitForExpectations(timeout: 10)
        XCTAssertEqual(center.frame.midY, original.midY, accuracy: 4)
        capture("02-masque-apres-miroir", app)
        let mirrored = center.frame
        let moved = center.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        moved.press(forDuration: 0.1, thenDragTo: moved.withOffset(CGVector(dx: 25, dy: 15)))
        XCTAssertGreaterThan(center.frame.midX, mirrored.midX + 15)
        app.buttons["arrow.uturn.backward"].tap()
        XCTAssertEqual(center.frame.midX, mirrored.midX, accuracy: 4)
        app.buttons["arrow.uturn.backward"].tap()
        XCTAssertEqual(center.frame.midX, original.midX, accuracy: 4)
        app.buttons["arrow.uturn.forward"].tap()
        XCTAssertEqual(center.frame.midX, mirrored.midX, accuracy: 4)
        app.buttons["arrow.uturn.backward"].tap() // Leave the photo geometry as it was.
        app.buttons["trash"].tap()
    }

    @MainActor private func open(_ panel: String, app: XCUIApplication) {
        let button = app.buttons["editor-tab-\(panel)"]
        let toolbar = app.scrollViews["tools-toolbar"]
        for _ in 0..<12 {
            if button.exists {
                let frame = button.frame
                if !frame.isNull && !frame.isInfinite && frame.width > 0 && app.frame.contains(CGPoint(x: frame.midX, y: frame.midY)) { break }
                if !frame.isNull && !frame.isInfinite && frame.maxX <= app.frame.minX {
                    toolbar.swipeRight(); continue
                }
            }
            toolbar.swipeLeft()
        }
        XCTAssertTrue(button.exists)
        if !button.isSelected { button.tap() }
    }

    @MainActor private func capture(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
