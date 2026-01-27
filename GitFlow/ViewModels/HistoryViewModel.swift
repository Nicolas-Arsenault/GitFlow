import Foundation

/// View model for commit history.
@MainActor
final class HistoryViewModel: ObservableObject {
    // MARK: - Published State

    /// The commit history.
    @Published private(set) var commits: [Commit] = []

    /// The currently selected commit.
    @Published var selectedCommit: Commit?

    /// Whether history is currently loading.
    @Published private(set) var isLoading: Bool = false

    /// Whether more commits can be loaded.
    @Published private(set) var hasMore: Bool = true

    /// Current error, if any.
    @Published var error: GitError?

    /// Optional file path filter.
    @Published var filePathFilter: String?

    /// Optional branch/ref filter.
    @Published var refFilter: String?

    // MARK: - Configuration

    /// Number of commits to load per page.
    let pageSize: Int = 50

    // MARK: - Dependencies

    private let repository: Repository
    private let gitService: GitService

    // MARK: - Initialization

    init(repository: Repository, gitService: GitService) {
        self.repository = repository
        self.gitService = gitService
    }

    // MARK: - Public Methods

    /// Refreshes the commit history.
    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        do {
            commits = try await gitService.getHistory(
                in: repository,
                limit: pageSize,
                ref: refFilter
            )
            hasMore = commits.count == pageSize
            error = nil

            // Clear selection if commit no longer in list
            if let selected = selectedCommit,
               !commits.contains(where: { $0.hash == selected.hash }) {
                selectedCommit = nil
            }

        } catch let gitError as GitError {
            error = gitError
        } catch {
            self.error = .unknown(message: error.localizedDescription)
        }
    }

    /// Loads more commits (pagination).
    func loadMore() async {
        guard hasMore, !isLoading else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let newCommits = try await gitService.getHistory(
                in: repository,
                limit: pageSize,
                ref: refFilter
            )

            // Skip commits we already have
            let existingHashes = Set(commits.map(\.hash))
            let uniqueNewCommits = newCommits.filter { !existingHashes.contains($0.hash) }

            if uniqueNewCommits.isEmpty {
                hasMore = false
            } else {
                commits.append(contentsOf: uniqueNewCommits)
                hasMore = newCommits.count == pageSize
            }

            error = nil

        } catch let gitError as GitError {
            error = gitError
        } catch {
            self.error = .unknown(message: error.localizedDescription)
        }
    }

    /// Selects a commit for viewing details.
    func selectCommit(_ commit: Commit) {
        selectedCommit = commit
    }

    /// Clears the current selection.
    func clearSelection() {
        selectedCommit = nil
    }

    /// Sets a file path filter and refreshes.
    func filterByFile(_ path: String?) async {
        filePathFilter = path
        await refresh()
    }

    /// Sets a ref filter and refreshes.
    func filterByRef(_ ref: String?) async {
        refFilter = ref
        await refresh()
    }

    // MARK: - Computed Properties

    /// Whether there are any commits.
    var hasCommits: Bool {
        !commits.isEmpty
    }

    /// The count of loaded commits.
    var commitCount: Int {
        commits.count
    }
}
