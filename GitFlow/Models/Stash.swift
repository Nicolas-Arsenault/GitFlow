import Foundation

/// Represents a Git stash entry.
struct Stash: Identifiable, Equatable, Hashable {
    /// The stash index (e.g., 0 for stash@{0}).
    let index: Int

    /// The stash reference name (e.g., "stash@{0}").
    var refName: String {
        "stash@{\(index)}"
    }

    /// The commit hash of the stash.
    let commitHash: String

    /// The branch the stash was created on.
    let branch: String?

    /// The stash message.
    let message: String

    /// The date when the stash was created.
    let date: Date

    var id: String { refName }

    /// Creates a Stash entry.
    init(
        index: Int,
        commitHash: String,
        branch: String? = nil,
        message: String,
        date: Date = Date()
    ) {
        self.index = index
        self.commitHash = commitHash
        self.branch = branch
        self.message = message
        self.date = date
    }
}
