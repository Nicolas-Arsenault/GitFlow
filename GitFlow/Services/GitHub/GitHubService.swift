import Foundation
import AppKit

/// Service for GitHub API interactions.
actor GitHubService {
    /// The base URL for the GitHub API.
    private let apiBaseURL = "https://api.github.com"

    /// The current authentication token.
    private var authToken: String?

    /// JSON decoder configured for GitHub API responses.
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    /// Sets the authentication token for API requests.
    func setAuthToken(_ token: String?) {
        self.authToken = token
    }

    /// Checks if the service is authenticated.
    var isAuthenticated: Bool {
        authToken != nil && !authToken!.isEmpty
    }

    // MARK: - Authentication

    /// Gets the authenticated user.
    func getAuthenticatedUser() async throws -> GitHubUser {
        let data = try await makeRequest(path: "/user")
        return try decoder.decode(GitHubUser.self, from: data)
    }

    /// Validates the current token.
    func validateToken() async -> Bool {
        do {
            _ = try await getAuthenticatedUser()
            return true
        } catch {
            return false
        }
    }

    // MARK: - Repository

    /// Gets repository information.
    func getRepository(owner: String, repo: String) async throws -> GitHubRepository {
        let data = try await makeRequest(path: "/repos/\(owner)/\(repo)")
        return try decoder.decode(GitHubRepository.self, from: data)
    }

    /// Extracts GitHub info from a repository's remotes.
    func getGitHubInfo(for repository: Repository, gitService: GitService) async -> GitHubRemoteInfo? {
        do {
            let remotes = try await gitService.getRemotes(in: repository)
            // Prefer origin
            if let origin = remotes.first(where: { $0.name == "origin" }),
               let info = GitHubRemoteInfo.parse(from: origin.url) {
                return info
            }
            // Fall back to first GitHub remote
            for remote in remotes {
                if let info = GitHubRemoteInfo.parse(from: remote.url) {
                    return info
                }
            }
        } catch {
            // Ignore errors
        }
        return nil
    }

    // MARK: - Issues

    /// Gets issues for a repository.
    func getIssues(
        owner: String,
        repo: String,
        state: String = "open",
        page: Int = 1,
        perPage: Int = 30
    ) async throws -> [GitHubIssue] {
        let path = "/repos/\(owner)/\(repo)/issues"
        let query = "state=\(state)&page=\(page)&per_page=\(perPage)"
        let data = try await makeRequest(path: path, query: query)
        return try decoder.decode([GitHubIssue].self, from: data)
    }

    /// Gets a specific issue.
    func getIssue(owner: String, repo: String, number: Int) async throws -> GitHubIssue {
        let data = try await makeRequest(path: "/repos/\(owner)/\(repo)/issues/\(number)")
        return try decoder.decode(GitHubIssue.self, from: data)
    }

    // MARK: - Pull Requests

    /// Gets pull requests for a repository.
    func getPullRequests(
        owner: String,
        repo: String,
        state: String = "open",
        page: Int = 1,
        perPage: Int = 30
    ) async throws -> [GitHubPullRequest] {
        let path = "/repos/\(owner)/\(repo)/pulls"
        let query = "state=\(state)&page=\(page)&per_page=\(perPage)"
        let data = try await makeRequest(path: path, query: query)
        return try decoder.decode([GitHubPullRequest].self, from: data)
    }

    /// Gets a specific pull request.
    func getPullRequest(owner: String, repo: String, number: Int) async throws -> GitHubPullRequest {
        let data = try await makeRequest(path: "/repos/\(owner)/\(repo)/pulls/\(number)")
        return try decoder.decode(GitHubPullRequest.self, from: data)
    }

    /// Gets reviews for a pull request.
    func getReviews(owner: String, repo: String, pullNumber: Int) async throws -> [GitHubReview] {
        let data = try await makeRequest(path: "/repos/\(owner)/\(repo)/pulls/\(pullNumber)/reviews")
        return try decoder.decode([GitHubReview].self, from: data)
    }

    /// Gets comments for a pull request.
    func getComments(owner: String, repo: String, pullNumber: Int) async throws -> [GitHubComment] {
        let data = try await makeRequest(path: "/repos/\(owner)/\(repo)/issues/\(pullNumber)/comments")
        return try decoder.decode([GitHubComment].self, from: data)
    }

    /// Gets the diff for a pull request.
    func getPullRequestDiff(owner: String, repo: String, number: Int) async throws -> String {
        var request = URLRequest(url: URL(string: "\(apiBaseURL)/repos/\(owner)/\(repo)/pulls/\(number)")!)
        request.setValue("application/vnd.github.v3.diff", forHTTPHeaderField: "Accept")

        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw GitHubError.httpError(statusCode: httpResponse.statusCode)
        }

        return String(data: data, encoding: .utf8) ?? ""
    }

    // MARK: - Check Runs

    /// Gets check runs for a commit.
    func getCheckRuns(owner: String, repo: String, ref: String) async throws -> [GitHubCheckRun] {
        let data = try await makeRequest(path: "/repos/\(owner)/\(repo)/commits/\(ref)/check-runs")
        let response = try decoder.decode(CheckRunsResponse.self, from: data)
        return response.checkRuns
    }

    private struct CheckRunsResponse: Codable {
        let totalCount: Int
        let checkRuns: [GitHubCheckRun]

        enum CodingKeys: String, CodingKey {
            case totalCount = "total_count"
            case checkRuns = "check_runs"
        }
    }

    // MARK: - URL Generation

    /// Opens the repository in the browser.
    func openInBrowser(owner: String, repo: String) {
        let url = URL(string: "https://github.com/\(owner)/\(repo)")!
        NSWorkspace.shared.open(url)
    }

    /// Opens a pull request in the browser.
    func openPullRequestInBrowser(owner: String, repo: String, number: Int) {
        let url = URL(string: "https://github.com/\(owner)/\(repo)/pull/\(number)")!
        NSWorkspace.shared.open(url)
    }

    /// Opens an issue in the browser.
    func openIssueInBrowser(owner: String, repo: String, number: Int) {
        let url = URL(string: "https://github.com/\(owner)/\(repo)/issues/\(number)")!
        NSWorkspace.shared.open(url)
    }

    /// Opens the compare view in browser.
    func openCompareInBrowser(owner: String, repo: String, base: String, head: String) {
        let url = URL(string: "https://github.com/\(owner)/\(repo)/compare/\(base)...\(head)")!
        NSWorkspace.shared.open(url)
    }

    /// Opens the actions page in browser.
    func openActionsInBrowser(owner: String, repo: String) {
        let url = URL(string: "https://github.com/\(owner)/\(repo)/actions")!
        NSWorkspace.shared.open(url)
    }

    /// Generates a URL for creating a new pull request.
    func newPullRequestURL(owner: String, repo: String, head: String, base: String? = nil) -> URL {
        var urlString = "https://github.com/\(owner)/\(repo)/compare/\(head)?expand=1"
        if let base = base {
            urlString = "https://github.com/\(owner)/\(repo)/compare/\(base)...\(head)?expand=1"
        }
        return URL(string: urlString)!
    }

    // MARK: - Private Helpers

    private func makeRequest(path: String, query: String? = nil) async throws -> Data {
        var urlString = apiBaseURL + path
        if let query = query {
            urlString += "?" + query
        }

        guard let url = URL(string: urlString) else {
            throw GitHubError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")

        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200..<300:
            return data
        case 401:
            throw GitHubError.unauthorized
        case 403:
            throw GitHubError.forbidden
        case 404:
            throw GitHubError.notFound
        case 422:
            throw GitHubError.validationFailed
        default:
            throw GitHubError.httpError(statusCode: httpResponse.statusCode)
        }
    }
}

/// Errors that can occur when interacting with the GitHub API.
enum GitHubError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case forbidden
    case notFound
    case validationFailed
    case httpError(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid GitHub URL"
        case .invalidResponse:
            return "Invalid response from GitHub"
        case .unauthorized:
            return "Authentication required. Please add a GitHub token."
        case .forbidden:
            return "Access forbidden. Check your token permissions."
        case .notFound:
            return "Resource not found"
        case .validationFailed:
            return "Validation failed"
        case .httpError(let statusCode):
            return "HTTP error: \(statusCode)"
        }
    }
}
