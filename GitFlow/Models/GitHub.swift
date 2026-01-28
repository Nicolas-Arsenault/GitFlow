import Foundation

/// Represents a GitHub repository.
struct GitHubRepository: Codable, Identifiable, Equatable {
    let id: Int
    let name: String
    let fullName: String
    let description: String?
    let htmlUrl: String
    let cloneUrl: String
    let sshUrl: String
    let defaultBranch: String
    let isPrivate: Bool
    let isFork: Bool
    let stargazersCount: Int
    let forksCount: Int
    let openIssuesCount: Int
    let owner: GitHubUser

    enum CodingKeys: String, CodingKey {
        case id, name, description, owner
        case fullName = "full_name"
        case htmlUrl = "html_url"
        case cloneUrl = "clone_url"
        case sshUrl = "ssh_url"
        case defaultBranch = "default_branch"
        case isPrivate = "private"
        case isFork = "fork"
        case stargazersCount = "stargazers_count"
        case forksCount = "forks_count"
        case openIssuesCount = "open_issues_count"
    }
}

/// Represents a GitHub user.
struct GitHubUser: Codable, Identifiable, Equatable {
    let id: Int
    let login: String
    let avatarUrl: String
    let htmlUrl: String
    let type: String

    var isOrganization: Bool {
        type == "Organization"
    }

    enum CodingKeys: String, CodingKey {
        case id, login, type
        case avatarUrl = "avatar_url"
        case htmlUrl = "html_url"
    }
}

/// Represents a GitHub issue.
struct GitHubIssue: Codable, Identifiable, Equatable {
    let id: Int
    let number: Int
    let title: String
    let body: String?
    let state: String
    let htmlUrl: String
    let user: GitHubUser
    let labels: [GitHubLabel]
    let assignees: [GitHubUser]
    let createdAt: Date
    let updatedAt: Date
    let closedAt: Date?
    let isPullRequest: Bool

    var isOpen: Bool {
        state == "open"
    }

    enum CodingKeys: String, CodingKey {
        case id, number, title, body, state, user, labels, assignees
        case htmlUrl = "html_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case closedAt = "closed_at"
        case isPullRequest = "pull_request"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        number = try container.decode(Int.self, forKey: .number)
        title = try container.decode(String.self, forKey: .title)
        body = try container.decodeIfPresent(String.self, forKey: .body)
        state = try container.decode(String.self, forKey: .state)
        htmlUrl = try container.decode(String.self, forKey: .htmlUrl)
        user = try container.decode(GitHubUser.self, forKey: .user)
        labels = try container.decodeIfPresent([GitHubLabel].self, forKey: .labels) ?? []
        assignees = try container.decodeIfPresent([GitHubUser].self, forKey: .assignees) ?? []
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        closedAt = try container.decodeIfPresent(Date.self, forKey: .closedAt)
        // pull_request key exists if this is a PR
        isPullRequest = try container.decodeIfPresent([String: String?].self, forKey: .isPullRequest) != nil
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(number, forKey: .number)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(body, forKey: .body)
        try container.encode(state, forKey: .state)
        try container.encode(htmlUrl, forKey: .htmlUrl)
        try container.encode(user, forKey: .user)
        try container.encode(labels, forKey: .labels)
        try container.encode(assignees, forKey: .assignees)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encodeIfPresent(closedAt, forKey: .closedAt)
    }
}

/// Represents a GitHub label.
struct GitHubLabel: Codable, Identifiable, Equatable {
    let id: Int
    let name: String
    let color: String
    let description: String?
}

/// Represents a GitHub pull request.
struct GitHubPullRequest: Codable, Identifiable, Equatable {
    let id: Int
    let number: Int
    let title: String
    let body: String?
    let state: String
    let htmlUrl: String
    let user: GitHubUser
    let labels: [GitHubLabel]
    let assignees: [GitHubUser]
    let createdAt: Date
    let updatedAt: Date
    let closedAt: Date?
    let mergedAt: Date?
    let head: GitHubBranchRef
    let base: GitHubBranchRef
    let isDraft: Bool
    let mergeable: Bool?
    let additions: Int?
    let deletions: Int?
    let changedFiles: Int?

    var isOpen: Bool {
        state == "open"
    }

    var isMerged: Bool {
        mergedAt != nil
    }

    enum CodingKeys: String, CodingKey {
        case id, number, title, body, state, user, labels, assignees, head, base, mergeable, additions, deletions
        case htmlUrl = "html_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case closedAt = "closed_at"
        case mergedAt = "merged_at"
        case isDraft = "draft"
        case changedFiles = "changed_files"
    }
}

/// Represents a branch reference in a pull request.
struct GitHubBranchRef: Codable, Equatable {
    let ref: String
    let sha: String
    let repo: GitHubRepository?
}

/// Represents a GitHub PR review.
struct GitHubReview: Codable, Identifiable, Equatable {
    let id: Int
    let user: GitHubUser
    let body: String?
    let state: ReviewState
    let submittedAt: Date?
    let htmlUrl: String

    enum ReviewState: String, Codable {
        case approved = "APPROVED"
        case changesRequested = "CHANGES_REQUESTED"
        case commented = "COMMENTED"
        case pending = "PENDING"
        case dismissed = "DISMISSED"
    }

    enum CodingKeys: String, CodingKey {
        case id, user, body, state
        case submittedAt = "submitted_at"
        case htmlUrl = "html_url"
    }
}

/// Represents a GitHub PR comment.
struct GitHubComment: Codable, Identifiable, Equatable {
    let id: Int
    let user: GitHubUser
    let body: String
    let createdAt: Date
    let updatedAt: Date
    let htmlUrl: String

    enum CodingKeys: String, CodingKey {
        case id, user, body
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case htmlUrl = "html_url"
    }
}

/// Status of a GitHub check.
enum GitHubCheckStatus: String, Codable {
    case queued
    case inProgress = "in_progress"
    case completed
}

/// Conclusion of a GitHub check.
enum GitHubCheckConclusion: String, Codable {
    case success
    case failure
    case neutral
    case cancelled
    case timedOut = "timed_out"
    case actionRequired = "action_required"
    case skipped
}

/// Represents a GitHub check run.
struct GitHubCheckRun: Codable, Identifiable, Equatable {
    let id: Int
    let name: String
    let status: GitHubCheckStatus
    let conclusion: GitHubCheckConclusion?
    let htmlUrl: String?
    let startedAt: Date?
    let completedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name, status, conclusion
        case htmlUrl = "html_url"
        case startedAt = "started_at"
        case completedAt = "completed_at"
    }
}

/// Information extracted from a GitHub remote URL.
struct GitHubRemoteInfo: Equatable {
    let owner: String
    let repo: String

    var webUrl: String {
        "https://github.com/\(owner)/\(repo)"
    }

    var apiUrl: String {
        "https://api.github.com/repos/\(owner)/\(repo)"
    }

    /// Parses GitHub remote info from a URL.
    static func parse(from url: String) -> GitHubRemoteInfo? {
        // Handle various URL formats:
        // https://github.com/owner/repo.git
        // git@github.com:owner/repo.git
        // https://github.com/owner/repo

        var cleaned = url

        // Remove protocol
        if cleaned.hasPrefix("https://github.com/") {
            cleaned = String(cleaned.dropFirst(19))
        } else if cleaned.hasPrefix("http://github.com/") {
            cleaned = String(cleaned.dropFirst(18))
        } else if cleaned.hasPrefix("git@github.com:") {
            cleaned = String(cleaned.dropFirst(15))
        } else {
            return nil
        }

        // Remove .git suffix
        if cleaned.hasSuffix(".git") {
            cleaned = String(cleaned.dropLast(4))
        }

        // Remove trailing slash
        if cleaned.hasSuffix("/") {
            cleaned = String(cleaned.dropLast())
        }

        // Split into owner/repo
        let parts = cleaned.split(separator: "/")
        guard parts.count >= 2 else { return nil }

        return GitHubRemoteInfo(
            owner: String(parts[0]),
            repo: String(parts[1])
        )
    }
}
