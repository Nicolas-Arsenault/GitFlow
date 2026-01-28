import Foundation
import AppKit

/// View model for GitHub integration features.
@MainActor
final class GitHubViewModel: ObservableObject {
    // MARK: - Published State

    /// GitHub repository info extracted from remotes.
    @Published private(set) var githubInfo: GitHubRemoteInfo?

    /// Whether this repository is connected to GitHub.
    @Published private(set) var isGitHubRepository: Bool = false

    /// The authenticated GitHub user.
    @Published private(set) var authenticatedUser: GitHubUser?

    /// Whether we're authenticated.
    @Published var isAuthenticated: Bool = false

    /// Current issues (excluding PRs).
    @Published private(set) var issues: [GitHubIssue] = []

    /// Current pull requests.
    @Published private(set) var pullRequests: [GitHubPullRequest] = []

    /// Selected pull request for detailed view.
    @Published var selectedPullRequest: GitHubPullRequest?

    /// Reviews for the selected PR.
    @Published private(set) var selectedPRReviews: [GitHubReview] = []

    /// Comments for the selected PR.
    @Published private(set) var selectedPRComments: [GitHubComment] = []

    /// Check runs for the selected PR.
    @Published private(set) var selectedPRChecks: [GitHubCheckRun] = []

    /// Whether data is loading.
    @Published private(set) var isLoading: Bool = false

    /// Current error, if any.
    @Published var error: GitHubError?

    /// Filter for issues/PRs state.
    @Published var stateFilter: StateFilter = .open

    /// The GitHub token (stored in keychain ideally).
    @Published var githubToken: String = "" {
        didSet {
            Task {
                await gitHubService.setAuthToken(githubToken.isEmpty ? nil : githubToken)
                await validateAndLoadUser()
            }
        }
    }

    // MARK: - Dependencies

    private let repository: Repository
    private let gitService: GitService
    private let gitHubService: GitHubService

    // MARK: - Types

    enum StateFilter: String, CaseIterable, Identifiable {
        case open = "open"
        case closed = "closed"
        case all = "all"

        var id: String { rawValue }

        var displayName: String {
            rawValue.capitalized
        }
    }

    // MARK: - Initialization

    init(repository: Repository, gitService: GitService, gitHubService: GitHubService = GitHubService()) {
        self.repository = repository
        self.gitService = gitService
        self.gitHubService = gitHubService
    }

    // MARK: - Public Methods

    /// Initializes GitHub connection by detecting if this is a GitHub repo.
    func initialize() async {
        githubInfo = await gitHubService.getGitHubInfo(for: repository, gitService: gitService)
        isGitHubRepository = githubInfo != nil

        if isGitHubRepository && !githubToken.isEmpty {
            await validateAndLoadUser()
        }
    }

    /// Validates the token and loads the authenticated user.
    func validateAndLoadUser() async {
        guard !githubToken.isEmpty else {
            isAuthenticated = false
            authenticatedUser = nil
            return
        }

        do {
            authenticatedUser = try await gitHubService.getAuthenticatedUser()
            isAuthenticated = true
        } catch {
            isAuthenticated = false
            authenticatedUser = nil
        }
    }

    /// Loads issues from GitHub.
    func loadIssues() async {
        guard let info = githubInfo else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let allIssues = try await gitHubService.getIssues(
                owner: info.owner,
                repo: info.repo,
                state: stateFilter.rawValue
            )
            // Filter out PRs (GitHub API returns both)
            issues = allIssues.filter { !$0.isPullRequest }
            error = nil
        } catch let gitHubError as GitHubError {
            error = gitHubError
        } catch {
            self.error = .invalidResponse
        }
    }

    /// Loads pull requests from GitHub.
    func loadPullRequests() async {
        guard let info = githubInfo else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            pullRequests = try await gitHubService.getPullRequests(
                owner: info.owner,
                repo: info.repo,
                state: stateFilter.rawValue
            )
            error = nil
        } catch let gitHubError as GitHubError {
            error = gitHubError
        } catch {
            self.error = .invalidResponse
        }
    }

    /// Loads details for the selected pull request.
    func loadPullRequestDetails() async {
        guard let info = githubInfo,
              let pr = selectedPullRequest else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            // Load reviews, comments, and checks in parallel
            async let reviews = gitHubService.getReviews(owner: info.owner, repo: info.repo, pullNumber: pr.number)
            async let comments = gitHubService.getComments(owner: info.owner, repo: info.repo, pullNumber: pr.number)
            async let checks = gitHubService.getCheckRuns(owner: info.owner, repo: info.repo, ref: pr.head.sha)

            selectedPRReviews = try await reviews
            selectedPRComments = try await comments
            selectedPRChecks = try await checks
            error = nil
        } catch let gitHubError as GitHubError {
            error = gitHubError
        } catch {
            self.error = .invalidResponse
        }
    }

    /// Refreshes all data.
    func refresh() async {
        await loadIssues()
        await loadPullRequests()
    }

    // MARK: - Browser Actions

    /// Opens the repository in the browser.
    func openRepositoryInBrowser() {
        guard let info = githubInfo else { return }
        Task {
            await gitHubService.openInBrowser(owner: info.owner, repo: info.repo)
        }
    }

    /// Opens a pull request in the browser.
    func openPullRequestInBrowser(_ pr: GitHubPullRequest) {
        guard let info = githubInfo else { return }
        Task {
            await gitHubService.openPullRequestInBrowser(owner: info.owner, repo: info.repo, number: pr.number)
        }
    }

    /// Opens an issue in the browser.
    func openIssueInBrowser(_ issue: GitHubIssue) {
        guard let info = githubInfo else { return }
        Task {
            await gitHubService.openIssueInBrowser(owner: info.owner, repo: info.repo, number: issue.number)
        }
    }

    /// Opens the compare view for creating a new PR.
    func openCreatePullRequest(from branch: String, to baseBranch: String? = nil) {
        guard let info = githubInfo else { return }
        Task {
            if let base = baseBranch {
                await gitHubService.openCompareInBrowser(owner: info.owner, repo: info.repo, base: base, head: branch)
            } else {
                let url = await gitHubService.newPullRequestURL(owner: info.owner, repo: info.repo, head: branch)
                NSWorkspace.shared.open(url)
            }
        }
    }

    /// Opens the Actions page in browser.
    func openActionsInBrowser() {
        guard let info = githubInfo else { return }
        Task {
            await gitHubService.openActionsInBrowser(owner: info.owner, repo: info.repo)
        }
    }

    // MARK: - Computed Properties

    /// Number of open issues.
    var openIssueCount: Int {
        issues.filter { $0.isOpen }.count
    }

    /// Number of open pull requests.
    var openPRCount: Int {
        pullRequests.filter { $0.isOpen }.count
    }

    /// Summary text for the current state.
    var statusSummary: String {
        guard isGitHubRepository else {
            return "Not a GitHub repository"
        }

        if !isAuthenticated {
            return "Not authenticated"
        }

        var parts: [String] = []
        if openIssueCount > 0 {
            parts.append("\(openIssueCount) open issues")
        }
        if openPRCount > 0 {
            parts.append("\(openPRCount) open PRs")
        }

        return parts.isEmpty ? "No open items" : parts.joined(separator: ", ")
    }
}
