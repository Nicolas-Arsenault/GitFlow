import Foundation

/// Represents the diff for a single file.
struct FileDiff: Identifiable, Equatable {
    /// Unique identifier based on file path (no UUID needed).
    var id: String { path }

    /// The file path (new path for renamed files).
    let path: String

    /// The original path if the file was renamed.
    let oldPath: String?

    /// The type of change.
    let changeType: FileChangeType

    /// Whether this is a binary file.
    let isBinary: Bool

    /// The hunks in this diff (empty for binary files).
    let hunks: [DiffHunk]

    /// The old file mode (e.g., "100644").
    let oldMode: String?

    /// The new file mode.
    let newMode: String?

    /// The old blob hash.
    let oldHash: String?

    /// The new blob hash.
    let newHash: String?

    /// Cached addition count for performance.
    private let _additions: Int

    /// Cached deletion count for performance.
    private let _deletions: Int

    /// Total number of additions.
    var additions: Int { _additions }

    /// Total number of deletions.
    var deletions: Int { _deletions }

    /// The file name without directory.
    var fileName: String {
        (path as NSString).lastPathComponent
    }

    /// The directory containing the file.
    var directory: String {
        let dir = (path as NSString).deletingLastPathComponent
        return dir.isEmpty ? "" : dir
    }

    /// Whether this file has any changes to display.
    var hasChanges: Bool {
        !hunks.isEmpty || isBinary
    }

    /// Creates a FileDiff.
    init(
        path: String,
        oldPath: String? = nil,
        changeType: FileChangeType = .modified,
        isBinary: Bool = false,
        hunks: [DiffHunk] = [],
        oldMode: String? = nil,
        newMode: String? = nil,
        oldHash: String? = nil,
        newHash: String? = nil
    ) {
        self.path = path
        self.oldPath = oldPath
        self.changeType = changeType
        self.isBinary = isBinary
        self.hunks = hunks
        self.oldMode = oldMode
        self.newMode = newMode
        self.oldHash = oldHash
        self.newHash = newHash
        // Cache counts at initialization for performance
        self._additions = hunks.reduce(0) { $0 + $1.additions }
        self._deletions = hunks.reduce(0) { $0 + $1.deletions }
    }

    /// Creates an empty diff for a file.
    static func empty(path: String, changeType: FileChangeType = .modified) -> FileDiff {
        FileDiff(path: path, changeType: changeType)
    }

    /// Creates a binary file diff.
    static func binary(path: String, changeType: FileChangeType = .modified) -> FileDiff {
        FileDiff(path: path, changeType: changeType, isBinary: true)
    }
}
