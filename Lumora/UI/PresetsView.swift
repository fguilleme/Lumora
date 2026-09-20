import SwiftUI
import UniformTypeIdentifiers

struct PresetsView: View {
    @Bindable var controller: PresetController
    let state: EditState
    let onApply: (Preset) -> Void
    @State private var showingCreate = false
    @State private var createName = ""
    @State private var selectedSections = PresetSection.photographicDefaults
    @State private var renamePreset: Preset?
    @State private var renameName = ""
    @State private var showingImporter = false
    @State private var showingExporter = false
    @State private var exportDocument: PresetFileDocument?
    @State private var exportName = "Preset Lumora"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Mes presets").font(.headline)
                    Spacer()
                    Button { showingImporter = true } label: { Label("Importer", systemImage: "square.and.arrow.down") }
                        .accessibilityIdentifier("preset-import")
                    Button { createName = ""; selectedSections = PresetSection.photographicDefaults; showingCreate = true } label: {
                        Label("Créer", systemImage: "plus.circle")
                    }.accessibilityIdentifier("preset-create")
                }
                if controller.isLoading { ProgressView("Chargement…") }
                else if controller.presets.isEmpty {
                    ContentUnavailableView("Aucun preset", systemImage: "slider.horizontal.2.square",
                                           description: Text("Enregistrez les réglages actuels, puis appliquez-les à d’autres photos."))
                } else {
                    ForEach(controller.presets) { preset in
                        presetRow(preset)
                    }
                }
            }.padding(.horizontal, 18).padding(.bottom, 12)
        }
        .accessibilityIdentifier("presets-controls")
        .sheet(isPresented: $showingCreate) { createSheet }
        .alert("Renommer le preset", isPresented: Binding(get: { renamePreset != nil }, set: { if !$0 { renamePreset = nil } })) {
            TextField("Nom", text: $renameName)
            Button("Annuler", role: .cancel) { renamePreset = nil }
            Button("Renommer") {
                if let preset = renamePreset { Task { await controller.rename(preset, to: renameName) } }
                renamePreset = nil
            }.disabled(renameName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .alert("Impossible de gérer le preset", isPresented: Binding(get: { controller.error != nil }, set: { if !$0 { controller.error = nil } })) {
            Button("OK") { controller.error = nil }
        } message: { Text(controller.error ?? "") }
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.json], allowsMultipleSelection: false) { result in
            if case .success(let urls) = result, let url = urls.first { Task { await controller.importPreset(from: url) } }
            else if case .failure(let error) = result { controller.error = error.localizedDescription }
        }
        .fileExporter(isPresented: $showingExporter, document: exportDocument,
                      contentType: .json, defaultFilename: exportName) { result in
            if case .failure(let error) = result { controller.error = error.localizedDescription }
            exportDocument = nil
        }
    }

    private func presetRow(_ preset: Preset) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(preset.name).font(.subheadline.weight(.semibold)).lineLimit(1)
                Text(preset.sections.sorted { $0.rawValue < $1.rawValue }.map(\.title).joined(separator: " · "))
                    .font(.caption2).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer()
            Button("Appliquer") { onApply(preset) }
                .buttonStyle(.borderedProminent).accessibilityIdentifier("preset-apply-\(preset.id)")
            Menu {
                Button("Renommer", systemImage: "pencil") { renamePreset = preset; renameName = preset.name }
                Button("Exporter", systemImage: "square.and.arrow.up") { prepareExport(preset) }
                Button("Supprimer", systemImage: "trash", role: .destructive) { Task { await controller.delete(preset) } }
            } label: { Image(systemName: "ellipsis.circle").frame(width: 44, height: 44) }
                .accessibilityLabel("Options de \(preset.name)")
        }.padding(10).background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 12))
    }

    private var createSheet: some View {
        NavigationStack {
            List {
                Section("Nom") { TextField("Nom du preset", text: $createName).accessibilityIdentifier("preset-name") }
                Section("Réglages inclus") {
                    ForEach(PresetSection.allCases) { section in
                        Toggle(section.title, isOn: Binding(
                            get: { selectedSections.contains(section) },
                            set: { included in
                                if included { selectedSections.insert(section) } else { selectedSections.remove(section) }
                            }))
                        .accessibilityIdentifier("preset-section-\(section.rawValue)")
                    }
                }
            }
            .navigationTitle("Nouveau preset").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler") { showingCreate = false } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        let name = createName; let sections = selectedSections
                        showingCreate = false
                        Task { await controller.create(name: name, sections: sections, state: state) }
                    }
                    .disabled(createName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedSections.isEmpty)
                    .accessibilityIdentifier("preset-save")
                }
            }
        }
    }

    private func prepareExport(_ preset: Preset) {
        do {
            exportDocument = try PresetFileDocument(preset: preset)
            exportName = preset.name.replacingOccurrences(of: "/", with: "-") + ".lumorapreset"
            showingExporter = true
        } catch { controller.error = error.localizedDescription }
    }
}
