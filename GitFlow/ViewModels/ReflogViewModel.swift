import Foundation

/// View model for reflog management.
/// The reflog records when the tips of branches and other references were updated,
/// allowing users to recover lost commits and branches.
@MainActor
final class ReflogViewModel: BaseViewModel {
    // MARK: - Published State

    /// All reflog entries.
    @Published private(set) var entries: [ReflogEntry] = []

    /// Filtered entries based on search query.
    @Published private(set) var filteredEntries: [ReflogEntry] = []

    /// The currently selected reflog entry.
    @Published var selectedEntry: ReflogEntry?

    /// The current search/filter query.
    @Published var searchQuery: String = "" {
        didSet { applyFilter() }
    }

    /// The selected action filter.
    @Published var actionFilter: ReflogAction? {
        didSet { applyFilter() }
    }

    /// Optional branch filter for viewing branch-specific reflog.
    @Published var branchFilter: String? {
        didSet {
            Task { await refresh() }
        }
    }

    // MARK: - Dependencies

    private let repository: Repository
    private let gitService: GitService

    // MARK: - Initialization

    init(repository: Repository, gitService: GitService) {
        self.repository = repository
        self.gitService = gitService
    }

    // MARK: - Public Methods

    /// Refreshes the reflog entries.
    func refresh() async {
        await performOperation {
            if let branch = self.branchFilter {
                self.entries = try await self.gitService.getBranchReflog(branchName: branch, in: self.repository)
            } else {
                self.entries = try await self.gitService.getReflog(in: self.repository)
            }
            self.applyFilter()

            // Clear selection if entry no longer exists
            if let selected = self.selectedEntry,
               !self.entries.contains(where: { $0.selector == selected.selector }) {
                self.selectedEntry = nil
            }
        }
    }

    /// Loads more reflog entries (for infinite scrolling).
    func loadMore() async {
        guard !isLoading else { return }

        await performOperation {
            let currentCount = self.entries.count
            let moreEntries: [ReflogEntry]

            if let branch = self.branchFilter {
                moreEntries = try await self.gitService.getBranchReflog(
                    branchName: branch,
                    in: self.repository,
                    limit: currentCount + 100
                )
            } else {
                moreEntries = try await self.gitService.getReflog(
                    in: self.repository,
                    limit: currentCount + 100
                )
            }

            // Only add entries that aren't already in our list
            let newEntries = moreEntries.filter { newEntry in
                !self.entries.contains(where: { $0.selector == newEntry.selector })
            }

            self.entries.append(contentsOf: newEntries)
            self.applyFilter()
        }
    }

    /// Checks out the commit from the selected reflog entry.
    /// Note: This will result in a detached HEAD state.
    func checkoutEntry(_ entry: ReflogEntry) async {
        await performOperation(showLoading: false) {
            try await self.gitService.checkoutReflogEntry(entry, in: self.repository)
        }
    }

    /// Creates a new branch from the selected reflog entry.
    /// This is useful for recovering lost branches.
    func createBranch(named name: String, from entry: ReflogEntry) async {
        await performOperation(showLoading: false) {
            try await self.gitService.createBranchFromReflogEntry(name: name, entry: entry, in: self.repository)
        }
        await refresh()
    }

    /// Cherry-picks the commit from a reflog entry.
    func cherryPickEntry(_ entry: ReflogEntry) async {
        await performOperation(showLoading: false) {
            try await self.gitService.cherryPick(commitHash: entry.hash, in: self.repository)
        }
    }

    /// Clears the search and action filters.
    func clearFilters() {
        searchQuery = ""
        actionFilter = nil
    }

    // MARK: - Private Methods

    /// Applies the current search query and action filter to entries.
    private func applyFilter() {
        var result = entries

        // Filter by action type
        if let action = actionFilter {
            result = result.filter { $0.action == action }
        }

        // Filter by search query
        if !searchQuery.isEmpty {
            let query = searchQuery.lowercased()
            result = result.filter { entry in
                entry.message.lowercased().contains(query) ||
                entry.hash.lowercased().contains(query) ||
                entry.shortHash.lowercased().contains(query) ||
                entry.selector.lowercased().contains(query) ||
                entry.actionRaw.lowercased().contains(query) ||
                entry.authorName.lowercased().contains(query)
            }
        }

        filteredEntries = result
    }

    // MARK: - Computed Properties

    /// Whether there are any reflog entries.
    var hasEntries: Bool {
        !entries.isEmpty
    }

    /// The count of reflog entries (filtered).
    var entryCount: Int {
        filteredEntries.count
    }

    /// The total count of reflog entries (unfiltered).
    var totalEntryCount: Int {
        entries.count
    }

    /// Available action types for filtering (based on current entries).
    var availableActions: [ReflogAction] {
        let actions = Set(entries.map { $0.action })
        return ReflogAction.allCases.filter { actions.contains($0) }
    }

    /// Whether any filter is currently active.
    var hasActiveFilter: Bool {
        !searchQuery.isEmpty || actionFilter != nil
    }
}
