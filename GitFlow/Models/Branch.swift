import Foundation

/// Represents a Git branch.
struct Branch: Identifiable, Equatable, Hashable {
    /// The full reference name (e.g., "refs/heads/main" or "refs/remotes/origin/main").
    let refName: String

    /// The short name of the branch (e.g., "main" or "origin/main").
    let name: String

    /// Whether this is the currently checked out branch.
    let isCurrent: Bool

    /// Whether this is a remote tracking branch.
    let isRemote: Bool

    /// The remote name if this is a remote branch (e.g., "origin").
    let remoteName: String?

    /// The commit hash that this branch points to.
    let commitHash: String

    /// The upstream branch name, if configured.
    let upstream: String?

    /// Number of commits ahead of upstream.
    let ahead: Int

    /// Number of commits behind upstream.
    let behind: Int

    var id: String { refName }

    /// Creates a local branch.
    static func local(
        name: String,
        commitHash: String,
        isCurrent: Bool = false,
        upstream: String? = nil,
        ahead: Int = 0,
        behind: Int = 0
    ) -> Branch {
        Branch(
            refName: "refs/heads/\(name)",
            name: name,
            isCurrent: isCurrent,
            isRemote: false,
            remoteName: nil,
            commitHash: commitHash,
            upstream: upstream,
            ahead: ahead,
            behind: behind
        )
    }

    /// Creates a remote tracking branch.
    static func remote(
        name: String,
        remoteName: String,
        commitHash: String
    ) -> Branch {
        Branch(
            refName: "refs/remotes/\(remoteName)/\(name)",
            name: "\(remoteName)/\(name)",
            isCurrent: false,
            isRemote: true,
            remoteName: remoteName,
            commitHash: commitHash,
            upstream: nil,
            ahead: 0,
            behind: 0
        )
    }
}
