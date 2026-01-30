import Foundation

/// View model for remote operations.
@MainActor
final class RemoteViewModel: BaseViewModel {
    // MARK: - Published State

    /// All remotes.
    @Published private(set) var remotes: [Remote] = []

    /// Progress message for current operation.
    @Published private(set) var operationMessage: String?

    /// Last fetch timestamp.
    @Published private(set) var lastFetchDate: Date?

    // MARK: - Dependencies

    private let repository: Repository
    private let gitService: GitService

    // MARK: - Initialization

    init(repository: Repository, gitService: GitService) {
        self.repository = repository
        self.gitService = gitService
    }

    // MARK: - Public Methods

    /// Refreshes the remote list.
    func refresh() async {
        await performOperation {
            self.remotes = try await self.gitService.getRemotes(in: self.repository)
        }
    }

    /// Fetches from all remotes.
    func fetchAll(prune: Bool = false) async {
        operationMessage = "Fetching from all remotes..."
        defer { operationMessage = nil }

        await performOperation(showLoading: false) {
            try await self.gitService.fetch(in: self.repository, prune: prune)
            self.lastFetchDate = Date()
        }
    }

    /// Fetches from a specific remote.
    func fetch(remote: String, prune: Bool = false) async {
        operationMessage = "Fetching from \(remote)..."
        defer { operationMessage = nil }

        await performOperation(showLoading: false) {
            try await self.gitService.fetch(in: self.repository, remote: remote, prune: prune)
            self.lastFetchDate = Date()
        }
    }

    /// Pulls changes from remote.
    func pull(remote: String? = nil, branch: String? = nil, rebase: Bool = false) async {
        operationMessage = "Pulling changes..."
        defer { operationMessage = nil }

        await performOperation(showLoading: false) {
            try await self.gitService.pull(in: self.repository, remote: remote, branch: branch, rebase: rebase)
        }
    }

    /// Pushes changes to remote.
    func push(remote: String? = nil, branch: String? = nil, setUpstream: Bool = false, force: Bool = false) async {
        operationMessage = force ? "Force pushing..." : "Pushing changes..."
        defer { operationMessage = nil }

        await performOperation(showLoading: false) {
            try await self.gitService.push(in: self.repository, remote: remote, branch: branch, setUpstream: setUpstream, force: force)
        }
    }

    // MARK: - Remote Management

    /// Adds a new remote.
    func addRemote(name: String, url: String) async {
        operationMessage = "Adding remote \(name)..."
        defer { operationMessage = nil }

        await performOperation(showLoading: false) {
            try await self.gitService.addRemote(name: name, url: url, in: self.repository)
        }
        await refresh()
    }

    /// Removes a remote.
    func removeRemote(name: String) async {
        operationMessage = "Removing remote \(name)..."
        defer { operationMessage = nil }

        await performOperation(showLoading: false) {
            try await self.gitService.removeRemote(name: name, in: self.repository)
        }
        await refresh()
    }

    /// Renames a remote.
    func renameRemote(oldName: String, newName: String) async {
        operationMessage = "Renaming remote..."
        defer { operationMessage = nil }

        await performOperation(showLoading: false) {
            try await self.gitService.renameRemote(oldName: oldName, newName: newName, in: self.repository)
        }
        await refresh()
    }

    /// Sets the URL of a remote.
    func setRemoteURL(name: String, url: String) async {
        operationMessage = "Updating remote URL..."
        defer { operationMessage = nil }

        await performOperation(showLoading: false) {
            try await self.gitService.setRemoteURL(name: name, url: url, in: self.repository)
        }
        await refresh()
    }

    // MARK: - Computed Properties

    /// Whether there are any remotes.
    var hasRemotes: Bool {
        !remotes.isEmpty
    }

    /// The default remote (usually "origin").
    var defaultRemote: Remote? {
        remotes.first { $0.name == "origin" } ?? remotes.first
    }

    /// Formatted last fetch time.
    var lastFetchDescription: String? {
        lastFetchDate?.formatted(.relative(presentation: .named))
    }

    /// Prunes deleted remote branches.
    func prune(remote: String) async {
        operationMessage = "Pruning \(remote)..."
        defer { operationMessage = nil }

        await performOperation(showLoading: false) {
            try await self.gitService.fetch(in: self.repository, remote: remote, prune: true)
        }
    }
}
