import SwiftUI

/// View for remote operations (fetch, pull, push).
struct RemoteView: View {
    @ObservedObject var viewModel: RemoteViewModel
    @ObservedObject var branchViewModel: BranchViewModel

    @State private var showPullOptions: Bool = false
    @State private var showPushOptions: Bool = false
    @State private var rebaseOnPull: Bool = false
    @State private var forceOnPush: Bool = false
    @State private var setUpstreamOnPush: Bool = false
    @State private var showForcePushConfirmation: Bool = false

    // Remote management state
    @State private var showAddRemoteSheet: Bool = false
    @State private var showEditRemoteSheet: Bool = false
    @State private var showRenameRemoteSheet: Bool = false
    @State private var showDeleteConfirmation: Bool = false
    @State private var selectedRemoteForEdit: Remote?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Sync")
                    .font(DSTypography.sectionTitle())

                Spacer()

                if viewModel.isOperationInProgress {
                    ProgressView()
                        .scaleEffect(0.6)
                }
            }
            .padding(.horizontal, DSSpacing.contentPaddingH)
            .padding(.vertical, DSSpacing.contentPaddingV)

            Divider()

            // Main content
            ScrollView {
                VStack(spacing: DSSpacing.sectionSpacing) {
                    // Status section
                    statusSection

                    Divider()

                    // Quick actions
                    quickActionsSection

                    // Force push warning
                    if forceOnPush {
                        forcePushWarning
                    }

                    Divider()

                    // Remotes list
                    remotesSection
                }
                .padding(DSSpacing.contentPaddingH)
            }

            // Operation message
            if let message = viewModel.operationMessage {
                Divider()
                HStack {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text(message)
                        .font(DSTypography.tertiaryContent())
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, DSSpacing.contentPaddingH)
                .padding(.vertical, DSSpacing.sm)
            }
        }
        .alert("Something went wrong", isPresented: .init(
            get: { viewModel.error != nil },
            set: { if !$0 { viewModel.error = nil } }
        )) {
            Button("Dismiss") { viewModel.error = nil }
        } message: {
            if let error = viewModel.error {
                Text(error.localizedDescription)
            }
        }
        .confirmationDialog(
            "Force Push Warning",
            isPresented: $showForcePushConfirmation,
            titleVisibility: .visible
        ) {
            Button("Force Push to Remote", role: .destructive) {
                Task { await viewModel.push(setUpstream: setUpstreamOnPush, force: true) }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Force pushing will overwrite the remote branch history. This can cause problems for others who have pulled from this branch.\n\nAre you sure you want to continue?")
        }
    }

    // MARK: - Sections

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            Text("Status")
                .font(DSTypography.subsectionTitle())

            HStack {
                if let branch = branchViewModel.currentBranch {
                    Label(branch.name, systemImage: "arrow.triangle.branch")
                        .font(DSTypography.tertiaryContent())

                    if let tracking = branch.upstream {
                        Image(systemName: "arrow.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Text(tracking)
                            .font(DSTypography.tertiaryContent())
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }

            if let lastFetch = viewModel.lastFetchDescription {
                Text("Last fetch: \(lastFetch)")
                    .font(DSTypography.tertiaryContent())
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            Text("Quick Actions")
                .font(DSTypography.subsectionTitle())

            HStack(spacing: DSSpacing.md) {
                // Fetch - safe operation
                Button {
                    Task { await viewModel.fetchAll(prune: true) }
                } label: {
                    Label("Fetch", systemImage: "arrow.down.circle")
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isOperationInProgress)
                .help("Download updates from all remotes (safe, doesn't modify local files)")

                // Pull
                Button {
                    Task { await viewModel.pull(rebase: rebaseOnPull) }
                } label: {
                    Label("Pull", systemImage: "arrow.down.to.line")
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isOperationInProgress)
                .help(rebaseOnPull
                    ? "Pull and rebase local commits on top"
                    : "Pull and merge remote changes")
                .contextMenu {
                    Toggle("Rebase instead of merge", isOn: $rebaseOnPull)
                }

                // Push - with force push protection
                Button {
                    if forceOnPush {
                        showForcePushConfirmation = true
                    } else {
                        Task { await viewModel.push(setUpstream: setUpstreamOnPush, force: false) }
                    }
                } label: {
                    HStack(spacing: DSSpacing.xs) {
                        Label("Push", systemImage: "arrow.up.to.line")
                        if forceOnPush {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(DSColors.warning)
                                .font(.caption)
                        }
                    }
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isOperationInProgress)
                .help(forceOnPush
                    ? "Force push will overwrite remote history (use with caution)"
                    : "Push local commits to remote")
                .contextMenu {
                    Toggle("Set upstream tracking", isOn: $setUpstreamOnPush)
                    Divider()
                    Toggle(isOn: $forceOnPush) {
                        Label("Force push (dangerous)", systemImage: "exclamationmark.triangle")
                    }
                }
            }
        }
    }

    /// Warning banner shown when force push is enabled
    private var forcePushWarning: some View {
        HStack(alignment: .top, spacing: DSSpacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(DSColors.warning)

            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                Text("Force Push Enabled")
                    .font(DSTypography.secondaryContent())
                    .fontWeight(.medium)

                Text("Force pushing rewrites remote history and can cause issues for collaborators. Use only when you're certain no one else is working on this branch.")
                    .font(DSTypography.tertiaryContent())
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Disable") {
                forceOnPush = false
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(DSSpacing.md)
        .background(DSColors.warningBadgeBackground)
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.md))
    }

    private var remotesSection: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            HStack {
                Text("Remotes")
                    .font(DSTypography.subsectionTitle())

                Spacer()

                Button {
                    showAddRemoteSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                .help("Add a new remote")

                Button {
                    Task { await viewModel.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .disabled(viewModel.isLoading)
                .help("Refresh remote list")
            }

            if viewModel.remotes.isEmpty && !viewModel.isLoading {
                EmptyStateView(
                    "No Remotes",
                    systemImage: "server.rack",
                    description: "Add a remote to sync with a server"
                )
                .frame(height: 120)
            } else {
                ForEach(viewModel.remotes) { remote in
                    RemoteRow(
                        remote: remote,
                        viewModel: viewModel,
                        onEdit: {
                            selectedRemoteForEdit = remote
                            showEditRemoteSheet = true
                        },
                        onRename: {
                            selectedRemoteForEdit = remote
                            showRenameRemoteSheet = true
                        },
                        onDelete: {
                            selectedRemoteForEdit = remote
                            showDeleteConfirmation = true
                        }
                    )
                }
            }
        }
        .sheet(isPresented: $showAddRemoteSheet) {
            AddRemoteSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $showEditRemoteSheet) {
            if let remote = selectedRemoteForEdit {
                EditRemoteURLSheet(viewModel: viewModel, remote: remote)
            }
        }
        .sheet(isPresented: $showRenameRemoteSheet) {
            if let remote = selectedRemoteForEdit {
                RenameRemoteSheet(viewModel: viewModel, remote: remote)
            }
        }
        .confirmationDialog(
            "Remove Remote",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Remove \(selectedRemoteForEdit?.name ?? "Remote")", role: .destructive) {
                if let remote = selectedRemoteForEdit {
                    Task { await viewModel.removeRemote(name: remote.name) }
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to remove this remote? This will not delete any remote branches that have already been fetched.")
        }
    }
}

/// Row displaying a single remote.
struct RemoteRow: View {
    let remote: Remote
    @ObservedObject var viewModel: RemoteViewModel
    var onEdit: () -> Void = {}
    var onRename: () -> Void = {}
    var onDelete: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            HStack {
                Image(systemName: "server.rack")
                    .foregroundStyle(DSColors.info)

                Text(remote.name)
                    .font(DSTypography.primaryContent())
                    .fontWeight(.medium)

                Spacer()

                Menu {
                    Button {
                        Task { await viewModel.fetch(remote: remote.name, prune: true) }
                    } label: {
                        Label("Fetch from \(remote.name)", systemImage: "arrow.down.circle")
                    }

                    Divider()

                    Button {
                        onEdit()
                    } label: {
                        Label("Change URL...", systemImage: "link")
                    }

                    Button {
                        onRename()
                    } label: {
                        Label("Rename...", systemImage: "pencil")
                    }

                    Divider()

                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Label("Remove Remote", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .buttonStyle(.borderless)
            }

            Text(remote.fetchURL)
                .font(DSTypography.code(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(DSSpacing.sm)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.md))
    }
}

// MARK: - Add Remote Sheet

/// Sheet for adding a new remote.
struct AddRemoteSheet: View {
    @ObservedObject var viewModel: RemoteViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var remoteName: String = ""
    @State private var remoteURL: String = ""

    private var isValid: Bool {
        !remoteName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !remoteURL.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Add Remote")
                    .font(.headline)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
            }
            .padding()

            Divider()

            // Form
            Form {
                TextField("Name", text: $remoteName, prompt: Text("origin"))
                    .textFieldStyle(.roundedBorder)

                TextField("URL", text: $remoteURL, prompt: Text("https://github.com/user/repo.git"))
                    .textFieldStyle(.roundedBorder)

                Text("Enter the remote repository URL. This can be HTTPS or SSH format.")
                    .font(DSTypography.tertiaryContent())
                    .foregroundStyle(.secondary)
            }
            .formStyle(.grouped)
            .padding()

            Divider()

            // Actions
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Add Remote") {
                    Task {
                        await viewModel.addRemote(
                            name: remoteName.trimmingCharacters(in: .whitespaces),
                            url: remoteURL.trimmingCharacters(in: .whitespaces)
                        )
                        dismiss()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid || viewModel.isOperationInProgress)
            }
            .padding()
        }
        .frame(width: 400)
    }
}

// MARK: - Edit Remote URL Sheet

/// Sheet for editing a remote's URL.
struct EditRemoteURLSheet: View {
    @ObservedObject var viewModel: RemoteViewModel
    let remote: Remote
    @Environment(\.dismiss) private var dismiss

    @State private var newURL: String = ""

    private var isValid: Bool {
        !newURL.trimmingCharacters(in: .whitespaces).isEmpty &&
        newURL.trimmingCharacters(in: .whitespaces) != remote.fetchURL
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Change Remote URL")
                    .font(.headline)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
            }
            .padding()

            Divider()

            // Form
            Form {
                LabeledContent("Remote") {
                    Text(remote.name)
                        .fontWeight(.medium)
                }

                TextField("New URL", text: $newURL, prompt: Text(remote.fetchURL))
                    .textFieldStyle(.roundedBorder)

                Text("Current: \(remote.fetchURL)")
                    .font(DSTypography.tertiaryContent())
                    .foregroundStyle(.secondary)
            }
            .formStyle(.grouped)
            .padding()

            Divider()

            // Actions
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Update URL") {
                    Task {
                        await viewModel.setRemoteURL(
                            name: remote.name,
                            url: newURL.trimmingCharacters(in: .whitespaces)
                        )
                        dismiss()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid || viewModel.isOperationInProgress)
            }
            .padding()
        }
        .frame(width: 450)
        .onAppear {
            newURL = remote.fetchURL
        }
    }
}

// MARK: - Rename Remote Sheet

/// Sheet for renaming a remote.
struct RenameRemoteSheet: View {
    @ObservedObject var viewModel: RemoteViewModel
    let remote: Remote
    @Environment(\.dismiss) private var dismiss

    @State private var newName: String = ""

    private var isValid: Bool {
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        return !trimmed.isEmpty && trimmed != remote.name
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Rename Remote")
                    .font(.headline)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
            }
            .padding()

            Divider()

            // Form
            Form {
                LabeledContent("Current Name") {
                    Text(remote.name)
                        .fontWeight(.medium)
                }

                TextField("New Name", text: $newName, prompt: Text("origin"))
                    .textFieldStyle(.roundedBorder)
            }
            .formStyle(.grouped)
            .padding()

            Divider()

            // Actions
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Rename") {
                    Task {
                        await viewModel.renameRemote(
                            oldName: remote.name,
                            newName: newName.trimmingCharacters(in: .whitespaces)
                        )
                        dismiss()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid || viewModel.isOperationInProgress)
            }
            .padding()
        }
        .frame(width: 350)
        .onAppear {
            newName = remote.name
        }
    }
}

#Preview {
    let repo = Repository(rootURL: URL(fileURLWithPath: "/tmp"))
    let gitService = GitService()

    return RemoteView(
        viewModel: RemoteViewModel(repository: repo, gitService: gitService),
        branchViewModel: BranchViewModel(repository: repo, gitService: gitService)
    )
    .frame(width: 400, height: 500)
}
