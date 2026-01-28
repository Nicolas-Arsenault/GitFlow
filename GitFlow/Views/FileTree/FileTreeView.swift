import SwiftUI
import UniformTypeIdentifiers

/// Main view for the file tree browser.
struct FileTreeView: View {
    @ObservedObject var viewModel: FileTreeViewModel

    @State private var showNewFileSheet: Bool = false
    @State private var showNewFolderSheet: Bool = false
    @State private var showRenameSheet: Bool = false
    @State private var targetDirectory: FileTreeNode?
    @State private var nodeToRename: FileTreeNode?
    @State private var nodeToDelete: FileTreeNode?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            FileTreeHeader(
                viewModel: viewModel,
                onNewFile: {
                    targetDirectory = viewModel.rootNode
                    showNewFileSheet = true
                },
                onNewFolder: {
                    targetDirectory = viewModel.rootNode
                    showNewFolderSheet = true
                }
            )

            Divider()

            // Search bar
            if !viewModel.searchText.isEmpty || viewModel.rootNode != nil {
                FileTreeSearchBar(searchText: $viewModel.searchText)
                    .onChange(of: viewModel.searchText) {
                        viewModel.search(viewModel.searchText)
                    }
            }

            // Content
            if viewModel.isLoading && viewModel.rootNode == nil {
                ProgressView("Loading files...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let root = viewModel.rootNode {
                if !viewModel.searchText.isEmpty {
                    // Search results
                    searchResultsView
                } else {
                    // Tree view
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            FileTreeNodeView(
                                node: root,
                                viewModel: viewModel,
                                onNewFile: { dir in
                                    targetDirectory = dir
                                    showNewFileSheet = true
                                },
                                onNewFolder: { dir in
                                    targetDirectory = dir
                                    showNewFolderSheet = true
                                },
                                onRename: { node in
                                    nodeToRename = node
                                    showRenameSheet = true
                                },
                                onDelete: { node in
                                    nodeToDelete = node
                                }
                            )
                        }
                        .padding(.vertical, 4)
                    }
                }
            } else {
                EmptyStateView(
                    "No Files",
                    systemImage: "folder",
                    description: "Load the file tree to browse files"
                )
            }
        }
        .task {
            await viewModel.loadTree()
        }
        .sheet(isPresented: $showNewFileSheet) {
            NewItemSheet(
                title: "New File",
                placeholder: "filename.txt",
                isPresented: $showNewFileSheet
            ) { name in
                if let dir = targetDirectory {
                    Task {
                        _ = await viewModel.createFile(name: name, in: dir)
                    }
                }
            }
        }
        .sheet(isPresented: $showNewFolderSheet) {
            NewItemSheet(
                title: "New Folder",
                placeholder: "folder-name",
                isPresented: $showNewFolderSheet
            ) { name in
                if let dir = targetDirectory {
                    Task {
                        _ = await viewModel.createFolder(name: name, in: dir)
                    }
                }
            }
        }
        .sheet(isPresented: $showRenameSheet) {
            if let node = nodeToRename {
                RenameSheet(
                    currentName: node.name,
                    isPresented: $showRenameSheet
                ) { newName in
                    Task {
                        _ = await viewModel.rename(node, to: newName)
                    }
                }
            }
        }
        .confirmationDialog(
            "Delete \(nodeToDelete?.name ?? "")?",
            isPresented: .init(
                get: { nodeToDelete != nil },
                set: { if !$0 { nodeToDelete = nil } }
            ),
            presenting: nodeToDelete
        ) { node in
            Button("Delete", role: .destructive) {
                Task {
                    _ = await viewModel.delete(node)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: { node in
            if node.isDirectory {
                Text("This will permanently delete the folder '\(node.name)' and all its contents.")
            } else {
                Text("This will permanently delete the file '\(node.name)'.")
            }
        }
        .alert("Error", isPresented: .init(
            get: { viewModel.error != nil },
            set: { if !$0 { viewModel.error = nil } }
        )) {
            Button("Dismiss") { viewModel.error = nil }
        } message: {
            if let error = viewModel.error {
                Text(error.localizedDescription)
            }
        }
    }

    private var searchResultsView: some View {
        List(viewModel.searchResults) { node in
            HStack(spacing: 8) {
                FileIconView(node: node)

                VStack(alignment: .leading, spacing: 2) {
                    Text(node.name)
                        .font(.body)

                    Text(node.relativePath)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                viewModel.selectedFile = node
                if !node.isDirectory {
                    viewModel.openFile(node)
                }
            }
            .contextMenu {
                FileContextMenu(
                    node: node,
                    viewModel: viewModel,
                    onNewFile: { _ in },
                    onNewFolder: { _ in },
                    onRename: { nodeToRename = $0; showRenameSheet = true },
                    onDelete: { nodeToDelete = $0 }
                )
            }
        }
        .listStyle(.inset)
    }
}

// MARK: - Header

private struct FileTreeHeader: View {
    @ObservedObject var viewModel: FileTreeViewModel
    let onNewFile: () -> Void
    let onNewFolder: () -> Void

    var body: some View {
        HStack {
            Text("Files")
                .font(.headline)

            Spacer()

            // Options menu
            Menu {
                Toggle("Show Hidden Files", isOn: $viewModel.config.showHiddenFiles)
                Toggle("Show Ignored Files", isOn: $viewModel.config.showIgnoredFiles)
                Toggle("Show Only Changed", isOn: $viewModel.config.showOnlyChangedFiles)

                Divider()

                Menu("Sort By") {
                    Button("Name (A-Z)") {
                        viewModel.config.sortOrder = .nameAscending
                    }
                    Button("Name (Z-A)") {
                        viewModel.config.sortOrder = .nameDescending
                    }
                    Button("Type") {
                        viewModel.config.sortOrder = .typeFirst
                    }
                    Button("Modified Date") {
                        viewModel.config.sortOrder = .modifiedDate
                    }
                }

                Divider()

                Button(action: { Task { await viewModel.expandAll() } }) {
                    Label("Expand All", systemImage: "chevron.down.square")
                }

                Button(action: { viewModel.collapseAll() }) {
                    Label("Collapse All", systemImage: "chevron.up.square")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .frame(width: 24)

            // New file/folder
            Menu {
                Button(action: onNewFile) {
                    Label("New File", systemImage: "doc.badge.plus")
                }
                Button(action: onNewFolder) {
                    Label("New Folder", systemImage: "folder.badge.plus")
                }
            } label: {
                Image(systemName: "plus")
            }
            .menuStyle(.borderlessButton)
            .frame(width: 24)

            // Refresh
            Button(action: { Task { await viewModel.refresh() } }) {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)

            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(0.6)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

// MARK: - Search Bar

private struct FileTreeSearchBar: View {
    @Binding var searchText: String

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search files...", text: $searchText)
                .textFieldStyle(.plain)

            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(Color.secondary.opacity(0.1))
    }
}

// MARK: - Tree Node View

private struct FileTreeNodeView: View {
    @ObservedObject var node: FileTreeNode
    @ObservedObject var viewModel: FileTreeViewModel
    let onNewFile: (FileTreeNode) -> Void
    let onNewFolder: (FileTreeNode) -> Void
    let onRename: (FileTreeNode) -> Void
    let onDelete: (FileTreeNode) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Node row
            HStack(spacing: 4) {
                // Indentation
                ForEach(0..<node.depth, id: \.self) { _ in
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: 16)
                }

                // Expand/collapse chevron
                if node.isDirectory {
                    Button(action: { Task { await viewModel.toggleExpanded(node) } }) {
                        Image(systemName: node.isExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .frame(width: 16)
                } else {
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: 16)
                }

                // Icon
                FileIconView(node: node)

                // Name
                Text(node.name)
                    .font(.body)
                    .lineLimit(1)

                Spacer()

                // Git status badge
                if node.gitStatus != .unmodified {
                    Text(node.gitStatus.rawValue)
                        .font(.caption.monospaced())
                        .foregroundStyle(statusColor)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(viewModel.selectedFile?.id == node.id ? Color.accentColor.opacity(0.2) : Color.clear)
            .contentShape(Rectangle())
            .onTapGesture {
                viewModel.selectedFile = node
                if !node.isDirectory {
                    viewModel.openFile(node)
                }
            }
            .onTapGesture(count: 2) {
                if node.isDirectory {
                    Task { await viewModel.toggleExpanded(node) }
                } else {
                    viewModel.openFile(node)
                }
            }
            .contextMenu {
                FileContextMenu(
                    node: node,
                    viewModel: viewModel,
                    onNewFile: onNewFile,
                    onNewFolder: onNewFolder,
                    onRename: onRename,
                    onDelete: onDelete
                )
            }

            // Children
            if node.isExpanded {
                ForEach(node.children) { child in
                    FileTreeNodeView(
                        node: child,
                        viewModel: viewModel,
                        onNewFile: onNewFile,
                        onNewFolder: onNewFolder,
                        onRename: onRename,
                        onDelete: onDelete
                    )
                }
            }
        }
    }

    private var statusColor: Color {
        switch node.gitStatus {
        case .modified: return .orange
        case .added: return .green
        case .deleted: return .red
        case .renamed, .copied: return .blue
        case .untracked: return .secondary
        case .conflict: return .red
        default: return .primary
        }
    }
}

// MARK: - File Icon

private struct FileIconView: View {
    let node: FileTreeNode

    var body: some View {
        Image(systemName: iconName)
            .foregroundStyle(iconColor)
            .frame(width: 16)
    }

    private var iconName: String {
        if node.isDirectory {
            return node.isExpanded ? "folder.fill" : "folder"
        }

        // Map extensions to icons
        switch node.fileExtension?.lowercased() {
        case "swift": return "swift"
        case "py": return "chevron.left.forwardslash.chevron.right"
        case "js", "ts", "jsx", "tsx": return "curlybraces"
        case "html": return "chevron.left.slash.chevron.right"
        case "css", "scss", "sass": return "paintbrush"
        case "json": return "curlybraces.square"
        case "md", "markdown": return "text.alignleft"
        case "txt": return "doc.text"
        case "pdf": return "doc.richtext"
        case "png", "jpg", "jpeg", "gif", "svg", "webp": return "photo"
        case "mp3", "wav", "m4a": return "music.note"
        case "mp4", "mov", "avi": return "film"
        case "zip", "tar", "gz", "rar": return "doc.zipper"
        case "yml", "yaml": return "list.bullet.rectangle"
        case "sh", "bash", "zsh": return "terminal"
        case "rb": return "diamond"
        case "go": return "chevron.left.forwardslash.chevron.right"
        case "rs": return "gearshape"
        case "java", "kt": return "cup.and.saucer"
        case "c", "cpp", "h", "hpp": return "c.square"
        default: return "doc"
        }
    }

    private var iconColor: Color {
        if node.isDirectory {
            return .blue
        }

        switch node.fileExtension?.lowercased() {
        case "swift": return .orange
        case "py": return .blue
        case "js", "ts": return .yellow
        case "html": return .orange
        case "css": return .blue
        case "json": return .green
        case "md": return .purple
        default: return .secondary
        }
    }
}

// MARK: - Context Menu

private struct FileContextMenu: View {
    let node: FileTreeNode
    @ObservedObject var viewModel: FileTreeViewModel
    let onNewFile: (FileTreeNode) -> Void
    let onNewFolder: (FileTreeNode) -> Void
    let onRename: (FileTreeNode) -> Void
    let onDelete: (FileTreeNode) -> Void

    var body: some View {
        Group {
            if node.isDirectory {
                Button(action: { onNewFile(node) }) {
                    Label("New File", systemImage: "doc.badge.plus")
                }

                Button(action: { onNewFolder(node) }) {
                    Label("New Folder", systemImage: "folder.badge.plus")
                }

                Divider()
            }

            Button(action: { viewModel.openFile(node) }) {
                Label("Open", systemImage: "arrow.up.forward.app")
            }

            Button(action: { viewModel.openInEditor(node) }) {
                Label("Open in Editor", systemImage: "pencil")
            }

            Button(action: { viewModel.revealInFinder(node) }) {
                Label("Reveal in Finder", systemImage: "folder")
            }

            Divider()

            Button(action: { viewModel.copyPath(node, absolute: false) }) {
                Label("Copy Relative Path", systemImage: "doc.on.doc")
            }

            Button(action: { viewModel.copyPath(node, absolute: true) }) {
                Label("Copy Absolute Path", systemImage: "doc.on.doc.fill")
            }

            Divider()

            Button(action: { onRename(node) }) {
                Label("Rename", systemImage: "pencil")
            }

            Button(role: .destructive, action: { onDelete(node) }) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

// MARK: - New Item Sheet

private struct NewItemSheet: View {
    let title: String
    let placeholder: String
    @Binding var isPresented: Bool
    let onCreate: (String) -> Void

    @State private var name: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // Form
            VStack(alignment: .leading, spacing: 8) {
                Text("Name:")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextField(placeholder, text: $name)
                    .textFieldStyle(.roundedBorder)
            }
            .padding()

            Divider()

            // Actions
            HStack {
                Spacer()

                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Button("Create") {
                    onCreate(name)
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty)
            }
            .padding()
        }
        .frame(width: 350)
    }
}

// MARK: - Rename Sheet

private struct RenameSheet: View {
    let currentName: String
    @Binding var isPresented: Bool
    let onRename: (String) -> Void

    @State private var newName: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Rename")
                    .font(.headline)
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // Form
            VStack(alignment: .leading, spacing: 8) {
                Text("Current: \(currentName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("New name:")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextField(currentName, text: $newName)
                    .textFieldStyle(.roundedBorder)
            }
            .padding()

            Divider()

            // Actions
            HStack {
                Spacer()

                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Button("Rename") {
                    onRename(newName)
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(newName.isEmpty || newName == currentName)
            }
            .padding()
        }
        .frame(width: 350)
        .onAppear {
            newName = currentName
        }
    }
}

// MARK: - Preview

#Preview {
    FileTreeView(
        viewModel: FileTreeViewModel(
            repository: Repository(rootURL: URL(fileURLWithPath: "/tmp")),
            gitService: GitService()
        )
    )
    .frame(width: 300, height: 500)
}
