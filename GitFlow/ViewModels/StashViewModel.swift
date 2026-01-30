import Foundation

/// View model for stash management.
@MainActor
final class StashViewModel: BaseViewModel {
    // MARK: - Published State

    /// All stashes.
    @Published private(set) var stashes: [Stash] = []

    /// The currently selected stash.
    @Published var selectedStash: Stash?

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
        await performOperation {
            self.stashes = try await self.gitService.getStashes(in: self.repository)

            // Clear selection if stash no longer exists
            if let selected = self.selectedStash,
               !self.stashes.contains(where: { $0.index == selected.index }) {
                self.selectedStash = nil
            }
        }
    }

    /// Creates a new stash.
    /// - Parameters:
    ///   - message: Optional message for the stash.
    ///   - includeUntracked: Whether to include untracked files.
    ///   - includeIgnored: Whether to include ignored files (implies includeUntracked).
    func createStash(message: String? = nil, includeUntracked: Bool = false, includeIgnored: Bool = false) async {
        await performOperation(showLoading: false) {
            try await self.gitService.createStash(
                message: message,
                includeUntracked: includeUntracked,
                includeIgnored: includeIgnored,
                in: self.repository
            )
        }
        await refresh()
    }

    /// Renames a stash by dropping and recreating it with a new message.
    /// Note: This changes the stash index as it creates a new stash entry.
    /// - Parameters:
    ///   - stash: The stash to rename.
    ///   - newMessage: The new message for the stash.
    func renameStash(_ stash: Stash, to newMessage: String) async {
        await performOperation(showLoading: false) {
            try await self.gitService.renameStash(stash.refName, to: newMessage, in: self.repository)
        }
        await refresh()
    }

    /// Applies a stash without removing it.
    func applyStash(_ stash: Stash) async {
        await performOperation(showLoading: false) {
            try await self.gitService.applyStash(stash.refName, in: self.repository)
        }
    }

    /// Pops a stash (apply and remove).
    func popStash(_ stash: Stash) async {
        await performOperation(showLoading: false) {
            try await self.gitService.popStash(stash.refName, in: self.repository)
        }
        await refresh()
    }

    /// Drops a stash.
    func dropStash(_ stash: Stash) async {
        await performOperation(showLoading: false) {
            try await self.gitService.dropStash(stash.refName, in: self.repository)
        }
        await refresh()
    }

    /// Clears all stashes.
    func clearAllStashes() async {
        await performOperation(showLoading: false) {
            try await self.gitService.clearStashes(in: self.repository)
        }
        await refresh()
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
