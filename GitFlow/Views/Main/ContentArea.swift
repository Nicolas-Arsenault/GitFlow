import SwiftUI

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
        case .stashes:
            StashesView(viewModel: viewModel.stashViewModel)
        case .tags:
            TagsView(viewModel: viewModel.tagViewModel)
        case .sync:
            SyncView(
                remoteViewModel: viewModel.remoteViewModel,
                branchViewModel: viewModel.branchViewModel
            )
        case .fileTree:
            FileTreeSectionView(viewModel: viewModel)
        case .submodules:
            SubmoduleSectionView(viewModel: viewModel)
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
        .task(id: statusViewModel.selectedFile?.id) {
            if let file = statusViewModel.selectedFile {
                await diffViewModel.loadDiff(for: file)
            }
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

/// View for remote sync operations.
struct SyncView: View {
    @ObservedObject var remoteViewModel: RemoteViewModel
    @ObservedObject var branchViewModel: BranchViewModel

    var body: some View {
        RemoteView(viewModel: remoteViewModel, branchViewModel: branchViewModel)
    }
}
