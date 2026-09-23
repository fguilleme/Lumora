import SwiftUI

struct ExportView: View {
    let request: ExportRequest
    @Bindable var controller: ExportController
    @Environment(\.dismiss) private var dismiss
    @State private var originalSize = true
    @State private var maximumDimension = 4096

    var body: some View {
        NavigationStack {
            Form {
                Section("Image") {
                    Text(request.name).font(.subheadline).foregroundStyle(.secondary)
                    Picker("Format", selection: $controller.settings.format) {
                        ForEach(ExportFormat.available) { format in Text(format.title).tag(format) }
                    }.accessibilityIdentifier("export-format")
                    if controller.settings.format.supportsQuality {
                        HStack {
                            Text("Quality")
                            Slider(value: $controller.settings.quality, in: 0.1...1, step: 0.01)
                                .accessibilityLabel("Export quality")
                            Text(controller.settings.quality, format: .percent.precision(.fractionLength(0)))
                                .monospacedDigit()
                        }
                    }
                    Picker("Color space", selection: $controller.settings.colorSpace) {
                        ForEach(ExportColorSpace.allCases) { space in Text(space.title).tag(space) }
                    }
                }.disabled(controller.isExporting)
                Section {
                    Toggle("Original dimensions", isOn: $originalSize)
                    if !originalSize {
                        Picker("Long edge", selection: $maximumDimension) {
                            ForEach([1024, 2048, 3000, 4096, 6000, 8000], id: \.self) { size in
                                Text("\(size) px").tag(size).accessibilityIdentifier("export-size-\(size)")
                            }
                        }.accessibilityIdentifier("export-dimension")
                    }
                } header: { Text("Dimensions") } footer: {
                    Text("Aspect ratio is preserved. Small images are never enlarged.")
                }.disabled(controller.isExporting)
                Section {
                    Toggle("Keep metadata", isOn: $controller.settings.includeMetadata)
                    Toggle("Remove location", isOn: $controller.settings.removeLocation)
                        .disabled(!controller.settings.includeMetadata)
                } header: { Text("Metadata") } footer: {
                    Text("Keeps EXIF capture information and standard TIFF fields when supported by the format. GPS data is removed by default. Proprietary blocks, XMP and IPTC are not copied.")
                }.disabled(controller.isExporting)
                Section {
                    if controller.isExporting {
                        ProgressView(value: controller.stage.fraction) {
                            Text(controller.isCancelling ? "Cancelling…" : controller.stage.title)
                        }
                        Text("Progress is reported by stage. A running GPU operation or encoding step must finish before cancellation.")
                            .font(.caption).foregroundStyle(.secondary)
                        Button("Cancel export", role: .cancel, action: controller.cancel).disabled(controller.isCancelling)
                    } else {
                        Button("Create file") {
                            controller.settings.maximumDimension = originalSize ? nil : maximumDimension
                            controller.start(request)
                        }.accessibilityIdentifier("export-create")
                    }
                    if let result = controller.result {
                        Label("Export complete", systemImage: "checkmark.circle.fill").foregroundStyle(.mint)
                        Text("\(result.width) × \(result.height) · \(ByteCountFormatter.string(fromByteCount: Int64(result.byteCount), countStyle: .file))")
                            .font(.subheadline).accessibilityIdentifier("export-result")
                        ShareLink(item: result.url) {
                            Label("Share or save…", systemImage: "square.and.arrow.up")
                        }.accessibilityIdentifier("export-share")
                        Text("Use Share to save the file to Files or another destination before closing this screen.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .accessibilityIdentifier("export-options")
            .navigationTitle("Export")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Close") { dismiss() }.disabled(controller.isExporting)
                }
            }
            .interactiveDismissDisabled(controller.isExporting)
            .alert("Export failed", isPresented: Binding(get: { controller.error != nil }, set: { if !$0 { controller.error = nil } })) {
                Button("OK") { controller.error = nil }
            } message: { Text(controller.error ?? "") }
        }
        .onChange(of: controller.settings) { _, _ in controller.discardResult() }
        .onChange(of: originalSize) { _, _ in controller.discardResult() }
        .onChange(of: maximumDimension) { _, _ in controller.discardResult() }
        .tint(.mint).preferredColorScheme(.dark)
    }
}
