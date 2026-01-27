import Foundation

/// View model for branch operations.
@MainActor
final class BranchViewModel: ObservableObject {
    // MARK: - Published State

    /// All branches (local and remote).
    @Published private(set) var branches: [Branch] = []

    /// Local branches only.
    @Published private(set) var localBranches: [Branch] = []

    /// Remote branches only.
    @Published private(set) var remoteBranches: [Branch] = []

    /// The current branch.
    @Published private(set) var currentBranch: Branch?

    /// The currently selected branch for viewing.
    @Published var selectedBranch: Branch?

    /// Whether branches are currently loading.
    @Published private(set) var isLoading: Bool = false

    /// Whether a branch operation is in progress.
    @Published private(set) var isOperationInProgress: Bool = false

    /// Current error, if any.
    @Published var error: GitError?

    /// Whether to show remote branches.
    @Published var showRemoteBranches: Bool = true

    // MARK: - Dependencies

    private let repository: Repository
    private let gitService: GitService

    // MARK: - Initialization

    init(repository: Repository, gitService: GitService) {
        self.repository = repository
        self.gitService = gitService
    }

    // MARK: - Public Methods

    /// Refreshes the branch list.
    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        do {
            branches = try await gitService.getBranches(in: repository, includeRemote: true)
            localBranches = branches.filter { !$0.isRemote }
            remoteBranches = branches.filter { $0.isRemote }
            currentBranch = branches.first { $0.isCurrent }
            error = nil
        } catch let gitError as GitError {
            error = gitError
        } catch {
            self.error = .unknown(message: error.localizedDescription)
        }
    }

    /// Checks out the specified branch.
    func checkout(branchName: String) async {
        isOperationInProgress = true
        defer { isOperationInProgress = false }

        do {
            try await gitService.checkout(branch: branchName, in: repository)
            await refresh()
            error = nil
        } catch let gitError as GitError {
            error = gitError
        } catch {
            self.error = .unknown(message: error.localizedDescription)
        }
    }

    /// Checks out the specified branch object.
    func checkout(branch: Branch) async {
        await checkout(branchName: branch.name)
    }

    /// Creates a new branch and checks it out.
    func createBranch(name: String, startPoint: String? = nil) async {
        isOperationInProgress = true
        defer { isOperationInProgress = false }

        do {
            try await gitService.createBranch(name: name, startPoint: startPoint, in: repository)
            await refresh()
            error = nil
        } catch let gitError as GitError {
            error = gitError
        } catch {
            self.error = .unknown(message: error.localizedDescription)
        }
    }

    /// Deletes a branch.
    func deleteBranch(name: String, force: Bool = false) async {
        isOperationInProgress = true
        defer { isOperationInProgress = false }

        do {
            try await gitService.deleteBranch(name: name, force: force, in: repository)
            await refresh()
            error = nil
        } catch let gitError as GitError {
            error = gitError
        } catch {
            self.error = .unknown(message: error.localizedDescription)
        }
    }

    /// Selects a branch for viewing.
    func selectBranch(_ branch: Branch) {
        selectedBranch = branch
    }

    // MARK: - Computed Properties

    /// Branches to display based on filter settings.
    var displayBranches: [Branch] {
        if showRemoteBranches {
            return branches
        }
        return localBranches
    }

    /// Local branch count.
    var localBranchCount: Int {
        localBranches.count
    }

    /// Remote branch count.
    var remoteBranchCount: Int {
        remoteBranches.count
    }

    /// The current branch name.
    var currentBranchName: String? {
        currentBranch?.name
    }

    /// Whether the current branch is ahead of upstream.
    var isAhead: Bool {
        (currentBranch?.ahead ?? 0) > 0
    }

    /// Whether the current branch is behind upstream.
    var isBehind: Bool {
        (currentBranch?.behind ?? 0) > 0
    }

    /// Summary of ahead/behind status.
    var syncStatus: String? {
        guard let branch = currentBranch, branch.upstream != nil else { return nil }

        if branch.ahead > 0 && branch.behind > 0 {
            return "↑\(branch.ahead) ↓\(branch.behind)"
        } else if branch.ahead > 0 {
            return "↑\(branch.ahead)"
        } else if branch.behind > 0 {
            return "↓\(branch.behind)"
        }
        return nil
    }
}
