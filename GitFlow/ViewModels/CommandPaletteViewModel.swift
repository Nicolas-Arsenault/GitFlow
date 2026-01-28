import Foundation
import Combine

/// View model for the command palette and global search.
@MainActor
final class CommandPaletteViewModel: ObservableObject {
    // MARK: - Published State

    /// Whether the palette is visible.
    @Published var isVisible: Bool = false

    /// The search query.
    @Published var query: String = "" {
        didSet {
            search()
        }
    }

    /// Filtered search results.
    @Published private(set) var searchResults: [GlobalSearchResult] = []

    /// All available commands.
    @Published private(set) var commands: [PaletteCommand] = []

    /// Filtered commands based on query.
    @Published private(set) var filteredCommands: [PaletteCommand] = []

    /// Recent actions.
    @Published private(set) var recentActions: [RecentAction] = []

    /// The selected result index.
    @Published var selectedIndex: Int = 0

    /// Whether search is in progress.
    @Published private(set) var isSearching: Bool = false

    /// Current search mode.
    @Published var searchMode: SearchMode = .all

    // MARK: - Dependencies

    private let repository: Repository
    private let gitService: GitService
    private var cancellables = Set<AnyCancellable>()
    private let maxRecentActions = 10

    // MARK: - Types

    enum SearchMode: String, CaseIterable, Identifiable {
        case all = "All"
        case files = "Files"
        case commits = "Commits"
        case branches = "Branches"
        case commands = "Commands"

        var id: String { rawValue }

        var prefix: String {
            switch self {
            case .all: return ""
            case .files: return ">"
            case .commits: return "#"
            case .branches: return "@"
            case .commands: return "/"
            }
        }
    }

    // MARK: - Initialization

    init(repository: Repository, gitService: GitService) {
        self.repository = repository
        self.gitService = gitService
        loadRecentActions()
        registerCommands()
    }

    // MARK: - Public Methods

    /// Shows the command palette.
    func show() {
        isVisible = true
        query = ""
        selectedIndex = 0
        searchMode = .all
    }

    /// Hides the command palette.
    func hide() {
        isVisible = false
        query = ""
        searchResults = []
    }

    /// Toggles the command palette visibility.
    func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }

    /// Moves selection up.
    func moveUp() {
        let total = totalResultCount
        guard total > 0 else { return }
        selectedIndex = (selectedIndex - 1 + total) % total
    }

    /// Moves selection down.
    func moveDown() {
        let total = totalResultCount
        guard total > 0 else { return }
        selectedIndex = (selectedIndex + 1) % total
    }

    /// Executes the selected item.
    func executeSelected() {
        let total = totalResultCount
        guard total > 0, selectedIndex < total else { return }

        if searchMode == .commands || (searchMode == .all && query.hasPrefix("/")) {
            // Command mode
            if selectedIndex < filteredCommands.count {
                let command = filteredCommands[selectedIndex]
                execute(command)
            }
        } else if searchMode == .all && query.isEmpty {
            // Show recent actions
            if selectedIndex < recentActions.count {
                // Could re-execute recent action if we stored the command
            }
        } else {
            // Search results
            if selectedIndex < searchResults.count {
                let result = searchResults[selectedIndex]
                result.action()
                addRecentAction(name: result.title, category: result.type.rawValue)
                hide()
            }
        }
    }

    /// Executes a command.
    func execute(_ command: PaletteCommand) {
        command.action()
        addRecentAction(name: command.name, category: command.category.rawValue)
        hide()
    }

    /// Performs search based on current query and mode.
    func search() {
        // Detect mode from prefix
        if query.hasPrefix(">") {
            searchMode = .files
        } else if query.hasPrefix("#") {
            searchMode = .commits
        } else if query.hasPrefix("@") {
            searchMode = .branches
        } else if query.hasPrefix("/") {
            searchMode = .commands
        }

        // Remove prefix for actual query
        let cleanQuery = query
            .trimmingCharacters(in: CharacterSet(charactersIn: ">@#/"))
            .trimmingCharacters(in: .whitespaces)
            .lowercased()

        // Reset selection
        selectedIndex = 0

        // Filter based on mode
        switch searchMode {
        case .commands:
            filterCommands(cleanQuery)
            searchResults = []

        case .files:
            Task { await searchFiles(cleanQuery) }

        case .commits:
            Task { await searchCommits(cleanQuery) }

        case .branches:
            Task { await searchBranches(cleanQuery) }

        case .all:
            if cleanQuery.isEmpty {
                filteredCommands = []
                searchResults = []
            } else {
                filterCommands(cleanQuery)
                Task { await searchAll(cleanQuery) }
            }
        }
    }

    // MARK: - Private Methods

    private func registerCommands() {
        commands = [
            // Git commands
            PaletteCommand(
                name: "Fetch",
                description: "Fetch from all remotes",
                category: .git,
                shortcut: "⌘⇧F",
                iconName: "arrow.down.circle"
            ) { /* Action defined by caller */ },

            PaletteCommand(
                name: "Pull",
                description: "Pull changes from remote",
                category: .git,
                shortcut: "⌘⇧P",
                iconName: "arrow.down.doc"
            ) { },

            PaletteCommand(
                name: "Push",
                description: "Push changes to remote",
                category: .git,
                shortcut: "⌘⇧U",
                iconName: "arrow.up.doc"
            ) { },

            // Branch commands
            PaletteCommand(
                name: "Create Branch",
                description: "Create a new branch",
                category: .branch,
                shortcut: "⌘⇧B",
                iconName: "plus.circle"
            ) { },

            PaletteCommand(
                name: "Switch Branch",
                description: "Switch to another branch",
                category: .branch,
                iconName: "arrow.left.arrow.right"
            ) { },

            PaletteCommand(
                name: "Merge Branch",
                description: "Merge another branch into current",
                category: .branch,
                iconName: "arrow.triangle.merge"
            ) { },

            // Commit commands
            PaletteCommand(
                name: "Commit",
                description: "Commit staged changes",
                category: .commit,
                shortcut: "⌘↩",
                iconName: "checkmark.circle"
            ) { },

            PaletteCommand(
                name: "Amend Commit",
                description: "Amend the last commit",
                category: .commit,
                iconName: "arrow.uturn.backward.circle"
            ) { },

            PaletteCommand(
                name: "Stash Changes",
                description: "Stash current changes",
                category: .commit,
                shortcut: "⌘⇧S",
                iconName: "tray.and.arrow.down"
            ) { },

            // File commands
            PaletteCommand(
                name: "Stage All",
                description: "Stage all changed files",
                category: .file,
                iconName: "plus.square"
            ) { },

            PaletteCommand(
                name: "Unstage All",
                description: "Unstage all files",
                category: .file,
                iconName: "minus.square"
            ) { },

            PaletteCommand(
                name: "Discard All Changes",
                description: "Discard all uncommitted changes",
                category: .file,
                iconName: "arrow.uturn.backward"
            ) { },

            // View commands
            PaletteCommand(
                name: "Toggle Sidebar",
                description: "Show or hide the sidebar",
                category: .view,
                shortcut: "⌘0",
                iconName: "sidebar.left"
            ) { },

            PaletteCommand(
                name: "Show History",
                description: "Show commit history",
                category: .view,
                iconName: "clock"
            ) { },

            PaletteCommand(
                name: "Show Changes",
                description: "Show working changes",
                category: .view,
                iconName: "doc.badge.ellipsis"
            ) { },

            // Repository commands
            PaletteCommand(
                name: "Open in Terminal",
                description: "Open repository in terminal",
                category: .repository,
                iconName: "terminal"
            ) { },

            PaletteCommand(
                name: "Reveal in Finder",
                description: "Show repository in Finder",
                category: .repository,
                iconName: "folder"
            ) { },

            PaletteCommand(
                name: "Copy Repository Path",
                description: "Copy path to clipboard",
                category: .repository,
                iconName: "doc.on.doc"
            ) { },
        ]
    }

    private func filterCommands(_ query: String) {
        if query.isEmpty {
            filteredCommands = commands
        } else {
            filteredCommands = commands.filter { command in
                command.name.lowercased().contains(query) ||
                command.category.rawValue.lowercased().contains(query) ||
                (command.description?.lowercased().contains(query) ?? false)
            }
        }
    }

    private func searchFiles(_ query: String) async {
        guard !query.isEmpty else {
            searchResults = []
            return
        }

        isSearching = true
        defer { isSearching = false }

        // Search for files matching the query
        let fileManager = FileManager.default
        var results: [GlobalSearchResult] = []

        func searchDirectory(_ url: URL, relativePath: String) {
            guard let contents = try? fileManager.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { return }

            for fileURL in contents {
                let name = fileURL.lastPathComponent
                let isDirectory = (try? fileURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false

                // Skip .git directory
                if name == ".git" { continue }

                let path = relativePath.isEmpty ? name : "\(relativePath)/\(name)"

                if name.lowercased().contains(query) {
                    results.append(GlobalSearchResult(
                        type: isDirectory ? .file : .file,
                        title: name,
                        subtitle: path,
                        path: path
                    ) {
                        // Open file action
                    })
                }

                if isDirectory && results.count < 50 {
                    searchDirectory(fileURL, relativePath: path)
                }

                if results.count >= 50 { return }
            }
        }

        searchDirectory(repository.rootURL, relativePath: "")
        searchResults = results
    }

    private func searchCommits(_ query: String) async {
        guard !query.isEmpty else {
            searchResults = []
            return
        }

        isSearching = true
        defer { isSearching = false }

        do {
            let commits = try await gitService.searchCommits(message: query, limit: 20, in: repository)
            searchResults = commits.map { commit in
                GlobalSearchResult(
                    type: .commit,
                    title: commit.message.components(separatedBy: .newlines).first ?? "",
                    subtitle: "\(commit.shortHash) by \(commit.author)",
                    path: commit.hash
                ) {
                    // View commit action
                }
            }
        } catch {
            searchResults = []
        }
    }

    private func searchBranches(_ query: String) async {
        guard !query.isEmpty else {
            searchResults = []
            return
        }

        isSearching = true
        defer { isSearching = false }

        do {
            let branches = try await gitService.getBranches(in: repository)
            let filtered = branches.filter { $0.name.lowercased().contains(query) }

            searchResults = filtered.prefix(20).map { branch in
                GlobalSearchResult(
                    type: .branch,
                    title: branch.name,
                    subtitle: branch.isRemote ? "Remote" : (branch.isHead ? "Current" : "Local"),
                    path: branch.name
                ) {
                    // Checkout branch action
                }
            }
        } catch {
            searchResults = []
        }
    }

    private func searchAll(_ query: String) async {
        guard !query.isEmpty else {
            searchResults = []
            return
        }

        isSearching = true
        defer { isSearching = false }

        var allResults: [GlobalSearchResult] = []

        // Search branches (quick)
        do {
            let branches = try await gitService.getBranches(in: repository)
            let filtered = branches.filter { $0.name.lowercased().contains(query) }

            allResults.append(contentsOf: filtered.prefix(5).map { branch in
                GlobalSearchResult(
                    type: .branch,
                    title: branch.name,
                    subtitle: branch.isRemote ? "Remote" : "Local"
                ) { }
            })
        } catch { }

        // Search commits
        do {
            let commits = try await gitService.searchCommits(message: query, limit: 5, in: repository)
            allResults.append(contentsOf: commits.map { commit in
                GlobalSearchResult(
                    type: .commit,
                    title: commit.message.components(separatedBy: .newlines).first ?? "",
                    subtitle: commit.shortHash
                ) { }
            })
        } catch { }

        searchResults = allResults
    }

    private func addRecentAction(name: String, category: String) {
        let action = RecentAction(name: name, category: category)
        recentActions.insert(action, at: 0)

        // Keep only recent actions
        if recentActions.count > maxRecentActions {
            recentActions = Array(recentActions.prefix(maxRecentActions))
        }

        saveRecentActions()
    }

    private func loadRecentActions() {
        // Load from UserDefaults or other storage
        if let data = UserDefaults.standard.data(forKey: "recentActions"),
           let actions = try? JSONDecoder().decode([RecentAction].self, from: data) {
            recentActions = actions
        }
    }

    private func saveRecentActions() {
        if let data = try? JSONEncoder().encode(recentActions) {
            UserDefaults.standard.set(data, forKey: "recentActions")
        }
    }

    // MARK: - Computed Properties

    private var totalResultCount: Int {
        if searchMode == .commands || (searchMode == .all && query.hasPrefix("/")) {
            return filteredCommands.count
        } else if searchMode == .all && query.isEmpty {
            return recentActions.count
        } else {
            return searchResults.count
        }
    }

    /// Commands grouped by category.
    var commandsByCategory: [(category: CommandCategory, commands: [PaletteCommand])] {
        CommandCategory.allCases.compactMap { category in
            let categoryCommands = filteredCommands.filter { $0.category == category }
            return categoryCommands.isEmpty ? nil : (category, categoryCommands)
        }
    }
}
