import SwiftUI

/// Sidebar sections for navigation.
enum SidebarSection: String, CaseIterable, Identifiable {
    // Workspace
    case changes = "Changes"
    case stashes = "Stashes"
    case fileTree = "Files"

    // Repository
    case history = "History"
    case branches = "Branches"
    case branchesReview = "Branches Review"
    case archivedBranches = "Archived Branches"
    case tags = "Tags"
    case reflog = "Reflog"
    case submodules = "Submodules"
    case worktrees = "Worktrees"

    // Remotes
    case remotes = "Remote"

    // Pull Requests
    case pullRequests = "Pull Requests"

    // GitHub Integration
    case github = "GitHub"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .changes: return "pencil.circle"
        case .history: return "clock"
        case .branches: return "arrow.triangle.branch"
        case .branchesReview: return "eye"
        case .archivedBranches: return "archivebox"
        case .stashes: return "tray.and.arrow.down"
        case .tags: return "tag"
        case .reflog: return "clock.arrow.circlepath"
        case .fileTree: return "folder"
        case .submodules: return "shippingbox"
        case .worktrees: return "rectangle.stack"
        case .remotes: return "arrow.triangle.2.circlepath"
        case .pullRequests: return "arrow.triangle.pull"
        case .github: return "link.circle"
        }
    }

    /// Whether this section should be shown in the sidebar (some may be hidden based on configuration).
    var isMainSection: Bool {
        switch self {
        case .changes, .stashes, .fileTree,
             .history, .branches, .tags, .reflog, .submodules, .worktrees,
             .remotes, .pullRequests,
             .github:
            return true
        case .branchesReview, .archivedBranches:
            return false // These are shown conditionally
        }
    }
}

/// Left sidebar navigation.
/// Supports drag and drop for git operations.
struct Sidebar: View {
    @Binding var selectedSection: SidebarSection
    @ObservedObject var viewModel: RepositoryViewModel

    /// Coordinator for drag and drop operations.
    @StateObject private var dragDropCoordinator = DragDropCoordinator()

    /// State for showing create branch sheet from dropped commit.
    @State private var commitForBranch: DraggableCommit?

    /// State for showing create tag sheet from dropped commit.
    @State private var commitForTag: DraggableCommit?

    var body: some View {
        List(selection: $selectedSection) {
            Section("Workspace") {
                sidebarItem(for: .changes, badge: changesCountBadge)
                    .dropTarget(.workingCopy, coordinator: dragDropCoordinator)
                sidebarItem(for: .stashes, badge: stashCountBadge)
                sidebarItem(for: .fileTree, badge: nil)
            }

            Section("Repository") {
                sidebarItem(for: .history, badge: nil)
                sidebarItem(for: .branches, badge: branchCountBadge)
                    .dropTarget(
                        .branchesHeader,
                        coordinator: dragDropCoordinator,
                        onCommitDropNeedsUI: { commit in
                            commitForBranch = commit
                        }
                    )
                sidebarItem(for: .branchesReview, badge: nil)
                sidebarItem(for: .archivedBranches, badge: archivedBranchCountBadge)
                sidebarItem(for: .tags, badge: tagCountBadge)
                    .dropTarget(
                        .tagsHeader,
                        coordinator: dragDropCoordinator,
                        onCommitDropNeedsUI: { commit in
                            commitForTag = commit
                        }
                    )
                sidebarItem(for: .reflog, badge: nil)
                sidebarItem(for: .submodules, badge: submoduleCountBadge)
                sidebarItem(for: .worktrees, badge: worktreeCountBadge)
            }

            Section("Remote") {
                sidebarItem(for: .remotes, badge: syncBadge)
                    .dropTarget(.remotesSection, coordinator: dragDropCoordinator)
                sidebarItem(for: .pullRequests, badge: prNotificationBadge)
                    .dropTarget(.pullRequests, coordinator: dragDropCoordinator)
            }

            Section("Services") {
                sidebarItem(for: .github, badge: nil)
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 300)
        .onAppear {
            dragDropCoordinator.repositoryViewModel = viewModel
        }
        .sheet(item: $commitForBranch) { commit in
            CreateBranchFromCommitSheet(
                viewModel: viewModel.branchViewModel,
                commitHash: commit.hash,
                commitSubject: commit.subject,
                isPresented: .init(
                    get: { commitForBranch != nil },
                    set: { if !$0 { commitForBranch = nil } }
                )
            )
        }
        .sheet(item: $commitForTag) { commit in
            CreateTagFromCommitSheet(
                viewModel: viewModel.tagViewModel,
                commitHash: commit.hash,
                commitSubject: commit.subject,
                isPresented: .init(
                    get: { commitForTag != nil },
                    set: { if !$0 { commitForTag = nil } }
                )
            )
        }
    }

    @ViewBuilder
    private func sidebarItem(for section: SidebarSection, badge: AnyView?) -> some View {
        Label {
            HStack {
                Text(section.rawValue)
                Spacer()
                if let badge {
                    badge
                }
            }
        } icon: {
            Image(systemName: section.icon)
        }
        .tag(section)
    }

    private var changesCountBadge: AnyView? {
        let count = viewModel.statusViewModel.status.totalChangedFiles
        guard count > 0 else { return nil }
        return AnyView(
            Text("\(count)")
                .font(DSTypography.smallLabel())
                .fontWeight(.medium)
                .padding(.horizontal, DSSpacing.sm)
                .padding(.vertical, DSSpacing.xs)
                .background(DSColors.badgeBackground)
                .clipShape(Capsule())
        )
    }

    private var branchCountBadge: AnyView? {
        let count = viewModel.branchViewModel.localBranchCount
        guard count > 0 else { return nil }
        return AnyView(
            Text("\(count)")
                .font(DSTypography.smallLabel())
                .foregroundStyle(.secondary)
        )
    }

    private var stashCountBadge: AnyView? {
        let count = viewModel.stashViewModel.stashCount
        guard count > 0 else { return nil }
        return AnyView(
            Text("\(count)")
                .font(DSTypography.smallLabel())
                .fontWeight(.medium)
                .padding(.horizontal, DSSpacing.sm)
                .padding(.vertical, DSSpacing.xs)
                .background(DSColors.warningBadgeBackground)
                .clipShape(Capsule())
        )
    }

    private var tagCountBadge: AnyView? {
        let count = viewModel.tagViewModel.tagCount
        guard count > 0 else { return nil }
        return AnyView(
            Text("\(count)")
                .font(DSTypography.smallLabel())
                .foregroundStyle(.secondary)
        )
    }

    private var archivedBranchCountBadge: AnyView? {
        // Archived branch count - would come from BranchViewModel
        return nil
    }

    private var submoduleCountBadge: AnyView? {
        // Submodule count - would come from SubmoduleViewModel
        return nil
    }

    private var worktreeCountBadge: AnyView? {
        // Worktree count - would come from WorktreeViewModel
        return nil
    }

    private var remoteCountBadge: AnyView? {
        // Remote count - would come from RemoteViewModel
        return nil
    }

    private var syncBadge: AnyView? {
        // Shows ahead/behind counts
        let ahead = viewModel.branchViewModel.currentBranchAhead
        let behind = viewModel.branchViewModel.currentBranchBehind
        guard ahead > 0 || behind > 0 else { return nil }

        return AnyView(
            HStack(spacing: 4) {
                if behind > 0 {
                    Text("↓\(behind)")
                        .font(.caption2)
                }
                if ahead > 0 {
                    Text("↑\(ahead)")
                        .font(.caption2)
                }
            }
            .foregroundStyle(.secondary)
        )
    }

    private var prNotificationBadge: AnyView? {
        // PR notification badge - can be implemented later
        return nil
    }

}

// MARK: - Drag and Drop Helper Sheets

/// Sheet for creating a branch from a dropped commit.
struct CreateBranchFromCommitSheet: View {
    @ObservedObject var viewModel: BranchViewModel
    let commitHash: String
    let commitSubject: String
    @Binding var isPresented: Bool

    @State private var branchName: String = ""

    var body: some View {
        VStack(spacing: DSSpacing.lg) {
            Text("Create Branch")
                .font(.headline)

            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                Text("Create a new branch from commit:")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                HStack {
                    Text(String(commitHash.prefix(7)))
                        .fontDesign(.monospaced)
                    Text(commitSubject)
                        .lineLimit(1)
                        .foregroundStyle(.secondary)
                }
                .padding(DSSpacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(DSRadius.sm)

                TextField("Branch name", text: $branchName)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Create Branch") {
                    Task {
                        await viewModel.createBranch(name: branchName, startPoint: commitHash)
                        isPresented = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(branchName.isEmpty || viewModel.isOperationInProgress)
            }
        }
        .padding()
        .frame(width: 400)
    }
}

/// Sheet for creating a tag from a dropped commit.
struct CreateTagFromCommitSheet: View {
    @ObservedObject var viewModel: TagViewModel
    let commitHash: String
    let commitSubject: String
    @Binding var isPresented: Bool

    @State private var tagName: String = ""
    @State private var tagMessage: String = ""

    var body: some View {
        VStack(spacing: DSSpacing.lg) {
            Text("Create Tag")
                .font(.headline)

            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                Text("Create a new tag at commit:")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                HStack {
                    Text(String(commitHash.prefix(7)))
                        .fontDesign(.monospaced)
                    Text(commitSubject)
                        .lineLimit(1)
                        .foregroundStyle(.secondary)
                }
                .padding(DSSpacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(DSRadius.sm)

                TextField("Tag name (e.g., v1.0.0)", text: $tagName)
                    .textFieldStyle(.roundedBorder)

                TextField("Message (optional)", text: $tagMessage)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Create Tag") {
                    Task {
                        if tagMessage.isEmpty {
                            await viewModel.createLightweightTag(name: tagName, commitHash: commitHash)
                        } else {
                            await viewModel.createAnnotatedTag(name: tagName, message: tagMessage, commitHash: commitHash)
                        }
                        isPresented = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(tagName.isEmpty || viewModel.isOperationInProgress)
            }
        }
        .padding()
        .frame(width: 400)
    }
}

#Preview {
    Sidebar(
        selectedSection: .constant(.changes),
        viewModel: RepositoryViewModel(
            repository: Repository(rootURL: URL(fileURLWithPath: "/tmp")),
            gitService: GitService()
        )
    )
    .frame(width: 200)
}
