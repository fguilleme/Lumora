import XCTest
import UIKit

final class EditorUITests: XCTestCase {
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
        app.buttons["Importer et options"].tap()
        app.buttons["Réinitialiser les réglages"].tap()
        let toolbar = app.scrollViews["tools-toolbar"]
        toolbar.swipeLeft(); toolbar.swipeLeft()
        app.buttons["Masques"].tap()
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
        let geometry = app.buttons["Géométrie"]
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
        app.buttons["Importer et options"].tap()
        app.buttons["Réinitialiser les réglages"].tap()
        let baseline = try redDominance(canvas.screenshot())
        let toolbar = app.scrollViews["tools-toolbar"]
        toolbar.swipeLeft(); toolbar.swipeLeft()
        app.buttons["Masques"].tap()
        app.scrollViews["masks-controls"].buttons["Radial"].tap()
        toolbar.swipeRight(); toolbar.swipeRight()
        app.buttons["Lumière"].tap()
        RunLoop.current.run(until: Date().addingTimeInterval(1))
        // No development adjustment has changed: only the selected matte can tint red.
        XCTAssertGreaterThan(try redDominance(canvas.screenshot()) - baseline, 10)
        app.sliders["Exposition"].adjust(toNormalizedSliderPosition: 0.55)
        XCTAssertTrue(toolbar.isHittable)
        RunLoop.current.run(until: Date().addingTimeInterval(1))
        XCTAssertGreaterThan(try redDominance(canvas.screenshot()) - baseline, 10)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Masque radial — superposition rouge visible"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

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
        XCTAssertEqual(canvas.frame.height, height, accuracy: 1)
        let amount = app.sliders["creative-amount"]
        XCTAssertTrue(amount.isHittable)
        amount.adjust(toNormalizedSliderPosition: 0.7)
        XCTAssertTrue(app.scrollViews["tools-toolbar"].isHittable)
        app.buttons["Options de l’effet"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        app.buttons["Dupliquer"].tap()
        XCTAssertEqual(effects.count, initialCount + 2)
        app.buttons["Annuler"].tap()
        XCTAssertEqual(effects.count, initialCount + 1)
        app.buttons["Détail Creative à résolution native"].tap()
        XCTAssertTrue(app.navigationBars["Détail Creative"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["100 % · un pixel photo par pixel écran"].exists)
        app.buttons["Fermer"].tap()
        XCTAssertTrue(controls.waitForExistence(timeout: 5))
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Creative — panneau compact"
        attachment.lifetime = .keepAlways
        add(attachment)
        // Accessibility slider adjustment can emit several discrete edits. Remove only
        // this test's new effect; duplication undo was asserted separately above.
        app.buttons["Options de l’effet"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        app.buttons["Supprimer"].tap()
        XCTAssertEqual(effects.count, initialCount)
    }

    @MainActor
    func testMaskSliderRestoresToolbar() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        if !app.sliders["Exposition"].waitForExistence(timeout: 4) {
            if app.buttons["Importer et options"].exists { app.buttons["Importer et options"].tap() }
            app.buttons["Photos"].tap()
            let photo = app.images.matching(identifier: "PXGGridLayout-Info").element(boundBy: 1)
            XCTAssertTrue(photo.waitForExistence(timeout: 20))
            photo.tap()
            XCTAssertTrue(app.sliders["Exposition"].waitForExistence(timeout: 30))
        }
        app.buttons["Importer et options"].tap()
        app.buttons["Réinitialiser les réglages"].tap()
        let canvas = app.descendants(matching: .any).matching(identifier: "photo-canvas").firstMatch
        XCTAssertTrue(canvas.waitForExistence(timeout: 5))
        let canvasWithoutMask = canvas.screenshot().pngRepresentation
        let toolbar = app.scrollViews["tools-toolbar"]
        toolbar.swipeLeft(); toolbar.swipeLeft()
        app.buttons["Masques"].tap()
        app.scrollViews["masks-controls"].buttons["Radial"].tap()

        let activeLayerMenu = app.buttons.matching(identifier: "active-layer").firstMatch
        XCTAssertTrue(activeLayerMenu.waitForExistence(timeout: 3))
        XCTAssertEqual(activeLayerMenu.value as? String, "Radial 1")
        activeLayerMenu.tap()
        app.buttons["quick-layer-base"].tap()
        XCTAssertEqual(activeLayerMenu.value as? String, "Photo entière")
        activeLayerMenu.tap()
        app.buttons["quick-layer-mask-0"].tap()
        XCTAssertEqual(activeLayerMenu.value as? String, "Radial 1")

        let masks = app.scrollViews["masks-controls"]
        let exposure = app.sliders["mask-adjustment-exposure"]
        for _ in 0..<14 {
            if exposure.isHittable { break }
            masks.swipeUpAlongLeadingEdge()
        }
        XCTAssertTrue(exposure.isHittable)
        exposure.adjust(toNormalizedSliderPosition: 0.82)
        XCTAssertNotEqual(exposure.value as? String, "0.00")
        XCTAssertTrue(toolbar.isHittable)

        toolbar.swipeRight(); toolbar.swipeRight()
        app.buttons["Lumière"].tap()
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))
        XCTAssertNotEqual(canvas.screenshot().pngRepresentation, canvasWithoutMask)
        let lightExposure = app.sliders["Exposition"]
        lightExposure.adjust(toNormalizedSliderPosition: 0.72)
        XCTAssertTrue(toolbar.isHittable)

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Lumora — masque rouge dans Lumière"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testFixedPreviewAndUnifiedColorTools() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        if app.buttons["Importer et options"].waitForExistence(timeout: 3) {
            app.buttons["Importer et options"].tap()
        }
        app.buttons["Photos"].tap()
        let photo = app.images.matching(identifier: "PXGGridLayout-Info").element(boundBy: 1)
        XCTAssertTrue(photo.waitForExistence(timeout: 20))
        photo.tap()
        let canvas = app.descendants(matching: .any).matching(identifier: "photo-canvas").firstMatch
        XCTAssertTrue(canvas.waitForExistence(timeout: 30))
        XCTAssertFalse(app.buttons["Avant / après"].exists)
        let previewHeight = canvas.frame.height
        canvas.press(forDuration: 0.4)
        let canvasCenter = app.coordinate(withNormalizedOffset: .zero).withOffset(
            CGVector(dx: canvas.frame.midX, dy: canvas.frame.midY)
        )
        canvas.pinch(withScale: 2, velocity: 1)
        XCTAssertNotEqual(canvas.value as? String, "Zoom 100 %")
        canvasCenter.doubleTap()
        XCTAssertEqual(canvas.value as? String, "Zoom 100 %")
        let exposure = app.sliders["Exposition"]
        XCTAssertTrue(exposure.exists)
        XCTAssertLessThanOrEqual(exposure.frame.height, 44)

        app.buttons["Colorimétrie"].tap()
        XCTAssertEqual(canvas.frame.height, previewHeight, accuracy: 1)
        XCTAssertTrue(app.segmentedControls.buttons["Mélangeur"].exists)
        app.segmentedControls.buttons["Grading"].tap()
        XCTAssertEqual(canvas.frame.height, previewHeight, accuracy: 1)
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "grading-wheel").count, 1)
        XCTAssertTrue(app.segmentedControls.buttons["Ombres"].exists)
        XCTAssertTrue(app.segmentedControls.buttons["Tons moyens"].exists)
        XCTAssertTrue(app.segmentedControls.buttons["Hautes lumières"].exists)

        let toolbar = app.scrollViews["tools-toolbar"]
        app.buttons["Effets"].tap()
        let beforeEffect = canvas.screenshot().pngRepresentation
        let dehaze = app.sliders["effect-dehaze"]
        XCTAssertTrue(dehaze.waitForExistence(timeout: 3))
        dehaze.adjust(toNormalizedSliderPosition: 0.85)
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))
        XCTAssertNotEqual(dehaze.value as? String, "0.00")
        XCTAssertNotEqual(canvas.screenshot().pngRepresentation, beforeEffect)
        XCTAssertTrue(toolbar.isHittable)

        toolbar.swipeLeft()
        app.buttons["Détail"].tap()
        let beforeDetail = canvas.screenshot().pngRepresentation
        let gain = app.sliders["detail-sharpeningAmount"]
        XCTAssertTrue(gain.waitForExistence(timeout: 3))
        gain.adjust(toNormalizedSliderPosition: 0.8)
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))
        XCTAssertNotEqual(gain.value as? String, "0.00")
        XCTAssertNotEqual(canvas.screenshot().pngRepresentation, beforeDetail)
        XCTAssertTrue(toolbar.isHittable)

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Lumora — colorimétrie unifiée"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testLibraryBatchSelection() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()

        for _ in 0..<2 {
            if app.buttons["Importer et options"].waitForExistence(timeout: 3) {
                app.buttons["Importer et options"].tap()
            }
            app.buttons["Photos"].tap()
            let photo = app.images.matching(identifier: "PXGGridLayout-Info").element(boundBy: 1)
            XCTAssertTrue(photo.waitForExistence(timeout: 20))
            photo.tap()
            XCTAssertTrue(app.sliders["Exposition"].waitForExistence(timeout: 30))
        }

        app.buttons["Importer et options"].tap()
        app.buttons["Bibliothèque"].tap()
        XCTAssertTrue(app.navigationBars["Bibliothèque"].waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(app.buttons.matching(identifier: "library-document-row").count, 2)
        app.buttons["library-select"].tap()

        let rows = app.buttons.matching(identifier: "library-selection-row")
        XCTAssertTrue(rows.element(boundBy: 1).waitForExistence(timeout: 5))
        rows.element(boundBy: 0).tap()
        rows.element(boundBy: 1).tap()
        XCTAssertTrue(app.navigationBars["2 sélectionnées"].waitForExistence(timeout: 5))

        app.buttons["library-batch-favorites"].tap()
        app.buttons["Ajouter aux favoris"].tap()
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Lumora — sélection multiple"
        attachment.lifetime = .keepAlways
        add(attachment)

        app.buttons["Terminé"].tap()
        let favorites = app.buttons.matching(identifier: "library-favorite-button")
        XCTAssertGreaterThanOrEqual(favorites.count, 2)
        XCTAssertEqual(favorites.element(boundBy: 0).value as? String, "Favori")
        XCTAssertEqual(favorites.element(boundBy: 1).value as? String, "Favori")
    }

    @MainActor
    func testLibraryListsImportedPhoto() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        if app.buttons["Importer et options"].waitForExistence(timeout: 3) {
            app.buttons["Importer et options"].tap()
        }
        app.buttons["Photos"].tap()
        let photo = app.images.matching(identifier: "PXGGridLayout-Info").element(boundBy: 1)
        XCTAssertTrue(photo.waitForExistence(timeout: 20))
        photo.tap()
        XCTAssertTrue(app.sliders["Exposition"].waitForExistence(timeout: 30))
        app.buttons["Importer et options"].tap()
        app.buttons["Bibliothèque"].tap()
        XCTAssertTrue(app.navigationBars["Bibliothèque"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons.matching(identifier: "library-document-row").firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Ouvert"].exists)
        let favorite = app.buttons.matching(identifier: "library-favorite-button").firstMatch
        XCTAssertTrue(favorite.exists)
        let expectedFavoriteValue = (favorite.value as? String == "Favori") ? "Non favori" : "Favori"
        favorite.tap()
        let favoriteChanged = NSPredicate(format: "value == %@", expectedFavoriteValue)
        expectation(for: favoriteChanged, evaluatedWith: favorite)
        waitForExpectations(timeout: 5)

        let folderName = "Voyages UI \(UUID().uuidString.prefix(6))"
        app.buttons["library-scope"].tap()
        app.buttons["Gérer les dossiers…"].tap()
        XCTAssertTrue(app.navigationBars["Dossiers"].waitForExistence(timeout: 5))
        app.buttons["library-new-folder"].tap()
        let folderField = app.textFields["Nom"]
        XCTAssertTrue(folderField.waitForExistence(timeout: 3))
        folderField.typeText(folderName)
        app.buttons["Créer"].tap()
        XCTAssertTrue(app.staticTexts[folderName].waitForExistence(timeout: 5))
        app.buttons["Terminé"].tap()

        let options = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Options de'")).firstMatch
        XCTAssertTrue(options.waitForExistence(timeout: 3))
        options.tap()
        app.buttons["Déplacer vers"].tap()
        app.buttons[folderName].tap()
        XCTAssertTrue(app.staticTexts[folderName].waitForExistence(timeout: 5))
        app.buttons["library-scope"].tap()
        app.buttons[folderName].tap()
        XCTAssertTrue(app.buttons.matching(identifier: "library-document-row").firstMatch.exists)

        let tagName = "Sélection UI \(UUID().uuidString.prefix(6))"
        app.buttons["library-scope"].tap()
        app.buttons["Gérer les étiquettes…"].tap()
        XCTAssertTrue(app.navigationBars["Étiquettes"].waitForExistence(timeout: 5))
        app.buttons["library-new-tag"].tap()
        let tagField = app.textFields["Nom"]
        XCTAssertTrue(tagField.waitForExistence(timeout: 3))
        tagField.typeText(tagName)
        app.buttons["Créer"].tap()
        XCTAssertTrue(app.staticTexts[tagName].waitForExistence(timeout: 5))
        app.buttons["Terminé"].tap()

        let taggedOptions = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Options de'")).firstMatch
        XCTAssertTrue(taggedOptions.waitForExistence(timeout: 3))
        taggedOptions.tap()
        app.buttons["Étiquettes"].tap()
        app.buttons[tagName].tap()
        XCTAssertTrue(app.staticTexts[tagName].waitForExistence(timeout: 5))
        app.buttons["library-scope"].tap()
        app.buttons[tagName].tap()
        XCTAssertTrue(app.buttons.matching(identifier: "library-document-row").firstMatch.exists)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Lumora — étiquettes de bibliothèque"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testAutoStraightenActionIsAvailable() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        if app.buttons["Importer et options"].waitForExistence(timeout: 3) {
            app.buttons["Importer et options"].tap()
        }
        app.buttons["Photos"].tap()
        let photo = app.images.matching(identifier: "PXGGridLayout-Info").element(boundBy: 1)
        XCTAssertTrue(photo.waitForExistence(timeout: 20))
        photo.tap()
        XCTAssertTrue(app.sliders["Exposition"].waitForExistence(timeout: 30))

        let toolbar = app.scrollViews["tools-toolbar"]
        let geometry = app.buttons["Géométrie"]
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
        attachment.name = "Lumora — poignées de géométrie"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testExportOptionsAndShare() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        if app.buttons["Importer et options"].waitForExistence(timeout: 3) {
            app.buttons["Importer et options"].tap()
        }
        app.buttons["Photos"].tap()
        let photo = app.images.matching(identifier: "PXGGridLayout-Info").element(boundBy: 1)
        XCTAssertTrue(photo.waitForExistence(timeout: 20))
        photo.tap()
        XCTAssertTrue(app.sliders["Exposition"].waitForExistence(timeout: 30))
        app.buttons["Importer et options"].tap()
        app.buttons["Exporter"].tap()
        XCTAssertTrue(app.navigationBars["Exporter"].waitForExistence(timeout: 5))
        app.switches["Dimensions originales"].switches.firstMatch.tap()
        app.descendants(matching: .any).matching(identifier: "export-dimension").firstMatch.tap()
        app.descendants(matching: .any).matching(identifier: "export-size-2048").firstMatch.tap()
        app.descendants(matching: .any).matching(identifier: "export-format").firstMatch.tap()
        app.buttons["PNG"].tap()
        app.descendants(matching: .any).matching(identifier: "export-options").firstMatch.swipeUp()
        app.buttons["export-create"].tap()
        app.descendants(matching: .any).matching(identifier: "export-options").firstMatch.swipeUp()
        XCTAssertTrue(app.staticTexts["Export terminé"].waitForExistence(timeout: 30), app.debugDescription)
        XCTAssertTrue(app.staticTexts["export-result"].label.filter(\.isNumber).contains("2048"))
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Lumora — export haute résolution"; attachment.lifetime = .keepAlways
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
        if app.buttons["Importer et options"].exists {
            app.buttons["Importer et options"].tap()
        }
        app.buttons["Photos"].tap()
        let photo = app.images.matching(identifier: "PXGGridLayout-Info").element(boundBy: 1)
        XCTAssertTrue(photo.waitForExistence(timeout: 20))
        photo.tap()
        let slider = app.sliders["Exposition"]
        XCTAssertTrue(slider.waitForExistence(timeout: 30), app.debugDescription)
        app.buttons["Importer et options"].tap()
        app.buttons["Réinitialiser les réglages"].tap()
        slider.adjust(toNormalizedSliderPosition: 0.65)
        let editedValue = slider.value as? String
        XCTAssertNotEqual(editedValue, "0.00")
        XCTAssertTrue(app.buttons["Annuler"].isEnabled)
        app.buttons["Annuler"].tap()
        XCTAssertEqual(slider.value as? String, "0.00")
        app.buttons["Rétablir"].tap()
        XCTAssertEqual(slider.value as? String, editedValue)
        let canvas = app.descendants(matching: .any).matching(identifier: "photo-canvas").firstMatch
        XCTAssertTrue(canvas.exists)
        canvas.press(forDuration: 0.4)
        XCTAssertFalse(app.buttons["Avant / après"].exists)
        app.buttons["Couleur"].tap()
        XCTAssertTrue(app.sliders["Température"].exists)
        app.buttons["Colorimétrie"].tap()
        app.segmentedControls.buttons["Grading"].tap()
        app.buttons["Courbes"].tap()
        app.buttons["Ajouter un point"].tap()
        XCTAssertTrue(app.staticTexts["Point 2 / 3"].exists)
        let chart = app.descendants(matching: .any).matching(identifier: "tone-curve-chart").firstMatch
        let start = chart.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let end = chart.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.3))
        start.press(forDuration: 0.1, thenDragTo: end)
        let curveValue = app.sliders["Sortie du point"].value as? String
        XCTAssertNotEqual(curveValue, "50.0")
        app.buttons["Annuler"].tap()
        XCTAssertEqual(app.sliders["Sortie du point"].value as? String, "50.0")
        app.buttons["Rétablir"].tap()
        XCTAssertEqual(app.sliders["Sortie du point"].value as? String, curveValue)
        app.buttons["Supprimer le point"].tap()
        XCTAssertTrue(app.staticTexts["Point 1 / 2"].exists)
        app.buttons["Annuler"].tap()
        XCTAssertTrue(app.staticTexts["Point 1 / 3"].exists)
        app.segmentedControls.buttons["Rouge"].tap()
        XCTAssertTrue(app.staticTexts["Point 1 / 2"].exists)
        app.buttons["Ajouter un point"].tap()
        app.sliders["Sortie du point"].adjust(toNormalizedSliderPosition: 0.6)
        app.segmentedControls.buttons["RVB"].tap()
        XCTAssertTrue(app.staticTexts["Point 1 / 3"].exists)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Lumora — courbes"; screenshot.lifetime = .keepAlways
        add(screenshot)
        app.terminate(); app.launch()
        XCTAssertTrue(app.sliders["Exposition"].waitForExistence(timeout: 15))
        XCTAssertEqual(app.sliders["Exposition"].value as? String, editedValue)
        app.buttons["Courbes"].tap()
        XCTAssertTrue(app.staticTexts["Point 1 / 3"].exists)
        app.segmentedControls.buttons["Rouge"].tap()
        XCTAssertTrue(app.staticTexts["Point 1 / 3"].exists)
        app.buttons["Réinitialiser la courbe Rouge"].tap()
        XCTAssertTrue(app.staticTexts["Point 1 / 2"].exists)
        app.segmentedControls.buttons["RVB"].tap()
        XCTAssertTrue(app.staticTexts["Point 1 / 3"].exists)
        app.scrollViews["tools-toolbar"].swipeLeft()
        app.buttons["Colorimétrie"].tap()
        app.buttons["mixer-band-green"].tap()
        let saturation = app.sliders["mixer-saturation"]
        XCTAssertEqual(saturation.value as? String, "0.00")
        saturation.adjust(toNormalizedSliderPosition: 0.25)
        let mixerValue = saturation.value as? String
        XCTAssertNotEqual(mixerValue, "0.00")
        app.buttons["Annuler"].tap()
        XCTAssertEqual(saturation.value as? String, "0.00")
        app.buttons["Rétablir"].tap()
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
        mixerScreenshot.name = "Lumora — mélangeur HSL"; mixerScreenshot.lifetime = .keepAlways
        add(mixerScreenshot)
        app.terminate(); app.launch()
        XCTAssertTrue(app.sliders["Exposition"].waitForExistence(timeout: 15))
        app.scrollViews["tools-toolbar"].swipeLeft()
        app.buttons["Colorimétrie"].tap()
        app.buttons["mixer-band-green"].tap()
        XCTAssertEqual(app.sliders["mixer-saturation"].value as? String, mixerValue)
        XCTAssertEqual(app.sliders["mixer-hue"].value as? String, hueValue)
        XCTAssertEqual(app.sliders["mixer-luminance"].value as? String, luminanceValue)
        app.buttons["Réinitialiser la plage Vert"].tap()
        XCTAssertEqual(app.sliders["mixer-saturation"].value as? String, "0.00")
        XCTAssertEqual(app.sliders["mixer-hue"].value as? String, "0.00")
        XCTAssertEqual(app.sliders["mixer-luminance"].value as? String, "0.00")
        app.buttons["Annuler"].tap()
        XCTAssertEqual(app.sliders["mixer-saturation"].value as? String, mixerValue)
        app.segmentedControls.buttons["Grading"].tap()
        let shadowWheel = app.descendants(matching: .any).matching(identifier: "grading-wheel").firstMatch
        let originalWheel = shadowWheel.value as? String
        let wheelStart = shadowWheel.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let wheelEnd = shadowWheel.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.25))
        wheelStart.press(forDuration: 0.1, thenDragTo: wheelEnd)
        let shadowValue = shadowWheel.value as? String
        XCTAssertNotEqual(shadowValue, originalWheel)
        app.buttons["Annuler"].tap()
        XCTAssertEqual(shadowWheel.value as? String, originalWheel)
        app.buttons["Rétablir"].tap()
        XCTAssertEqual(shadowWheel.value as? String, shadowValue)
        app.sliders["grading-luminance"].adjust(toNormalizedSliderPosition: 0.6)
        let shadowLuminance = app.sliders["grading-luminance"].value as? String
        app.segmentedControls.buttons["Tons moyens"].tap()
        XCTAssertEqual(app.sliders["grading-luminance"].value as? String, "0.00")
        app.segmentedControls.buttons["Ombres"].tap()
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
        app.buttons["Effets"].tap()
        app.terminate(); app.launch()
        XCTAssertTrue(app.sliders["Exposition"].waitForExistence(timeout: 15))
        app.scrollViews["tools-toolbar"].swipeLeft()
        app.buttons["Colorimétrie"].tap()
        app.segmentedControls.buttons["Grading"].tap()
        XCTAssertEqual(shadowWheel.value as? String, shadowValue)
        XCTAssertEqual(app.sliders["grading-luminance"].value as? String, shadowLuminance)
        app.buttons["Réinitialiser grading Ombres"].tap()
        XCTAssertEqual(shadowWheel.value as? String, originalWheel)
        app.buttons["Annuler"].tap()
        XCTAssertEqual(shadowWheel.value as? String, shadowValue)
        app.scrollViews["grading-controls"].swipeUp()
        XCTAssertEqual(app.sliders["grading-blending"].value as? String, blendingValue)
        XCTAssertEqual(app.sliders["grading-balance"].value as? String, balanceValue)
        app.scrollViews["tools-toolbar"].swipeLeft()
        app.buttons["Effets"].tap()
        let texture = app.sliders["effect-texture"]
        XCTAssertEqual(texture.value as? String, "0.00")
        texture.adjust(toNormalizedSliderPosition: 0.7)
        let textureValue = texture.value as? String
        XCTAssertNotEqual(textureValue, "0.00")
        app.buttons["Annuler"].tap()
        XCTAssertEqual(texture.value as? String, "0.00")
        app.buttons["Rétablir"].tap()
        XCTAssertEqual(texture.value as? String, textureValue)
        app.scrollViews["effects-controls"].swipeUp()
        app.sliders["effect-grain"].adjust(toNormalizedSliderPosition: 0.45)
        let grainValue = app.sliders["effect-grain"].value as? String
        let effectsScreenshot = XCTAttachment(screenshot: app.screenshot())
        effectsScreenshot.name = "Lumora — effets"; effectsScreenshot.lifetime = .keepAlways
        add(effectsScreenshot)
        app.buttons["Lumière"].tap()
        app.terminate(); app.launch()
        XCTAssertTrue(app.sliders["Exposition"].waitForExistence(timeout: 15))
        app.scrollViews["tools-toolbar"].swipeLeft()
        app.buttons["Effets"].tap()
        XCTAssertEqual(app.sliders["effect-texture"].value as? String, textureValue)
        app.scrollViews["effects-controls"].swipeUp()
        XCTAssertEqual(app.sliders["effect-grain"].value as? String, grainValue)
        app.scrollViews["tools-toolbar"].swipeLeft()
        app.buttons["Détail"].tap()
        let sharpening = app.sliders["detail-sharpeningAmount"]
        XCTAssertEqual(sharpening.value as? String, "0.00")
        sharpening.adjust(toNormalizedSliderPosition: 0.65)
        let sharpeningValue = sharpening.value as? String
        XCTAssertNotEqual(sharpeningValue, "0.00")
        app.buttons["Annuler"].tap()
        XCTAssertEqual(sharpening.value as? String, "0.00")
        app.buttons["Rétablir"].tap()
        XCTAssertEqual(sharpening.value as? String, sharpeningValue)
        app.scrollViews["detail-controls"].swipeUp()
        app.scrollViews["detail-controls"].swipeUp()
        let luminanceNoise = app.sliders["detail-luminanceNoise"]
        XCTAssertTrue(luminanceNoise.waitForExistence(timeout: 5))
        luminanceNoise.adjust(toNormalizedSliderPosition: 0.4)
        let noiseValue = luminanceNoise.value as? String
        let detailScreenshot = XCTAttachment(screenshot: app.screenshot())
        detailScreenshot.name = "Lumora — détail"; detailScreenshot.lifetime = .keepAlways
        add(detailScreenshot)
        app.buttons["Détail"].tap()
        app.terminate(); app.launch()
        XCTAssertTrue(app.sliders["Exposition"].waitForExistence(timeout: 15))
        app.scrollViews["tools-toolbar"].swipeLeft()
        app.buttons["Détail"].tap()
        XCTAssertEqual(app.sliders["detail-sharpeningAmount"].value as? String, sharpeningValue)
        app.scrollViews["detail-controls"].swipeUp()
        app.scrollViews["detail-controls"].swipeUp()
        XCTAssertEqual(app.sliders["detail-luminanceNoise"].value as? String, noiseValue)
        app.scrollViews["tools-toolbar"].swipeLeft()
        app.buttons["Optique"].tap()
        let profile = app.switches["optics-profile"]
        XCTAssertTrue(profile.exists)
        XCTAssertFalse(profile.isEnabled)
        let distortion = app.sliders["optics-distortion"]
        XCTAssertTrue(distortion.waitForExistence(timeout: 5))
        distortion.adjust(toNormalizedSliderPosition: 0.7)
        let distortionValue = distortion.value as? String
        XCTAssertNotEqual(distortionValue, "0.00")
        app.buttons["Annuler"].tap()
        XCTAssertEqual(distortion.value as? String, "0.00")
        app.buttons["Rétablir"].tap()
        XCTAssertEqual(distortion.value as? String, distortionValue)
        app.scrollViews["optics-controls"].swipeUp()
        let chromatic = app.sliders["optics-chromaticAberration"]
        chromatic.adjust(toNormalizedSliderPosition: 0.6)
        let chromaticValue = chromatic.value as? String
        let opticsScreenshot = XCTAttachment(screenshot: app.screenshot())
        opticsScreenshot.name = "Lumora — optique"; opticsScreenshot.lifetime = .keepAlways
        add(opticsScreenshot)
        app.buttons["Optique"].tap()
        app.terminate(); app.launch()
        XCTAssertTrue(app.sliders["Exposition"].waitForExistence(timeout: 15))
        app.scrollViews["tools-toolbar"].swipeLeft()
        app.buttons["Optique"].tap()
        XCTAssertEqual(app.sliders["optics-distortion"].value as? String, distortionValue)
        app.scrollViews["optics-controls"].swipeUp()
        XCTAssertEqual(app.sliders["optics-chromaticAberration"].value as? String, chromaticValue)
        app.scrollViews["tools-toolbar"].swipeLeft()
        app.buttons["Géométrie"].tap()
        XCTAssertTrue(app.buttons["Rotation droite"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["geometry-auto-straighten"].exists)
        XCTAssertTrue(app.buttons["geometry-auto-perspective"].exists)
        app.buttons["Rotation droite"].tap()
        app.buttons["geometry-aspect-square"].tap()
        XCTAssertTrue(app.buttons["geometry-aspect-square"].isSelected)
        let straighten = app.sliders["geometry-straighten"]
        straighten.adjust(toNormalizedSliderPosition: 0.65)
        let straightenValue = straighten.value as? String
        XCTAssertNotEqual(straightenValue, "0.00")
        app.buttons["Annuler"].tap()
        XCTAssertEqual(straighten.value as? String, "0.00")
        app.buttons["Rétablir"].tap()
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
        XCTAssertTrue(app.sliders["Exposition"].waitForExistence(timeout: 15))
        app.scrollViews["tools-toolbar"].swipeLeft()
        app.buttons["Géométrie"].tap()
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
        if !app.sliders["Exposition"].waitForExistence(timeout: 4) {
            if app.buttons["Importer et options"].exists { app.buttons["Importer et options"].tap() }
            app.buttons["Photos"].tap()
            let photo = app.images.matching(identifier: "PXGGridLayout-Info").element(boundBy: 1)
            XCTAssertTrue(photo.waitForExistence(timeout: 20))
            photo.tap()
            XCTAssertTrue(app.sliders["Exposition"].waitForExistence(timeout: 30))
        }
        app.buttons["Importer et options"].tap()
        app.buttons["Réinitialiser les réglages"].tap()
        app.scrollViews["tools-toolbar"].swipeLeft()
        app.scrollViews["tools-toolbar"].swipeLeft()
        app.buttons["Masques"].tap()
        app.scrollViews["masks-controls"].buttons["Pinceau"].tap()
        let layerOpacity = app.sliders["layer-opacity"]
        XCTAssertTrue(layerOpacity.waitForExistence(timeout: 5))
        layerOpacity.adjust(toNormalizedSliderPosition: 0.62)
        let layerOpacityValue = layerOpacity.value as? String
        XCTAssertNotEqual(layerOpacityValue, "100")
        let visibility = app.buttons["layer-visibility"]
        visibility.tap()
        XCTAssertTrue(visibility.label.contains("Masqué"))
        visibility.tap()
        XCTAssertTrue(visibility.label.contains("Visible"))
        app.buttons["layer-rename"].tap()
        let rename = app.alerts["Renommer le calque"].textFields.firstMatch
        XCTAssertTrue(rename.waitForExistence(timeout: 3))
        rename.tap(); rename.clearAndType("Sujet clair")
        app.alerts["Renommer le calque"].buttons["Renommer"].tap()
        XCTAssertTrue(app.buttons["Sujet clair"].waitForExistence(timeout: 3))
        let brushSize = app.sliders["mask-parameter-size"]
        XCTAssertTrue(brushSize.waitForExistence(timeout: 5))
        brushSize.adjust(toNormalizedSliderPosition: 0.3)
        let brushMode = app.segmentedControls["brush-mode"]
        XCTAssertTrue(brushMode.waitForExistence(timeout: 5))
        brushMode.buttons["Effacer"].tap()
        XCTAssertTrue(brushMode.buttons["Effacer"].isSelected)
        let canvas = app.images["photo-canvas"]
        XCTAssertTrue(canvas.exists)
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: 0.45))
            .press(forDuration: 0.1, thenDragTo: canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.55, dy: 0.55)))
        app.buttons["Annuler"].tap()
        app.buttons["Rétablir"].tap()
        brushMode.buttons["Peindre"].tap()
        let localExposure = app.sliders["mask-adjustment-exposure"]
        XCTAssertTrue(localExposure.waitForExistence(timeout: 5))
        for _ in 0..<14 {
            if localExposure.isHittable { break }
            app.scrollViews["masks-controls"].swipeUpAlongLeadingEdge()
        }
        XCTAssertTrue(localExposure.isHittable)
        localExposure.adjust(toNormalizedSliderPosition: 0.85)
        let localExposureValue = localExposure.value as? String
        XCTAssertNotEqual(localExposureValue, "0.00")
        XCTAssertTrue(app.scrollViews["tools-toolbar"].isHittable)
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.35, dy: 0.4))
            .press(forDuration: 0.2, thenDragTo: canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.65, dy: 0.6)))
        app.buttons["Annuler"].tap()
        app.buttons["Rétablir"].tap()
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
        app.buttons["Annuler"].tap()
        XCTAssertEqual(centerX.value as? String, originalCenterX)
        app.buttons["Rétablir"].tap()
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
        app.buttons["Annuler"].tap()
        XCTAssertEqual(featherSlider.value as? String, originalFeather)
        app.buttons["Rétablir"].tap()
        XCTAssertEqual(featherSlider.value as? String, movedFeather)

        let operation = app.segmentedControls["mask-component-operation"]
        XCTAssertTrue(operation.waitForExistence(timeout: 5))
        operation.buttons["Ajouter"].tap()
        XCTAssertTrue(app.buttons["+ Radial 2"].exists)
        app.buttons["Annuler"].tap()
        XCTAssertTrue(app.buttons["− Radial 2"].exists)
        let componentEarlier = app.buttons["mask-component-earlier"]
        XCTAssertTrue(componentEarlier.isEnabled)
        componentEarlier.tap()
        XCTAssertTrue(app.buttons["− Radial 1"].exists)
        app.buttons["Annuler"].tap()
        XCTAssertTrue(app.buttons["− Radial 2"].exists)
        app.buttons["mask-component-delete"].tap()
        XCTAssertFalse(app.buttons["− Radial 2"].exists)
        app.buttons["Annuler"].tap()
        app.buttons["− Radial 2"].tap()
        XCTAssertTrue(app.buttons["− Radial 2"].exists)
        app.switches["mask-invert"].tap(); app.switches["mask-invert"].tap()
        let masksScreenshot = XCTAttachment(screenshot: app.screenshot())
        masksScreenshot.name = "Lumora — masques"; masksScreenshot.lifetime = .keepAlways
        add(masksScreenshot)
        app.terminate(); app.launch()
        XCTAssertTrue(app.sliders["Exposition"].waitForExistence(timeout: 15))
        app.scrollViews["tools-toolbar"].swipeLeft()
        app.buttons["Masques"].tap()
        app.buttons["Sujet clair"].tap()
        XCTAssertTrue(app.switches["mask-invert"].exists)
        XCTAssertEqual(app.sliders["layer-opacity"].value as? String, layerOpacityValue)
        XCTAssertEqual(app.sliders["mask-parameter-centerX"].value as? String, movedCenterX)
        XCTAssertEqual(app.sliders["mask-parameter-feather"].value as? String, movedFeather)
        app.scrollViews["masks-controls"].swipeUp()
        app.scrollViews["masks-controls"].swipeUp()
        app.scrollViews["masks-controls"].swipeUp()
        XCTAssertEqual(app.sliders["mask-adjustment-exposure"].value as? String, localExposureValue)
        app.scrollViews["masks-controls"].swipeDown()
        app.scrollViews["masks-controls"].swipeDown()
        app.scrollViews["masks-controls"].swipeDown()
        app.buttons["mask-new"].tap()
        app.buttons["Linéaire"].tap()
        let moveEarlier = app.buttons["layer-move-earlier"]
        XCTAssertTrue(moveEarlier.waitForExistence(timeout: 3) && moveEarlier.isEnabled)
        moveEarlier.tap()
        app.buttons["Annuler"].tap()
        app.buttons["Rétablir"].tap()
    }

    @MainActor
    func testSmartSubjectMaskGenerationAndPersistence() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        if !app.sliders["Exposition"].waitForExistence(timeout: 4) {
            if app.buttons["Importer et options"].exists { app.buttons["Importer et options"].tap() }
            app.buttons["Photos"].tap()
            let photo = app.images.matching(identifier: "PXGGridLayout-Info").element(boundBy: 1)
            XCTAssertTrue(photo.waitForExistence(timeout: 20))
            photo.tap()
            XCTAssertTrue(app.sliders["Exposition"].waitForExistence(timeout: 30))
        }
        app.buttons["Importer et options"].tap()
        app.buttons["Réinitialiser les réglages"].tap()
        app.scrollViews["tools-toolbar"].swipeLeft()
        app.scrollViews["tools-toolbar"].swipeLeft()
        app.buttons["Masques"].tap()
        app.buttons["mask-new"].tap()
        XCTAssertTrue(app.buttons["Personne"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Visage"].exists)
        XCTAssertTrue(app.buttons["Yeux"].exists)
        XCTAssertTrue(app.buttons["Ciel"].exists)
        XCTAssertTrue(app.buttons["Peau"].exists)
        app.buttons["Sujet"].tap()
        let subjectMask = app.buttons["+ Sujet 1"]
        let visionAlert = app.alerts["Impossible de terminer"]
        let deadline = Date().addingTimeInterval(30)
        while Date() < deadline, !subjectMask.exists, !visionAlert.exists {
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        if visionAlert.staticTexts["Could not create inference context"].exists {
            throw XCTSkip("Le runtime iOS Simulator 27 ne peut pas créer le contexte d’inférence Vision.")
        }
        XCTAssertTrue(subjectMask.exists, app.debugDescription)

        let masksControls = app.scrollViews["masks-controls"]
        let localExposure = app.sliders["mask-adjustment-exposure"]
        for _ in 0..<4 {
            if localExposure.isHittable { break }
            masksControls.swipeUpAlongLeadingEdge()
        }
        XCTAssertTrue(localExposure.isHittable)
        localExposure.adjust(toNormalizedSliderPosition: 0.8)
        let value = localExposure.value as? String
        XCTAssertNotEqual(value, "0.00")
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Lumora — masque Sujet Vision"; attachment.lifetime = .keepAlways
        add(attachment)

        app.terminate(); app.launch()
        XCTAssertTrue(app.sliders["Exposition"].waitForExistence(timeout: 15))
        app.scrollViews["tools-toolbar"].swipeLeft()
        app.scrollViews["tools-toolbar"].swipeLeft()
        app.buttons["Masques"].tap()
        app.buttons["Sujet"].tap()
        XCTAssertTrue(app.buttons["+ Sujet 1"].waitForExistence(timeout: 5))
        let restoredControls = app.scrollViews["masks-controls"]
        let restoredExposure = app.sliders["mask-adjustment-exposure"]
        for _ in 0..<4 {
            if restoredExposure.isHittable { break }
            restoredControls.swipeUpAlongLeadingEdge()
        }
        XCTAssertEqual(restoredExposure.value as? String, value)
    }

    @MainActor
    func testPresetCreateApplyRenamePersistAndDelete() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        if !app.sliders["Exposition"].waitForExistence(timeout: 4) {
            if app.buttons["Importer et options"].exists { app.buttons["Importer et options"].tap() }
            app.buttons["Photos"].tap()
            let photo = app.images.matching(identifier: "PXGGridLayout-Info").element(boundBy: 1)
            XCTAssertTrue(photo.waitForExistence(timeout: 20))
            photo.tap()
            XCTAssertTrue(app.sliders["Exposition"].waitForExistence(timeout: 30))
        }
        app.buttons["Importer et options"].tap()
        app.buttons["Réinitialiser les réglages"].tap()
        let exposure = app.sliders["Exposition"]
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

        app.buttons["Importer et options"].tap()
        app.buttons["Réinitialiser les réglages"].tap()
        app.buttons.matching(identifier: "Appliquer").firstMatch.tap()
        app.scrollViews["tools-toolbar"].swipeRight()
        app.scrollViews["tools-toolbar"].swipeRight()
        app.buttons["Lumière"].tap()
        XCTAssertEqual(app.sliders["Exposition"].value as? String, presetExposure)
        app.buttons["Annuler"].tap()
        XCTAssertEqual(app.sliders["Exposition"].value as? String, "0.00")
        app.buttons["Rétablir"].tap()
        XCTAssertEqual(app.sliders["Exposition"].value as? String, presetExposure)

        app.scrollViews["tools-toolbar"].swipeLeft()
        app.scrollViews["tools-toolbar"].swipeLeft()
        app.buttons["Presets"].tap()
        app.buttons["Options de Preset UI"].tap()
        app.buttons["Renommer"].tap()
        let rename = app.alerts["Renommer le preset"].textFields.firstMatch
        rename.tap(); rename.clearAndType("Preset renommé")
        app.alerts["Renommer le preset"].buttons["Renommer"].tap()
        XCTAssertTrue(app.staticTexts["Preset renommé"].waitForExistence(timeout: 5))
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Lumora — presets"; attachment.lifetime = .keepAlways
        add(attachment)

        app.terminate(); app.launch()
        XCTAssertTrue(app.sliders["Exposition"].waitForExistence(timeout: 15))
        app.scrollViews["tools-toolbar"].swipeLeft()
        app.scrollViews["tools-toolbar"].swipeLeft()
        app.buttons["Presets"].tap()
        XCTAssertTrue(app.staticTexts["Preset renommé"].waitForExistence(timeout: 5))
        app.buttons["Options de Preset renommé"].tap()
        app.buttons["Supprimer"].tap()
        XCTAssertFalse(app.staticTexts["Preset renommé"].waitForExistence(timeout: 2))
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
