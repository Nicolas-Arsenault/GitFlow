import Foundation

/// Represents a Git commit.
struct Commit: Identifiable, Equatable, Hashable {
    /// The full commit hash (40 characters).
    let hash: String

    /// The abbreviated commit hash (typically 7 characters).
    let shortHash: String

    /// The commit message subject (first line).
    let subject: String

    /// The full commit message body (excluding subject).
    let body: String

    /// The author name.
    let authorName: String

    /// The author email.
    let authorEmail: String

    /// The author date.
    let authorDate: Date

    /// The committer name.
    let committerName: String

    /// The committer email.
    let committerEmail: String

    /// The commit date.
    let commitDate: Date

    /// Parent commit hashes.
    let parentHashes: [String]

    /// Whether this is a merge commit (has multiple parents).
    var isMerge: Bool {
        parentHashes.count > 1
    }

    var id: String { hash }

    /// The full commit message (subject + body).
    var fullMessage: String {
        if body.isEmpty {
            return subject
        }
        return "\(subject)\n\n\(body)"
    }

    /// Creates a commit with the given properties.
    init(
        hash: String,
        shortHash: String? = nil,
        subject: String,
        body: String = "",
        authorName: String,
        authorEmail: String,
        authorDate: Date,
        committerName: String? = nil,
        committerEmail: String? = nil,
        commitDate: Date? = nil,
        parentHashes: [String] = []
    ) {
        self.hash = hash
        self.shortHash = shortHash ?? String(hash.prefix(7))
        self.subject = subject
        self.body = body
        self.authorName = authorName
        self.authorEmail = authorEmail
        self.authorDate = authorDate
        self.committerName = committerName ?? authorName
        self.committerEmail = committerEmail ?? authorEmail
        self.commitDate = commitDate ?? authorDate
        self.parentHashes = parentHashes
    }
}
