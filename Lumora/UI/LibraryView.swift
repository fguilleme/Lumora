import SwiftUI
import ImageIO

struct LibraryView: View {
    @Bindable var session: EditorSession
    @Environment(\.dismiss) private var dismiss
    @State private var pendingDeletion: LibraryDocument?
    @State private var search = ""
    @State private var sort = LibrarySortOrder.newest
    @State private var scope = LibraryScope.all
    @State private var showingFolders = false
    @State private var showingTags = false
    @State private var isSelecting = false
    @State private var selection: Set<UUID> = []
    @State private var showingBatchDeletion = false

    private var effectiveScope: LibraryScope {
        if case let .folder(id) = scope, !session.libraryFolders.contains(where: { $0.id == id }) { return .all }
        if case let .tag(id) = scope, !session.libraryTags.contains(where: { $0.id == id }) { return .all }
        return scope
    }

    private var visibleDocuments: [LibraryDocument] {
        LibraryQuery.results(session.libraryDocuments, search: search, sort: sort, scope: effectiveScope)
    }

    private var scopeTitle: String {
        switch effectiveScope {
        case .all: "Toutes"
        case .favorites: "Favoris"
        case let .folder(id): session.libraryFolders.first(where: { $0.id == id })?.name ?? "Toutes"
        case let .tag(id): session.libraryTags.first(where: { $0.id == id })?.name ?? "Toutes"
        }
    }

    private var scopeSymbol: String {
        switch effectiveScope {
        case .all: "photo.stack"
        case .favorites: "star"
        case .folder: "folder"
        case .tag: "tag"
        }
    }

    private var visibleDocumentIDs: Set<UUID> { Set(visibleDocuments.map(\.id)) }

    private var navigationTitle: String {
        guard isSelecting else { return "Bibliothèque" }
        return selection.isEmpty ? "Sélectionner" : "\(selection.count) sélectionnée\(selection.count > 1 ? "s" : "")"
    }

    var body: some View {
        NavigationStack {
            Group {
                if session.isLoadingLibrary {
                    ProgressView("Chargement de la bibliothèque…")
                } else if session.libraryDocuments.isEmpty {
                    ContentUnavailableView("Bibliothèque vide", systemImage: "photo.stack",
                                           description: Text("Importez une photo pour créer un développement local."))
                } else if visibleDocuments.isEmpty {
                    if search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        ContentUnavailableView("Aucune photo", systemImage: "folder",
                                               description: Text("Ce dossier ou cette sélection est vide."))
                    } else {
                        ContentUnavailableView.search(text: search)
                    }
                } else {
                    List(visibleDocuments) { entry in libraryRow(entry) }
                        .listStyle(.plain)
                        .refreshable { await session.loadLibrary() }
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if isSelecting {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(selection == visibleDocumentIDs ? "Aucune" : "Toutes") {
                            selection = selection == visibleDocumentIDs ? [] : visibleDocumentIDs
                        }
                        .accessibilityIdentifier("library-select-all")
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Terminé") { endSelection() }
                    }
                    ToolbarItemGroup(placement: .bottomBar) {
                        batchActions
                    }
                } else {
                    ToolbarItemGroup(placement: .topBarLeading) {
                        Menu {
                            Button("Toutes", systemImage: "photo.stack") { scope = .all }
                            Button("Favoris", systemImage: "star") { scope = .favorites }
                            if !session.libraryFolders.isEmpty {
                                Section("Dossiers") {
                                    ForEach(session.libraryFolders) { folder in
                                        Button(folder.name, systemImage: "folder") { scope = .folder(folder.id) }
                                    }
                                }
                            }
                            if !session.libraryTags.isEmpty {
                                Section("Étiquettes") {
                                    ForEach(session.libraryTags) { tag in
                                        Button(tag.name, systemImage: "tag") { scope = .tag(tag.id) }
                                    }
                                }
                            }
                            Divider()
                            Button("Gérer les dossiers…", systemImage: "folder.badge.gearshape") {
                                showingFolders = true
                            }
                            Button("Gérer les étiquettes…", systemImage: "tag") {
                                showingTags = true
                            }
                        } label: { Label(scopeTitle, systemImage: scopeSymbol) }
                        .accessibilityIdentifier("library-scope")

                        Menu {
                            Picker("Tri", selection: $sort) {
                                ForEach(LibrarySortOrder.allCases) { order in Text(order.title).tag(order) }
                            }
                        } label: { Label("Trier", systemImage: "arrow.up.arrow.down") }
                        .accessibilityIdentifier("library-sort")
                    }
                    ToolbarItemGroup(placement: .confirmationAction) {
                        Button("Sélectionner") {
                            isSelecting = true
                            selection.removeAll()
                        }
                        .accessibilityIdentifier("library-select")
                        Button("Fermer") { dismiss() }
                    }
                }
            }
        }
        .searchable(text: $search, prompt: "Rechercher une photo")
        .task { await session.loadLibrary() }
        .sheet(isPresented: $showingFolders) { LibraryFoldersView(session: session) }
        .sheet(isPresented: $showingTags) { LibraryTagsView(session: session) }
        .onChange(of: visibleDocumentIDs) { _, ids in selection.formIntersection(ids) }
        .confirmationDialog("Supprimer ce développement ?", isPresented: Binding(
            get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } }),
                            titleVisibility: .visible) {
            Button("Supprimer définitivement", role: .destructive) {
                guard let entry = pendingDeletion else { return }
                pendingDeletion = nil
                Task { await session.deleteDocument(entry.id) }
            }
            Button("Annuler", role: .cancel) { pendingDeletion = nil }
        } message: {
            Text("L’original privé et toutes ses retouches seront supprimés de Lumora.")
        }
        .confirmationDialog("Supprimer \(selection.count) développement\(selection.count > 1 ? "s" : "") ?",
                            isPresented: $showingBatchDeletion, titleVisibility: .visible) {
            Button("Supprimer définitivement", role: .destructive) {
                let ids = selection
                endSelection()
                Task { await session.deleteDocuments(ids) }
            }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Les originaux privés et toutes leurs retouches seront supprimés de Lumora.")
        }
    }

    private func libraryRow(_ entry: LibraryDocument) -> some View {
        Group {
            if isSelecting {
                Button {
                    if selection.contains(entry.id) { selection.remove(entry.id) }
                    else { selection.insert(entry.id) }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: selection.contains(entry.id) ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(selection.contains(entry.id) ? Color.accentColor : Color.secondary)
                        libraryRowContent(entry)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("library-selection-row")
                .accessibilityValue(selection.contains(entry.id) ? "Sélectionnée" : "Non sélectionnée")
            } else {
                standardLibraryRow(entry)
            }
        }
        .padding(.vertical, 4)
    }

    private func standardLibraryRow(_ entry: LibraryDocument) -> some View {
        HStack(spacing: 12) {
            Button {
                Task {
                    await session.openDocument(entry.id)
                    if session.document?.id == entry.id { dismiss() }
                }
            } label: {
                libraryRowContent(entry)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("library-document-row")
            .accessibilityHint("Ouvre ce développement")

            Button {
                Task { await session.toggleFavorite(entry.id) }
            } label: {
                Image(systemName: entry.isFavorite ? "star.fill" : "star")
                    .frame(width: 44, height: 44)
            }
            .foregroundStyle(entry.isFavorite ? .yellow : .secondary)
            .accessibilityLabel(entry.isFavorite ? "Retirer des favoris" : "Ajouter aux favoris")
            .accessibilityValue(entry.isFavorite ? "Favori" : "Non favori")
            .accessibilityIdentifier("library-favorite-button")

            Menu {
                Menu("Déplacer vers", systemImage: "folder") {
                    Button("Sans dossier", systemImage: "tray") {
                        Task { await session.setLibraryFolder(nil, for: entry.id) }
                    }
                    ForEach(session.libraryFolders) { folder in
                        Button(folder.name, systemImage: entry.folderID == folder.id ? "checkmark" : "folder") {
                            Task { await session.setLibraryFolder(folder.id, for: entry.id) }
                        }
                    }
                }
                if !session.libraryTags.isEmpty {
                    Menu("Étiquettes", systemImage: "tag") {
                        ForEach(session.libraryTags) { tag in
                            Button(tag.name,
                                   systemImage: entry.tagIDs.contains(tag.id) ? "checkmark.circle.fill" : "circle") {
                                Task { await session.toggleLibraryTag(tag.id, for: entry.id) }
                            }
                        }
                    }
                }
                Button("Supprimer", systemImage: "trash", role: .destructive) {
                    pendingDeletion = entry
                }
            } label: {
                Image(systemName: "ellipsis.circle").frame(width: 44, height: 44)
            }
            .accessibilityLabel("Options de \(entry.document.originalName)")
        }
    }

    private func libraryRowContent(_ entry: LibraryDocument) -> some View {
        HStack(spacing: 12) {
            LibraryThumbnailView(url: entry.originalURL)
            VStack(alignment: .leading, spacing: 5) {
                Text(entry.document.originalName)
                    .font(.subheadline.weight(.semibold)).lineLimit(1)
                Text(entry.document.createdAt, format: .dateTime.day().month(.abbreviated).year().hour().minute())
                    .font(.caption).foregroundStyle(.secondary)
                if session.document?.id == entry.id {
                    Label("Ouvert", systemImage: "checkmark.circle.fill")
                        .font(.caption2.weight(.medium)).foregroundStyle(.mint)
                }
                if let folderID = entry.folderID,
                   let folder = session.libraryFolders.first(where: { $0.id == folderID }) {
                    Label(folder.name, systemImage: "folder.fill")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                let tags = session.libraryTags.filter { entry.tagIDs.contains($0.id) }
                if !tags.isEmpty {
                    Label(tags.map(\.name).joined(separator: " · "), systemImage: "tag.fill")
                        .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer()
        }
    }

    @ViewBuilder private var batchActions: some View {
        Menu {
            Button("Ajouter aux favoris", systemImage: "star.fill") {
                let ids = selection
                Task { await session.setFavorites(true, for: ids) }
            }
            Button("Retirer des favoris", systemImage: "star.slash") {
                let ids = selection
                Task { await session.setFavorites(false, for: ids) }
            }
        } label: { Label("Favoris", systemImage: "star") }
        .disabled(selection.isEmpty)
        .accessibilityIdentifier("library-batch-favorites")

        Menu {
            Button("Sans dossier", systemImage: "tray") {
                let ids = selection
                Task { await session.setLibraryFolder(nil, for: ids) }
            }
            ForEach(session.libraryFolders) { folder in
                Button(folder.name, systemImage: "folder") {
                    let ids = selection
                    Task { await session.setLibraryFolder(folder.id, for: ids) }
                }
            }
        } label: { Label("Dossier", systemImage: "folder") }
        .disabled(selection.isEmpty)
        .accessibilityIdentifier("library-batch-folder")

        Menu {
            ForEach(session.libraryTags) { tag in
                Menu(tag.name) {
                    Button("Ajouter", systemImage: "plus") {
                        let ids = selection
                        Task { await session.setLibraryTag(tag.id, enabled: true, for: ids) }
                    }
                    Button("Retirer", systemImage: "minus") {
                        let ids = selection
                        Task { await session.setLibraryTag(tag.id, enabled: false, for: ids) }
                    }
                }
            }
        } label: { Label("Étiquettes", systemImage: "tag") }
        .disabled(selection.isEmpty || session.libraryTags.isEmpty)
        .accessibilityIdentifier("library-batch-tags")

        Spacer()
        Button("Supprimer", systemImage: "trash", role: .destructive) {
            showingBatchDeletion = true
        }
        .disabled(selection.isEmpty)
        .accessibilityIdentifier("library-batch-delete")
    }

    private func endSelection() {
        isSelecting = false
        selection.removeAll()
    }
}

private struct LibraryTagsView: View {
    @Bindable var session: EditorSession
    @Environment(\.dismiss) private var dismiss
    @State private var showingNewTag = false
    @State private var newTagName = ""
    @State private var pendingDeletion: LibraryTag?

    var body: some View {
        NavigationStack {
            Group {
                if session.libraryTags.isEmpty {
                    ContentUnavailableView("Aucune étiquette", systemImage: "tag",
                                           description: Text("Créez des étiquettes pour croiser vos classements."))
                } else {
                    List(session.libraryTags) { tag in
                        HStack {
                            Label(tag.name, systemImage: "tag.fill")
                            Spacer()
                            Text(session.libraryDocuments.filter { $0.tagIDs.contains(tag.id) }.count, format: .number)
                                .foregroundStyle(.secondary)
                        }
                        .swipeActions {
                            Button("Supprimer", systemImage: "trash", role: .destructive) {
                                pendingDeletion = tag
                            }
                        }
                    }
                }
            }
            .navigationTitle("Étiquettes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Nouvelle", systemImage: "tag.badge.plus") {
                        newTagName = ""
                        showingNewTag = true
                    }
                    .accessibilityIdentifier("library-new-tag")
                }
                ToolbarItem(placement: .confirmationAction) { Button("Terminé") { dismiss() } }
            }
        }
        .alert("Nouvelle étiquette", isPresented: $showingNewTag) {
            TextField("Nom", text: $newTagName)
            Button("Créer") { Task { await session.createLibraryTag(named: newTagName) } }
            Button("Annuler", role: .cancel) {}
        }
        .confirmationDialog("Supprimer cette étiquette ?", isPresented: Binding(
            get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } }),
                            titleVisibility: .visible) {
            Button("Supprimer l’étiquette", role: .destructive) {
                guard let tag = pendingDeletion else { return }
                pendingDeletion = nil
                Task { await session.deleteLibraryTag(tag.id) }
            }
            Button("Annuler", role: .cancel) { pendingDeletion = nil }
        } message: {
            Text("Les photos et leurs retouches resteront dans la bibliothèque.")
        }
    }
}

private struct LibraryFoldersView: View {
    @Bindable var session: EditorSession
    @Environment(\.dismiss) private var dismiss
    @State private var showingNewFolder = false
    @State private var newFolderName = ""
    @State private var pendingDeletion: LibraryFolder?

    var body: some View {
        NavigationStack {
            Group {
                if session.libraryFolders.isEmpty {
                    ContentUnavailableView("Aucun dossier", systemImage: "folder",
                                           description: Text("Créez un dossier pour classer vos développements."))
                } else {
                    List(session.libraryFolders) { folder in
                        HStack {
                            Label(folder.name, systemImage: "folder.fill")
                            Spacer()
                            Text(session.libraryDocuments.filter { $0.folderID == folder.id }.count, format: .number)
                                .foregroundStyle(.secondary)
                        }
                        .swipeActions {
                            Button("Supprimer", systemImage: "trash", role: .destructive) {
                                pendingDeletion = folder
                            }
                        }
                    }
                }
            }
            .navigationTitle("Dossiers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Nouveau", systemImage: "folder.badge.plus") {
                        newFolderName = ""
                        showingNewFolder = true
                    }
                    .accessibilityIdentifier("library-new-folder")
                }
                ToolbarItem(placement: .confirmationAction) { Button("Terminé") { dismiss() } }
            }
        }
        .alert("Nouveau dossier", isPresented: $showingNewFolder) {
            TextField("Nom", text: $newFolderName)
            Button("Créer") { Task { await session.createLibraryFolder(named: newFolderName) } }
            Button("Annuler", role: .cancel) {}
        }
        .confirmationDialog("Supprimer ce dossier ?", isPresented: Binding(
            get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } }),
                            titleVisibility: .visible) {
            Button("Supprimer le dossier", role: .destructive) {
                guard let folder = pendingDeletion else { return }
                pendingDeletion = nil
                Task { await session.deleteLibraryFolder(folder.id) }
            }
            Button("Annuler", role: .cancel) { pendingDeletion = nil }
        } message: {
            Text("Les photos resteront dans la bibliothèque et seront simplement retirées de ce dossier.")
        }
    }
}

private struct LibraryThumbnailView: View {
    let url: URL
    @State private var image: CGImage?

    var body: some View {
        Group {
            if let image {
                Image(decorative: image, scale: 1).resizable().scaledToFill()
            } else {
                ZStack {
                    Color.secondary.opacity(0.12)
                    Image(systemName: "photo").foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: 72, height: 58)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .task(id: url) { image = await LibraryThumbnailLoader.shared.load(url) }
        .accessibilityHidden(true)
    }
}

private actor LibraryThumbnailLoader {
    static let shared = LibraryThumbnailLoader()

    func load(_ url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, [
            kCGImageSourceShouldCache: false
        ] as CFDictionary) else { return nil }
        return CGImageSourceCreateThumbnailAtIndex(source, 0, [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 240,
            kCGImageSourceShouldCacheImmediately: true
        ] as CFDictionary)
    }
}
