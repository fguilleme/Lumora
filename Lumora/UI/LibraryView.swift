import SwiftUI
import ImageIO
import CoreImage

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
        case .all: "All"
        case .favorites: "Favorites"
        case let .folder(id): session.libraryFolders.first(where: { $0.id == id })?.name ?? "All"
        case let .tag(id): session.libraryTags.first(where: { $0.id == id })?.name ?? "All"
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
        guard isSelecting else { return "Library" }
        return selection.isEmpty ? "Select" : "\(selection.count) selected"
    }

    var body: some View {
        NavigationStack {
            Group {
                if session.isLoadingLibrary {
                    ProgressView("Loading library…")
                } else if session.libraryDocuments.isEmpty {
                    ContentUnavailableView("Empty library", systemImage: "photo.stack",
                                           description: Text("Import a photo to create a local edit."))
                } else if visibleDocuments.isEmpty {
                    if search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        ContentUnavailableView("No photos", systemImage: "folder",
                                               description: Text("This folder or selection is empty."))
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
                        Button(selection == visibleDocumentIDs ? String(localized: "None") : String(localized: "All")) {
                            selection = selection == visibleDocumentIDs ? [] : visibleDocumentIDs
                        }
                        .accessibilityIdentifier("library-select-all")
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { endSelection() }
                    }
                    ToolbarItemGroup(placement: .bottomBar) {
                        batchActions
                    }
                } else {
                    ToolbarItemGroup(placement: .topBarLeading) {
                        Menu {
                            Button("All", systemImage: "photo.stack") { scope = .all }
                            Button("Favorites", systemImage: "star") { scope = .favorites }
                            if !session.libraryFolders.isEmpty {
                                Section("Folders") {
                                    ForEach(session.libraryFolders) { folder in
                                        Button(folder.name, systemImage: "folder") { scope = .folder(folder.id) }
                                    }
                                }
                            }
                            if !session.libraryTags.isEmpty {
                                Section("Tags") {
                                    ForEach(session.libraryTags) { tag in
                                        Button(tag.name, systemImage: "tag") { scope = .tag(tag.id) }
                                    }
                                }
                            }
                            Divider()
                            Button("Manage folders…", systemImage: "folder.badge.gearshape") {
                                showingFolders = true
                            }
                            Button("Manage tags…", systemImage: "tag") {
                                showingTags = true
                            }
                        } label: { Label(scopeTitle, systemImage: scopeSymbol) }
                        .accessibilityIdentifier("library-scope")

                        Menu {
                            Picker("Sort", selection: $sort) {
                                ForEach(LibrarySortOrder.allCases) { order in Text(order.title).tag(order) }
                            }
                        } label: { Label("Sort by", systemImage: "arrow.up.arrow.down") }
                        .accessibilityIdentifier("library-sort")
                    }
                    ToolbarItemGroup(placement: .confirmationAction) {
                        Button("Select") {
                            isSelecting = true
                            selection.removeAll()
                        }
                        .accessibilityIdentifier("library-select")
                        Button("Close") { dismiss() }
                    }
                }
            }
        }
        .searchable(text: $search, prompt: "Search photos")
        .task { await session.loadLibrary() }
        .sheet(isPresented: $showingFolders) { LibraryFoldersView(session: session) }
        .sheet(isPresented: $showingTags) { LibraryTagsView(session: session) }
        .onChange(of: visibleDocumentIDs) { _, ids in selection.formIntersection(ids) }
        .confirmationDialog("Delete this edit?", isPresented: Binding(
            get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } }),
                            titleVisibility: .visible) {
            Button("Delete permanently", role: .destructive) {
                guard let entry = pendingDeletion else { return }
                pendingDeletion = nil
                Task { await session.deleteDocument(entry.id) }
            }
            Button("Cancel", role: .cancel) { pendingDeletion = nil }
        } message: {
            Text("The private original and all its edits will be deleted from Lumora.")
        }
        .confirmationDialog("Delete \(selection.count) edit\(selection.count > 1 ? "s" : "")?",
                            isPresented: $showingBatchDeletion, titleVisibility: .visible) {
            Button("Delete permanently", role: .destructive) {
                let ids = selection
                endSelection()
                Task { await session.deleteDocuments(ids) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The private originals and all their edits will be deleted from Lumora.")
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
                .accessibilityValue(selection.contains(entry.id) ? "Selected" : "Not selected")
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
            .accessibilityHint("Open this edit")

            Button {
                Task { await session.toggleFavorite(entry.id) }
            } label: {
                Image(systemName: entry.isFavorite ? "star.fill" : "star")
                    .frame(width: 44, height: 44)
            }
            .foregroundStyle(entry.isFavorite ? .yellow : .secondary)
            .accessibilityLabel(entry.isFavorite ? "Remove from favorites" : "Add to favorites")
            .accessibilityValue(entry.isFavorite ? "Favorite" : "Not a favorite")
            .accessibilityIdentifier("library-favorite-button")

            Menu {
                Menu("Move to", systemImage: "folder") {
                    Button("No folder", systemImage: "tray") {
                        Task { await session.setLibraryFolder(nil, for: entry.id) }
                    }
                    ForEach(session.libraryFolders) { folder in
                        Button(folder.name, systemImage: entry.folderID == folder.id ? "checkmark" : "folder") {
                            Task { await session.setLibraryFolder(folder.id, for: entry.id) }
                        }
                    }
                }
                if !session.libraryTags.isEmpty {
                    Menu("Tags", systemImage: "tag") {
                        ForEach(session.libraryTags) { tag in
                            Button(tag.name,
                                   systemImage: entry.tagIDs.contains(tag.id) ? "checkmark.circle.fill" : "circle") {
                                Task { await session.toggleLibraryTag(tag.id, for: entry.id) }
                            }
                        }
                    }
                }
                Button("Delete", systemImage: "trash", role: .destructive) {
                    pendingDeletion = entry
                }
            } label: {
                Image(systemName: "ellipsis.circle").frame(width: 44, height: 44)
            }
            .accessibilityLabel("Options for \(entry.document.originalName)")
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
                    Label("Open", systemImage: "checkmark.circle.fill")
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
            Button("Add to favorites", systemImage: "star.fill") {
                let ids = selection
                Task { await session.setFavorites(true, for: ids) }
            }
            Button("Remove from favorites", systemImage: "star.slash") {
                let ids = selection
                Task { await session.setFavorites(false, for: ids) }
            }
        } label: { Label("Favorites", systemImage: "star") }
        .disabled(selection.isEmpty)
        .accessibilityIdentifier("library-batch-favorites")

        Menu {
            Button("No folder", systemImage: "tray") {
                let ids = selection
                Task { await session.setLibraryFolder(nil, for: ids) }
            }
            ForEach(session.libraryFolders) { folder in
                Button(folder.name, systemImage: "folder") {
                    let ids = selection
                    Task { await session.setLibraryFolder(folder.id, for: ids) }
                }
            }
        } label: { Label("Folder", systemImage: "folder") }
        .disabled(selection.isEmpty)
        .accessibilityIdentifier("library-batch-folder")

        Menu {
            ForEach(session.libraryTags) { tag in
                Menu(tag.name) {
                    Button("Add", systemImage: "plus") {
                        let ids = selection
                        Task { await session.setLibraryTag(tag.id, enabled: true, for: ids) }
                    }
                    Button("Remove", systemImage: "minus") {
                        let ids = selection
                        Task { await session.setLibraryTag(tag.id, enabled: false, for: ids) }
                    }
                }
            }
        } label: { Label("Tags", systemImage: "tag") }
        .disabled(selection.isEmpty || session.libraryTags.isEmpty)
        .accessibilityIdentifier("library-batch-tags")

        Spacer()
        Button("Delete", systemImage: "trash", role: .destructive) {
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
                    ContentUnavailableView("No tags", systemImage: "tag",
                                           description: Text("Create tags to organize photos across folders."))
                } else {
                    List(session.libraryTags) { tag in
                        HStack {
                            Label(tag.name, systemImage: "tag.fill")
                            Spacer()
                            Text(session.libraryDocuments.filter { $0.tagIDs.contains(tag.id) }.count, format: .number)
                                .foregroundStyle(.secondary)
                        }
                        .swipeActions {
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                pendingDeletion = tag
                            }
                        }
                    }
                }
            }
            .navigationTitle("Tags")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("New", systemImage: "tag.badge.plus") {
                        newTagName = ""
                        showingNewTag = true
                    }
                    .accessibilityIdentifier("library-new-tag")
                }
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .alert("New tag", isPresented: $showingNewTag) {
            TextField("Name", text: $newTagName)
            Button("Create") { Task { await session.createLibraryTag(named: newTagName) } }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Delete this tag?", isPresented: Binding(
            get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } }),
                            titleVisibility: .visible) {
            Button("Delete tag", role: .destructive) {
                guard let tag = pendingDeletion else { return }
                pendingDeletion = nil
                Task { await session.deleteLibraryTag(tag.id) }
            }
            Button("Cancel", role: .cancel) { pendingDeletion = nil }
        } message: {
            Text("Photos and edits will remain in the library.")
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
                    ContentUnavailableView("No folders", systemImage: "folder",
                                           description: Text("Create a folder to organize your edits."))
                } else {
                    List(session.libraryFolders) { folder in
                        HStack {
                            Label(folder.name, systemImage: "folder.fill")
                            Spacer()
                            Text(session.libraryDocuments.filter { $0.folderID == folder.id }.count, format: .number)
                                .foregroundStyle(.secondary)
                        }
                        .swipeActions {
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                pendingDeletion = folder
                            }
                        }
                    }
                }
            }
            .navigationTitle("Folders")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("New", systemImage: "folder.badge.plus") {
                        newFolderName = ""
                        showingNewFolder = true
                    }
                    .accessibilityIdentifier("library-new-folder")
                }
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .alert("New folder", isPresented: $showingNewFolder) {
            TextField("Name", text: $newFolderName)
            Button("Create") { Task { await session.createLibraryFolder(named: newFolderName) } }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Delete this folder?", isPresented: Binding(
            get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } }),
                            titleVisibility: .visible) {
            Button("Delete folder", role: .destructive) {
                guard let folder = pendingDeletion else { return }
                pendingDeletion = nil
                Task { await session.deleteLibraryFolder(folder.id) }
            }
            Button("Cancel", role: .cancel) { pendingDeletion = nil }
        } message: {
            Text("Photos will remain in the library and simply be removed from this folder.")
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
    private let context = CIContext(options: [.cacheIntermediates: false])

    func load(_ url: URL) -> CGImage? {
        if let source = CGImageSourceCreateWithURL(url as CFURL, [
            kCGImageSourceShouldCache: false
        ] as CFDictionary), let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 240,
            kCGImageSourceShouldCacheImmediately: true
        ] as CFDictionary) {
            return thumbnail
        }
        guard let raw = RAWDecoder.filter(url) else { return nil }
        raw.scaleFactor = Float(min(1, 240 / max(raw.nativeSize.width, raw.nativeSize.height)))
        guard let output = raw.outputImage,
              let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        return context.createCGImage(output, from: output.extent, format: .RGBA8, colorSpace: space)
    }
}
