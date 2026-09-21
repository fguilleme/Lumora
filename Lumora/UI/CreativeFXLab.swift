#if DEBUG
import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins
import Metal
import UniformTypeIdentifiers

/// Developer-only chart/photo comparison; never compiled into Release.
struct CreativeFXLab: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.displayScale) private var scale
    @State private var choice = "Original"
    @State private var source: Data?
    @State private var image: CGImage?
    @State private var importing = false
    @State private var native = false
    @State private var status = ""
    var body: some View {
        NavigationStack {
            VStack {
                Picker("Traitement", selection: $choice) {
                    ForEach(["Original", "High Key", "Low Key", "Grain"], id: \.self) { Text($0) }
                }.pickerStyle(.segmented)
                if let image {
                    if native {
                        ScrollView([.horizontal, .vertical]) { Image(decorative: image, scale: scale).interpolation(.none) }
                    } else { Image(decorative: image, scale: 1).resizable().scaledToFit() }
                }
                Text(status).font(.caption.monospacedDigit())
                Toggle("100 %", isOn: $native)
                HStack {
                    Button("Charger une photo") { importing = true }
                    Button("Mire") { source = nil }
                }
            }.padding().background(.black).navigationTitle("Creative FX Lab")
                .toolbar { Button("Fermer") { dismiss() } }
                .fileImporter(isPresented: $importing, allowedContentTypes: [.image]) { result in
                    do {
                        let url = try result.get()
                        let scoped = url.startAccessingSecurityScopedResource()
                        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                        source = try Data(contentsOf: url)
                    } catch { status = error.localizedDescription }
                }
                .task(id: choice + String(source?.count ?? 0)) {
                    do {
                        let data = source, mode = choice
                        let result = try await Task.detached(priority: .userInitiated) {
                            let start = ContinuousClock.now
                            let input: CIImage
                            if let data, let photo = CIImage(data: data, options: [.applyOrientationProperty: true]) {
                                let factor = min(1, 2048 / max(photo.extent.width, photo.extent.height))
                                input = photo.transformed(by: CGAffineTransform(scaleX: factor, y: factor))
                            } else { input = Self.chart() }
                            let kind: CreativeEffectKind? = mode == "High Key" ? .highKey : mode == "Low Key" ? .lowKey : mode == "Grain" ? .grain : nil
                            let output = try CreativeStackRenderer.apply(input, stack: .init(effects: kind.map { [CreativeEffect($0)] } ?? []), masks: [])
                            guard let device = MTLCreateSystemDefaultDevice(), let linear = CGColorSpace(name: CGColorSpace.extendedLinearSRGB), let display = CGColorSpace(name: CGColorSpace.displayP3) else { throw PhotoError.renderFailed }
                            let context = CIContext(mtlDevice: device, options: [.workingColorSpace: linear])
                            guard let cg = context.createCGImage(output, from: output.extent, format: .RGBA8, colorSpace: display) else { throw PhotoError.renderFailed }
                            return (cg, "\(cg.width) × \(cg.height) · \(start.duration(to: .now))")
                        }.value
                        try Task.checkCancellation(); image = result.0; status = result.1
                    } catch { status = error.localizedDescription }
                }
        }.preferredColorScheme(.dark)
    }
    nonisolated private static func chart() -> CIImage {
        let bounds = CGRect(x: 0, y: 0, width: 1536, height: 1024)
        let ramp = CIFilter.linearGradient()
        ramp.point0 = CGPoint(x: 0, y: 0); ramp.point1 = CGPoint(x: 1536, y: 0)
        ramp.color0 = CIColor(red: 0, green: 0, blue: 0); ramp.color1 = CIColor(red: 1, green: 1, blue: 1)
        var image = ramp.outputImage!.cropped(to: bounds)
        let colors: [CIColor] = [CIColor(red: 0.01, green: 0.01, blue: 0.01), CIColor(red: 0.1, green: 0.1, blue: 0.1), CIColor(red: 0.5, green: 0.5, blue: 0.5), CIColor(red: 0.95, green: 0.95, blue: 0.95), .red, .green, .blue, CIColor(red: 0.75, green: 0.45, blue: 0.3)]
        for (index, color) in colors.enumerated() {
            image = CIImage(color: color).cropped(to: CGRect(x: index*192, y: 0, width: 192, height: 400)).composited(over: image)
        }
        return image
    }
}
#endif
