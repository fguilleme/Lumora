import Testing
import Foundation
import CoreGraphics
import CoreImage
@testable import LumoraCore

@Test func cropGesturesPreserveFirstContactAndRejectInvalidInput() {
    var settings = GeometrySettings()
    settings.aspect = .fourFive; settings.cropZoom = 25; settings.cropX = 17; settings.cropY = -23
    let size = CGSize(width: 1200, height: 800)
    #expect(GeometryCropInteraction.changed(initial: settings, imageSize: size,
        viewportWidth: 300, magnification: 1, translation: .zero) == settings)
    #expect(GeometryCropInteraction.changed(initial: settings, imageSize: size,
        viewportWidth: 300, magnification: .nan, translation: .zero) == settings)
}

@Test func cropGesturesFollowTheFingerKeepCoverageAndClampZoom() {
    var settings = GeometrySettings(); settings.aspect = .fourFive
    let size = CGSize(width: 1200, height: 800)
    let zoomed = GeometryCropInteraction.changed(initial: settings, imageSize: size,
        viewportWidth: 320, magnification: 2, translation: .zero)
    #expect(abs(zoomed.cropZoom - 62.5) < 0.001)
    let initial = GeometryCropInteraction.rect(settings: zoomed, imageSize: size)
    let moved = GeometryCropInteraction.changed(initial: zoomed, imageSize: size,
        viewportWidth: 320, magnification: 1, translation: CGSize(width: 40, height: 50))
    let final = GeometryCropInteraction.rect(settings: moved, imageSize: size)
    #expect(final.minX < initial.minX && final.minY < initial.minY)
    #expect(abs((initial.minX - final.minX) - 40) <= 1)
    #expect(abs((initial.minY - final.minY) - 50) <= 1)
    let extreme = GeometryCropInteraction.changed(initial: zoomed, imageSize: size,
        viewportWidth: 320, magnification: 100, translation: CGSize(width: 99999, height: -99999))
    #expect(extreme.cropZoom == 80 && extreme.cropX == -100 && extreme.cropY == 100)
    #expect(CGRect(origin: .zero, size: size).contains(GeometryCropInteraction.rect(settings: extreme, imageSize: size)))
}

@Test func socialFormatsMatchRendererAndSurviveSerialization() throws {
    let size = CGSize(width: 1200, height: 800)
    let input = CIImage(color: .red).cropped(to: CGRect(origin: .zero, size: size))
    for aspect in CropAspect.allCases {
        for zoom in [0.0, 25.0, 80.0] {
            var settings = GeometrySettings()
            settings.aspect = aspect; settings.cropZoom = zoom; settings.cropX = 33; settings.cropY = -22
            let rect = GeometryCropInteraction.rect(settings: settings, imageSize: size)
            let rendered = GeometryRenderer.apply(input, settings: settings)
            #expect(rect.size == rendered.extent.size)
            #expect(CGRect(origin: .zero, size: size).contains(rect))
            #expect(try JSONDecoder().decode(GeometrySettings.self, from: JSONEncoder().encode(settings)) == settings)
            let context = settings.withoutCrop
            #expect(context.aspect == .original && context.cropZoom == 0 && context.cropX == 0 && context.cropY == 0)
        }
    }
    #expect(CropAspect.fourFive.ratio == 0.8)
    #expect(CropAspect.nineSixteen.ratio == 0.5625)
    #expect(try JSONDecoder().decode(CropAspect.self, from: Data("\"sixteenNine\"".utf8)) == .sixteenNine)
}
