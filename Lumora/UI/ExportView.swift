import SwiftUI

struct ExportView: View {
    let request: ExportRequest
    @Bindable var controller: ExportController
    let engine: RenderEngine
    let directlyToPhotos: Bool
    let includeMetadataByDefault: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var originalSize: Bool
    @State private var maximumDimension: Int
    @State private var didStart = false
    @AppStorage("export.photosAlbumName") private var photosAlbumName = ""

    init(request: ExportRequest, controller: ExportController, engine: RenderEngine, directlyToPhotos: Bool,
         includeMetadataByDefault: Bool) {
        self.request = request
        self.controller = controller
        self.engine = engine
        self.directlyToPhotos = directlyToPhotos
        self.includeMetadataByDefault = includeMetadataByDefault
        let dimension = controller.settings.maximumDimension
        _originalSize = State(initialValue: dimension == nil)
        _maximumDimension = State(initialValue: dimension ?? 4096)
    }

    private var showsAlbumField: Bool {
        !directlyToPhotos || (!controller.isSavingToPhotos && controller.photosSaveMessage == nil)
    }

    var body: some View {
        NavigationStack {
            Form {
                if !directlyToPhotos {
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
                    }.disabled(controller.isBusy)
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
                    }.disabled(controller.isBusy)
                    Section {
                        Toggle("Keep metadata", isOn: $controller.settings.includeMetadata)
                        Toggle("Remove location", isOn: $controller.settings.removeLocation)
                            .disabled(!controller.settings.includeMetadata)
                    } header: { Text("Metadata") } footer: {
                        Text("Keeps EXIF capture information and standard TIFF fields when supported by the format. GPS data is removed by default. Proprietary blocks, XMP and IPTC are not copied.")
                    }.disabled(controller.isBusy)
                }
                Section {
                    if controller.isExporting {
                        ProgressView(value: controller.stage.fraction) {
                            AnimatedLoadingMessage(controller.isCancelling ? String(localized: "Cancelling…") : controller.stage.title, compact: true)
                        }
                        Text("Progress is reported by stage. A running GPU operation or encoding step must finish before cancellation.")
                            .font(.caption).foregroundStyle(.secondary)
                        Button("Cancel export", role: .cancel, action: controller.cancel).disabled(controller.isCancelling)
                    } else if !controller.isSavingToPhotos && (!directlyToPhotos || controller.result == nil) {
                        Button(directlyToPhotos ? LocalizedStringKey("Export to Photos") : "Create file") { start() }
                            .accessibilityIdentifier("export-create")
                    }
                    if let result = controller.result {
                        Label("Export complete", systemImage: "checkmark.circle.fill").foregroundStyle(.mint)
                        Text("\(result.width) × \(result.height) · \(ByteCountFormatter.string(fromByteCount: Int64(result.byteCount), countStyle: .file))")
                            .font(.subheadline).accessibilityIdentifier("export-result")
                        if !directlyToPhotos || showsAlbumField {
                            ShareLink(item: result.url) {
                                Label("Share or save…", systemImage: "square.and.arrow.up")
                            }.accessibilityIdentifier("export-share")
                                .disabled(controller.isSavingToPhotos)
                            Text("Save to Photos below, or use Share to save the file to Files or another destination before closing this screen.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                if controller.result != nil {
                    Section {
                        if showsAlbumField {
                            TextField("Album name (optional)", text: $photosAlbumName)
                                .autocorrectionDisabled()
                                .submitLabel(.done)
                                .accessibilityIdentifier("export-photos-album")
                                .disabled(controller.isSavingToPhotos || controller.photosSaveMessage != nil)
                        }
                        if controller.isSavingToPhotos {
                            AnimatedLoadingMessage("Saving to Photos…", compact: true)
                        } else if let message = controller.photosSaveMessage {
                            Label(message, systemImage: "checkmark.circle.fill").foregroundStyle(.mint)
                                .accessibilityIdentifier("export-photos-saved")
                        } else {
                            Button {
                                let albumName = photosAlbumName
                                Task { await controller.saveToPhotos(albumName: albumName) }
                            } label: { Label("Save to Photos", systemImage: "photo.badge.arrow.down") }
                            .disabled(controller.isExporting)
                            .accessibilityIdentifier("export-save-photos")
                        }
                    } header: { Text("Photos") } footer: {
                        if showsAlbumField {
                            Text("Leave empty to save to the library. An existing album is reused; otherwise it is created. The last album name is remembered. Albums require Full Access to Photos.")
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .accessibilityIdentifier("export-options")
            .navigationTitle(directlyToPhotos ? LocalizedStringKey("Export to Photos") : "Export")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Close") { dismiss() }.disabled(controller.isBusy)
                }
            }
            .interactiveDismissDisabled(controller.isBusy)
            .alert("Export failed", isPresented: Binding(get: { controller.error != nil }, set: { if !$0 { controller.error = nil } })) {
                if let maximum = controller.suggestedMaximumDimension {
                    Button(String(format: String(localized: "Export up to %@ px"), maximum.formatted())) {
                        start(maximumDimension: maximum)
                    }
                    Button("Cancel", role: .cancel) { controller.error = nil }
                } else {
                    Button("OK") { controller.error = nil }
                }
            } message: { Text(controller.error ?? "") }
            .alert("Unable to save to Photos", isPresented: Binding(get: { controller.photosError != nil }, set: { if !$0 { controller.photosError = nil } })) {
                Button("OK") { controller.photosError = nil }
            } message: { Text(controller.photosError ?? "") }
        }
        .onAppear {
            guard directlyToPhotos, !didStart else { return }
            didStart = true
            start()
        }
        .onChange(of: controller.settings) { _, _ in controller.discardResult() }
        .onChange(of: originalSize) { _, _ in controller.discardResult() }
        .onChange(of: maximumDimension) { _, _ in controller.discardResult() }
        .tint(.mint).preferredColorScheme(.dark)
    }

    private func start(maximumDimension override: Int? = nil) {
        if directlyToPhotos {
            controller.startToPhotos(request, using: engine, albumName: photosAlbumName,
                                     includeMetadataByDefault: includeMetadataByDefault, maximumDimension: override)
        } else {
            if let override {
                originalSize = false
                maximumDimension = override
            }
            controller.settings.maximumDimension = originalSize ? nil : maximumDimension
            controller.start(request, using: engine)
        }
    }
}
