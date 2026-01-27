import Foundation
import Combine

/// Main view model for repository coordination.
/// Manages child view models and coordinates repository-wide operations.
@MainActor
final class RepositoryViewModel: ObservableObject {
    // MARK: - Published State

    /// The repository being managed.
    let repository: Repository

    /// Whether the repository is currently loading.
    @Published private(set) var isLoading: Bool = false

    /// Current error, if any.
    @Published var error: GitError?

    /// The current branch name.
    @Published private(set) var currentBranch: String?

    /// The current HEAD commit hash.
    @Published private(set) var headCommit: String?

    // MARK: - Child View Models

    @Published private(set) var statusViewModel: StatusViewModel
    @Published private(set) var diffViewModel: DiffViewModel
    @Published private(set) var commitViewModel: CommitViewModel
    @Published private(set) var historyViewModel: HistoryViewModel
    @Published private(set) var branchViewModel: BranchViewModel
    @Published private(set) var stashViewModel: StashViewModel
    @Published private(set) var remoteViewModel: RemoteViewModel
    @Published private(set) var tagViewModel: TagViewModel

    // MARK: - Services

    private let gitService: GitService

    // MARK: - Initialization

    init(repository: Repository, gitService: GitService) {
        self.repository = repository
        self.gitService = gitService

        // Initialize child view models
        self.statusViewModel = StatusViewModel(repository: repository, gitService: gitService)
        self.diffViewModel = DiffViewModel(repository: repository, gitService: gitService)
        self.commitViewModel = CommitViewModel(repository: repository, gitService: gitService)
        self.historyViewModel = HistoryViewModel(repository: repository, gitService: gitService)
        self.branchViewModel = BranchViewModel(repository: repository, gitService: gitService)
        self.stashViewModel = StashViewModel(repository: repository, gitService: gitService)
        self.remoteViewModel = RemoteViewModel(repository: repository, gitService: gitService)
        self.tagViewModel = TagViewModel(repository: repository, gitService: gitService)

        // Set up cross-view model coordination
        setupBindings()
    }

    // MARK: - Public Methods

    /// Refreshes all repository data.
    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        do {
            // Refresh branch info
            currentBranch = try await gitService.getCurrentBranch(in: repository)
            headCommit = try await gitService.getHead(in: repository)

            // Refresh child view models in parallel
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await self.statusViewModel.refresh() }
                group.addTask { await self.historyViewModel.refresh() }
                group.addTask { await self.branchViewModel.refresh() }
                group.addTask { await self.stashViewModel.refresh() }
                group.addTask { await self.remoteViewModel.refresh() }
                group.addTask { await self.tagViewModel.refresh() }
            }

        } catch let gitError as GitError {
            error = gitError
        } catch {
            self.error = .unknown(message: error.localizedDescription)
        }
    }

    /// Stages the specified files and refreshes status.
    func stageFiles(_ paths: [String]) async {
        await statusViewModel.stageFiles(paths)
        diffViewModel.clearDiff()
    }

    /// Unstages the specified files and refreshes status.
    func unstageFiles(_ paths: [String]) async {
        await statusViewModel.unstageFiles(paths)
        diffViewModel.clearDiff()
    }

    /// Creates a commit with the staged changes.
    func createCommit(message: String) async {
        await commitViewModel.createCommit(message: message)
        await refresh()
    }

    /// Checks out the specified branch.
    func checkoutBranch(_ branchName: String) async {
        await branchViewModel.checkout(branchName: branchName)
        await refresh()
    }

    // MARK: - Private Methods

    private func setupBindings() {
        // Propagate status changes to diff view model when a file is selected
        statusViewModel.$selectedFile
            .compactMap { $0 }
            .sink { [weak self] fileStatus in
                Task {
                    await self?.diffViewModel.loadDiff(for: fileStatus)
                }
            }
            .store(in: &cancellables)

        // Propagate commit success to trigger refresh
        commitViewModel.$lastCommitSucceeded
            .filter { $0 }
            .sink { [weak self] _ in
                Task {
                    await self?.refresh()
                }
            }
            .store(in: &cancellables)

        // Refresh status when hunk staging changes
        diffViewModel.onStatusChanged = { [weak self] in
            Task {
                await self?.statusViewModel.refresh()
            }
        }
    }

    private var cancellables = Set<AnyCancellable>()
}
