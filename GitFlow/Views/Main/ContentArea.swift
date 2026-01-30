import SwiftUI
import WebKit

/// Main content area that displays the selected section.
struct ContentArea: View {
    let selectedSection: SidebarSection
    @ObservedObject var viewModel: RepositoryViewModel

    var body: some View {
        switch selectedSection {
        case .changes:
            ChangesView(
                statusViewModel: viewModel.statusViewModel,
                diffViewModel: viewModel.diffViewModel,
                commitViewModel: viewModel.commitViewModel
            )
        case .history:
            HistoryView(
                historyViewModel: viewModel.historyViewModel,
                diffViewModel: viewModel.diffViewModel
            )
        case .branches:
            BranchesView(viewModel: viewModel.branchViewModel)
        case .branchesReview:
            BranchesReviewSectionView(viewModel: viewModel)
        case .archivedBranches:
            ArchivedBranchesSectionView(viewModel: viewModel)
        case .stashes:
            StashesView(viewModel: viewModel.stashViewModel)
        case .tags:
            TagsView(viewModel: viewModel.tagViewModel)
        case .reflog:
            ReflogSectionView(viewModel: viewModel)
        case .fileTree:
            FileTreeSectionView(viewModel: viewModel)
        case .submodules:
            SubmoduleSectionView(viewModel: viewModel)
        case .worktrees:
            WorktreesSectionView(viewModel: viewModel)
        case .remotes:
            RemoteView(
                viewModel: viewModel.remoteViewModel,
                branchViewModel: viewModel.branchViewModel
            )
        case .pullRequests:
            PullRequestsSectionView(viewModel: viewModel)
        case .github:
            GitHubSectionView(viewModel: viewModel)
        }
    }
}

/// Wrapper view for file tree browser.
struct FileTreeSectionView: View {
    @ObservedObject var viewModel: RepositoryViewModel
    @StateObject private var fileTreeViewModel: FileTreeViewModel

    init(viewModel: RepositoryViewModel) {
        self.viewModel = viewModel
        self._fileTreeViewModel = StateObject(wrappedValue: FileTreeViewModel(
            repository: viewModel.repository,
            gitService: viewModel.gitService
        ))
    }

    var body: some View {
        FileTreeView(viewModel: fileTreeViewModel)
            .task {
                await fileTreeViewModel.loadTree()
            }
    }
}

/// Wrapper view for submodules.
struct SubmoduleSectionView: View {
    @ObservedObject var viewModel: RepositoryViewModel
    @StateObject private var submoduleViewModel: SubmoduleViewModel

    init(viewModel: RepositoryViewModel) {
        self.viewModel = viewModel
        self._submoduleViewModel = StateObject(wrappedValue: SubmoduleViewModel(
            repository: viewModel.repository,
            gitService: viewModel.gitService
        ))
    }

    var body: some View {
        SubmoduleListView(viewModel: submoduleViewModel)
            .task {
                await submoduleViewModel.refresh()
            }
    }
}

/// Wrapper view for GitHub integration.
struct GitHubSectionView: View {
    @ObservedObject var viewModel: RepositoryViewModel
    @StateObject private var githubViewModel: GitHubViewModel

    init(viewModel: RepositoryViewModel) {
        self.viewModel = viewModel
        self._githubViewModel = StateObject(wrappedValue: GitHubViewModel(
            repository: viewModel.repository,
            gitService: viewModel.gitService
        ))
    }

    var body: some View {
        GitHubView(viewModel: githubViewModel)
    }
}

/// Combined view for working tree changes, staging, and commit creation.
struct ChangesView: View {
    @ObservedObject var statusViewModel: StatusViewModel
    @ObservedObject var diffViewModel: DiffViewModel
    @ObservedObject var commitViewModel: CommitViewModel

    @State private var isDiffFullscreen: Bool = false

    var body: some View {
        HSplitView {
            // Left panel: File list and commit
            if !isDiffFullscreen {
                VStack(spacing: 0) {
                    FileStatusList(viewModel: statusViewModel)

                    Divider()

                    CommitCreationView(
                        viewModel: commitViewModel,
                        canCommit: statusViewModel.canCommit
                    )
                }
                .frame(minWidth: 250, maxWidth: 350)
            }

            // Right panel: Diff view
            DiffView(viewModel: diffViewModel, isFullscreen: $isDiffFullscreen)
                .frame(minWidth: 400)
        }
    }
}

/// View for commit history.
struct HistoryView: View {
    @ObservedObject var historyViewModel: HistoryViewModel
    @ObservedObject var diffViewModel: DiffViewModel

    @State private var isDiffFullscreen: Bool = false

    var body: some View {
        HSplitView {
            // Left: Commit list
            if !isDiffFullscreen {
                CommitHistoryView(viewModel: historyViewModel)
                    .frame(minWidth: 300, maxWidth: 400)
            }

            // Right: Commit diff or details
            VStack {
                if let commit = historyViewModel.selectedCommit {
                    if !isDiffFullscreen {
                        CommitDetailView(commit: commit)
                            .frame(height: 150)

                        Divider()
                    }

                    DiffView(viewModel: diffViewModel, isFullscreen: $isDiffFullscreen)
                } else {
                    EmptyStateView(
                        "Select a Commit",
                        systemImage: "clock",
                        description: "Select a commit from the list to view its changes"
                    )
                }
            }
            .frame(minWidth: 400)
            .task(id: historyViewModel.selectedCommit?.hash) {
                if let commit = historyViewModel.selectedCommit {
                    await diffViewModel.loadCommitDiff(for: commit.hash)
                }
            }
        }
    }
}

/// View for branch management.
struct BranchesView: View {
    @ObservedObject var viewModel: BranchViewModel

    var body: some View {
        BranchListView(viewModel: viewModel)
    }
}

/// View for stash management.
struct StashesView: View {
    @ObservedObject var viewModel: StashViewModel

    var body: some View {
        StashListView(viewModel: viewModel)
    }
}

/// View for tag management.
struct TagsView: View {
    @ObservedObject var viewModel: TagViewModel

    var body: some View {
        TagListView(viewModel: viewModel)
    }
}

/// Wrapper view for reflog.
struct ReflogSectionView: View {
    @ObservedObject var viewModel: RepositoryViewModel
    @StateObject private var reflogViewModel: ReflogViewModel

    init(viewModel: RepositoryViewModel) {
        self.viewModel = viewModel
        self._reflogViewModel = StateObject(wrappedValue: ReflogViewModel(
            repository: viewModel.repository,
            gitService: viewModel.gitService
        ))
    }

    var body: some View {
        ReflogView(viewModel: reflogViewModel)
            .task {
                await reflogViewModel.refresh()
            }
    }
}

/// Wrapper view for branches review.
struct BranchesReviewSectionView: View {
    @ObservedObject var viewModel: RepositoryViewModel

    var body: some View {
        BranchesReviewView(viewModel: viewModel.branchViewModel)
    }
}

/// Wrapper view for archived branches.
struct ArchivedBranchesSectionView: View {
    @ObservedObject var viewModel: RepositoryViewModel

    var body: some View {
        ArchivedBranchesView(viewModel: viewModel.branchViewModel)
    }
}

/// Wrapper view for worktrees.
struct WorktreesSectionView: View {
    @ObservedObject var viewModel: RepositoryViewModel

    var body: some View {
        WorktreeView(repository: viewModel.repository)
    }
}

/// Wrapper view for pull requests (unified across services).
struct PullRequestsSectionView: View {
    @ObservedObject var viewModel: RepositoryViewModel
    @StateObject private var githubViewModel: GitHubViewModel

    init(viewModel: RepositoryViewModel) {
        self.viewModel = viewModel
        self._githubViewModel = StateObject(wrappedValue: GitHubViewModel(
            repository: viewModel.repository,
            gitService: viewModel.gitService
        ))
    }

    var body: some View {
        UnifiedPullRequestsView(repository: viewModel.repository)
            .task {
                await githubViewModel.initialize()
                await githubViewModel.loadPullRequests()
            }
    }
}

// MARK: - Placeholder Views for new sections

/// Branches review view showing stale branches, merge status, etc.
struct BranchesReviewView: View {
    @ObservedObject var viewModel: BranchViewModel

    var body: some View {
        VStack {
            Text("Branches Review")
                .font(.title2)
                .padding()

            List {
                Section("Stale Branches") {
                    ForEach(viewModel.staleBranches, id: \.name) { branch in
                        HStack {
                            Image(systemName: "clock.badge.exclamationmark")
                                .foregroundColor(.orange)
                            Text(branch.name)
                            Spacer()
                            Text("Last activity: \(branch.lastCommitDate?.formatted(.relative(presentation: .named)) ?? "Unknown")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Section("Merged Branches") {
                    ForEach(viewModel.mergedBranches, id: \.name) { branch in
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text(branch.name)
                            Spacer()
                            Button("Delete") {
                                Task { await viewModel.deleteBranch(name: branch.name, force: false) }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }
            }
        }
    }
}

/// Archived branches view.
struct ArchivedBranchesView: View {
    @ObservedObject var viewModel: BranchViewModel

    var body: some View {
        VStack {
            if viewModel.archivedBranches.isEmpty {
                EmptyStateView(
                    "No Archived Branches",
                    systemImage: "archivebox",
                    description: "Archive branches you want to keep but hide from the main list"
                )
            } else {
                List(viewModel.archivedBranches, id: \.name) { branch in
                    HStack {
                        Image(systemName: "archivebox")
                            .foregroundColor(.secondary)
                        Text(branch.name)
                        Spacer()
                        Button("Unarchive") {
                            Task { await viewModel.unarchiveBranch(branch.name) }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .contextMenu {
                        Button("Unarchive") {
                            Task { await viewModel.unarchiveBranch(branch.name) }
                        }
                        Button("Delete", role: .destructive) {
                            Task { await viewModel.deleteBranch(name: branch.name, force: true) }
                        }
                    }
                }
            }
        }
    }
}

/// GitHub pull requests view.
struct UnifiedPullRequestsView: View {
    let repository: Repository

    @StateObject private var viewModel: GitHubPullRequestsViewModel
    @State private var localStateFilter: GitHubPRState = .open

    init(repository: Repository) {
        self.repository = repository
        self._viewModel = StateObject(wrappedValue: GitHubPullRequestsViewModel(repository: repository))
    }

    var body: some View {
        HSplitView {
            // PR List sidebar
            prListSidebar
                .frame(minWidth: 300, maxWidth: 400)

            // Detail view
            detailView
                .frame(minWidth: 400)
        }
        .task {
            await viewModel.loadPullRequests()
        }
    }

    private var prListSidebar: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Pull Requests")
                    .font(.headline)
                Spacer()
                if viewModel.isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
                Button {
                    Task { await viewModel.loadPullRequests() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Refresh pull requests")
                .disabled(viewModel.isLoading)
            }
            .padding()

            Divider()

            // State filter
            Picker("State", selection: $localStateFilter) {
                Text("Open").tag(GitHubPRState.open)
                Text("Closed").tag(GitHubPRState.closed)
                Text("All").tag(GitHubPRState.all)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)
            .onChange(of: localStateFilter) { newValue in
                Task { @MainActor in
                    viewModel.stateFilter = newValue
                }
            }

            Divider()

            // PR List
            if viewModel.hasNoPRs && !viewModel.isLoading {
                emptyState
            } else {
                prList
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "arrow.triangle.pull")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No Pull Requests")
                .font(.headline)
            Text(!viewModel.isConnected
                ? "Connect to GitHub in Settings to view pull requests."
                : "No pull requests found for the current filter.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding()
    }

    private var prList: some View {
        List(selection: $viewModel.selectedPR) {
            Section {
                ForEach(viewModel.filteredPullRequests) { pr in
                    GitHubPRRow(pr: pr)
                        .tag(pr)
                }
            } header: {
                HStack {
                    Image(systemName: "link.circle")
                    Text("GitHub")
                    Text("(\(viewModel.filteredPullRequests.count))")
                        .foregroundStyle(.secondary)
                    if viewModel.isLoading {
                        ProgressView()
                            .controlSize(.mini)
                    }
                }
            }
        }
        .listStyle(.inset)
    }

    @ViewBuilder
    private var detailView: some View {
        if let selectedPR = viewModel.selectedPR {
            GitHubPRDetailView(
                pr: selectedPR,
                repository: repository,
                viewModel: viewModel
            )
        } else {
            VStack {
                Spacer()
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("Select a Pull Request")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text("Choose a pull request from the list to view its details and diff.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - GitHub PR Types

enum GitHubPRState: String, CaseIterable {
    case open, closed, all
}

// MARK: - GitHub PR Row

struct GitHubPRRow: View {
    let pr: GitHubPullRequest

    var body: some View {
        HStack(spacing: 8) {
            // Status icon
            Image(systemName: pr.state == "open" ? "arrow.triangle.pull" : "checkmark.circle")
                .foregroundStyle(pr.state == "open" ? .green : .purple)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text("#\(pr.number)")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                    Text(pr.title)
                        .lineLimit(1)
                }

                HStack(spacing: 8) {
                    Text(pr.user.login)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 4) {
                        Text(pr.head.ref)
                            .font(.caption2.monospaced())
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(3)

                        Image(systemName: "arrow.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)

                        Text(pr.base.ref)
                            .font(.caption2.monospaced())
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(3)
                    }
                }
            }

            Spacer()

            if pr.isDraft {
                Text("Draft")
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(4)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - GitHub PR Detail View

struct GitHubPRDetailView: View {
    let pr: GitHubPullRequest
    let repository: Repository
    @ObservedObject var viewModel: GitHubPullRequestsViewModel

    @State private var selectedTab: DetailTab = .diff
    @State private var showCommentSheet = false
    @State private var showReviewSheet = false
    @State private var showMergeSheet = false
    @State private var showCloseConfirmation = false
    @State private var actionError: String?
    @State private var isPerformingAction = false

    enum DetailTab: String, CaseIterable {
        case diff = "Changes"
        case description = "Description"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            prHeader

            // Action buttons for open PRs
            if pr.state == "open" {
                Divider()
                prActions
            }

            Divider()

            // Tab picker
            Picker("Tab", selection: $selectedTab) {
                ForEach(DetailTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            Divider()

            // Content
            switch selectedTab {
            case .diff:
                diffView
            case .description:
                descriptionView
            }
        }
        .sheet(isPresented: $showCommentSheet) {
            GitHubPRCommentSheet(pr: pr, viewModel: viewModel, onDismiss: { showCommentSheet = false })
        }
        .sheet(isPresented: $showReviewSheet) {
            GitHubPRReviewSheet(pr: pr, viewModel: viewModel, onDismiss: { showReviewSheet = false })
        }
        .sheet(isPresented: $showMergeSheet) {
            GitHubPRMergeSheet(pr: pr, viewModel: viewModel, onDismiss: { showMergeSheet = false })
        }
        .alert("Close Pull Request?", isPresented: $showCloseConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Close", role: .destructive) {
                Task {
                    await viewModel.closePR(pr)
                }
            }
        } message: {
            Text("This will close the pull request without merging. This action can usually be undone.")
        }
        .alert("Action Failed", isPresented: .init(
            get: { actionError != nil },
            set: { if !$0 { actionError = nil } }
        )) {
            Button("OK") { actionError = nil }
        } message: {
            if let error = actionError {
                Text(error)
            }
        }
    }

    private var prHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "link.circle")
                    .foregroundStyle(.blue)
                Text("GitHub")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if let webURL = URL(string: pr.htmlUrl) {
                    Link(destination: webURL) {
                        HStack(spacing: 4) {
                            Text("Open in Browser")
                                .font(.caption)
                            Image(systemName: "arrow.up.right.square")
                                .font(.caption)
                        }
                    }
                    .buttonStyle(.borderless)
                }
            }

            HStack(alignment: .top) {
                Image(systemName: pr.state == "open" ? "arrow.triangle.pull" : "checkmark.circle.fill")
                    .foregroundStyle(pr.state == "open" ? .green : .purple)
                    .font(.title2)

                VStack(alignment: .leading, spacing: 4) {
                    Text(pr.title)
                        .font(.headline)

                    HStack(spacing: 8) {
                        Text("#\(pr.number)")
                            .font(.subheadline.monospaced())
                            .foregroundStyle(.secondary)

                        Text("by \(pr.user.login)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        if pr.isDraft {
                            Text("Draft")
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.2))
                                .foregroundStyle(.orange)
                                .cornerRadius(4)
                        }
                    }

                    HStack(spacing: 4) {
                        Text(pr.head.ref)
                            .font(.caption.monospaced())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(4)

                        Image(systemName: "arrow.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(pr.base.ref)
                            .font(.caption.monospaced())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
            }
        }
        .padding()
    }

    private var prActions: some View {
        HStack(spacing: 12) {
            // Comment button
            Button {
                showCommentSheet = true
            } label: {
                Label("Comment", systemImage: "text.bubble")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            // Review button
            Button {
                showReviewSheet = true
            } label: {
                Label("Review", systemImage: "checkmark.circle")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Spacer()

            // Close button
            Button {
                showCloseConfirmation = true
            } label: {
                Label("Close", systemImage: "xmark.circle")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .tint(.red)

            // Merge button
            Button {
                showMergeSheet = true
            } label: {
                Label("Merge", systemImage: "arrow.triangle.merge")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .tint(.green)
            .disabled(pr.isDraft)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
    }

    @ViewBuilder
    private var diffView: some View {
        GitHubPRDiffView(pr: pr, repository: repository, viewModel: viewModel)
    }

    private var descriptionView: some View {
        Group {
            if let description = pr.body, !description.isEmpty {
                MarkdownContentView(markdown: description)
            } else {
                VStack {
                    Spacer()
                    Text("No description provided.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .italic()
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

// MARK: - PR Comment Sheet

struct GitHubPRCommentSheet: View {
    let pr: GitHubPullRequest
    @ObservedObject var viewModel: GitHubPullRequestsViewModel
    let onDismiss: () -> Void

    @State private var commentText = ""
    @State private var isSubmitting = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Add Comment")
                    .font(.headline)
                Spacer()
                Button("Cancel") {
                    onDismiss()
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // Comment input
            VStack(alignment: .leading, spacing: 8) {
                Text("Comment on GitHub #\(pr.number)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                TextEditor(text: $commentText)
                    .font(.body)
                    .frame(minHeight: 150)
                    .border(Color(NSColor.separatorColor), width: 1)
            }
            .padding()

            if let error = error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }

            Divider()

            // Actions
            HStack {
                Spacer()
                Button("Cancel") {
                    onDismiss()
                }
                .keyboardShortcut(.escape)

                Button("Submit Comment") {
                    submitComment()
                }
                .buttonStyle(.borderedProminent)
                .disabled(commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
                .keyboardShortcut(.return, modifiers: .command)
            }
            .padding()
        }
        .frame(width: 500, height: 350)
    }

    private func submitComment() {
        isSubmitting = true
        error = nil

        Task {
            do {
                try await viewModel.addComment(to: pr, body: commentText)
                onDismiss()
            } catch {
                self.error = error.localizedDescription
            }
            isSubmitting = false
        }
    }
}

// MARK: - PR Review Sheet

struct GitHubPRReviewSheet: View {
    let pr: GitHubPullRequest
    @ObservedObject var viewModel: GitHubPullRequestsViewModel
    let onDismiss: () -> Void

    @State private var reviewBody = ""
    @State private var reviewAction: ReviewAction = .comment
    @State private var isSubmitting = false
    @State private var error: String?

    enum ReviewAction: String, CaseIterable {
        case approve = "Approve"
        case requestChanges = "Request Changes"
        case comment = "Comment"

        var icon: String {
            switch self {
            case .approve: return "checkmark.circle.fill"
            case .requestChanges: return "exclamationmark.circle.fill"
            case .comment: return "text.bubble"
            }
        }

        var color: Color {
            switch self {
            case .approve: return .green
            case .requestChanges: return .red
            case .comment: return .blue
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Submit Review")
                    .font(.headline)
                Spacer()
                Button("Cancel") {
                    onDismiss()
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            VStack(alignment: .leading, spacing: 16) {
                // Review type picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Review Action")
                        .font(.subheadline.bold())

                    HStack(spacing: 12) {
                        ForEach(ReviewAction.allCases, id: \.self) { action in
                            Button {
                                reviewAction = action
                            } label: {
                                HStack {
                                    Image(systemName: action.icon)
                                        .foregroundStyle(action.color)
                                    Text(action.rawValue)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(reviewAction == action ? action.color.opacity(0.15) : Color.clear)
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(reviewAction == action ? action.color : Color.clear, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Review comment
                VStack(alignment: .leading, spacing: 8) {
                    Text("Review Comment \(reviewAction == .comment ? "(required)" : "(optional)")")
                        .font(.subheadline.bold())

                    TextEditor(text: $reviewBody)
                        .font(.body)
                        .frame(minHeight: 120)
                        .border(Color(NSColor.separatorColor), width: 1)
                }
            }
            .padding()

            if let error = error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }

            Divider()

            // Actions
            HStack {
                Spacer()
                Button("Cancel") {
                    onDismiss()
                }
                .keyboardShortcut(.escape)

                Button {
                    submitReview()
                } label: {
                    HStack {
                        Image(systemName: reviewAction.icon)
                        Text("Submit \(reviewAction.rawValue)")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(reviewAction.color)
                .disabled(isSubmitting || (reviewAction == .comment && reviewBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
                .keyboardShortcut(.return, modifiers: .command)
            }
            .padding()
        }
        .frame(width: 550, height: 420)
    }

    private func submitReview() {
        isSubmitting = true
        error = nil

        Task {
            do {
                try await viewModel.submitReview(
                    to: pr,
                    action: reviewAction,
                    body: reviewBody.isEmpty ? nil : reviewBody
                )
                onDismiss()
            } catch {
                self.error = error.localizedDescription
            }
            isSubmitting = false
        }
    }
}

// MARK: - PR Merge Sheet

struct GitHubPRMergeSheet: View {
    let pr: GitHubPullRequest
    @ObservedObject var viewModel: GitHubPullRequestsViewModel
    let onDismiss: () -> Void

    @State private var mergeMethod: MergeMethod = .merge
    @State private var commitTitle = ""
    @State private var commitMessage = ""
    @State private var deleteSourceBranch = false
    @State private var isSubmitting = false
    @State private var error: String?

    enum MergeMethod: String, CaseIterable {
        case merge = "Merge Commit"
        case squash = "Squash and Merge"
        case rebase = "Rebase and Merge"

        var description: String {
            switch self {
            case .merge: return "All commits will be added to the base branch via a merge commit."
            case .squash: return "All commits will be combined into one commit in the base branch."
            case .rebase: return "All commits will be rebased and added to the base branch."
            }
        }

        var icon: String {
            switch self {
            case .merge: return "arrow.triangle.merge"
            case .squash: return "square.stack.3d.up"
            case .rebase: return "arrow.triangle.branch"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Merge Pull Request")
                    .font(.headline)
                Spacer()
                Button("Cancel") {
                    onDismiss()
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // PR info
                    HStack {
                        Image(systemName: "arrow.triangle.pull")
                            .foregroundStyle(.green)
                        Text("#\(pr.number)")
                            .fontWeight(.semibold)
                        Text(pr.title)
                            .lineLimit(1)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)

                    // Merge method picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Merge Method")
                            .font(.subheadline.bold())

                        ForEach(MergeMethod.allCases, id: \.self) { method in
                            Button {
                                mergeMethod = method
                            } label: {
                                HStack {
                                    Image(systemName: mergeMethod == method ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(mergeMethod == method ? .green : .secondary)

                                    Image(systemName: method.icon)
                                        .frame(width: 20)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(method.rawValue)
                                            .fontWeight(.medium)
                                        Text(method.description)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()
                                }
                                .padding(10)
                                .background(mergeMethod == method ? Color.green.opacity(0.1) : Color.clear)
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Commit details (for squash/merge)
                    if mergeMethod != .rebase {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Commit Title")
                                .font(.subheadline.bold())

                            TextField("Merge pull request #\(pr.number)", text: $commitTitle)
                                .textFieldStyle(.roundedBorder)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Commit Message (optional)")
                                .font(.subheadline.bold())

                            TextEditor(text: $commitMessage)
                                .font(.body)
                                .frame(height: 80)
                                .border(Color(NSColor.separatorColor), width: 1)
                        }
                    }

                    // Delete source branch option
                    Toggle(isOn: $deleteSourceBranch) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Delete source branch")
                                .fontWeight(.medium)
                            Text("Delete '\(pr.head.ref)' after merging")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .toggleStyle(.checkbox)
                }
                .padding()
            }

            if let error = error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }

            Divider()

            // Actions
            HStack {
                Spacer()
                Button("Cancel") {
                    onDismiss()
                }
                .keyboardShortcut(.escape)

                Button {
                    performMerge()
                } label: {
                    HStack {
                        if isSubmitting {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Image(systemName: "arrow.triangle.merge")
                        Text("Confirm Merge")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(isSubmitting)
                .keyboardShortcut(.return, modifiers: .command)
            }
            .padding()
        }
        .frame(width: 550, height: 580)
        .onAppear {
            // Set default commit title
            commitTitle = "Merge pull request #\(pr.number) from \(pr.head.ref)"
        }
    }

    private func performMerge() {
        isSubmitting = true
        error = nil

        Task {
            do {
                try await viewModel.mergePR(
                    pr,
                    method: mergeMethod,
                    title: commitTitle.isEmpty ? nil : commitTitle,
                    message: commitMessage.isEmpty ? nil : commitMessage,
                    deleteSourceBranch: deleteSourceBranch
                )
                onDismiss()
            } catch {
                self.error = error.localizedDescription
            }
            isSubmitting = false
        }
    }
}

// MARK: - GitHub PR Diff View

struct GitHubPRDiffView: View {
    let pr: GitHubPullRequest
    let repository: Repository
    @ObservedObject var viewModel: GitHubPullRequestsViewModel

    @State private var files: [PRFileItem] = []
    @State private var selectedFile: PRFileItem?
    @State private var isLoading = false
    @State private var error: String?

    // Diff settings
    @State private var isFullscreen = false
    @State private var showLineNumbers = true
    @State private var wrapLines = false
    @State private var showSearch = false
    @State private var searchText = ""

    var body: some View {
        HSplitView {
            // Files list (hidden in fullscreen)
            if !isFullscreen {
                VStack(spacing: 0) {
                    HStack {
                        Text("Files")
                            .font(.caption.bold())
                        Text("(\(files.count))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)

                    Divider()

                    if isLoading && files.isEmpty {
                        Spacer()
                        ProgressView()
                            .controlSize(.small)
                        Spacer()
                    } else if let error = error {
                        Spacer()
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding()
                        Spacer()
                    } else if files.isEmpty {
                        Spacer()
                        Text("No files changed")
                            .foregroundStyle(.secondary)
                        Spacer()
                    } else {
                        List(files, selection: $selectedFile) { file in
                            PRFileItemRow(file: file)
                                .tag(file)
                        }
                        .listStyle(.inset)
                    }

                    if !files.isEmpty {
                        Divider()
                        HStack(spacing: 8) {
                            Text("+\(totalAdditions)")
                                .foregroundStyle(.green)
                                .font(.caption2)
                            Text("-\(totalDeletions)")
                                .foregroundStyle(.red)
                                .font(.caption2)
                        }
                        .padding(6)
                    }
                }
                .frame(minWidth: 180, maxWidth: 220)
            }

            // Diff content
            VStack(spacing: 0) {
                if let file = selectedFile {
                    fileDiffView(for: file)
                } else {
                    Spacer()
                    Text("Select a file to view diff")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
        }
        .onAppear {
            loadFiles()
        }
        .onChange(of: pr.id) { _ in
            files = []
            selectedFile = nil
            loadFiles()
        }
    }

    private var totalAdditions: Int {
        files.reduce(0) { $0 + $1.additions }
    }

    private var totalDeletions: Int {
        files.reduce(0) { $0 + $1.deletions }
    }

    private func loadFiles() {
        isLoading = true
        error = nil

        Task {
            do {
                files = try await viewModel.loadFilesForPR(pr)
                isLoading = false
            } catch {
                self.error = error.localizedDescription
                isLoading = false
            }
        }
    }

    @ViewBuilder
    private func fileDiffView(for file: PRFileItem) -> some View {
        VStack(spacing: 0) {
            // Toolbar
            PRDiffToolbar(
                file: file,
                showLineNumbers: $showLineNumbers,
                wrapLines: $wrapLines,
                showSearch: $showSearch,
                isFullscreen: $isFullscreen
            )

            Divider()

            // Search bar
            if showSearch {
                PRDiffSearchBar(
                    searchText: $searchText,
                    onClose: {
                        showSearch = false
                        searchText = ""
                    }
                )
                Divider()
            }

            // Diff content
            if let patch = file.patch {
                ScrollView([.horizontal, .vertical]) {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(patch.components(separatedBy: .newlines).enumerated()), id: \.offset) { index, line in
                            PRDiffLineRow(
                                line: line,
                                lineNumber: index + 1,
                                showLineNumbers: showLineNumbers,
                                wrapLines: wrapLines,
                                searchText: searchText
                            )
                        }
                    }
                    .font(.system(.body, design: .monospaced))
                    .padding()
                }
            } else {
                Spacer()
                Text("Binary file or diff not available")
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
    }
}

// MARK: - PR Diff Toolbar

struct PRDiffToolbar: View {
    let file: PRFileItem
    @Binding var showLineNumbers: Bool
    @Binding var wrapLines: Bool
    @Binding var showSearch: Bool
    @Binding var isFullscreen: Bool

    var body: some View {
        HStack {
            // File info
            HStack(spacing: 6) {
                Image(systemName: file.statusIcon)
                    .foregroundStyle(file.statusColor)
                Text(file.filename)
                    .font(.headline)
                    .lineLimit(1)
            }

            Spacer()

            // Stats
            HStack(spacing: 8) {
                Text("+\(file.additions)")
                    .foregroundStyle(.green)
                Text("-\(file.deletions)")
                    .foregroundStyle(.red)
            }
            .font(.caption.monospaced())

            Divider()
                .frame(height: 16)

            // Search button
            Button {
                showSearch.toggle()
            } label: {
                Image(systemName: "magnifyingglass")
            }
            .buttonStyle(.borderless)
            .help("Search in diff (⌘F)")

            // Options menu
            Menu {
                Section("Display") {
                    Toggle("Show Line Numbers", isOn: $showLineNumbers)
                    Toggle("Wrap Lines", isOn: $wrapLines)
                }

                Divider()

                Button {
                    copyDiffToClipboard()
                } label: {
                    Label("Copy Diff to Clipboard", systemImage: "doc.on.doc")
                }
            } label: {
                Image(systemName: "gearshape")
            }
            .menuStyle(.borderlessButton)
            .frame(width: 24)
            .help("Diff options")

            // Fullscreen toggle
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isFullscreen.toggle()
                }
            } label: {
                Image(systemName: isFullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
            }
            .buttonStyle(.borderless)
            .help(isFullscreen ? "Exit fullscreen" : "Fullscreen diff")
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private func copyDiffToClipboard() {
        if let patch = file.patch {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(patch, forType: .string)
        }
    }
}

// MARK: - PR Diff Search Bar

struct PRDiffSearchBar: View {
    @Binding var searchText: String
    let onClose: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Search in diff...", text: $searchText)
                    .textFieldStyle(.plain)
                    .focused($isFocused)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Clear search")
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)

            Spacer()

            Button {
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Close search (Esc)")
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear { isFocused = true }
        .onExitCommand { onClose() }
    }
}

// MARK: - PR Diff Line Row

struct PRDiffLineRow: View {
    let line: String
    let lineNumber: Int
    let showLineNumbers: Bool
    let wrapLines: Bool
    let searchText: String

    var body: some View {
        HStack(spacing: 0) {
            if showLineNumbers {
                Text("\(lineNumber)")
                    .frame(width: 40, alignment: .trailing)
                    .foregroundStyle(.secondary)
                    .font(.caption.monospaced())

                Text(" ")
                    .frame(width: 8)
            }

            if wrapLines {
                Text(highlightedLine)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            } else {
                Text(highlightedLine)
                    .fixedSize(horizontal: true, vertical: false)
                    .textSelection(.enabled)
            }
        }
        .padding(.vertical, 1)
        .background(backgroundColor)
    }

    private var highlightedLine: AttributedString {
        var attributedLine = AttributedString(line)

        // Highlight search matches
        if !searchText.isEmpty {
            let lowercasedLine = line.lowercased()
            let lowercasedSearch = searchText.lowercased()
            var searchStart = lowercasedLine.startIndex

            while let range = lowercasedLine.range(of: lowercasedSearch, range: searchStart..<lowercasedLine.endIndex) {
                // Convert String range to AttributedString range
                if let attrRange = Range(NSRange(range, in: line), in: attributedLine) {
                    attributedLine[attrRange].backgroundColor = .yellow
                    attributedLine[attrRange].foregroundColor = .black
                }
                searchStart = range.upperBound
            }
        }

        return attributedLine
    }

    private var backgroundColor: Color {
        if line.hasPrefix("+") && !line.hasPrefix("+++") {
            return Color.green.opacity(0.15)
        } else if line.hasPrefix("-") && !line.hasPrefix("---") {
            return Color.red.opacity(0.15)
        } else if line.hasPrefix("@@") {
            return Color.blue.opacity(0.1)
        }
        return Color.clear
    }
}

// MARK: - GitHub PR File

struct PRFileItem: Identifiable, Hashable {
    let id: String
    let filename: String
    let status: String
    let additions: Int
    let deletions: Int
    let patch: String?

    var statusIcon: String {
        switch status {
        case "added": return "plus.circle.fill"
        case "removed", "deleted": return "minus.circle.fill"
        case "modified": return "pencil.circle.fill"
        case "renamed": return "arrow.right.circle.fill"
        default: return "doc.circle"
        }
    }

    var statusColor: Color {
        switch status {
        case "added": return .green
        case "removed", "deleted": return .red
        case "modified": return .orange
        case "renamed": return .blue
        default: return .secondary
        }
    }
}

struct PRFileItemRow: View {
    let file: PRFileItem

    private var displayName: String {
        // Show just the filename, not the full path
        (file.filename as NSString).lastPathComponent
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: file.statusIcon)
                .foregroundStyle(file.statusColor)
                .font(.caption2)

            Text(displayName)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.middle)
                .help(file.filename) // Show full path on hover

            Spacer(minLength: 2)

            HStack(spacing: 2) {
                if file.additions > 0 {
                    Text("+\(file.additions)")
                        .foregroundStyle(.green)
                        .font(.caption2)
                }
                if file.deletions > 0 {
                    Text("-\(file.deletions)")
                        .foregroundStyle(.red)
                        .font(.caption2)
                }
            }
        }
        .padding(.vertical, 1)
    }
}

// MARK: - GitHub Pull Requests View Model

@MainActor
class GitHubPullRequestsViewModel: ObservableObject {
    @Published var stateFilter: GitHubPRState = .open
    @Published var selectedPR: GitHubPullRequest?

    @Published private(set) var pullRequests: [GitHubPullRequest] = []
    @Published private(set) var isLoading = false

    private let repository: Repository
    private let keychainService = KeychainService.shared
    private let gitService = GitService()
    private lazy var githubService = GitHubService()

    init(repository: Repository) {
        self.repository = repository
    }

    var isConnected: Bool {
        keychainService.retrieve(for: KeychainAccount.githubToken) != nil
    }

    var hasNoPRs: Bool {
        filteredPullRequests.isEmpty
    }

    var filteredPullRequests: [GitHubPullRequest] {
        pullRequests.filter { pr in
            switch stateFilter {
            case .open: return pr.state == "open"
            case .closed: return pr.state == "closed"
            case .all: return true
            }
        }
    }

    func loadPullRequests() async {
        isLoading = true
        defer { isLoading = false }

        guard let token = keychainService.retrieve(for: KeychainAccount.githubToken),
              let repoInfo = await githubService.getGitHubInfo(for: repository, gitService: gitService) else {
            return
        }

        await githubService.setAuthToken(token)

        do {
            pullRequests = try await githubService.getPullRequests(
                owner: repoInfo.owner,
                repo: repoInfo.repo,
                state: "all"
            )
        } catch {
            print("Failed to load GitHub PRs: \(error)")
        }
    }

    func loadFilesForPR(_ pr: GitHubPullRequest) async throws -> [PRFileItem] {
        guard let repoInfo = await githubService.getGitHubInfo(for: repository, gitService: gitService) else {
            return []
        }

        let files = try await githubService.getPullRequestFiles(
            owner: repoInfo.owner,
            repo: repoInfo.repo,
            number: pr.number
        )

        return files.map { file in
            PRFileItem(
                id: file.id,
                filename: file.filename,
                status: file.status.rawValue,
                additions: file.additions,
                deletions: file.deletions,
                patch: file.patch
            )
        }
    }

    // MARK: - PR Actions

    /// Add a comment to a pull request
    func addComment(to pr: GitHubPullRequest, body: String) async throws {
        guard let repoInfo = await githubService.getGitHubInfo(for: repository, gitService: gitService) else {
            throw PRActionError.missingRepoInfo
        }
        _ = try await githubService.addComment(
            owner: repoInfo.owner,
            repo: repoInfo.repo,
            issueNumber: pr.number,
            body: body
        )
    }

    /// Submit a review to a pull request
    func submitReview(to pr: GitHubPullRequest, action: GitHubPRReviewSheet.ReviewAction, body: String?) async throws {
        guard let repoInfo = await githubService.getGitHubInfo(for: repository, gitService: gitService) else {
            throw PRActionError.missingRepoInfo
        }

        let event: GitHubService.ReviewEvent
        switch action {
        case .approve: event = .approve
        case .requestChanges: event = .requestChanges
        case .comment: event = .comment
        }

        _ = try await githubService.submitReview(
            owner: repoInfo.owner,
            repo: repoInfo.repo,
            pullNumber: pr.number,
            body: body,
            event: event
        )

        // Refresh PRs after action
        await loadPullRequests()
    }

    /// Merge a pull request
    func mergePR(
        _ pr: GitHubPullRequest,
        method: GitHubPRMergeSheet.MergeMethod,
        title: String?,
        message: String?,
        deleteSourceBranch: Bool
    ) async throws {
        guard let repoInfo = await githubService.getGitHubInfo(for: repository, gitService: gitService) else {
            throw PRActionError.missingRepoInfo
        }

        let mergeMethod: String
        switch method {
        case .merge: mergeMethod = "merge"
        case .squash: mergeMethod = "squash"
        case .rebase: mergeMethod = "rebase"
        }

        _ = try await githubService.mergePullRequest(
            owner: repoInfo.owner,
            repo: repoInfo.repo,
            number: pr.number,
            commitTitle: title,
            commitMessage: message,
            mergeMethod: mergeMethod
        )

        // Delete source branch if requested
        if deleteSourceBranch {
            try? await githubService.deleteBranch(
                owner: repoInfo.owner,
                repo: repoInfo.repo,
                branch: pr.head.ref
            )
        }

        // Refresh PRs after merge
        selectedPR = nil
        await loadPullRequests()
    }

    /// Close a pull request without merging
    func closePR(_ pr: GitHubPullRequest) async {
        do {
            guard let repoInfo = await githubService.getGitHubInfo(for: repository, gitService: gitService) else {
                return
            }
            _ = try await githubService.closePullRequest(
                owner: repoInfo.owner,
                repo: repoInfo.repo,
                number: pr.number
            )

            // Refresh PRs after close
            selectedPR = nil
            await loadPullRequests()
        } catch {
            print("Failed to close PR: \(error)")
        }
    }
}

// MARK: - PR Action Errors

enum PRActionError: LocalizedError {
    case missingRepoInfo
    case notImplemented(String)
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .missingRepoInfo:
            return "Could not determine repository information"
        case .notImplemented(let feature):
            return "\(feature) is not yet implemented"
        case .apiError(let message):
            return message
        }
    }
}

// MARK: - Markdown Content View

/// A view that renders markdown content with image support using WKWebView.
struct MarkdownContentView: NSViewRepresentable {
    let markdown: String

    @Environment(\.colorScheme) private var colorScheme

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.preferences.isTextInteractionEnabled = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")

        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let html = generateHTML(from: markdown)
        webView.loadHTMLString(html, baseURL: nil)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    private func generateHTML(from markdown: String) -> String {
        let isDark = colorScheme == .dark
        let textColor = isDark ? "#e6edf3" : "#1f2328"
        let bgColor = isDark ? "#0d1117" : "#ffffff"
        let linkColor = isDark ? "#58a6ff" : "#0969da"
        let codeBackground = isDark ? "#161b22" : "#f6f8fa"
        let borderColor = isDark ? "#30363d" : "#d0d7de"

        // Convert markdown to HTML (basic conversion + pass through existing HTML)
        let processedContent = convertMarkdownToHTML(markdown)

        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                * {
                    box-sizing: border-box;
                }
                body {
                    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", "Noto Sans", Helvetica, Arial, sans-serif;
                    font-size: 14px;
                    line-height: 1.6;
                    color: \(textColor);
                    background-color: \(bgColor);
                    padding: 16px;
                    margin: 0;
                    word-wrap: break-word;
                }
                a {
                    color: \(linkColor);
                    text-decoration: none;
                }
                a:hover {
                    text-decoration: underline;
                }
                img {
                    max-width: 100%;
                    height: auto;
                    border-radius: 6px;
                    margin: 8px 0;
                }
                code {
                    font-family: ui-monospace, SFMono-Regular, "SF Mono", Menlo, Consolas, monospace;
                    font-size: 12px;
                    background-color: \(codeBackground);
                    padding: 2px 6px;
                    border-radius: 4px;
                }
                pre {
                    background-color: \(codeBackground);
                    padding: 16px;
                    border-radius: 6px;
                    overflow-x: auto;
                }
                pre code {
                    padding: 0;
                    background: none;
                }
                blockquote {
                    margin: 0;
                    padding: 0 16px;
                    border-left: 4px solid \(borderColor);
                    color: \(isDark ? "#8b949e" : "#656d76");
                }
                hr {
                    border: none;
                    border-top: 1px solid \(borderColor);
                    margin: 16px 0;
                }
                h1, h2, h3, h4, h5, h6 {
                    margin-top: 24px;
                    margin-bottom: 16px;
                    font-weight: 600;
                    line-height: 1.25;
                }
                h1 { font-size: 2em; border-bottom: 1px solid \(borderColor); padding-bottom: 0.3em; }
                h2 { font-size: 1.5em; border-bottom: 1px solid \(borderColor); padding-bottom: 0.3em; }
                h3 { font-size: 1.25em; }
                ul, ol {
                    padding-left: 2em;
                }
                li {
                    margin: 4px 0;
                }
                table {
                    border-collapse: collapse;
                    width: 100%;
                    margin: 16px 0;
                }
                th, td {
                    border: 1px solid \(borderColor);
                    padding: 8px 12px;
                    text-align: left;
                }
                th {
                    background-color: \(codeBackground);
                    font-weight: 600;
                }
                .task-list-item {
                    list-style-type: none;
                    margin-left: -1.5em;
                }
                .task-list-item input {
                    margin-right: 0.5em;
                }
            </style>
        </head>
        <body>
            \(processedContent)
        </body>
        </html>
        """
    }

    private func convertMarkdownToHTML(_ markdown: String) -> String {
        var html = markdown

        // The content often already contains HTML (especially from GitHub)
        // We'll do basic markdown conversion for common patterns

        // Convert markdown images ![alt](url) to <img>
        let imagePattern = #"!\[([^\]]*)\]\(([^)]+)\)"#
        if let regex = try? NSRegularExpression(pattern: imagePattern, options: []) {
            let range = NSRange(html.startIndex..., in: html)
            html = regex.stringByReplacingMatches(in: html, options: [], range: range, withTemplate: "<img alt=\"$1\" src=\"$2\" />")
        }

        // Convert markdown links [text](url) to <a>
        let linkPattern = #"\[([^\]]+)\]\(([^)]+)\)"#
        if let regex = try? NSRegularExpression(pattern: linkPattern, options: []) {
            let range = NSRange(html.startIndex..., in: html)
            html = regex.stringByReplacingMatches(in: html, options: [], range: range, withTemplate: "<a href=\"$2\" target=\"_blank\">$1</a>")
        }

        // Convert code blocks ```code```
        let codeBlockPattern = #"```(\w*)\n([\s\S]*?)```"#
        if let regex = try? NSRegularExpression(pattern: codeBlockPattern, options: []) {
            let range = NSRange(html.startIndex..., in: html)
            html = regex.stringByReplacingMatches(in: html, options: [], range: range, withTemplate: "<pre><code>$2</code></pre>")
        }

        // Convert inline code `code`
        let inlineCodePattern = #"`([^`]+)`"#
        if let regex = try? NSRegularExpression(pattern: inlineCodePattern, options: []) {
            let range = NSRange(html.startIndex..., in: html)
            html = regex.stringByReplacingMatches(in: html, options: [], range: range, withTemplate: "<code>$1</code>")
        }

        // Convert headers
        html = html.replacingOccurrences(of: #"^######\s+(.+)$"#, with: "<h6>$1</h6>", options: .regularExpression)
        html = html.replacingOccurrences(of: #"^#####\s+(.+)$"#, with: "<h5>$1</h5>", options: .regularExpression)
        html = html.replacingOccurrences(of: #"^####\s+(.+)$"#, with: "<h4>$1</h4>", options: .regularExpression)
        html = html.replacingOccurrences(of: #"^###\s+(.+)$"#, with: "<h3>$1</h3>", options: .regularExpression)
        html = html.replacingOccurrences(of: #"^##\s+(.+)$"#, with: "<h2>$1</h2>", options: .regularExpression)
        html = html.replacingOccurrences(of: #"^#\s+(.+)$"#, with: "<h1>$1</h1>", options: .regularExpression)

        // Convert bold **text** or __text__
        let boldPattern = #"\*\*([^*]+)\*\*|__([^_]+)__"#
        if let regex = try? NSRegularExpression(pattern: boldPattern, options: []) {
            let range = NSRange(html.startIndex..., in: html)
            html = regex.stringByReplacingMatches(in: html, options: [], range: range, withTemplate: "<strong>$1$2</strong>")
        }

        // Convert italic *text* or _text_
        let italicPattern = #"(?<!\*)\*([^*]+)\*(?!\*)|(?<!_)_([^_]+)_(?!_)"#
        if let regex = try? NSRegularExpression(pattern: italicPattern, options: []) {
            let range = NSRange(html.startIndex..., in: html)
            html = regex.stringByReplacingMatches(in: html, options: [], range: range, withTemplate: "<em>$1$2</em>")
        }

        // Convert blockquotes
        html = html.replacingOccurrences(of: #"^>\s+(.+)$"#, with: "<blockquote>$1</blockquote>", options: .regularExpression)

        // Convert horizontal rules
        html = html.replacingOccurrences(of: #"^---+$"#, with: "<hr>", options: .regularExpression)
        html = html.replacingOccurrences(of: #"^\*\*\*+$"#, with: "<hr>", options: .regularExpression)

        // Convert task lists - [ ] and - [x]
        html = html.replacingOccurrences(of: #"^-\s+\[\s*\]\s+(.+)$"#, with: "<li class=\"task-list-item\"><input type=\"checkbox\" disabled> $1</li>", options: .regularExpression)
        html = html.replacingOccurrences(of: #"^-\s+\[[xX]\]\s+(.+)$"#, with: "<li class=\"task-list-item\"><input type=\"checkbox\" disabled checked> $1</li>", options: .regularExpression)

        // Convert unordered lists
        html = html.replacingOccurrences(of: #"^[-*]\s+(.+)$"#, with: "<li>$1</li>", options: .regularExpression)

        // Convert newlines to <br> for lines that aren't already HTML
        let lines = html.components(separatedBy: "\n")
        var processedLines: [String] = []
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // Don't add <br> after block elements
            if trimmed.hasPrefix("<h") || trimmed.hasPrefix("<li") || trimmed.hasPrefix("<pre") ||
               trimmed.hasPrefix("<blockquote") || trimmed.hasPrefix("<hr") || trimmed.hasPrefix("<ul") ||
               trimmed.hasPrefix("<ol") || trimmed.hasPrefix("</") || trimmed.hasPrefix("<p") ||
               trimmed.hasPrefix("<div") || trimmed.hasPrefix("<table") || trimmed.hasPrefix("<tr") ||
               trimmed.hasPrefix("<img") || trimmed.isEmpty {
                processedLines.append(line)
            } else {
                processedLines.append(line)
                // Add line break if next line isn't empty and isn't a block element
            }
        }
        html = processedLines.joined(separator: "\n")

        // Wrap consecutive <li> items in <ul>
        html = html.replacingOccurrences(of: #"((?:<li[^>]*>.*?</li>\n?)+)"#, with: "<ul>$1</ul>", options: .regularExpression)

        // Convert double newlines to paragraphs
        html = html.replacingOccurrences(of: "\n\n", with: "</p><p>")
        if !html.hasPrefix("<") {
            html = "<p>" + html + "</p>"
        }

        return html
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            // Open external links in the default browser
            if navigationAction.navigationType == .linkActivated,
               let url = navigationAction.request.url {
                NSWorkspace.shared.open(url)
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }
    }
}
