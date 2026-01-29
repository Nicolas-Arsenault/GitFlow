import SwiftUI

/// View for managing multiple repositories with tabs.
struct RepositoryManagerView: View {
    @ObservedObject var viewModel: RepositoryManagerViewModel

    @State private var showAddRepository: Bool = false
    @State private var showDiscovery: Bool = false
    @State private var repositoryToRename: RepositoryInfo?

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            if !viewModel.tabs.isEmpty {
                RepositoryTabBar(viewModel: viewModel)
            }

            Divider()

            // Repository list
            RepositoryListView(
                viewModel: viewModel,
                onOpen: { viewModel.openInTab($0) },
                onRename: { repositoryToRename = $0 }
            )
        }
        .toolbar {
            ToolbarItemGroup {
                Button(action: { showAddRepository = true }) {
                    Label("Add Repository", systemImage: "plus")
                }

                Button(action: { showDiscovery = true }) {
                    Label("Discover Repositories", systemImage: "magnifyingglass")
                }

                Button(action: { viewModel.cleanupInvalidRepositories() }) {
                    Label("Clean Up", systemImage: "trash")
                }
            }
        }
        .sheet(isPresented: $showAddRepository) {
            AddRepositorySheet(isPresented: $showAddRepository) { path in
                viewModel.addRepository(at: path)
            }
        }
        .sheet(isPresented: $showDiscovery) {
            DiscoverySheet(viewModel: viewModel, isPresented: $showDiscovery)
        }
        .sheet(item: $repositoryToRename) { repo in
            RenameRepositorySheet(
                repository: repo,
                isPresented: .init(
                    get: { repositoryToRename != nil },
                    set: { if !$0 { repositoryToRename = nil } }
                )
            ) { newName in
                viewModel.renameRepository(repo, to: newName)
            }
        }
    }
}

// MARK: - Tab Bar

private struct RepositoryTabBar: View {
    @ObservedObject var viewModel: RepositoryManagerViewModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(viewModel.tabs) { tab in
                    TabButton(
                        tab: tab,
                        isActive: tab.isActive,
                        onActivate: { viewModel.activateTab(tab.id) },
                        onClose: { viewModel.closeTab(tab.id) }
                    )
                }
            }
        }
        .frame(height: 32)
        .background(Color.secondary.opacity(0.1))
    }
}

private struct TabButton: View {
    let tab: RepositoryTab
    let isActive: Bool
    let onActivate: () -> Void
    let onClose: () -> Void

    @State private var isHovering: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            // Color indicator
            if let color = tab.repositoryInfo.color {
                Circle()
                    .fill(Color(hex: color) ?? .blue)
                    .frame(width: 8, height: 8)
            }

            // Name
            Text(tab.repositoryInfo.name)
                .font(.caption)
                .lineLimit(1)

            // Close button
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Close tab")
            .opacity(isHovering ? 1 : 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isActive ? Color.accentColor.opacity(0.2) : Color.clear)
        .onHover { isHovering = $0 }
        .onTapGesture(perform: onActivate)
    }
}

// MARK: - Repository List

private struct RepositoryListView: View {
    @ObservedObject var viewModel: RepositoryManagerViewModel
    let onOpen: (RepositoryInfo) -> Void
    let onRename: (RepositoryInfo) -> Void

    var body: some View {
        List {
            // Favorites section
            if !viewModel.favoriteRepositories.isEmpty {
                Section("Favorites") {
                    ForEach(viewModel.favoriteRepositories) { repo in
                        RepositoryRow(
                            repository: repo,
                            onOpen: onOpen,
                            onToggleFavorite: { viewModel.toggleFavorite(repo) },
                            onRename: onRename,
                            onRemove: { viewModel.removeRepository(repo) }
                        )
                    }
                }
            }

            // Recent section
            Section("Recent") {
                ForEach(viewModel.recentRepositories) { repo in
                    RepositoryRow(
                        repository: repo,
                        onOpen: onOpen,
                        onToggleFavorite: { viewModel.toggleFavorite(repo) },
                        onRename: onRename,
                        onRemove: { viewModel.removeRepository(repo) }
                    )
                }
            }

            // All repositories section
            Section("All Repositories (\(viewModel.repositories.count))") {
                ForEach(viewModel.repositories.sorted { $0.name < $1.name }) { repo in
                    RepositoryRow(
                        repository: repo,
                        onOpen: onOpen,
                        onToggleFavorite: { viewModel.toggleFavorite(repo) },
                        onRename: onRename,
                        onRemove: { viewModel.removeRepository(repo) }
                    )
                }
            }
        }
        .listStyle(.sidebar)
    }
}

private struct RepositoryRow: View {
    let repository: RepositoryInfo
    let onOpen: (RepositoryInfo) -> Void
    let onToggleFavorite: () -> Void
    let onRename: (RepositoryInfo) -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Color/icon
            if let color = repository.color {
                Circle()
                    .fill(Color(hex: color) ?? .blue)
                    .frame(width: 12, height: 12)
            } else {
                Image(systemName: "folder.fill")
                    .foregroundStyle(.blue)
            }

            // Info
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(repository.name)
                        .font(.body)

                    if repository.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundStyle(.yellow)
                    }
                }

                Text(repository.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Status
            if !repository.exists {
                Text("Missing")
                    .font(.caption)
                    .foregroundStyle(.red)
            } else if !repository.isGitRepository {
                Text("Not a Git repo")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onOpen(repository) }
        .contextMenu {
            Button("Open") { onOpen(repository) }

            Button(repository.isFavorite ? "Remove from Favorites" : "Add to Favorites") {
                onToggleFavorite()
            }

            Button("Rename...") { onRename(repository) }

            Menu("Set Color") {
                Button("None") {
                    // Would need to pass viewModel
                }
                ForEach(["red", "orange", "yellow", "green", "blue", "purple"], id: \.self) { color in
                    Button {
                        // Set color
                    } label: {
                        HStack {
                            Circle()
                                .fill(Color(hex: color) ?? .clear)
                                .frame(width: 12, height: 12)
                            Text(color.capitalized)
                        }
                    }
                }
            }

            Divider()

            Button("Show in Finder") {
                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: repository.path)
            }

            Button("Copy Path") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(repository.path, forType: .string)
            }

            Divider()

            Button("Remove from List", role: .destructive) {
                onRemove()
            }
        }
    }
}

// MARK: - Add Repository Sheet

private struct AddRepositorySheet: View {
    @Binding var isPresented: Bool
    let onAdd: (String) -> Void

    @State private var path: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Add Repository")
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
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Repository Path")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack {
                        TextField("/path/to/repository", text: $path)
                            .textFieldStyle(.roundedBorder)

                        Button("Browse...") {
                            let panel = NSOpenPanel()
                            panel.canChooseFiles = false
                            panel.canChooseDirectories = true
                            panel.allowsMultipleSelection = false

                            if panel.runModal() == .OK, let url = panel.url {
                                path = url.path
                            }
                        }
                    }
                }
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

                Button("Add") {
                    onAdd(path)
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(path.isEmpty)
            }
            .padding()
        }
        .frame(width: 450)
    }
}

// MARK: - Discovery Sheet

private struct DiscoverySheet: View {
    @ObservedObject var viewModel: RepositoryManagerViewModel
    @Binding var isPresented: Bool

    @State private var scanPath: String = ""
    @State private var maxDepth: Int = 3
    @State private var result: RepositoryScanResult?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Discover Repositories")
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
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Search Directory")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack {
                        TextField("~/Developer", text: $scanPath)
                            .textFieldStyle(.roundedBorder)

                        Button("Browse...") {
                            let panel = NSOpenPanel()
                            panel.canChooseFiles = false
                            panel.canChooseDirectories = true

                            if panel.runModal() == .OK, let url = panel.url {
                                scanPath = url.path
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Max Depth: \(maxDepth)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Slider(value: .init(
                        get: { Double(maxDepth) },
                        set: { maxDepth = Int($0) }
                    ), in: 1...5, step: 1)
                }

                // Progress
                if viewModel.isScanning {
                    ProgressView("Scanning...")
                        .progressViewStyle(.linear)
                }

                // Result
                if let result = result {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Found \(result.foundRepositories.count) repositories")
                            .font(.headline)

                        Text("Scanned \(result.scannedDirectories) directories in \(String(format: "%.2f", result.elapsedTime))s")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                }
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

                Button("Scan") {
                    Task {
                        let url = URL(fileURLWithPath: (scanPath as NSString).expandingTildeInPath)
                        var options = DiscoveryOptions()
                        options.maxDepth = maxDepth
                        result = await viewModel.discoverRepositories(in: url, options: options)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(scanPath.isEmpty || viewModel.isScanning)
            }
            .padding()
        }
        .frame(width: 450, height: 350)
    }
}

// MARK: - Rename Sheet

private struct RenameRepositorySheet: View {
    let repository: RepositoryInfo
    @Binding var isPresented: Bool
    let onRename: (String) -> Void

    @State private var newName: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Rename Repository")
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
                Text("Display name for \(repository.path)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextField(repository.name, text: $newName)
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
                .disabled(newName.isEmpty)
            }
            .padding()
        }
        .frame(width: 400)
        .onAppear {
            newName = repository.name
        }
    }
}

// MARK: - Preview

#Preview {
    RepositoryManagerView(viewModel: RepositoryManagerViewModel())
        .frame(width: 400, height: 600)
}
