import SwiftUI

/// View displaying all submodules.
struct SubmoduleListView: View {
    @ObservedObject var viewModel: SubmoduleViewModel

    @State private var showAddSubmodule: Bool = false
    @State private var submoduleToRemove: Submodule?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            SubmoduleHeader(viewModel: viewModel, showAddSubmodule: $showAddSubmodule)

            Divider()

            // Content
            if viewModel.isLoading && viewModel.submodules.isEmpty {
                LoadingView("Loading submodules...")
            } else if viewModel.submodules.isEmpty {
                EmptyStateView(
                    "No Submodules",
                    systemImage: "folder.badge.gearshape",
                    description: "This repository has no submodules"
                )
            } else {
                List(viewModel.submodules, selection: $viewModel.selectedSubmodule) { submodule in
                    SubmoduleRow(submodule: submodule)
                        .tag(submodule)
                        .contextMenu {
                            submoduleContextMenu(for: submodule)
                        }
                }
                .listStyle(.inset)
            }
        }
        .task {
            await viewModel.refresh()
        }
        .sheet(isPresented: $showAddSubmodule) {
            AddSubmoduleSheet(isPresented: $showAddSubmodule) { url, path, branch in
                await viewModel.addSubmodule(url: url, path: path, branch: branch)
            }
        }
        .confirmationDialog(
            "Remove Submodule",
            isPresented: .init(
                get: { submoduleToRemove != nil },
                set: { if !$0 { submoduleToRemove = nil } }
            ),
            presenting: submoduleToRemove
        ) { submodule in
            Button("Remove", role: .destructive) {
                Task { await viewModel.deinitSubmodule(submodule, force: true) }
            }
            Button("Cancel", role: .cancel) { }
        } message: { submodule in
            Text("This will remove the submodule '\(submodule.name)' from the working tree.")
        }
        .alert("Submodule Error", isPresented: .init(
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

    @ViewBuilder
    private func submoduleContextMenu(for submodule: Submodule) -> some View {
        if !submodule.isInitialized {
            Button("Initialize") {
                Task {
                    await viewModel.updateSubmodule(submodule)
                }
            }
        } else {
            Button("Update") {
                Task {
                    await viewModel.updateSubmodule(submodule)
                }
            }

            Button("Update from Remote") {
                Task {
                    await viewModel.updateSubmodule(submodule, remote: true)
                }
            }

            Divider()

            Button("Remove", role: .destructive) {
                submoduleToRemove = submodule
            }
        }
    }
}

// MARK: - Header

private struct SubmoduleHeader: View {
    @ObservedObject var viewModel: SubmoduleViewModel
    @Binding var showAddSubmodule: Bool

    var body: some View {
        HStack {
            Text("Submodules")
                .font(.headline)

            Spacer()

            // Status summary
            if viewModel.hasSubmodules {
                Text(viewModel.statusSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Actions menu
            Menu {
                Button(action: { Task { await viewModel.initializeAll() } }) {
                    Label("Initialize All", systemImage: "arrow.down.circle")
                }

                Button(action: { Task { await viewModel.updateAll() } }) {
                    Label("Update All", systemImage: "arrow.clockwise")
                }

                Button(action: { Task { await viewModel.updateAll(remote: true) } }) {
                    Label("Update from Remote", systemImage: "arrow.triangle.2.circlepath")
                }

                Divider()

                Button(action: { Task { await viewModel.syncAll() } }) {
                    Label("Sync URLs", systemImage: "link")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .frame(width: 24)

            Button(action: { showAddSubmodule = true }) {
                Image(systemName: "plus")
            }
            .buttonStyle(.borderless)
            .help("Add submodule")

            if viewModel.isLoading || viewModel.isOperationInProgress {
                ProgressView()
                    .scaleEffect(0.6)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

// MARK: - Submodule Row

private struct SubmoduleRow: View {
    let submodule: Submodule

    var body: some View {
        HStack(spacing: 12) {
            // Status icon
            Image(systemName: submodule.status.iconName)
                .foregroundStyle(statusColor)

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(submodule.name)
                    .font(.body)

                HStack(spacing: 8) {
                    if let commit = submodule.shortCommit {
                        Text(commit)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }

                    if let branch = submodule.branch {
                        Label(branch, systemImage: "arrow.triangle.branch")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            // Status badge
            Text(submodule.status.rawValue)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(statusColor.opacity(0.1))
                .foregroundStyle(statusColor)
                .cornerRadius(4)
        }
        .padding(.vertical, 4)
    }

    private var statusColor: Color {
        switch submodule.status {
        case .upToDate:
            return .green
        case .outOfDate:
            return .orange
        case .modified:
            return .blue
        case .uninitialized:
            return .secondary
        }
    }
}

// MARK: - Add Submodule Sheet

private struct AddSubmoduleSheet: View {
    @Binding var isPresented: Bool
    let onAdd: (String, String, String?) async -> Void

    @State private var url: String = ""
    @State private var path: String = ""
    @State private var branch: String = ""
    @State private var isAdding: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Add Submodule")
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
                    Text("Repository URL")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("https://github.com/user/repo.git", text: $url)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Path")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("libs/mylib", text: $path)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Branch (optional)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("main", text: $branch)
                        .textFieldStyle(.roundedBorder)
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
                    addSubmodule()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(!isValid || isAdding)
            }
            .padding()
        }
        .frame(width: 400)
    }

    private var isValid: Bool {
        !url.isEmpty && !path.isEmpty
    }

    private func addSubmodule() {
        isAdding = true
        let branchArg = branch.isEmpty ? nil : branch

        Task {
            await onAdd(url, path, branchArg)
            isPresented = false
            isAdding = false
        }
    }
}


#Preview {
    SubmoduleListView(
        viewModel: SubmoduleViewModel(
            repository: Repository(rootURL: URL(fileURLWithPath: "/tmp")),
            gitService: GitService()
        )
    )
    .frame(width: 400, height: 300)
}
