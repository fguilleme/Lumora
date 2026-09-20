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
                            Text("Qualité")
                            Slider(value: $controller.settings.quality, in: 0.1...1, step: 0.01)
                                .accessibilityLabel("Qualité de l’export")
                            Text(controller.settings.quality, format: .percent.precision(.fractionLength(0)))
                                .monospacedDigit()
                        }
                    }
                    Picker("Espace couleur", selection: $controller.settings.colorSpace) {
                        ForEach(ExportColorSpace.allCases) { space in Text(space.title).tag(space) }
                    }
                }.disabled(controller.isExporting)
                Section {
                    Toggle("Dimensions originales", isOn: $originalSize)
                    if !originalSize {
                        Picker("Grand côté", selection: $maximumDimension) {
                            ForEach([1024, 2048, 3000, 4096, 6000, 8000], id: \.self) { size in
                                Text("\(size) px").tag(size).accessibilityIdentifier("export-size-\(size)")
                            }
                        }.accessibilityIdentifier("export-dimension")
                    }
                } header: { Text("Dimensions") } footer: {
                    Text("Le ratio est conservé. Une petite image n’est jamais agrandie.")
                }.disabled(controller.isExporting)
                Section {
                    Toggle("Conserver les métadonnées", isOn: $controller.settings.includeMetadata)
                    Toggle("Supprimer la localisation", isOn: $controller.settings.removeLocation)
                        .disabled(!controller.settings.includeMetadata)
                } header: { Text("Métadonnées") } footer: {
                    Text("Conserve les informations EXIF de prise de vue et les champs TIFF usuels lorsque le format le permet. Les données GPS sont supprimées par défaut. Les blocs propriétaires, XMP et IPTC ne sont pas recopiés.")
                }.disabled(controller.isExporting)
                Section {
                    if controller.isExporting {
                        ProgressView(value: controller.stage.fraction) {
                            Text(controller.isCancelling ? "Annulation en cours…" : controller.stage.title)
                        }
                        Text("Progression par étapes. Un calcul GPU ou un encodage déjà lancé doit se terminer avant l’annulation.")
                            .font(.caption).foregroundStyle(.secondary)
                        Button("Annuler l’export", role: .cancel, action: controller.cancel).disabled(controller.isCancelling)
                    } else {
                        Button("Créer le fichier") {
                            controller.settings.maximumDimension = originalSize ? nil : maximumDimension
                            controller.start(request)
                        }.accessibilityIdentifier("export-create")
                    }
                    if let result = controller.result {
                        Label("Export terminé", systemImage: "checkmark.circle.fill").foregroundStyle(.mint)
                        Text("\(result.width) × \(result.height) · \(ByteCountFormatter.string(fromByteCount: Int64(result.byteCount), countStyle: .file))")
                            .font(.subheadline).accessibilityIdentifier("export-result")
                        ShareLink(item: result.url) {
                            Label("Partager ou enregistrer…", systemImage: "square.and.arrow.up")
                        }.accessibilityIdentifier("export-share")
                        Text("Utilisez le partage pour enregistrer le fichier dans Fichiers ou une autre destination avant de fermer cet écran.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .accessibilityIdentifier("export-options")
            .navigationTitle("Exporter")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fermer") { dismiss() }.disabled(controller.isExporting)
                }
            }
            .interactiveDismissDisabled(controller.isExporting)
            .alert("Export impossible", isPresented: Binding(get: { controller.error != nil }, set: { if !$0 { controller.error = nil } })) {
                Button("OK") { controller.error = nil }
            } message: { Text(controller.error ?? "") }
        }
        .onChange(of: controller.settings) { _, _ in controller.discardResult() }
        .onChange(of: originalSize) { _, _ in controller.discardResult() }
        .onChange(of: maximumDimension) { _, _ in controller.discardResult() }
        .tint(.mint).preferredColorScheme(.dark)
    }
}
