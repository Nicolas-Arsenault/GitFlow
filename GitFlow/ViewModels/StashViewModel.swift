import Foundation

/// View model for stash management.
@MainActor
final class StashViewModel: ObservableObject {
    // MARK: - Published State

    /// All stashes.
    @Published private(set) var stashes: [Stash] = []

    /// The currently selected stash.
    @Published var selectedStash: Stash?

    /// Whether stashes are loading.
    @Published private(set) var isLoading: Bool = false

    /// Whether an operation is in progress.
    @Published private(set) var isOperationInProgress: Bool = false

    /// Current error, if any.
    @Published var error: GitError?

    // MARK: - Dependencies

    private let repository: Repository
    private let gitService: GitService

    // MARK: - Initialization

    init(repository: Repository, gitService: GitService) {
        self.repository = repository
        self.gitService = gitService
    }

    // MARK: - Public Methods

    /// Refreshes the stash list.
    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        do {
            stashes = try await gitService.getStashes(in: repository)
            error = nil

            // Clear selection if stash no longer exists
            if let selected = selectedStash,
               !stashes.contains(where: { $0.index == selected.index }) {
                selectedStash = nil
            }
        } catch let gitError as GitError {
            error = gitError
        } catch {
            self.error = .unknown(message: error.localizedDescription)
        }
    }

    /// Creates a new stash.
    func createStash(message: String? = nil, includeUntracked: Bool = false) async {
        isOperationInProgress = true
        defer { isOperationInProgress = false }

        do {
            try await gitService.createStash(message: message, includeUntracked: includeUntracked, in: repository)
            await refresh()
            error = nil
        } catch let gitError as GitError {
            error = gitError
        } catch {
            self.error = .unknown(message: error.localizedDescription)
        }
    }

    /// Applies a stash without removing it.
    func applyStash(_ stash: Stash) async {
        isOperationInProgress = true
        defer { isOperationInProgress = false }

        do {
            try await gitService.applyStash(stash.refName, in: repository)
            error = nil
        } catch let gitError as GitError {
            error = gitError
        } catch {
            self.error = .unknown(message: error.localizedDescription)
        }
    }

    /// Pops a stash (apply and remove).
    func popStash(_ stash: Stash) async {
        isOperationInProgress = true
        defer { isOperationInProgress = false }

        do {
            try await gitService.popStash(stash.refName, in: repository)
            await refresh()
            error = nil
        } catch let gitError as GitError {
            error = gitError
        } catch {
            self.error = .unknown(message: error.localizedDescription)
        }
    }

    /// Drops a stash.
    func dropStash(_ stash: Stash) async {
        isOperationInProgress = true
        defer { isOperationInProgress = false }

        do {
            try await gitService.dropStash(stash.refName, in: repository)
            await refresh()
            error = nil
        } catch let gitError as GitError {
            error = gitError
        } catch {
            self.error = .unknown(message: error.localizedDescription)
        }
    }

    /// Clears all stashes.
    func clearAllStashes() async {
        isOperationInProgress = true
        defer { isOperationInProgress = false }

        do {
            try await gitService.clearStashes(in: repository)
            await refresh()
            error = nil
        } catch let gitError as GitError {
            error = gitError
        } catch {
            self.error = .unknown(message: error.localizedDescription)
        }
    }

    // MARK: - Computed Properties

    /// Whether there are any stashes.
    var hasStashes: Bool {
        !stashes.isEmpty
    }

    /// The count of stashes.
    var stashCount: Int {
        stashes.count
    }
}
