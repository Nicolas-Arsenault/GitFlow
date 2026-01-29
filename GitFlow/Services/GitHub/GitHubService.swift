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
               let info = GitHubRemoteInfo.parse(from: origin.fetchURL) {
                return info
            }
            // Fall back to first GitHub remote
            for remote in remotes {
                if let info = GitHubRemoteInfo.parse(from: remote.fetchURL) {
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

    /// Gets the files changed in a pull request.
    func getPullRequestFiles(owner: String, repo: String, number: Int) async throws -> [PRFileChange] {
        let data = try await makeRequest(path: "/repos/\(owner)/\(repo)/pulls/\(number)/files")
        let files = try decoder.decode([GitHubPRFile].self, from: data)

        return files.map { file in
            PRFileChange(
                id: file.sha ?? file.filename,
                filename: file.filename,
                status: PRFileChange.FileStatus(rawValue: file.status) ?? .modified,
                additions: file.additions,
                deletions: file.deletions,
                changes: file.changes,
                patch: file.patch
            )
        }
    }

    // MARK: - Pull Request Write Operations

    /// Creates a new pull request.
    /// - Parameters:
    ///   - owner: Repository owner.
    ///   - repo: Repository name.
    ///   - title: PR title.
    ///   - body: PR description (optional).
    ///   - head: The branch with changes (can include fork prefix: "username:branch").
    ///   - base: The branch to merge into.
    ///   - draft: Whether to create as a draft PR.
    /// - Returns: The created pull request.
    func createPullRequest(
        owner: String,
        repo: String,
        title: String,
        body: String?,
        head: String,
        base: String,
        draft: Bool = false
    ) async throws -> GitHubPullRequest {
        var payload: [String: Any] = [
            "title": title,
            "head": head,
            "base": base,
            "draft": draft
        ]
        if let body = body {
            payload["body"] = body
        }

        let data = try await makePostRequest(
            path: "/repos/\(owner)/\(repo)/pulls",
            body: payload
        )
        return try decoder.decode(GitHubPullRequest.self, from: data)
    }

    /// Updates an existing pull request.
    /// - Parameters:
    ///   - owner: Repository owner.
    ///   - repo: Repository name.
    ///   - number: PR number.
    ///   - title: New title (optional).
    ///   - body: New body (optional).
    ///   - state: New state: "open" or "closed" (optional).
    ///   - base: New base branch (optional).
    /// - Returns: The updated pull request.
    func updatePullRequest(
        owner: String,
        repo: String,
        number: Int,
        title: String? = nil,
        body: String? = nil,
        state: String? = nil,
        base: String? = nil
    ) async throws -> GitHubPullRequest {
        var payload: [String: Any] = [:]
        if let title = title { payload["title"] = title }
        if let body = body { payload["body"] = body }
        if let state = state { payload["state"] = state }
        if let base = base { payload["base"] = base }

        let data = try await makePatchRequest(
            path: "/repos/\(owner)/\(repo)/pulls/\(number)",
            body: payload
        )
        return try decoder.decode(GitHubPullRequest.self, from: data)
    }

    /// Closes a pull request.
    func closePullRequest(owner: String, repo: String, number: Int) async throws -> GitHubPullRequest {
        try await updatePullRequest(owner: owner, repo: repo, number: number, state: "closed")
    }

    /// Merges a pull request.
    /// - Parameters:
    ///   - owner: Repository owner.
    ///   - repo: Repository name.
    ///   - number: PR number.
    ///   - commitTitle: Custom commit title (optional).
    ///   - commitMessage: Custom commit message (optional).
    ///   - mergeMethod: The merge method: "merge", "squash", or "rebase".
    /// - Returns: The merge result.
    func mergePullRequest(
        owner: String,
        repo: String,
        number: Int,
        commitTitle: String? = nil,
        commitMessage: String? = nil,
        mergeMethod: String = "merge"
    ) async throws -> MergeResult {
        var payload: [String: Any] = [
            "merge_method": mergeMethod
        ]
        if let title = commitTitle { payload["commit_title"] = title }
        if let message = commitMessage { payload["commit_message"] = message }

        let data = try await makePutRequest(
            path: "/repos/\(owner)/\(repo)/pulls/\(number)/merge",
            body: payload
        )
        return try decoder.decode(MergeResult.self, from: data)
    }

    /// Result of a pull request merge.
    struct MergeResult: Codable {
        let sha: String
        let merged: Bool
        let message: String
    }

    /// Deletes a branch from the repository.
    /// - Parameters:
    ///   - owner: Repository owner.
    ///   - repo: Repository name.
    ///   - branch: Branch name to delete.
    func deleteBranch(owner: String, repo: String, branch: String) async throws {
        try await makeDeleteRequest(
            path: "/repos/\(owner)/\(repo)/git/refs/heads/\(branch)"
        )
    }

    // MARK: - Comment Operations

    /// Adds a comment to a pull request or issue.
    func addComment(
        owner: String,
        repo: String,
        issueNumber: Int,
        body: String
    ) async throws -> GitHubComment {
        let payload: [String: Any] = ["body": body]
        let data = try await makePostRequest(
            path: "/repos/\(owner)/\(repo)/issues/\(issueNumber)/comments",
            body: payload
        )
        return try decoder.decode(GitHubComment.self, from: data)
    }

    /// Updates an existing comment.
    func updateComment(
        owner: String,
        repo: String,
        commentId: Int,
        body: String
    ) async throws -> GitHubComment {
        let payload: [String: Any] = ["body": body]
        let data = try await makePatchRequest(
            path: "/repos/\(owner)/\(repo)/issues/comments/\(commentId)",
            body: payload
        )
        return try decoder.decode(GitHubComment.self, from: data)
    }

    /// Deletes a comment.
    func deleteComment(owner: String, repo: String, commentId: Int) async throws {
        try await makeDeleteRequest(
            path: "/repos/\(owner)/\(repo)/issues/comments/\(commentId)"
        )
    }

    // MARK: - Review Operations

    /// Submits a review for a pull request.
    /// - Parameters:
    ///   - owner: Repository owner.
    ///   - repo: Repository name.
    ///   - pullNumber: PR number.
    ///   - body: Review body/comment.
    ///   - event: Review event: "APPROVE", "REQUEST_CHANGES", or "COMMENT".
    /// - Returns: The submitted review.
    func submitReview(
        owner: String,
        repo: String,
        pullNumber: Int,
        body: String?,
        event: ReviewEvent
    ) async throws -> GitHubReview {
        var payload: [String: Any] = [
            "event": event.rawValue
        ]
        if let body = body {
            payload["body"] = body
        }

        let data = try await makePostRequest(
            path: "/repos/\(owner)/\(repo)/pulls/\(pullNumber)/reviews",
            body: payload
        )
        return try decoder.decode(GitHubReview.self, from: data)
    }

    /// Review events for PR reviews.
    enum ReviewEvent: String {
        case approve = "APPROVE"
        case requestChanges = "REQUEST_CHANGES"
        case comment = "COMMENT"
    }

    /// Dismisses a review.
    func dismissReview(
        owner: String,
        repo: String,
        pullNumber: Int,
        reviewId: Int,
        message: String
    ) async throws {
        let payload: [String: Any] = ["message": message]
        _ = try await makePutRequest(
            path: "/repos/\(owner)/\(repo)/pulls/\(pullNumber)/reviews/\(reviewId)/dismissals",
            body: payload
        )
    }

    // MARK: - Branch Operations

    /// Gets branches for a repository.
    func getBranches(owner: String, repo: String) async throws -> [GitHubBranch] {
        let data = try await makeRequest(path: "/repos/\(owner)/\(repo)/branches")
        return try decoder.decode([GitHubBranch].self, from: data)
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
        try await makeHTTPRequest(method: "GET", path: path, query: query, body: nil)
    }

    private func makePostRequest(path: String, body: [String: Any]) async throws -> Data {
        try await makeHTTPRequest(method: "POST", path: path, query: nil, body: body)
    }

    private func makePatchRequest(path: String, body: [String: Any]) async throws -> Data {
        try await makeHTTPRequest(method: "PATCH", path: path, query: nil, body: body)
    }

    private func makePutRequest(path: String, body: [String: Any]) async throws -> Data {
        try await makeHTTPRequest(method: "PUT", path: path, query: nil, body: body)
    }

    private func makeDeleteRequest(path: String) async throws {
        _ = try await makeHTTPRequest(method: "DELETE", path: path, query: nil, body: nil)
    }

    private func makeHTTPRequest(
        method: String,
        path: String,
        query: String?,
        body: [String: Any]?
    ) async throws -> Data {
        var urlString = apiBaseURL + path
        if let query = query {
            urlString += "?" + query
        }

        guard let url = URL(string: urlString) else {
            throw GitHubError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")

        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body = body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
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
