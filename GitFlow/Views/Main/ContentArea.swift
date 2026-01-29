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
        case .gitlab:
            GitLabSectionView(viewModel: viewModel)
        case .bitbucket:
            BitbucketSectionView(viewModel: viewModel)
        case .azureDevOps:
            AzureDevOpsSectionView(viewModel: viewModel)
        case .gitea:
            GiteaSectionView(viewModel: viewModel)
        case .beanstalk:
            BeanstalkSectionView(viewModel: viewModel)
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

    var body: some View {
        UnifiedPullRequestsView(repository: viewModel.repository)
    }
}

/// Wrapper view for GitLab integration.
struct GitLabSectionView: View {
    @ObservedObject var viewModel: RepositoryViewModel
    @StateObject private var gitLabViewModel: GitLabViewModel

    init(viewModel: RepositoryViewModel) {
        self.viewModel = viewModel
        self._gitLabViewModel = StateObject(wrappedValue: GitLabViewModel(
            repository: viewModel.repository,
            gitService: viewModel.gitService
        ))
    }

    var body: some View {
        GitLabView(viewModel: gitLabViewModel)
    }
}

/// Wrapper view for Bitbucket integration.
struct BitbucketSectionView: View {
    @ObservedObject var viewModel: RepositoryViewModel
    @StateObject private var bitbucketViewModel: BitbucketViewModel

    init(viewModel: RepositoryViewModel) {
        self.viewModel = viewModel
        self._bitbucketViewModel = StateObject(wrappedValue: BitbucketViewModel(
            repository: viewModel.repository,
            gitService: viewModel.gitService
        ))
    }

    var body: some View {
        BitbucketView(viewModel: bitbucketViewModel)
    }
}

/// Wrapper view for Azure DevOps integration.
struct AzureDevOpsSectionView: View {
    @ObservedObject var viewModel: RepositoryViewModel

    var body: some View {
        AzureDevOpsView()
    }
}

/// Wrapper view for Gitea integration.
struct GiteaSectionView: View {
    @ObservedObject var viewModel: RepositoryViewModel

    var body: some View {
        GiteaView()
    }
}

/// Wrapper view for Beanstalk integration.
struct BeanstalkSectionView: View {
    @ObservedObject var viewModel: RepositoryViewModel

    var body: some View {
        BeanstalkView()
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

/// Unified pull requests view across all services.
struct UnifiedPullRequestsView: View {
    let repository: Repository

    @StateObject private var viewModel: UnifiedPullRequestsViewModel
    @State private var localStateFilter: UnifiedPRState = .open

    init(repository: Repository) {
        self.repository = repository
        self._viewModel = StateObject(wrappedValue: UnifiedPullRequestsViewModel(repository: repository))
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
            await viewModel.loadAllPullRequests()
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
                    Task { await viewModel.loadAllPullRequests() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .disabled(viewModel.isLoading)
            }
            .padding()

            Divider()

            // State filter
            Picker("State", selection: $localStateFilter) {
                Text("Open").tag(UnifiedPRState.open)
                Text("Closed").tag(UnifiedPRState.closed)
                Text("All").tag(UnifiedPRState.all)
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

            // PR List by service
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
            Text(viewModel.connectedServices.isEmpty
                ? "Connect a service in Settings to view pull requests."
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
            // GitHub PRs
            if viewModel.isServiceConnected(.github) {
                Section {
                    ForEach(viewModel.filteredGitHubPRs) { pr in
                        UnifiedPRRow(pr: .github(pr))
                            .tag(UnifiedPR.github(pr))
                    }
                } header: {
                    serviceHeader(
                        name: "GitHub",
                        icon: "link.circle",
                        count: viewModel.filteredGitHubPRs.count,
                        isLoading: viewModel.isLoadingGitHub
                    )
                }
            }

            // GitLab MRs
            if viewModel.isServiceConnected(.gitlab) {
                Section {
                    ForEach(viewModel.filteredGitLabMRs) { mr in
                        UnifiedPRRow(pr: .gitlab(mr))
                            .tag(UnifiedPR.gitlab(mr))
                    }
                } header: {
                    serviceHeader(
                        name: "GitLab",
                        icon: "g.circle",
                        count: viewModel.filteredGitLabMRs.count,
                        isLoading: viewModel.isLoadingGitLab
                    )
                }
            }

            // Bitbucket PRs
            if viewModel.isServiceConnected(.bitbucket) {
                Section {
                    ForEach(viewModel.filteredBitbucketPRs) { pr in
                        UnifiedPRRow(pr: .bitbucket(pr))
                            .tag(UnifiedPR.bitbucket(pr))
                    }
                } header: {
                    serviceHeader(
                        name: "Bitbucket",
                        icon: "b.circle",
                        count: viewModel.filteredBitbucketPRs.count,
                        isLoading: viewModel.isLoadingBitbucket
                    )
                }
            }

            // Azure DevOps PRs
            if viewModel.isServiceConnected(.azureDevOps) {
                Section {
                    ForEach(viewModel.filteredAzureDevOpsPRs) { pr in
                        UnifiedPRRow(pr: .azureDevOps(pr))
                            .tag(UnifiedPR.azureDevOps(pr))
                    }
                } header: {
                    serviceHeader(
                        name: "Azure DevOps",
                        icon: "a.circle",
                        count: viewModel.filteredAzureDevOpsPRs.count,
                        isLoading: viewModel.isLoadingAzureDevOps
                    )
                }
            }

            // Gitea PRs
            if viewModel.isServiceConnected(.gitea) {
                Section {
                    ForEach(viewModel.filteredGiteaPRs) { pr in
                        UnifiedPRRow(pr: .gitea(pr))
                            .tag(UnifiedPR.gitea(pr))
                    }
                } header: {
                    serviceHeader(
                        name: "Gitea",
                        icon: "leaf.circle",
                        count: viewModel.filteredGiteaPRs.count,
                        isLoading: viewModel.isLoadingGitea
                    )
                }
            }
        }
        .listStyle(.inset)
    }

    private func serviceHeader(name: String, icon: String, count: Int, isLoading: Bool) -> some View {
        HStack {
            Image(systemName: icon)
            Text(name)
            Text("(\(count))")
                .foregroundStyle(.secondary)
            if isLoading {
                ProgressView()
                    .controlSize(.mini)
            }
        }
    }

    @ViewBuilder
    private var detailView: some View {
        if let selectedPR = viewModel.selectedPR {
            UnifiedPRDetailView(
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

// MARK: - Unified PR Types

enum UnifiedPRState: String, CaseIterable {
    case open, closed, all
}

enum UnifiedPRService: String, CaseIterable {
    case github, gitlab, bitbucket, azureDevOps, gitea
}

enum UnifiedPR: Identifiable, Hashable {
    case github(GitHubPullRequest)
    case gitlab(GitLabMergeRequest)
    case bitbucket(BitbucketPullRequest)
    case azureDevOps(AzureDevOpsPullRequest)
    case gitea(GiteaPullRequest)

    var id: String {
        switch self {
        case .github(let pr): return "github-\(pr.id)"
        case .gitlab(let mr): return "gitlab-\(mr.id)"
        case .bitbucket(let pr): return "bitbucket-\(pr.id)"
        case .azureDevOps(let pr): return "azure-\(pr.pullRequestId)"
        case .gitea(let pr): return "gitea-\(pr.id)"
        }
    }

    var title: String {
        switch self {
        case .github(let pr): return pr.title
        case .gitlab(let mr): return mr.title
        case .bitbucket(let pr): return pr.title
        case .azureDevOps(let pr): return pr.title
        case .gitea(let pr): return pr.title
        }
    }

    var number: Int {
        switch self {
        case .github(let pr): return pr.number
        case .gitlab(let mr): return mr.iid
        case .bitbucket(let pr): return pr.id
        case .azureDevOps(let pr): return pr.pullRequestId
        case .gitea(let pr): return pr.number
        }
    }

    var authorName: String {
        switch self {
        case .github(let pr): return pr.user.login
        case .gitlab(let mr): return mr.author.username
        case .bitbucket(let pr): return pr.author.displayName
        case .azureDevOps(let pr): return pr.createdBy.displayName
        case .gitea(let pr): return pr.user?.login ?? "Unknown"
        }
    }

    var sourceBranch: String {
        switch self {
        case .github(let pr): return pr.head.ref
        case .gitlab(let mr): return mr.sourceBranch
        case .bitbucket(let pr): return pr.source.branch.name
        case .azureDevOps(let pr): return pr.sourceRefName.replacingOccurrences(of: "refs/heads/", with: "")
        case .gitea(let pr): return pr.head?.ref ?? ""
        }
    }

    var targetBranch: String {
        switch self {
        case .github(let pr): return pr.base.ref
        case .gitlab(let mr): return mr.targetBranch
        case .bitbucket(let pr): return pr.destination.branch.name
        case .azureDevOps(let pr): return pr.targetRefName.replacingOccurrences(of: "refs/heads/", with: "")
        case .gitea(let pr): return pr.base?.ref ?? ""
        }
    }

    var isOpen: Bool {
        switch self {
        case .github(let pr): return pr.state == "open"
        case .gitlab(let mr): return mr.state == .opened
        case .bitbucket(let pr): return pr.state == .open
        case .azureDevOps(let pr): return pr.status == "active"
        case .gitea(let pr): return pr.state == "open"
        }
    }

    var isDraft: Bool {
        switch self {
        case .github(let pr): return pr.isDraft
        case .gitlab(let mr): return mr.isDraft
        case .bitbucket: return false
        case .azureDevOps(let pr): return pr.isDraft ?? false
        case .gitea: return false
        }
    }

    var serviceName: String {
        switch self {
        case .github: return "GitHub"
        case .gitlab: return "GitLab"
        case .bitbucket: return "Bitbucket"
        case .azureDevOps: return "Azure DevOps"
        case .gitea: return "Gitea"
        }
    }

    var serviceIcon: String {
        switch self {
        case .github: return "link.circle"
        case .gitlab: return "g.circle"
        case .bitbucket: return "b.circle"
        case .azureDevOps: return "a.circle"
        case .gitea: return "leaf.circle"
        }
    }

    var webURL: String? {
        switch self {
        case .github(let pr): return pr.htmlUrl
        case .gitlab(let mr): return mr.webUrl
        case .bitbucket(let pr): return pr.links.html?.href
        case .azureDevOps(let pr): return pr.url
        case .gitea(let pr): return pr.htmlUrl
        }
    }
}

// MARK: - Unified PR Row

struct UnifiedPRRow: View {
    let pr: UnifiedPR

    var body: some View {
        HStack(spacing: 8) {
            // Status icon
            Image(systemName: pr.isOpen ? "arrow.triangle.pull" : "checkmark.circle")
                .foregroundStyle(pr.isOpen ? .green : .purple)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text("#\(pr.number)")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                    Text(pr.title)
                        .lineLimit(1)
                }

                HStack(spacing: 8) {
                    Text(pr.authorName)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 4) {
                        Text(pr.sourceBranch)
                            .font(.caption2.monospaced())
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(3)

                        Image(systemName: "arrow.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)

                        Text(pr.targetBranch)
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

// MARK: - Unified PR Detail View

struct UnifiedPRDetailView: View {
    let pr: UnifiedPR
    let repository: Repository
    @ObservedObject var viewModel: UnifiedPullRequestsViewModel

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
            if pr.isOpen {
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
            UnifiedPRCommentSheet(pr: pr, viewModel: viewModel, onDismiss: { showCommentSheet = false })
        }
        .sheet(isPresented: $showReviewSheet) {
            UnifiedPRReviewSheet(pr: pr, viewModel: viewModel, onDismiss: { showReviewSheet = false })
        }
        .sheet(isPresented: $showMergeSheet) {
            UnifiedPRMergeSheet(pr: pr, viewModel: viewModel, onDismiss: { showMergeSheet = false })
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
                Image(systemName: pr.serviceIcon)
                    .foregroundStyle(.blue)
                Text(pr.serviceName)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if let url = pr.webURL, let webURL = URL(string: url) {
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
                Image(systemName: pr.isOpen ? "arrow.triangle.pull" : "checkmark.circle.fill")
                    .foregroundStyle(pr.isOpen ? .green : .purple)
                    .font(.title2)

                VStack(alignment: .leading, spacing: 4) {
                    Text(pr.title)
                        .font(.headline)

                    HStack(spacing: 8) {
                        Text("#\(pr.number)")
                            .font(.subheadline.monospaced())
                            .foregroundStyle(.secondary)

                        Text("by \(pr.authorName)")
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
                        Text(pr.sourceBranch)
                            .font(.caption.monospaced())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(4)

                        Image(systemName: "arrow.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(pr.targetBranch)
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
        UnifiedPRDiffView(pr: pr, repository: repository, viewModel: viewModel)
    }

    private var descriptionView: some View {
        Group {
            if let description = prDescription, !description.isEmpty {
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

    private var prDescription: String? {
        switch pr {
        case .github(let pr): return pr.body
        case .gitlab(let mr): return mr.description
        case .bitbucket(let pr): return pr.description
        case .azureDevOps(let pr): return pr.description
        case .gitea(let pr): return pr.body
        }
    }
}

// MARK: - PR Comment Sheet

struct UnifiedPRCommentSheet: View {
    let pr: UnifiedPR
    @ObservedObject var viewModel: UnifiedPullRequestsViewModel
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
                Text("Comment on \(pr.serviceName) #\(pr.number)")
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

struct UnifiedPRReviewSheet: View {
    let pr: UnifiedPR
    @ObservedObject var viewModel: UnifiedPullRequestsViewModel
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

struct UnifiedPRMergeSheet: View {
    let pr: UnifiedPR
    @ObservedObject var viewModel: UnifiedPullRequestsViewModel
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
                            Text("Delete '\(pr.sourceBranch)' after merging")
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
            commitTitle = "Merge pull request #\(pr.number) from \(pr.sourceBranch)"
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

// MARK: - Unified PR Diff View

struct UnifiedPRDiffView: View {
    let pr: UnifiedPR
    let repository: Repository
    @ObservedObject var viewModel: UnifiedPullRequestsViewModel

    @State private var files: [UnifiedPRFile] = []
    @State private var selectedFile: UnifiedPRFile?
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
                            UnifiedPRFileRow(file: file)
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
    private func fileDiffView(for file: UnifiedPRFile) -> some View {
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
    let file: UnifiedPRFile
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

// MARK: - Unified PR File

struct UnifiedPRFile: Identifiable, Hashable {
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

struct UnifiedPRFileRow: View {
    let file: UnifiedPRFile

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

// MARK: - Unified Pull Requests View Model

@MainActor
class UnifiedPullRequestsViewModel: ObservableObject {
    @Published var stateFilter: UnifiedPRState = .open
    @Published var selectedPR: UnifiedPR?

    @Published private(set) var githubPRs: [GitHubPullRequest] = []
    @Published private(set) var gitlabMRs: [GitLabMergeRequest] = []
    @Published private(set) var bitbucketPRs: [BitbucketPullRequest] = []
    @Published private(set) var azureDevOpsPRs: [AzureDevOpsPullRequest] = []
    @Published private(set) var giteaPRs: [GiteaPullRequest] = []

    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingGitHub = false
    @Published private(set) var isLoadingGitLab = false
    @Published private(set) var isLoadingBitbucket = false
    @Published private(set) var isLoadingAzureDevOps = false
    @Published private(set) var isLoadingGitea = false

    private let repository: Repository
    private let keychainService = KeychainService.shared
    private let gitService = GitService()

    // Service instances (using shared singletons where required)
    private lazy var githubService = GitHubService()
    private lazy var gitlabService = GitLabService()
    private lazy var bitbucketService = BitbucketService()
    private var azureDevOpsService: AzureDevOpsService { AzureDevOpsService.shared }
    private var giteaService: GiteaService { GiteaService.shared }

    init(repository: Repository) {
        self.repository = repository
    }

    var connectedServices: [UnifiedPRService] {
        var services: [UnifiedPRService] = []
        if isServiceConnected(.github) { services.append(.github) }
        if isServiceConnected(.gitlab) { services.append(.gitlab) }
        if isServiceConnected(.bitbucket) { services.append(.bitbucket) }
        if isServiceConnected(.azureDevOps) { services.append(.azureDevOps) }
        if isServiceConnected(.gitea) { services.append(.gitea) }
        return services
    }

    func isServiceConnected(_ service: UnifiedPRService) -> Bool {
        switch service {
        case .github:
            return keychainService.retrieve(for: KeychainAccount.githubToken) != nil
        case .gitlab:
            return keychainService.retrieve(for: KeychainAccount.gitlabToken) != nil
        case .bitbucket:
            return keychainService.retrieve(for: KeychainAccount.bitbucketToken) != nil
        case .azureDevOps:
            return keychainService.retrieve(for: KeychainAccount.azureDevOpsToken) != nil
        case .gitea:
            // Gitea uses account-based auth stored differently
            return false // TODO: Check Gitea accounts
        }
    }

    var hasNoPRs: Bool {
        filteredGitHubPRs.isEmpty &&
        filteredGitLabMRs.isEmpty &&
        filteredBitbucketPRs.isEmpty &&
        filteredAzureDevOpsPRs.isEmpty &&
        filteredGiteaPRs.isEmpty
    }

    var filteredGitHubPRs: [GitHubPullRequest] {
        filterPRs(githubPRs) { pr in
            switch stateFilter {
            case .open: return pr.state == "open"
            case .closed: return pr.state == "closed"
            case .all: return true
            }
        }
    }

    var filteredGitLabMRs: [GitLabMergeRequest] {
        filterPRs(gitlabMRs) { mr in
            switch stateFilter {
            case .open: return mr.state == .opened
            case .closed: return mr.state == .closed || mr.state == .merged
            case .all: return true
            }
        }
    }

    var filteredBitbucketPRs: [BitbucketPullRequest] {
        filterPRs(bitbucketPRs) { pr in
            switch stateFilter {
            case .open: return pr.state == .open
            case .closed: return pr.state == .merged || pr.state == .declined
            case .all: return true
            }
        }
    }

    var filteredAzureDevOpsPRs: [AzureDevOpsPullRequest] {
        filterPRs(azureDevOpsPRs) { pr in
            switch stateFilter {
            case .open: return pr.status == "active"
            case .closed: return pr.status == "completed" || pr.status == "abandoned"
            case .all: return true
            }
        }
    }

    var filteredGiteaPRs: [GiteaPullRequest] {
        filterPRs(giteaPRs) { pr in
            switch stateFilter {
            case .open: return pr.state == "open"
            case .closed: return pr.state == "closed"
            case .all: return true
            }
        }
    }

    private func filterPRs<T>(_ prs: [T], predicate: (T) -> Bool) -> [T] {
        prs.filter(predicate)
    }

    func loadAllPullRequests() async {
        isLoading = true

        await withTaskGroup(of: Void.self) { group in
            if isServiceConnected(.github) {
                group.addTask { await self.loadGitHubPRs() }
            }
            if isServiceConnected(.gitlab) {
                group.addTask { await self.loadGitLabMRs() }
            }
            if isServiceConnected(.bitbucket) {
                group.addTask { await self.loadBitbucketPRs() }
            }
            if isServiceConnected(.azureDevOps) {
                group.addTask { await self.loadAzureDevOpsPRs() }
            }
        }

        isLoading = false
    }

    private func loadGitHubPRs() async {
        isLoadingGitHub = true
        defer { isLoadingGitHub = false }

        guard let token = keychainService.retrieve(for: KeychainAccount.githubToken),
              let repoInfo = await githubService.getGitHubInfo(for: repository, gitService: gitService) else {
            return
        }

        await githubService.setAuthToken(token)

        do {
            githubPRs = try await githubService.getPullRequests(
                owner: repoInfo.owner,
                repo: repoInfo.repo,
                state: "all"
            )
        } catch {
            print("Failed to load GitHub PRs: \(error)")
        }
    }

    private func loadGitLabMRs() async {
        isLoadingGitLab = true
        // GitLab loading would go here
        // For now, leave empty as it requires project ID
        isLoadingGitLab = false
    }

    private func loadBitbucketPRs() async {
        isLoadingBitbucket = true
        // Bitbucket loading would go here
        isLoadingBitbucket = false
    }

    private func loadAzureDevOpsPRs() async {
        isLoadingAzureDevOps = true
        // Azure DevOps loading would go here
        isLoadingAzureDevOps = false
    }

    func loadFilesForPR(_ pr: UnifiedPR) async throws -> [UnifiedPRFile] {
        switch pr {
        case .github(let ghPR):
            return try await loadGitHubPRFiles(ghPR)
        case .gitlab(let mr):
            return try await loadGitLabMRFiles(mr)
        case .bitbucket(let bbPR):
            return try await loadBitbucketPRFiles(bbPR)
        case .azureDevOps(let adoPR):
            return try await loadAzureDevOpsPRFiles(adoPR)
        case .gitea(let giteaPR):
            return try await loadGiteaPRFiles(giteaPR)
        }
    }

    private func loadGitHubPRFiles(_ pr: GitHubPullRequest) async throws -> [UnifiedPRFile] {
        guard let repoInfo = await githubService.getGitHubInfo(for: repository, gitService: gitService) else {
            return []
        }

        let files = try await githubService.getPullRequestFiles(
            owner: repoInfo.owner,
            repo: repoInfo.repo,
            number: pr.number
        )

        return files.map { file in
            UnifiedPRFile(
                id: file.id,
                filename: file.filename,
                status: file.status.rawValue,
                additions: file.additions,
                deletions: file.deletions,
                patch: file.patch
            )
        }
    }

    private func loadGitLabMRFiles(_ mr: GitLabMergeRequest) async throws -> [UnifiedPRFile] {
        // GitLab MR files loading would go here
        return []
    }

    private func loadBitbucketPRFiles(_ pr: BitbucketPullRequest) async throws -> [UnifiedPRFile] {
        // Bitbucket PR files loading would go here
        return []
    }

    private func loadAzureDevOpsPRFiles(_ pr: AzureDevOpsPullRequest) async throws -> [UnifiedPRFile] {
        // Azure DevOps PR files loading would go here
        return []
    }

    private func loadGiteaPRFiles(_ pr: GiteaPullRequest) async throws -> [UnifiedPRFile] {
        // Gitea PR files loading would go here
        return []
    }

    // MARK: - PR Actions

    /// Add a comment to a pull request
    func addComment(to pr: UnifiedPR, body: String) async throws {
        switch pr {
        case .github(let ghPR):
            guard let repoInfo = await githubService.getGitHubInfo(for: repository, gitService: gitService) else {
                throw PRActionError.missingRepoInfo
            }
            _ = try await githubService.addComment(
                owner: repoInfo.owner,
                repo: repoInfo.repo,
                issueNumber: ghPR.number,
                body: body
            )

        case .gitlab:
            throw PRActionError.notImplemented("GitLab comments")

        case .bitbucket:
            throw PRActionError.notImplemented("Bitbucket comments")

        case .azureDevOps(let adoPR):
            guard let repoRef = adoPR.repository else {
                throw PRActionError.missingRepoInfo
            }
            _ = try await azureDevOpsService.addPullRequestComment(
                projectId: repoRef.project?.id ?? "",
                repositoryId: repoRef.id,
                pullRequestId: adoPR.pullRequestId,
                content: body
            )

        case .gitea(let giteaPR):
            guard let repo = giteaPR.base?.repo else {
                throw PRActionError.missingRepoInfo
            }
            _ = try await giteaService.addComment(
                owner: repo.owner?.login ?? "",
                repo: repo.name,
                index: giteaPR.number,
                body: body
            )
        }
    }

    /// Submit a review to a pull request
    func submitReview(to pr: UnifiedPR, action: UnifiedPRReviewSheet.ReviewAction, body: String?) async throws {
        switch pr {
        case .github(let ghPR):
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
                pullNumber: ghPR.number,
                body: body,
                event: event
            )

        case .gitlab:
            throw PRActionError.notImplemented("GitLab reviews")

        case .bitbucket:
            throw PRActionError.notImplemented("Bitbucket reviews")

        case .azureDevOps:
            throw PRActionError.notImplemented("Azure DevOps reviews")

        case .gitea(let giteaPR):
            guard let repo = giteaPR.base?.repo else {
                throw PRActionError.missingRepoInfo
            }

            let event: GiteaReviewEvent
            switch action {
            case .approve: event = .approve
            case .requestChanges: event = .requestChanges
            case .comment: event = .comment
            }

            _ = try await giteaService.addReview(
                owner: repo.owner?.login ?? "",
                repo: repo.name,
                index: giteaPR.number,
                event: event,
                body: body
            )
        }

        // Refresh PRs after action
        await loadAllPullRequests()
    }

    /// Merge a pull request
    func mergePR(
        _ pr: UnifiedPR,
        method: UnifiedPRMergeSheet.MergeMethod,
        title: String?,
        message: String?,
        deleteSourceBranch: Bool
    ) async throws {
        switch pr {
        case .github(let ghPR):
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
                number: ghPR.number,
                commitTitle: title,
                commitMessage: message,
                mergeMethod: mergeMethod
            )

            // Delete source branch if requested
            if deleteSourceBranch {
                try? await githubService.deleteBranch(
                    owner: repoInfo.owner,
                    repo: repoInfo.repo,
                    branch: ghPR.head.ref
                )
            }

        case .gitlab:
            throw PRActionError.notImplemented("GitLab merge")

        case .bitbucket:
            throw PRActionError.notImplemented("Bitbucket merge")

        case .azureDevOps:
            throw PRActionError.notImplemented("Azure DevOps merge")

        case .gitea(let giteaPR):
            guard let repo = giteaPR.base?.repo else {
                throw PRActionError.missingRepoInfo
            }

            let mergeStyle: GiteaMergeStyle
            switch method {
            case .merge: mergeStyle = .merge
            case .squash: mergeStyle = .squash
            case .rebase: mergeStyle = .rebase
            }

            try await giteaService.mergePullRequest(
                owner: repo.owner?.login ?? "",
                repo: repo.name,
                index: giteaPR.number,
                mergeStyle: mergeStyle,
                title: title,
                message: message
            )
        }

        // Refresh PRs after merge
        selectedPR = nil
        await loadAllPullRequests()
    }

    /// Close a pull request without merging
    func closePR(_ pr: UnifiedPR) async {
        do {
            switch pr {
            case .github(let ghPR):
                guard let repoInfo = await githubService.getGitHubInfo(for: repository, gitService: gitService) else {
                    return
                }
                _ = try await githubService.closePullRequest(
                    owner: repoInfo.owner,
                    repo: repoInfo.repo,
                    number: ghPR.number
                )

            case .gitlab:
                print("GitLab close PR not implemented")

            case .bitbucket:
                print("Bitbucket close PR not implemented")

            case .azureDevOps:
                print("Azure DevOps close PR not implemented")

            case .gitea:
                print("Gitea close PR not implemented")
            }

            // Refresh PRs after close
            selectedPR = nil
            await loadAllPullRequests()
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
