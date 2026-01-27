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
                    RemoteRow(remote: remote, viewModel: viewModel)
                }
            }
        }
    }
}

/// Row displaying a single remote.
struct RemoteRow: View {
    let remote: Remote
    @ObservedObject var viewModel: RemoteViewModel

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

#Preview {
    let repo = Repository(rootURL: URL(fileURLWithPath: "/tmp"))
    let gitService = GitService()

    return RemoteView(
        viewModel: RemoteViewModel(repository: repo, gitService: gitService),
        branchViewModel: BranchViewModel(repository: repo, gitService: gitService)
    )
    .frame(width: 400, height: 500)
}
