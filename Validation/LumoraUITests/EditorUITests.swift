import XCTest
import UIKit

final class EditorUITests: XCTestCase {
    @MainActor
    private func selectMaskEditingPanel(_ name: String, in app: XCUIApplication) {
        let toolbar = app.scrollViews["tools-toolbar"]
        for _ in 0..<4 {
            if app.buttons[name].isHittable { break }
            if name == "Light" { toolbar.swipeRight() } else { toolbar.swipeLeft() }
        }
        app.buttons[name].tap()
    }

    @MainActor
    func testGlamourGlowStylesUseOneEffectAndUndoRedo() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        let canvas = app.descendants(matching: .any).matching(identifier: "photo-canvas").firstMatch
        if !canvas.waitForExistence(timeout: 5) {
            app.buttons["Photos"].tap()
            let photo = app.images.matching(identifier: "PXGGridLayout-Info").element(boundBy: 1)
            XCTAssertTrue(photo.waitForExistence(timeout: 20)); photo.tap()
            XCTAssertTrue(canvas.waitForExistence(timeout: 30))
        }
        app.buttons["Import and options"].tap()
        app.buttons["Reset settings"].tap()
        app.buttons["Creative"].tap()
        let controls = app.scrollViews["creative-controls"]
        XCTAssertTrue(controls.waitForExistence(timeout: 5))
        app.buttons["creative-add"].tap()
        let glow = app.buttons.matching(NSPredicate(format: "label == %@", "Glamour Glow")).firstMatch
        XCTAssertTrue(glow.waitForExistence(timeout: 5)); glow.tap()
        let effects = controls.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "creative-effect-"))
        XCTAssertEqual(effects.count, 1)
        let strip = app.scrollViews["creative-preset-strip"]
        XCTAssertTrue(strip.waitForExistence(timeout: 5))
        let subtle = app.buttons["creative-preset-chip-glamourGlow:Subtle Glow"]
        XCTAssertTrue(subtle.isHittable); subtle.tap()
        XCTAssertEqual(subtle.value as? String, "Selected")
        let portrait = app.buttons["creative-preset-chip-glamourGlow:Portrait Glow"]
        for _ in 0..<4 where !portrait.isHittable { strip.swipeLeft() }
        XCTAssertTrue(portrait.isHittable); portrait.tap()
        XCTAssertEqual(portrait.value as? String, "Selected")
        XCTAssertEqual(effects.count, 1)
        app.buttons["Undo"].tap()
        XCTAssertEqual(subtle.value as? String, "Selected")
        app.buttons["Redo"].tap()
        XCTAssertEqual(portrait.value as? String, "Selected")
    }

    @MainActor
    func testCreativePresetChipsSelectionCustomUndoAndScroll() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        let canvas = app.descendants(matching: .any).matching(identifier: "photo-canvas").firstMatch
        if !canvas.waitForExistence(timeout: 5) {
            app.buttons["Photos"].tap()
            let photo = app.images.matching(identifier: "PXGGridLayout-Info").element(boundBy: 1)
            XCTAssertTrue(photo.waitForExistence(timeout: 20)); photo.tap()
            XCTAssertTrue(canvas.waitForExistence(timeout: 30))
        }
        app.buttons["Import and options"].tap()
        app.buttons["Reset settings"].tap()
        app.buttons["Creative"].tap()
        let controls = app.scrollViews["creative-controls"]
        XCTAssertTrue(controls.waitForExistence(timeout: 5))
        app.buttons["creative-add"].tap()
        let detail = app.buttons.matching(NSPredicate(format: "label == %@", "Detail Extractor")).firstMatch
        XCTAssertTrue(detail.waitForExistence(timeout: 5)); detail.tap()
        let effects = controls.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "creative-effect-"))
        XCTAssertEqual(effects.count, 1)
        let strip = app.scrollViews["creative-preset-strip"]
        XCTAssertTrue(strip.waitForExistence(timeout: 5))
        XCTAssertTrue(controls.staticTexts["Styles"].exists)
        XCTAssertTrue(controls.staticTexts["Settings"].exists)
        let natural = app.buttons["creative-preset-chip-detailExtractor:Natural Detail"]
        for _ in 0..<5 where !natural.isHittable { strip.swipeLeft() }
        XCTAssertTrue(natural.isHittable)
        XCTAssertTrue(natural.label.contains("preset"))
        natural.tap()
        XCTAssertEqual(natural.value as? String, "Selected")
        XCTAssertFalse(app.staticTexts["creative-preset-custom"].exists)

        let extreme = app.buttons["creative-preset-chip-detailExtractor:Extreme Detail"]
        for _ in 0..<6 where !extreme.isHittable { strip.swipeLeft() }
        XCTAssertTrue(extreme.isHittable)
        extreme.tap()
        XCTAssertEqual(extreme.value as? String, "Selected")
        XCTAssertEqual(effects.count, 1, "A style changes parameters on the same effect")
        app.buttons["Undo"].tap()
        XCTAssertEqual(natural.value as? String, "Selected")
        app.buttons["Redo"].tap()
        XCTAssertEqual(extreme.value as? String, "Selected")

        let fine = app.sliders["creative-fine"]
        for _ in 0..<8 where !fine.isHittable { controls.swipeUp() }
        XCTAssertTrue(fine.isHittable)
        fine.adjust(toNormalizedSliderPosition: 0.25)
        XCTAssertTrue(app.staticTexts["creative-preset-custom"].exists)
        for _ in 0..<8 where !natural.isHittable { controls.swipeDown() }
        for _ in 0..<5 where !natural.isHittable { strip.swipeRight() }
        XCTAssertTrue(natural.isHittable)
        natural.tap()
        XCTAssertEqual(natural.value as? String, "Selected")
        XCTAssertFalse(app.staticTexts["creative-preset-custom"].exists)
        XCTAssertEqual(effects.count, 1)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Creative — selectable styles"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testCreativePresetChipsRemainScrollableAtLargeTextSize() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityM",
                                "-AppleInterfaceStyle", "Dark"]
        app.launch()
        let canvas = app.descendants(matching: .any).matching(identifier: "photo-canvas").firstMatch
        if !canvas.waitForExistence(timeout: 5) {
            app.buttons["Photos"].tap()
            let photo = app.images.matching(identifier: "PXGGridLayout-Info").element(boundBy: 1)
            XCTAssertTrue(photo.waitForExistence(timeout: 20)); photo.tap()
            XCTAssertTrue(canvas.waitForExistence(timeout: 30))
        }
        app.buttons["Creative"].tap()
        let controls = app.scrollViews["creative-controls"]
        XCTAssertTrue(controls.waitForExistence(timeout: 5))
        let addButton = app.buttons["creative-add"]
        addButton.tap()
        let detail = app.buttons.matching(NSPredicate(format: "label == %@", "Detail Extractor")).firstMatch
        XCTAssertTrue(detail.waitForExistence(timeout: 5)); detail.tap()
        let strip = app.scrollViews["creative-preset-strip"]
        XCTAssertTrue(strip.waitForExistence(timeout: 5))
        let first = app.buttons["creative-preset-chip-detailExtractor:Subtle Detail"]
        XCTAssertTrue(first.exists)
        for _ in 0..<8 where !first.isHittable { controls.swipeUp() }
        XCTAssertTrue(first.isHittable)
        XCTAssertGreaterThanOrEqual(first.frame.height, 44)
        let last = app.buttons["creative-preset-chip-detailExtractor:Extreme Detail"]
        for _ in 0..<8 where !last.isHittable { strip.swipeLeft() }
        XCTAssertTrue(last.isHittable)
        XCTAssertGreaterThanOrEqual(last.frame.height, 44)
        last.tap()
        XCTAssertEqual(last.value as? String, "Selected")
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Creative — large type, dark mode"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testCreativePresetChipsInLandscape() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        let canvas = app.descendants(matching: .any).matching(identifier: "photo-canvas").firstMatch
        if !canvas.waitForExistence(timeout: 5) {
            app.buttons["Photos"].tap()
            let photo = app.images.matching(identifier: "PXGGridLayout-Info").element(boundBy: 1)
            XCTAssertTrue(photo.waitForExistence(timeout: 20)); photo.tap()
            XCTAssertTrue(canvas.waitForExistence(timeout: 30))
        }
        app.buttons["Creative"].tap()
        let controls = app.scrollViews["creative-controls"]
        XCTAssertTrue(controls.waitForExistence(timeout: 5))
        app.buttons["creative-add"].tap()
        let high = app.buttons.matching(NSPredicate(format: "label == %@", "High Key")).firstMatch
        XCTAssertTrue(high.waitForExistence(timeout: 5)); high.tap()
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        let subtle = app.buttons["creative-preset-chip-highKey:Soft High Key"]
        XCTAssertTrue(subtle.waitForExistence(timeout: 5))
        for _ in 0..<5 where !subtle.isHittable { controls.swipeUp() }
        XCTAssertTrue(subtle.isHittable)
        subtle.tap()
        XCTAssertEqual(subtle.value as? String, "Selected")
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Creative — styles en paysage"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testLongPressDoesNotStealMaskOrCropHandles() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        let canvas = app.descendants(matching: .any).matching(identifier: "photo-canvas").firstMatch
        if !canvas.waitForExistence(timeout: 5) {
            app.buttons["Photos"].tap()
            let photo = app.images.matching(identifier: "PXGGridLayout-Info").element(boundBy: 1)
            XCTAssertTrue(photo.waitForExistence(timeout: 20)); photo.tap()
            XCTAssertTrue(canvas.waitForExistence(timeout: 30))
        }
        app.buttons["Import and options"].tap()
        app.buttons["Reset settings"].tap()
        let toolbar = app.scrollViews["tools-toolbar"]
        toolbar.swipeLeft(); toolbar.swipeLeft()
        app.buttons["Masks"].tap()
        app.scrollViews["masks-controls"].buttons["Radial"].tap()
        let centerX = app.sliders["mask-parameter-centerX"]
        XCTAssertTrue(centerX.waitForExistence(timeout: 5))
        let before = centerX.value as? String
        let handle = app.descendants(matching: .any).matching(identifier: "mask-handle-center").firstMatch
        XCTAssertTrue(handle.waitForExistence(timeout: 5))
        let start = handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.5, thenDragTo: start.withOffset(CGVector(dx: 60, dy: 0)))
        XCTAssertNotEqual(centerX.value as? String, before, "A deliberate hold on the mask handle must still move it")
        XCTAssertFalse(app.staticTexts["ORIGINAL"].exists)

        toolbar.swipeRight()
        let geometry = app.buttons["Geometry"]
        for _ in 0..<4 {
            if geometry.isHittable { break }
            toolbar.swipeLeft()
        }
        geometry.tap()
        let cropX = app.sliders["geometry-cropX"]
        XCTAssertTrue(cropX.waitForExistence(timeout: 5))
        let cropXBefore = cropX.value as? String
        let crop = app.descendants(matching: .any).matching(identifier: "geometry-handle-crop-position").firstMatch
        XCTAssertTrue(crop.waitForExistence(timeout: 5))
        let cropStart = crop.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        cropStart.press(forDuration: 0.5, thenDragTo: cropStart.withOffset(CGVector(dx: 45, dy: 0)))
        XCTAssertNotEqual(cropX.value as? String, cropXBefore, "A deliberate hold on the crop handle must still move it")
        XCTAssertFalse(app.staticTexts["ORIGINAL"].exists)
        XCTAssertTrue(crop.exists)
    }

    @MainActor
    func testSelectedMaskActuallyTintsPreviewRed() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        let canvas = app.descendants(matching: .any).matching(identifier: "photo-canvas").firstMatch
        if !canvas.waitForExistence(timeout: 5) {
            app.buttons["Photos"].tap()
            let photo = app.images.matching(identifier: "PXGGridLayout-Info").element(boundBy: 1)
            XCTAssertTrue(photo.waitForExistence(timeout: 20)); photo.tap()
            XCTAssertTrue(canvas.waitForExistence(timeout: 30))
        }
        app.buttons["Import and options"].tap()
        app.buttons["Reset settings"].tap()
        let baseline = try redDominance(canvas.screenshot())
        let toolbar = app.scrollViews["tools-toolbar"]
        toolbar.swipeLeft(); toolbar.swipeLeft()
        app.buttons["Masks"].tap()
        app.scrollViews["masks-controls"].buttons["Radial"].tap()
        RunLoop.current.run(until: Date().addingTimeInterval(1))
        XCTAssertGreaterThan(try redDominance(canvas.screenshot()) - baseline, 10)
        toolbar.swipeRight(); toolbar.swipeRight()
        app.buttons["Light"].tap()
        RunLoop.current.run(until: Date().addingTimeInterval(1))
        // Selection remains active, but the visualization belongs to Masks only.
        XCTAssertLessThan(abs(try redDominance(canvas.screenshot()) - baseline), 3)
        app.sliders["Exposure"].adjust(toNormalizedSliderPosition: 0.55)
        XCTAssertTrue(toolbar.isHittable)
        toolbar.swipeLeft(); toolbar.swipeLeft()
        app.buttons["Masks"].tap()
        RunLoop.current.run(until: Date().addingTimeInterval(1))
        XCTAssertGreaterThan(try redDominance(canvas.screenshot()) - baseline, 10)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Radial mask — overlay limited to Masks"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    private func redDominance(_ screenshot: XCUIScreenshot) throws -> Double {
        let image = try XCTUnwrap(screenshot.image.cgImage)
        let size = 64
        var pixels = [UInt8](repeating: 0, count: size * size * 4)
        let context = try XCTUnwrap(CGContext(data: &pixels, width: size, height: size,
            bitsPerComponent: 8, bytesPerRow: size * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(image, in: CGRect(x: 0, y: 0, width: size, height: size))
        // Central patch is inside the default radial mask and away from controls.
        var sum = 0.0
        for y in 24..<40 {
            for x in 24..<40 {
                let i = (y * size + x) * 4
                sum += Double(pixels[i]) - (Double(pixels[i + 1]) + Double(pixels[i + 2])) / 2
            }
        }
        return sum / 256
    }

    @MainActor
    func testCreativeStackAndNativeInspector() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        let canvas = app.descendants(matching: .any).matching(identifier: "photo-canvas").firstMatch
        if !canvas.waitForExistence(timeout: 5) {
            app.buttons["Photos"].tap()
            let photo = app.images.matching(identifier: "PXGGridLayout-Info").element(boundBy: 1)
            XCTAssertTrue(photo.waitForExistence(timeout: 20)); photo.tap()
            XCTAssertTrue(canvas.waitForExistence(timeout: 30))
        }
        let height = canvas.frame.height
        app.buttons["Import and options"].tap()
        app.buttons["Reset settings"].tap()
        app.buttons["Creative"].tap()
        let controls = app.scrollViews["creative-controls"]
        XCTAssertTrue(controls.waitForExistence(timeout: 5))
        let effects = controls.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "creative-effect-"))
        let initialCount = effects.count
        app.buttons["creative-add"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        // UIKit's menu bridge exposes titles but drops SwiftUI item identifiers on iOS 27.
        let lowKeyItems = app.buttons.matching(NSPredicate(format: "label == %@ AND NOT (identifier BEGINSWITH %@)", "Low Key", "creative-effect-"))
        XCTAssertTrue(lowKeyItems.firstMatch.waitForExistence(timeout: 3))
        try XCTUnwrap(lowKeyItems.allElementsBoundByIndex.last).tap()
        XCTAssertEqual(effects.count, initialCount + 1)
        XCTAssertEqual(canvas.frame.height, height + 28, accuracy: 1)
        let amount = app.sliders["creative-amount"]
        XCTAssertTrue(amount.exists)
        XCTAssertTrue(app.scrollViews["tools-toolbar"].isHittable)
        let duplicate = app.buttons["creative-action-duplicate"]
        for _ in 0..<4 where !duplicate.isHittable { controls.swipeDown() }
        duplicate.tap()
        XCTAssertEqual(effects.count, initialCount + 2)
        app.buttons["Undo"].tap()
        XCTAssertEqual(effects.count, initialCount + 1)
        let inspector = app.buttons["Creative detail at native resolution"]
        for _ in 0..<8 where !inspector.isHittable { controls.swipeDown() }
        XCTAssertTrue(inspector.isHittable)
        inspector.tap()
        XCTAssertTrue(app.navigationBars["Creative detail"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["100% · one photo pixel per screen pixel"].exists)
        app.buttons["Close"].tap()
        XCTAssertTrue(controls.waitForExistence(timeout: 5))
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Creative — panneau compact"
        attachment.lifetime = .keepAlways
        add(attachment)
        // Accessibility slider adjustment can emit several discrete edits. Remove only
        // this test's new effect; duplication undo was asserted separately above.
        app.buttons["creative-action-delete"].tap()
        XCTAssertEqual(effects.count, initialCount)
    }

    @MainActor
    func testMaskSliderRestoresToolbar() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        if !app.sliders["Exposure"].waitForExistence(timeout: 4) {
            if app.buttons["Import and options"].exists { app.buttons["Import and options"].tap() }
            app.buttons["Photos"].tap()
            let photo = app.images.matching(identifier: "PXGGridLayout-Info").element(boundBy: 1)
            XCTAssertTrue(photo.waitForExistence(timeout: 20))
            photo.tap()
            XCTAssertTrue(app.sliders["Exposure"].waitForExistence(timeout: 30))
        }
        app.buttons["Import and options"].tap()
        app.buttons["Reset settings"].tap()
        let canvas = app.descendants(matching: .any).matching(identifier: "photo-canvas").firstMatch
        XCTAssertTrue(canvas.waitForExistence(timeout: 5))
        let canvasWithoutMask = canvas.screenshot().pngRepresentation
        let toolbar = app.scrollViews["tools-toolbar"]
        toolbar.swipeLeft(); toolbar.swipeLeft()
        app.buttons["Masks"].tap()
        app.scrollViews["masks-controls"].buttons["Radial"].tap()

        let activeLayerMenu = app.buttons.matching(identifier: "active-layer").firstMatch
        XCTAssertTrue(activeLayerMenu.waitForExistence(timeout: 3))
        XCTAssertEqual(activeLayerMenu.value as? String, "Radial 1")
        activeLayerMenu.tap()
        app.buttons["quick-layer-base"].tap()
        XCTAssertEqual(activeLayerMenu.value as? String, "Whole photo")
        activeLayerMenu.tap()
        app.buttons["quick-layer-mask-0"].tap()
        XCTAssertEqual(activeLayerMenu.value as? String, "Radial 1")

        XCTAssertFalse(app.staticTexts["Layer shortcuts"].exists)
        selectMaskEditingPanel("Light", in: app)
        let exposure = app.sliders["Exposure"]
        XCTAssertTrue(exposure.isHittable)
        exposure.adjust(toNormalizedSliderPosition: 0.82)
        XCTAssertNotEqual(exposure.value as? String, "0.00")
        XCTAssertTrue(toolbar.isHittable)

        toolbar.swipeRight(); toolbar.swipeRight()
        app.buttons["Light"].tap()
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))
        XCTAssertNotEqual(canvas.screenshot().pngRepresentation, canvasWithoutMask)
        let lightExposure = app.sliders["Exposure"]
        lightExposure.adjust(toNormalizedSliderPosition: 0.72)
        XCTAssertTrue(toolbar.isHittable)

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Lumora — red mask in Light"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testFixedPreviewAndUnifiedColorTools() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        if app.buttons["Import and options"].waitForExistence(timeout: 3) {
            app.buttons["Import and options"].tap()
        }
        app.buttons["Photos"].tap()
        let photo = app.images.matching(identifier: "PXGGridLayout-Info").element(boundBy: 1)
        XCTAssertTrue(photo.waitForExistence(timeout: 20))
        photo.tap()
        let canvas = app.descendants(matching: .any).matching(identifier: "photo-canvas").firstMatch
        XCTAssertTrue(canvas.waitForExistence(timeout: 30))
        XCTAssertFalse(app.buttons["Before / After"].exists)
        let previewHeight = canvas.frame.height
        canvas.press(forDuration: 0.4)
        let canvasCenter = app.coordinate(withNormalizedOffset: .zero).withOffset(
            CGVector(dx: canvas.frame.midX, dy: canvas.frame.midY)
        )
        canvas.pinch(withScale: 2, velocity: 1)
        XCTAssertNotEqual(canvas.value as? String, "Zoom 100 %")
        canvasCenter.doubleTap()
        XCTAssertEqual(canvas.value as? String, "Zoom 100 %")
        let exposure = app.sliders["Exposure"]
        XCTAssertTrue(exposure.exists)
        XCTAssertLessThanOrEqual(exposure.frame.height, 44)

        app.buttons["Color Tools"].tap()
        XCTAssertEqual(canvas.frame.height, previewHeight, accuracy: 1)
        XCTAssertTrue(app.segmentedControls.buttons["Color Mixer"].exists)
        app.segmentedControls.buttons["Grading"].tap()
        XCTAssertEqual(canvas.frame.height, previewHeight, accuracy: 1)
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "grading-wheel").count, 1)
        XCTAssertTrue(app.segmentedControls.buttons["Shadows"].exists)
        XCTAssertTrue(app.segmentedControls.buttons["Midtones"].exists)
        XCTAssertTrue(app.segmentedControls.buttons["Highlights"].exists)

        let toolbar = app.scrollViews["tools-toolbar"]
        app.buttons["Effects"].tap()
        let beforeEffect = canvas.screenshot().pngRepresentation
        let dehaze = app.sliders["effect-dehaze"]
        XCTAssertTrue(dehaze.waitForExistence(timeout: 3))
        dehaze.adjust(toNormalizedSliderPosition: 0.85)
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))
        XCTAssertNotEqual(dehaze.value as? String, "0.00")
        XCTAssertNotEqual(canvas.screenshot().pngRepresentation, beforeEffect)
        XCTAssertTrue(toolbar.isHittable)

        toolbar.swipeLeft()
        app.buttons["Detail"].tap()
        let beforeDetail = canvas.screenshot().pngRepresentation
        let gain = app.sliders["detail-sharpeningAmount"]
        XCTAssertTrue(gain.waitForExistence(timeout: 3))
        gain.adjust(toNormalizedSliderPosition: 0.8)
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))
        XCTAssertNotEqual(gain.value as? String, "0.00")
        XCTAssertNotEqual(canvas.screenshot().pngRepresentation, beforeDetail)
        XCTAssertTrue(toolbar.isHittable)

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Lumora — unified Color Tools"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testLibraryBatchSelection() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()

        for _ in 0..<2 {
            if app.buttons["Import and options"].waitForExistence(timeout: 3) {
                app.buttons["Import and options"].tap()
            }
            app.buttons["Photos"].tap()
            let photo = app.images.matching(identifier: "PXGGridLayout-Info").element(boundBy: 1)
            XCTAssertTrue(photo.waitForExistence(timeout: 20))
            photo.tap()
            XCTAssertTrue(app.sliders["Exposure"].waitForExistence(timeout: 30))
        }

        app.buttons["Import and options"].tap()
        app.buttons["Library"].tap()
        XCTAssertTrue(app.navigationBars["Library"].waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(app.buttons.matching(identifier: "library-document-row").count, 2)
        app.buttons["library-select"].tap()

        let rows = app.buttons.matching(identifier: "library-selection-row")
        XCTAssertTrue(rows.element(boundBy: 1).waitForExistence(timeout: 5))
        rows.element(boundBy: 0).tap()
        rows.element(boundBy: 1).tap()
        XCTAssertTrue(app.navigationBars["2 selected"].waitForExistence(timeout: 5))

        app.buttons["library-batch-favorites"].tap()
        app.buttons["Add to favorites"].tap()
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Lumora — multi-selection"
        attachment.lifetime = .keepAlways
        add(attachment)

        app.buttons["Done"].tap()
        let favorites = app.buttons.matching(identifier: "library-favorite-button")
        XCTAssertGreaterThanOrEqual(favorites.count, 2)
        XCTAssertEqual(favorites.element(boundBy: 0).value as? String, "Favorite")
        XCTAssertEqual(favorites.element(boundBy: 1).value as? String, "Favorite")
    }

    @MainActor
    func testLibraryListsImportedPhoto() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        if app.buttons["Import and options"].waitForExistence(timeout: 3) {
            app.buttons["Import and options"].tap()
        }
        app.buttons["Photos"].tap()
        let photo = app.images.matching(identifier: "PXGGridLayout-Info").element(boundBy: 1)
        XCTAssertTrue(photo.waitForExistence(timeout: 20))
        photo.tap()
        XCTAssertTrue(app.sliders["Exposure"].waitForExistence(timeout: 30))
        app.buttons["Import and options"].tap()
        app.buttons["Library"].tap()
        XCTAssertTrue(app.navigationBars["Library"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons.matching(identifier: "library-document-row").firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Open"].exists)
        let favorite = app.buttons.matching(identifier: "library-favorite-button").firstMatch
        XCTAssertTrue(favorite.exists)
        let expectedFavoriteValue = (favorite.value as? String == "Favorite") ? "Not a favorite" : "Favorite"
        favorite.tap()
        let favoriteChanged = NSPredicate(format: "value == %@", expectedFavoriteValue)
        expectation(for: favoriteChanged, evaluatedWith: favorite)
        waitForExpectations(timeout: 5)

        let folderName = "Voyages UI \(UUID().uuidString.prefix(6))"
        app.buttons["library-scope"].tap()
        app.buttons["Manage folders…"].tap()
        XCTAssertTrue(app.navigationBars["Folders"].waitForExistence(timeout: 5))
        app.buttons["library-new-folder"].tap()
        let folderField = app.textFields["Name"]
        XCTAssertTrue(folderField.waitForExistence(timeout: 3))
        folderField.typeText(folderName)
        app.buttons["Create"].tap()
        XCTAssertTrue(app.staticTexts[folderName].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()

        let options = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Options for'")).firstMatch
        XCTAssertTrue(options.waitForExistence(timeout: 3))
        options.tap()
        app.buttons["Move to"].tap()
        app.buttons[folderName].tap()
        XCTAssertTrue(app.staticTexts[folderName].waitForExistence(timeout: 5))
        app.buttons["library-scope"].tap()
        app.buttons[folderName].tap()
        XCTAssertTrue(app.buttons.matching(identifier: "library-document-row").firstMatch.exists)

        let tagName = "UI Selection \(UUID().uuidString.prefix(6))"
        app.buttons["library-scope"].tap()
        app.buttons["Manage tags…"].tap()
        XCTAssertTrue(app.navigationBars["Tags"].waitForExistence(timeout: 5))
        app.buttons["library-new-tag"].tap()
        let tagField = app.textFields["Name"]
        XCTAssertTrue(tagField.waitForExistence(timeout: 3))
        tagField.typeText(tagName)
        app.buttons["Create"].tap()
        XCTAssertTrue(app.staticTexts[tagName].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()

        let taggedOptions = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Options for'")).firstMatch
        XCTAssertTrue(taggedOptions.waitForExistence(timeout: 3))
        taggedOptions.tap()
        app.buttons["Tags"].tap()
        app.buttons[tagName].tap()
        XCTAssertTrue(app.staticTexts[tagName].waitForExistence(timeout: 5))
        app.buttons["library-scope"].tap()
        app.buttons[tagName].tap()
        XCTAssertTrue(app.buttons.matching(identifier: "library-document-row").firstMatch.exists)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Lumora — library tags"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testAutoStraightenActionIsAvailable() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        if app.buttons["Import and options"].waitForExistence(timeout: 3) {
            app.buttons["Import and options"].tap()
        }
        app.buttons["Photos"].tap()
        let photo = app.images.matching(identifier: "PXGGridLayout-Info").element(boundBy: 1)
        XCTAssertTrue(photo.waitForExistence(timeout: 20))
        photo.tap()
        XCTAssertTrue(app.sliders["Exposure"].waitForExistence(timeout: 30))

        let toolbar = app.scrollViews["tools-toolbar"]
        let geometry = app.buttons["Geometry"]
        for _ in 0..<4 {
            if geometry.isHittable { break }
            toolbar.swipeLeft()
        }
        XCTAssertTrue(geometry.isHittable)
        geometry.tap()
        XCTAssertTrue(app.buttons["geometry-auto-straighten"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["geometry-auto-perspective"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["geometry-handle-crop-position"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["geometry-handle-crop-zoom"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["geometry-handle-perspective-top-left"].exists)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Lumora — geometry handles"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testExportOptionsAndShare() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        if app.buttons["Import and options"].waitForExistence(timeout: 3) {
            app.buttons["Import and options"].tap()
        }
        app.buttons["Photos"].tap()
        let photo = app.images.matching(identifier: "PXGGridLayout-Info").element(boundBy: 1)
        XCTAssertTrue(photo.waitForExistence(timeout: 20))
        photo.tap()
        XCTAssertTrue(app.sliders["Exposure"].waitForExistence(timeout: 30))
        app.buttons["Import and options"].tap()
        app.buttons["Export"].tap()
        XCTAssertTrue(app.navigationBars["Export"].waitForExistence(timeout: 5))
        app.switches["Original dimensions"].switches.firstMatch.tap()
        app.descendants(matching: .any).matching(identifier: "export-dimension").firstMatch.tap()
        app.descendants(matching: .any).matching(identifier: "export-size-2048").firstMatch.tap()
        app.descendants(matching: .any).matching(identifier: "export-format").firstMatch.tap()
        app.buttons["PNG"].tap()
        app.descendants(matching: .any).matching(identifier: "export-options").firstMatch.swipeUp()
        app.buttons["export-create"].tap()
        app.descendants(matching: .any).matching(identifier: "export-options").firstMatch.swipeUp()
        XCTAssertTrue(app.staticTexts["Export complete"].waitForExistence(timeout: 30), app.debugDescription)
        XCTAssertTrue(app.staticTexts["export-result"].exists)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Lumora — high-resolution export"; attachment.lifetime = .keepAlways
        add(attachment)
        app.buttons["export-share"].tap()
        // Opening the system share sheet is sufficient: no test sends files to anyone.
        XCTAssertTrue(app.otherElements["ActivityListView"].waitForExistence(timeout: 5) || app.buttons["Copy"].exists || app.buttons["Copier"].exists, app.debugDescription)
    }

    @MainActor
    func testPhotosImportEditUndoAndRestore() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        if app.buttons["Import and options"].exists {
            app.buttons["Import and options"].tap()
        }
        app.buttons["Photos"].tap()
        let photo = app.images.matching(identifier: "PXGGridLayout-Info").element(boundBy: 1)
        XCTAssertTrue(photo.waitForExistence(timeout: 20))
        photo.tap()
        let slider = app.sliders["Exposure"]
        XCTAssertTrue(slider.waitForExistence(timeout: 30), app.debugDescription)
        app.buttons["Import and options"].tap()
        app.buttons["Reset settings"].tap()
        slider.adjust(toNormalizedSliderPosition: 0.65)
        let editedValue = slider.value as? String
        XCTAssertNotEqual(editedValue, "0.00")
        XCTAssertTrue(app.buttons["Undo"].isEnabled)
        app.buttons["Undo"].tap()
        XCTAssertEqual(slider.value as? String, "0.00")
        app.buttons["Redo"].tap()
        XCTAssertEqual(slider.value as? String, editedValue)
        let canvas = app.descendants(matching: .any).matching(identifier: "photo-canvas").firstMatch
        XCTAssertTrue(canvas.exists)
        canvas.press(forDuration: 0.4)
        XCTAssertFalse(app.buttons["Before / After"].exists)
        app.buttons["Color"].tap()
        XCTAssertTrue(app.sliders["Temperature"].exists)
        app.buttons["Color Tools"].tap()
        app.segmentedControls.buttons["Grading"].tap()
        app.buttons["Curves"].tap()
        app.buttons["Add point"].tap()
        XCTAssertTrue(app.staticTexts["Point 2 / 3"].exists)
        let chart = app.descendants(matching: .any).matching(identifier: "tone-curve-chart").firstMatch
        let start = chart.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let end = chart.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.3))
        start.press(forDuration: 0.1, thenDragTo: end)
        let curveValue = app.sliders["Output of point"].value as? String
        XCTAssertNotEqual(curveValue, "50.0")
        app.buttons["Undo"].tap()
        XCTAssertEqual(app.sliders["Output of point"].value as? String, "50.0")
        app.buttons["Redo"].tap()
        XCTAssertEqual(app.sliders["Output of point"].value as? String, curveValue)
        app.buttons["Delete point"].tap()
        XCTAssertTrue(app.staticTexts["Point 1 / 2"].exists)
        app.buttons["Undo"].tap()
        XCTAssertTrue(app.staticTexts["Point 1 / 3"].exists)
        app.segmentedControls.buttons["Red"].tap()
        XCTAssertTrue(app.staticTexts["Point 1 / 2"].exists)
        app.buttons["Add point"].tap()
        app.sliders["Output of point"].adjust(toNormalizedSliderPosition: 0.6)
        app.segmentedControls.buttons["RGB"].tap()
        XCTAssertTrue(app.staticTexts["Point 1 / 3"].exists)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Lumora — courbes"; screenshot.lifetime = .keepAlways
        add(screenshot)
        app.terminate(); app.launch()
        XCTAssertTrue(app.sliders["Exposure"].waitForExistence(timeout: 15))
        XCTAssertEqual(app.sliders["Exposure"].value as? String, editedValue)
        app.buttons["Curves"].tap()
        XCTAssertTrue(app.staticTexts["Point 1 / 3"].exists)
        app.segmentedControls.buttons["Red"].tap()
        XCTAssertTrue(app.staticTexts["Point 1 / 3"].exists)
        app.buttons["Reset Red curve"].tap()
        XCTAssertTrue(app.staticTexts["Point 1 / 2"].exists)
        app.segmentedControls.buttons["RGB"].tap()
        XCTAssertTrue(app.staticTexts["Point 1 / 3"].exists)
        app.scrollViews["tools-toolbar"].swipeLeft()
        app.buttons["Color Tools"].tap()
        app.buttons["mixer-band-green"].tap()
        let saturation = app.sliders["mixer-saturation"]
        XCTAssertEqual(saturation.value as? String, "0.00")
        saturation.adjust(toNormalizedSliderPosition: 0.25)
        let mixerValue = saturation.value as? String
        XCTAssertNotEqual(mixerValue, "0.00")
        app.buttons["Undo"].tap()
        XCTAssertEqual(saturation.value as? String, "0.00")
        app.buttons["Redo"].tap()
        XCTAssertEqual(saturation.value as? String, mixerValue)
        app.sliders["mixer-hue"].adjust(toNormalizedSliderPosition: 0.6)
        let hueValue = app.sliders["mixer-hue"].value as? String
        app.sliders["mixer-luminance"].adjust(toNormalizedSliderPosition: 0.6)
        let luminanceValue = app.sliders["mixer-luminance"].value as? String
        app.buttons["mixer-band-red"].tap()
        XCTAssertEqual(saturation.value as? String, "0.00")
        app.buttons["mixer-band-green"].tap()
        XCTAssertEqual(saturation.value as? String, mixerValue)
        let mixerScreenshot = XCTAttachment(screenshot: app.screenshot())
        mixerScreenshot.name = "Lumora — HSL mixer"; mixerScreenshot.lifetime = .keepAlways
        add(mixerScreenshot)
        app.terminate(); app.launch()
        XCTAssertTrue(app.sliders["Exposure"].waitForExistence(timeout: 15))
        app.scrollViews["tools-toolbar"].swipeLeft()
        app.buttons["Color Tools"].tap()
        app.buttons["mixer-band-green"].tap()
        XCTAssertEqual(app.sliders["mixer-saturation"].value as? String, mixerValue)
        XCTAssertEqual(app.sliders["mixer-hue"].value as? String, hueValue)
        XCTAssertEqual(app.sliders["mixer-luminance"].value as? String, luminanceValue)
        app.buttons["Reset Green range"].tap()
        XCTAssertEqual(app.sliders["mixer-saturation"].value as? String, "0.00")
        XCTAssertEqual(app.sliders["mixer-hue"].value as? String, "0.00")
        XCTAssertEqual(app.sliders["mixer-luminance"].value as? String, "0.00")
        app.buttons["Undo"].tap()
        XCTAssertEqual(app.sliders["mixer-saturation"].value as? String, mixerValue)
        app.segmentedControls.buttons["Grading"].tap()
        let shadowWheel = app.descendants(matching: .any).matching(identifier: "grading-wheel").firstMatch
        let originalWheel = shadowWheel.value as? String
        let wheelStart = shadowWheel.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let wheelEnd = shadowWheel.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.25))
        wheelStart.press(forDuration: 0.1, thenDragTo: wheelEnd)
        let shadowValue = shadowWheel.value as? String
        XCTAssertNotEqual(shadowValue, originalWheel)
        app.buttons["Undo"].tap()
        XCTAssertEqual(shadowWheel.value as? String, originalWheel)
        app.buttons["Redo"].tap()
        XCTAssertEqual(shadowWheel.value as? String, shadowValue)
        app.sliders["grading-luminance"].adjust(toNormalizedSliderPosition: 0.6)
        let shadowLuminance = app.sliders["grading-luminance"].value as? String
        app.segmentedControls.buttons["Midtones"].tap()
        XCTAssertEqual(app.sliders["grading-luminance"].value as? String, "0.00")
        app.segmentedControls.buttons["Shadows"].tap()
        XCTAssertEqual(app.sliders["grading-luminance"].value as? String, shadowLuminance)
        app.scrollViews["grading-controls"].swipeUp()
        app.sliders["grading-blending"].adjust(toNormalizedSliderPosition: 0.7)
        app.sliders["grading-balance"].adjust(toNormalizedSliderPosition: 0.65)
        let blendingValue = app.sliders["grading-blending"].value as? String
        let balanceValue = app.sliders["grading-balance"].value as? String
        app.scrollViews["grading-controls"].swipeDown()
        let gradingScreenshot = XCTAttachment(screenshot: app.screenshot())
        gradingScreenshot.name = "Lumora — color grading"; gradingScreenshot.lifetime = .keepAlways
        add(gradingScreenshot)
        app.buttons["Effects"].tap()
        app.terminate(); app.launch()
        XCTAssertTrue(app.sliders["Exposure"].waitForExistence(timeout: 15))
        app.scrollViews["tools-toolbar"].swipeLeft()
        app.buttons["Color Tools"].tap()
        app.segmentedControls.buttons["Grading"].tap()
        XCTAssertEqual(shadowWheel.value as? String, shadowValue)
        XCTAssertEqual(app.sliders["grading-luminance"].value as? String, shadowLuminance)
        app.buttons["Reset grading for Shadows"].tap()
        XCTAssertEqual(shadowWheel.value as? String, originalWheel)
        app.buttons["Undo"].tap()
        XCTAssertEqual(shadowWheel.value as? String, shadowValue)
        app.scrollViews["grading-controls"].swipeUp()
        XCTAssertEqual(app.sliders["grading-blending"].value as? String, blendingValue)
        XCTAssertEqual(app.sliders["grading-balance"].value as? String, balanceValue)
        app.scrollViews["tools-toolbar"].swipeLeft()
        app.buttons["Effects"].tap()
        let texture = app.sliders["effect-texture"]
        XCTAssertEqual(texture.value as? String, "0.00")
        texture.adjust(toNormalizedSliderPosition: 0.7)
        let textureValue = texture.value as? String
        XCTAssertNotEqual(textureValue, "0.00")
        app.buttons["Undo"].tap()
        XCTAssertEqual(texture.value as? String, "0.00")
        app.buttons["Redo"].tap()
        XCTAssertEqual(texture.value as? String, textureValue)
        app.scrollViews["effects-controls"].swipeUp()
        app.sliders["effect-grain"].adjust(toNormalizedSliderPosition: 0.45)
        let grainValue = app.sliders["effect-grain"].value as? String
        let effectsScreenshot = XCTAttachment(screenshot: app.screenshot())
        effectsScreenshot.name = "Lumora — effets"; effectsScreenshot.lifetime = .keepAlways
        add(effectsScreenshot)
        app.buttons["Light"].tap()
        app.terminate(); app.launch()
        XCTAssertTrue(app.sliders["Exposure"].waitForExistence(timeout: 15))
        app.scrollViews["tools-toolbar"].swipeLeft()
        app.buttons["Effects"].tap()
        XCTAssertEqual(app.sliders["effect-texture"].value as? String, textureValue)
        app.scrollViews["effects-controls"].swipeUp()
        XCTAssertEqual(app.sliders["effect-grain"].value as? String, grainValue)
        app.scrollViews["tools-toolbar"].swipeLeft()
        app.buttons["Detail"].tap()
        let sharpening = app.sliders["detail-sharpeningAmount"]
        XCTAssertEqual(sharpening.value as? String, "0.00")
        sharpening.adjust(toNormalizedSliderPosition: 0.65)
        let sharpeningValue = sharpening.value as? String
        XCTAssertNotEqual(sharpeningValue, "0.00")
        app.buttons["Undo"].tap()
        XCTAssertEqual(sharpening.value as? String, "0.00")
        app.buttons["Redo"].tap()
        XCTAssertEqual(sharpening.value as? String, sharpeningValue)
        app.scrollViews["detail-controls"].swipeUp()
        app.scrollViews["detail-controls"].swipeUp()
        let luminanceNoise = app.sliders["detail-luminanceNoise"]
        XCTAssertTrue(luminanceNoise.waitForExistence(timeout: 5))
        luminanceNoise.adjust(toNormalizedSliderPosition: 0.4)
        let noiseValue = luminanceNoise.value as? String
        let detailScreenshot = XCTAttachment(screenshot: app.screenshot())
        detailScreenshot.name = "Lumora — detail"; detailScreenshot.lifetime = .keepAlways
        add(detailScreenshot)
        app.buttons["Detail"].tap()
        app.terminate(); app.launch()
        XCTAssertTrue(app.sliders["Exposure"].waitForExistence(timeout: 15))
        app.scrollViews["tools-toolbar"].swipeLeft()
        app.buttons["Detail"].tap()
        XCTAssertEqual(app.sliders["detail-sharpeningAmount"].value as? String, sharpeningValue)
        app.scrollViews["detail-controls"].swipeUp()
        app.scrollViews["detail-controls"].swipeUp()
        XCTAssertEqual(app.sliders["detail-luminanceNoise"].value as? String, noiseValue)
        app.scrollViews["tools-toolbar"].swipeLeft()
        app.buttons["Optics"].tap()
        let profile = app.switches["optics-profile"]
        XCTAssertTrue(profile.exists)
        XCTAssertFalse(profile.isEnabled)
        let distortion = app.sliders["optics-distortion"]
        XCTAssertTrue(distortion.waitForExistence(timeout: 5))
        distortion.adjust(toNormalizedSliderPosition: 0.7)
        let distortionValue = distortion.value as? String
        XCTAssertNotEqual(distortionValue, "0.00")
        app.buttons["Undo"].tap()
        XCTAssertEqual(distortion.value as? String, "0.00")
        app.buttons["Redo"].tap()
        XCTAssertEqual(distortion.value as? String, distortionValue)
        app.scrollViews["optics-controls"].swipeUp()
        let chromatic = app.sliders["optics-chromaticAberration"]
        chromatic.adjust(toNormalizedSliderPosition: 0.6)
        let chromaticValue = chromatic.value as? String
        let opticsScreenshot = XCTAttachment(screenshot: app.screenshot())
        opticsScreenshot.name = "Lumora — optique"; opticsScreenshot.lifetime = .keepAlways
        add(opticsScreenshot)
        app.buttons["Optics"].tap()
        app.terminate(); app.launch()
        XCTAssertTrue(app.sliders["Exposure"].waitForExistence(timeout: 15))
        app.scrollViews["tools-toolbar"].swipeLeft()
        app.buttons["Optics"].tap()
        XCTAssertEqual(app.sliders["optics-distortion"].value as? String, distortionValue)
        app.scrollViews["optics-controls"].swipeUp()
        XCTAssertEqual(app.sliders["optics-chromaticAberration"].value as? String, chromaticValue)
        app.scrollViews["tools-toolbar"].swipeLeft()
        app.buttons["Geometry"].tap()
        XCTAssertTrue(app.buttons["Rotate right"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["geometry-auto-straighten"].exists)
        XCTAssertTrue(app.buttons["geometry-auto-perspective"].exists)
        app.buttons["Rotate right"].tap()
        app.buttons["geometry-aspect-square"].tap()
        XCTAssertTrue(app.buttons["geometry-aspect-square"].isSelected)
        let straighten = app.sliders["geometry-straighten"]
        straighten.adjust(toNormalizedSliderPosition: 0.65)
        let straightenValue = straighten.value as? String
        XCTAssertNotEqual(straightenValue, "0.00")
        app.buttons["Undo"].tap()
        XCTAssertEqual(straighten.value as? String, "0.00")
        app.buttons["Redo"].tap()
        XCTAssertEqual(straighten.value as? String, straightenValue)
        let geometryControls = app.scrollViews["geometry-controls"]
        let verticalPerspective = app.sliders["geometry-perspectiveVertical"]
        for _ in 0..<8 {
            if verticalPerspective.isHittable { break }
            geometryControls.swipeUpAlongLeadingEdge()
        }
        XCTAssertTrue(verticalPerspective.isHittable)
        verticalPerspective.adjust(toNormalizedSliderPosition: 0.7)
        let verticalPerspectiveValue = verticalPerspective.value as? String
        XCTAssertNotEqual(verticalPerspectiveValue, "0.00")
        let geometryScreenshot = XCTAttachment(screenshot: app.screenshot())
        geometryScreenshot.name = "Lumora — perspective et grille"; geometryScreenshot.lifetime = .keepAlways
        add(geometryScreenshot)

        let perspectiveScale = app.sliders["geometry-perspectiveScale"]
        for _ in 0..<10 {
            if perspectiveScale.isHittable { break }
            geometryControls.swipeUpAlongLeadingEdge()
        }
        XCTAssertTrue(perspectiveScale.isHittable)
        perspectiveScale.adjust(toNormalizedSliderPosition: 0.25)
        let perspectiveScaleValue = perspectiveScale.value as? String
        XCTAssertNotEqual(perspectiveScaleValue, "100.00")

        let cropZoom = app.sliders["geometry-cropZoom"]
        for _ in 0..<12 {
            if cropZoom.isHittable { break }
            geometryControls.swipeUpAlongLeadingEdge()
        }
        XCTAssertTrue(cropZoom.isHittable)
        cropZoom.adjust(toNormalizedSliderPosition: 0.35)
        let cropValue = cropZoom.value as? String
        app.terminate(); app.launch()
        XCTAssertTrue(app.sliders["Exposure"].waitForExistence(timeout: 15))
        app.scrollViews["tools-toolbar"].swipeLeft()
        app.buttons["Geometry"].tap()
        XCTAssertTrue(app.buttons["geometry-aspect-square"].isSelected)
        XCTAssertEqual(app.sliders["geometry-straighten"].value as? String, straightenValue)
        let restoredGeometryControls = app.scrollViews["geometry-controls"]
        let restoredVertical = app.sliders["geometry-perspectiveVertical"]
        for _ in 0..<3 {
            if restoredVertical.isHittable { break }
            restoredGeometryControls.swipeUpAlongLeadingEdge()
        }
        XCTAssertEqual(restoredVertical.value as? String, verticalPerspectiveValue)
        let restoredScale = app.sliders["geometry-perspectiveScale"]
        for _ in 0..<10 {
            if restoredScale.isHittable { break }
            restoredGeometryControls.swipeUpAlongLeadingEdge()
        }
        XCTAssertEqual(restoredScale.value as? String, perspectiveScaleValue)
        let restoredCrop = app.sliders["geometry-cropZoom"]
        for _ in 0..<12 {
            if restoredCrop.isHittable { break }
            restoredGeometryControls.swipeUpAlongLeadingEdge()
        }
        XCTAssertEqual(app.sliders["geometry-cropZoom"].value as? String, cropValue)
    }

    @MainActor
    func testMasksLocalEditingAndPersistence() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        if !app.sliders["Exposure"].waitForExistence(timeout: 4) {
            if app.buttons["Import and options"].exists { app.buttons["Import and options"].tap() }
            app.buttons["Photos"].tap()
            let photo = app.images.matching(identifier: "PXGGridLayout-Info").element(boundBy: 1)
            XCTAssertTrue(photo.waitForExistence(timeout: 20))
            photo.tap()
            XCTAssertTrue(app.sliders["Exposure"].waitForExistence(timeout: 30))
        }
        app.buttons["Import and options"].tap()
        app.buttons["Reset settings"].tap()
        app.scrollViews["tools-toolbar"].swipeLeft()
        app.scrollViews["tools-toolbar"].swipeLeft()
        app.buttons["Masks"].tap()
        app.scrollViews["masks-controls"].buttons["Brush"].tap()
        let layerOpacity = app.sliders["layer-opacity"]
        XCTAssertTrue(layerOpacity.waitForExistence(timeout: 5))
        layerOpacity.adjust(toNormalizedSliderPosition: 0.62)
        let layerOpacityValue = layerOpacity.value as? String
        XCTAssertNotEqual(layerOpacityValue, "100")
        let visibility = app.buttons["layer-visibility"]
        visibility.tap()
        XCTAssertTrue(visibility.label.contains("Outline"))
        visibility.tap()
        XCTAssertTrue(visibility.label.contains("Visible"))
        app.buttons["layer-rename"].tap()
        let rename = app.alerts["Rename layer"].textFields.firstMatch
        XCTAssertTrue(rename.waitForExistence(timeout: 3))
        rename.tap(); rename.clearAndType("Bright subject")
        app.alerts["Rename layer"].buttons["Rename"].tap()
        XCTAssertTrue(app.buttons["Bright subject"].waitForExistence(timeout: 3))
        let brushSize = app.sliders["mask-parameter-size"]
        XCTAssertTrue(brushSize.waitForExistence(timeout: 5))
        brushSize.adjust(toNormalizedSliderPosition: 0.3)
        let brushMode = app.segmentedControls["brush-mode"]
        XCTAssertTrue(brushMode.waitForExistence(timeout: 5))
        brushMode.buttons["Erase"].tap()
        XCTAssertTrue(brushMode.buttons["Erase"].isSelected)
        let canvas = app.images["photo-canvas"]
        XCTAssertTrue(canvas.exists)
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: 0.45))
            .press(forDuration: 0.1, thenDragTo: canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.55, dy: 0.55)))
        app.buttons["Undo"].tap()
        app.buttons["Redo"].tap()
        brushMode.buttons["Paint"].tap()
        selectMaskEditingPanel("Light", in: app)
        let localExposure = app.sliders["Exposure"]
        XCTAssertTrue(localExposure.isHittable)
        localExposure.adjust(toNormalizedSliderPosition: 0.85)
        let localExposureValue = localExposure.value as? String
        XCTAssertNotEqual(localExposureValue, "0.00")
        selectMaskEditingPanel("Masks", in: app)
        XCTAssertTrue(app.scrollViews["tools-toolbar"].isHittable)
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.35, dy: 0.4))
            .press(forDuration: 0.2, thenDragTo: canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.65, dy: 0.6)))
        app.buttons["Undo"].tap()
        app.buttons["Redo"].tap()
        app.scrollViews["masks-controls"].swipeDown()
        app.scrollViews["masks-controls"].swipeDown()
        app.scrollViews["masks-controls"].swipeDown()
        app.buttons["mask-add-component-subtract"].tap()
        app.collectionViews.buttons["Radial"].tap()
        XCTAssertTrue(app.sliders["mask-parameter-radiusX"].waitForExistence(timeout: 5))
        let centerX = app.sliders["mask-parameter-centerX"]
        let originalCenterX = centerX.value as? String
        let centerHandle = app.descendants(matching: .any).matching(identifier: "mask-handle-center").firstMatch
        XCTAssertTrue(centerHandle.waitForExistence(timeout: 5), app.debugDescription)
        let start = centerHandle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 70, dy: 0)))
        let movedCenterX = centerX.value as? String
        XCTAssertNotEqual(movedCenterX, originalCenterX)
        app.buttons["Undo"].tap()
        XCTAssertEqual(centerX.value as? String, originalCenterX)
        app.buttons["Redo"].tap()
        XCTAssertEqual(centerX.value as? String, movedCenterX)

        let handleCenterBeforeZoom = centerHandle.frame.midX
        canvas.pinch(withScale: 2, velocity: 1)
        let zoomedHandle = app.descendants(matching: .any).matching(identifier: "mask-handle-center").firstMatch
        let handleMovedWithPhoto = NSPredicate { element, _ in
            guard let element = element as? XCUIElement else { return false }
            return abs(element.frame.midX - handleCenterBeforeZoom) > 8
        }
        expectation(for: handleMovedWithPhoto, evaluatedWith: zoomedHandle)
        waitForExpectations(timeout: 5)

        let featherSlider = app.sliders["mask-parameter-feather"]
        let originalFeather = featherSlider.value as? String
        let featherHandle = app.descendants(matching: .any).matching(identifier: "mask-handle-feather").firstMatch
        XCTAssertTrue(featherHandle.waitForExistence(timeout: 5), app.debugDescription)
        let featherStart = featherHandle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        featherStart.press(forDuration: 0.1, thenDragTo: featherStart.withOffset(CGVector(dx: -35, dy: -25)))
        let movedFeather = featherSlider.value as? String
        XCTAssertNotEqual(movedFeather, originalFeather)
        app.buttons["Undo"].tap()
        XCTAssertEqual(featherSlider.value as? String, originalFeather)
        app.buttons["Redo"].tap()
        XCTAssertEqual(featherSlider.value as? String, movedFeather)

        let operation = app.segmentedControls["mask-component-operation"]
        XCTAssertTrue(operation.waitForExistence(timeout: 5))
        operation.buttons["Add"].tap()
        XCTAssertTrue(app.buttons["+ Radial 2"].exists)
        app.buttons["Undo"].tap()
        XCTAssertTrue(app.buttons["− Radial 2"].exists)
        let componentEarlier = app.buttons["mask-component-earlier"]
        XCTAssertTrue(componentEarlier.isEnabled)
        componentEarlier.tap()
        XCTAssertTrue(app.buttons["− Radial 1"].exists)
        app.buttons["Undo"].tap()
        XCTAssertTrue(app.buttons["− Radial 2"].exists)
        app.buttons["mask-component-delete"].tap()
        XCTAssertFalse(app.buttons["− Radial 2"].exists)
        app.buttons["Undo"].tap()
        app.buttons["− Radial 2"].tap()
        XCTAssertTrue(app.buttons["− Radial 2"].exists)
        app.switches["mask-invert"].tap(); app.switches["mask-invert"].tap()
        let masksScreenshot = XCTAttachment(screenshot: app.screenshot())
        masksScreenshot.name = "Lumora — masques"; masksScreenshot.lifetime = .keepAlways
        add(masksScreenshot)
        app.terminate(); app.launch()
        XCTAssertTrue(app.sliders["Exposure"].waitForExistence(timeout: 15))
        app.scrollViews["tools-toolbar"].swipeLeft()
        app.buttons["Masks"].tap()
        app.buttons["Bright subject"].tap()
        XCTAssertTrue(app.switches["mask-invert"].exists)
        XCTAssertEqual(app.sliders["layer-opacity"].value as? String, layerOpacityValue)
        XCTAssertEqual(app.sliders["mask-parameter-centerX"].value as? String, movedCenterX)
        XCTAssertEqual(app.sliders["mask-parameter-feather"].value as? String, movedFeather)
        selectMaskEditingPanel("Light", in: app)
        XCTAssertEqual(app.sliders["Exposure"].value as? String, localExposureValue)
        selectMaskEditingPanel("Masks", in: app)
        app.buttons["mask-new"].tap()
        app.buttons["Linear"].tap()
        let moveEarlier = app.buttons["layer-move-earlier"]
        XCTAssertTrue(moveEarlier.waitForExistence(timeout: 3) && moveEarlier.isEnabled)
        moveEarlier.tap()
        app.buttons["Undo"].tap()
        app.buttons["Redo"].tap()
    }

    @MainActor
    func testSmartSubjectMaskGenerationAndPersistence() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        if !app.sliders["Exposure"].waitForExistence(timeout: 4) {
            if app.buttons["Import and options"].exists { app.buttons["Import and options"].tap() }
            app.buttons["Photos"].tap()
            let photo = app.images.matching(identifier: "PXGGridLayout-Info").element(boundBy: 1)
            XCTAssertTrue(photo.waitForExistence(timeout: 20))
            photo.tap()
            XCTAssertTrue(app.sliders["Exposure"].waitForExistence(timeout: 30))
        }
        app.buttons["Import and options"].tap()
        app.buttons["Reset settings"].tap()
        app.scrollViews["tools-toolbar"].swipeLeft()
        app.scrollViews["tools-toolbar"].swipeLeft()
        app.buttons["Masks"].tap()
        app.buttons["mask-new"].tap()
        XCTAssertTrue(app.buttons["Person"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Face"].exists)
        XCTAssertTrue(app.buttons["Eyes"].exists)
        XCTAssertTrue(app.buttons["Sky"].exists)
        XCTAssertTrue(app.buttons["Skin"].exists)
        app.buttons["Subject"].tap()
        let subjectMask = app.buttons["+ Sujet 1"]
        let visionAlert = app.alerts["Unable to finish"]
        let deadline = Date().addingTimeInterval(30)
        while Date() < deadline, !subjectMask.exists, !visionAlert.exists {
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        if visionAlert.staticTexts["Could not create inference context"].exists {
            throw XCTSkip("The iOS Simulator 27 runtime cannot create the Vision inference context.")
        }
        XCTAssertTrue(subjectMask.exists, app.debugDescription)

        selectMaskEditingPanel("Light", in: app)
        let localExposure = app.sliders["Exposure"]
        XCTAssertTrue(localExposure.isHittable)
        localExposure.adjust(toNormalizedSliderPosition: 0.8)
        let value = localExposure.value as? String
        XCTAssertNotEqual(value, "0.00")
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Lumora — Vision Subject mask"; attachment.lifetime = .keepAlways
        add(attachment)

        app.terminate(); app.launch()
        XCTAssertTrue(app.sliders["Exposure"].waitForExistence(timeout: 15))
        app.scrollViews["tools-toolbar"].swipeLeft()
        app.scrollViews["tools-toolbar"].swipeLeft()
        app.buttons["Masks"].tap()
        app.buttons["Subject"].tap()
        XCTAssertTrue(app.buttons["+ Sujet 1"].waitForExistence(timeout: 5))
        selectMaskEditingPanel("Light", in: app)
        let restoredExposure = app.sliders["Exposure"]
        XCTAssertEqual(restoredExposure.value as? String, value)
    }

    @MainActor
    func testPresetCreateApplyRenamePersistAndDelete() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        if !app.sliders["Exposure"].waitForExistence(timeout: 4) {
            if app.buttons["Import and options"].exists { app.buttons["Import and options"].tap() }
            app.buttons["Photos"].tap()
            let photo = app.images.matching(identifier: "PXGGridLayout-Info").element(boundBy: 1)
            XCTAssertTrue(photo.waitForExistence(timeout: 20))
            photo.tap()
            XCTAssertTrue(app.sliders["Exposure"].waitForExistence(timeout: 30))
        }
        app.buttons["Import and options"].tap()
        app.buttons["Reset settings"].tap()
        let exposure = app.sliders["Exposure"]
        exposure.adjust(toNormalizedSliderPosition: 0.72)
        let presetExposure = exposure.value as? String
        XCTAssertNotEqual(presetExposure, "0.00")

        app.scrollViews["tools-toolbar"].swipeLeft()
        app.scrollViews["tools-toolbar"].swipeLeft()
        app.buttons["Presets"].tap()
        app.buttons["preset-create"].tap()
        let name = app.textFields["preset-name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap(); name.typeText("Preset UI")
        app.buttons["preset-save"].tap()
        XCTAssertTrue(app.staticTexts["Preset UI"].waitForExistence(timeout: 5))

        app.buttons["Import and options"].tap()
        app.buttons["Reset settings"].tap()
        app.buttons.matching(identifier: "Apply").firstMatch.tap()
        app.scrollViews["tools-toolbar"].swipeRight()
        app.scrollViews["tools-toolbar"].swipeRight()
        app.buttons["Light"].tap()
        XCTAssertEqual(app.sliders["Exposure"].value as? String, presetExposure)
        app.buttons["Undo"].tap()
        XCTAssertEqual(app.sliders["Exposure"].value as? String, "0.00")
        app.buttons["Redo"].tap()
        XCTAssertEqual(app.sliders["Exposure"].value as? String, presetExposure)

        app.scrollViews["tools-toolbar"].swipeLeft()
        app.scrollViews["tools-toolbar"].swipeLeft()
        app.buttons["Presets"].tap()
        app.buttons["Options for Preset UI"].tap()
        app.buttons["Rename"].tap()
        let rename = app.alerts["Rename preset"].textFields.firstMatch
        rename.tap(); rename.clearAndType("Renamed preset")
        app.alerts["Rename preset"].buttons["Rename"].tap()
        XCTAssertTrue(app.staticTexts["Renamed preset"].waitForExistence(timeout: 5))
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Lumora — presets"; attachment.lifetime = .keepAlways
        add(attachment)

        app.terminate(); app.launch()
        XCTAssertTrue(app.sliders["Exposure"].waitForExistence(timeout: 15))
        app.scrollViews["tools-toolbar"].swipeLeft()
        app.scrollViews["tools-toolbar"].swipeLeft()
        app.buttons["Presets"].tap()
        XCTAssertTrue(app.staticTexts["Renamed preset"].waitForExistence(timeout: 5))
        app.buttons["Options for Renamed preset"].tap()
        app.buttons["Delete"].tap()
        XCTAssertFalse(app.staticTexts["Renamed preset"].waitForExistence(timeout: 2))
    }
}

private extension XCUIElement {
    func swipeUpAlongLeadingEdge() {
        let start = coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.85))
        let end = coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.15))
        start.press(forDuration: 0.05, thenDragTo: end)
    }

    func clearAndType(_ text: String) {
        tap()
        if let current = value as? String, !current.isEmpty {
            typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
        }
        typeText(text)
    }
}
