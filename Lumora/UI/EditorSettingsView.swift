import SwiftUI

struct EditorSettingsView: View {
    let session: EditorSession
    @Binding var showHistogram: Bool
    @Binding var includeMetadataInExport: Bool
    @Binding var tabOrder: String
    @Binding var hiddenTabs: String
    private var tabs: [EditorPanel] { EditorTabPreferences.ordered(tabOrder) }
    var body: some View {
        List {
            Section {
                Toggle("Show histogram", isOn: $showHistogram)
                    .accessibilityIdentifier("settings-histogram")
            } header: { Text("Display") }
            Section {
                Toggle("Include metadata in exports", isOn: $includeMetadataInExport)
                    .accessibilityIdentifier("settings-export-metadata")
            } header: { Text("Export") } footer: {
                Text("Sets the default for new exports. It can still be changed for an individual export; location remains removed by default.")
            }
            Section {
                Toggle(isOn: Binding(
                    get: { session.iCloudSyncEnabled },
                    set: { enabled in Task { await session.setICloudSyncEnabled(enabled) } }
                )) {
                    Label("Sync library with iCloud Drive", systemImage: "icloud")
                }
                .disabled(session.isChangingDocumentStorage)
                .accessibilityIdentifier("settings-icloud-sync")
                HStack {
                    Label(session.iCloudSyncEnabled ? "iCloud Drive" : "On My iPhone or iPad",
                          systemImage: session.iCloudSyncEnabled ? "icloud.fill" : "iphone")
                        .foregroundStyle(.secondary)
                    Spacer()
                    if session.isChangingDocumentStorage { ProgressView().controlSize(.small) }
                }
            } header: { Text("Library") } footer: {
                Text("The Lumora folder is stored in Documents. iCloud sync is off by default; enabling it moves the library to iCloud Drive so it can appear on your other devices.")
            }
            Section {
                ForEach(tabs, id: \.self) { tab in
                    HStack {
                        Image(systemName: tab.symbol).foregroundStyle(.mint).frame(width: 24).accessibilityHidden(true)
                        if tab == .settings {
                            Text(tab.title); Spacer()
                            Text("Always visible").font(.caption).foregroundStyle(.secondary)
                        } else {
                            Text(tab.title)
                            Spacer()
                            let visible = !EditorTabPreferences.hidden(hiddenTabs).contains(tab.rawValue)
                            Button {
                                var hidden = EditorTabPreferences.hidden(hiddenTabs)
                                if visible { hidden.insert(tab.rawValue) } else { hidden.remove(tab.rawValue) }
                                hiddenTabs = EditorTabPreferences.encode(hidden.sorted())
                            } label: {
                                Image(systemName: visible ? "eye" : "eye.slash")
                                    .frame(width: 44, height: 44)
                                    .foregroundStyle(visible ? .mint : .secondary)
                            }.buttonStyle(.borderless)
                                .accessibilityLabel(tab.title)
                                .accessibilityValue(visible ? String(localized: "Visible") : String(localized: "Hidden"))
                                .accessibilityIdentifier("settings-visible-\(tab.rawValue)")
                        }
                    }.listRowBackground(Color.clear)
                }.onMove { indices, destination in
                    var order = tabs
                    order.move(fromOffsets: indices, toOffset: destination)
                    tabOrder = EditorTabPreferences.encode(order.map(\.rawValue))
                }
            } header: { Text("Editor tabs") } footer: {
                Text("Drag the handles to reorder tabs. Hiding a tab keeps its photo adjustments active. Settings stays visible so you can restore any tab.")
            }
            Section {
                Button("Restore interface defaults") {
                    showHistogram = true; includeMetadataInExport = true; tabOrder = ""; hiddenTabs = ""
                }.accessibilityIdentifier("settings-reset")
            } footer: { Text("These preferences apply to the app, not to individual photos.") }
        }
        .listStyle(.insetGrouped).scrollContentBackground(.hidden)
        .environment(\.editMode, .constant(.active))
        .accessibilityIdentifier("editor-settings")
    }
}
