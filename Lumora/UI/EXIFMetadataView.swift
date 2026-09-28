import SwiftUI
import ImageIO
import UniformTypeIdentifiers

struct EXIFMetadataView: View {
    let sourceURL: URL?
    @State private var snapshot: EXIFMetadataSnapshot?
    @State private var failed = false

    var body: some View {
        Group {
            if let snapshot {
                List {
                    ForEach(snapshot.sections) { section in
                        Section(section.title) {
                            ForEach(section.rows) { row in
                                LabeledContent(row.label) {
                                    Text(row.value)
                                        .multilineTextAlignment(.trailing)
                                        .textSelection(.enabled)
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            } else if failed {
                ContentUnavailableView("No metadata", systemImage: "info.circle",
                                       description: Text("This image does not expose readable EXIF metadata."))
            } else {
                ProgressView("Reading metadata…")
            }
        }
        .accessibilityIdentifier("exif-controls")
        .task(id: sourceURL) {
            snapshot = nil; failed = false
            guard let sourceURL else { failed = true; return }
            snapshot = await Task.detached { EXIFMetadataSnapshot.read(from: sourceURL) }.value
            failed = snapshot == nil
        }
    }
}

struct EXIFMetadataSnapshot: Sendable, Equatable {
    struct Row: Sendable, Equatable, Identifiable {
        let label: String
        let value: String
        var id: String { label }
    }
    struct Section: Sendable, Equatable, Identifiable {
        let title: String
        let rows: [Row]
        var id: String { title }
    }
    let sections: [Section]

    static func read(from url: URL) -> Self? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        else { return nil }
        let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any] ?? [:]
        let tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any] ?? [:]
        let gps = properties[kCGImagePropertyGPSDictionary] as? [CFString: Any] ?? [:]
        let width = number(properties[kCGImagePropertyPixelWidth]).map { Int($0) }
        let height = number(properties[kCGImagePropertyPixelHeight]).map { Int($0) }
        let type = CGImageSourceGetType(source).flatMap { UTType(String($0)) }

        var fileRows = [Row("File", url.lastPathComponent)]
        if let type { fileRows.append(Row("Format", type.localizedDescription ?? type.identifier)) }
        if let width, let height { fileRows.append(Row("Dimensions", "\(width) × \(height) px")) }
        if let bytes = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize {
            fileRows.append(Row("File size", ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)))
        }
        if let profile = properties[kCGImagePropertyProfileName] as? String { fileRows.append(Row("Color profile", profile)) }

        var camera: [Row] = []
        append("Manufacturer", tiff[kCGImagePropertyTIFFMake], to: &camera)
        append("Camera", tiff[kCGImagePropertyTIFFModel], to: &camera)
        append("Lens", exif[kCGImagePropertyExifLensModel], to: &camera)
        if let focal = number(exif[kCGImagePropertyExifFocalLength]) { camera.append(Row("Focal length", decimal(focal, suffix: " mm"))) }
        if let focal35 = number(exif[kCGImagePropertyExifFocalLenIn35mmFilm]) { camera.append(Row("35 mm equivalent", decimal(focal35, suffix: " mm"))) }

        var capture: [Row] = []
        append("Date captured", exif[kCGImagePropertyExifDateTimeOriginal] ?? tiff[kCGImagePropertyTIFFDateTime], to: &capture)
        if let exposure = number(exif[kCGImagePropertyExifExposureTime]) { capture.append(Row("Exposure time", exposureText(exposure))) }
        if let aperture = number(exif[kCGImagePropertyExifFNumber]) { capture.append(Row("Aperture", "f/" + decimal(aperture))) }
        if let iso = isoValue(exif[kCGImagePropertyExifISOSpeedRatings]) { capture.append(Row("ISO", decimal(iso))) }
        if let bias = number(exif[kCGImagePropertyExifExposureBiasValue]) { capture.append(Row("Exposure bias", signed(bias, suffix: " EV"))) }
        if let flash = number(exif[kCGImagePropertyExifFlash]) {
            capture.append(Row("Flash", NSLocalizedString(Int(flash) & 1 == 1 ? "Fired" : "Did not fire", comment: "EXIF flash value")))
        }
        if let whiteBalance = number(exif[kCGImagePropertyExifWhiteBalance]) {
            capture.append(Row("White balance", NSLocalizedString(Int(whiteBalance) == 1 ? "Manual" : "Automatic", comment: "EXIF white balance value")))
        }

        var location: [Row] = []
        if let latitude = coordinate(gps[kCGImagePropertyGPSLatitude], reference: gps[kCGImagePropertyGPSLatitudeRef]),
           let longitude = coordinate(gps[kCGImagePropertyGPSLongitude], reference: gps[kCGImagePropertyGPSLongitudeRef]) {
            location.append(Row("Coordinates", String(format: "%.5f, %.5f", latitude, longitude)))
        }
        if let altitude = number(gps[kCGImagePropertyGPSAltitude]) { location.append(Row("Altitude", decimal(altitude, suffix: " m"))) }

        var authorship: [Row] = []
        append("Artist", tiff[kCGImagePropertyTIFFArtist], to: &authorship)
        append("Copyright", tiff[kCGImagePropertyTIFFCopyright], to: &authorship)
        append("Software", tiff[kCGImagePropertyTIFFSoftware], to: &authorship)

        let groups: [(String, [Row])] = [("File", fileRows), ("Camera", camera), ("Capture", capture),
                                         ("Location", location), ("Authorship", authorship)]
        return Self(sections: groups.compactMap {
            $0.1.isEmpty ? nil : Section(title: NSLocalizedString($0.0, comment: "EXIF metadata section"), rows: $0.1)
        })
    }

    private static func append(_ label: String, _ value: Any?, to rows: inout [Row]) {
        if let value = value as? String, !value.isEmpty { rows.append(Row(label, value.trimmingCharacters(in: .whitespacesAndNewlines))) }
    }
    private static func number(_ value: Any?) -> Double? {
        if let value = value as? NSNumber { return value.doubleValue }
        if let value = value as? Double { return value }
        if let value = value as? Int { return Double(value) }
        return nil
    }
    private static func isoValue(_ value: Any?) -> Double? {
        if let array = value as? [NSNumber] { return array.first?.doubleValue }
        return number(value)
    }
    private static func coordinate(_ value: Any?, reference: Any?) -> Double? {
        guard var result = number(value) else { return nil }
        if let ref = reference as? String, ref == "S" || ref == "W" { result = -result }
        return result
    }
    private static func decimal(_ value: Double, suffix: String = "") -> String {
        let digits = value.rounded() == value ? 0 : 1
        return String(format: "%.*f", digits, value) + suffix
    }
    private static func signed(_ value: Double, suffix: String) -> String {
        String(format: "%+.1f", value) + suffix
    }
    private static func exposureText(_ value: Double) -> String {
        if value > 0, value < 1 { return "1/\(Int((1 / value).rounded())) s" }
        return decimal(value, suffix: " s")
    }
}

private extension EXIFMetadataSnapshot.Row {
    init(_ label: String, _ value: String) {
        self.label = NSLocalizedString(label, comment: "EXIF metadata label")
        self.value = value
    }
}
