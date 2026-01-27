import Foundation

/// View model for remote operations.
@MainActor
final class RemoteViewModel: ObservableObject {
    // MARK: - Published State

    /// All remotes.
    @Published private(set) var remotes: [Remote] = []

    /// Whether remotes are loading.
    @Published private(set) var isLoading: Bool = false

    /// Whether an operation is in progress.
    @Published private(set) var isOperationInProgress: Bool = false

    /// Progress message for current operation.
    @Published private(set) var operationMessage: String?

    /// Current error, if any.
    @Published var error: GitError?

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
        isLoading = true
        defer { isLoading = false }

        do {
            remotes = try await gitService.getRemotes(in: repository)
            error = nil
        } catch let gitError as GitError {
            error = gitError
        } catch {
            self.error = .unknown(message: error.localizedDescription)
        }
    }

    /// Fetches from all remotes.
    func fetchAll(prune: Bool = false) async {
        isOperationInProgress = true
        operationMessage = "Fetching from all remotes..."
        defer {
            isOperationInProgress = false
            operationMessage = nil
        }

        do {
            try await gitService.fetch(in: repository, prune: prune)
            lastFetchDate = Date()
            error = nil
        } catch let gitError as GitError {
            error = gitError
        } catch {
            self.error = .unknown(message: error.localizedDescription)
        }
    }

    /// Fetches from a specific remote.
    func fetch(remote: String, prune: Bool = false) async {
        isOperationInProgress = true
        operationMessage = "Fetching from \(remote)..."
        defer {
            isOperationInProgress = false
            operationMessage = nil
        }

        do {
            try await gitService.fetch(in: repository, remote: remote, prune: prune)
            lastFetchDate = Date()
            error = nil
        } catch let gitError as GitError {
            error = gitError
        } catch {
            self.error = .unknown(message: error.localizedDescription)
        }
    }

    /// Pulls changes from remote.
    func pull(remote: String? = nil, branch: String? = nil, rebase: Bool = false) async {
        isOperationInProgress = true
        operationMessage = "Pulling changes..."
        defer {
            isOperationInProgress = false
            operationMessage = nil
        }

        do {
            try await gitService.pull(in: repository, remote: remote, branch: branch, rebase: rebase)
            error = nil
        } catch let gitError as GitError {
            error = gitError
        } catch {
            self.error = .unknown(message: error.localizedDescription)
        }
    }

    /// Pushes changes to remote.
    func push(remote: String? = nil, branch: String? = nil, setUpstream: Bool = false, force: Bool = false) async {
        isOperationInProgress = true
        operationMessage = force ? "Force pushing..." : "Pushing changes..."
        defer {
            isOperationInProgress = false
            operationMessage = nil
        }

        do {
            try await gitService.push(in: repository, remote: remote, branch: branch, setUpstream: setUpstream, force: force)
            error = nil
        } catch let gitError as GitError {
            error = gitError
        } catch {
            self.error = .unknown(message: error.localizedDescription)
        }
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
}
