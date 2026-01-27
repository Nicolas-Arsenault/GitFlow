import SwiftUI
import AppKit

/// Global application state container.
/// Manages the currently open repository and application-wide settings.
@MainActor
final class AppState: ObservableObject {
    // MARK: - Published State

    /// The currently open repository, if any.
    @Published private(set) var currentRepository: Repository?

    /// The view model for the current repository.
    @Published private(set) var repositoryViewModel: RepositoryViewModel?

    /// List of recently opened repository paths.
    @Published private(set) var recentRepositories: [URL] = []

    /// Whether the app is currently loading a repository.
    @Published private(set) var isLoading: Bool = false

    /// Current error to display, if any.
    @Published var currentError: GitError?

    // MARK: - Services

    private let recentRepositoriesStore = RecentRepositoriesStore()
    private let gitService = GitService()

    // MARK: - Initialization

    init() {
        loadRecentRepositories()
    }

    // MARK: - Repository Management

    /// Opens a repository at the specified path.
    /// - Parameter url: The URL to the repository root directory.
    func openRepository(at url: URL) {
        Task {
            await performOpenRepository(at: url)
        }
    }

    /// Shows the system open panel to select a repository directory.
    func showOpenRepositoryPanel() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select a Git repository folder"
        panel.prompt = "Open"

        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            self?.openRepository(at: url)
        }
    }

    /// Closes the currently open repository.
    func closeRepository() {
        currentRepository = nil
        repositoryViewModel = nil
    }

    // MARK: - Recent Repositories

    /// Clears the list of recent repositories.
    func clearRecentRepositories() {
        recentRepositories = []
        recentRepositoriesStore.clear()
    }

    // MARK: - Private Methods

    private func performOpenRepository(at url: URL) async {
        isLoading = true
        defer { isLoading = false }

        do {
            // Validate that this is a Git repository
            let isRepo = try await gitService.isGitRepository(at: url)
            guard isRepo else {
                currentError = .notARepository(path: url.path)
                return
            }

            // Create repository model
            let repository = Repository(rootURL: url)
            currentRepository = repository

            // Create view model and load initial data
            let viewModel = RepositoryViewModel(repository: repository, gitService: gitService)
            repositoryViewModel = viewModel

            // Add to recent repositories
            addToRecentRepositories(url)

            // Perform initial refresh
            await viewModel.refresh()

        } catch let error as GitError {
            currentError = error
        } catch {
            currentError = .unknown(message: error.localizedDescription)
        }
    }

    private func addToRecentRepositories(_ url: URL) {
        // Remove if already exists to move to front
        recentRepositories.removeAll { $0 == url }

        // Add to front
        recentRepositories.insert(url, at: 0)

        // Keep only last 10
        if recentRepositories.count > 10 {
            recentRepositories = Array(recentRepositories.prefix(10))
        }

        // Persist
        recentRepositoriesStore.save(recentRepositories)
    }

    private func loadRecentRepositories() {
        recentRepositories = recentRepositoriesStore.load()
    }
}
