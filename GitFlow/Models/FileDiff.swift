import Foundation

/// Represents the diff for a single file.
struct FileDiff: Identifiable, Equatable {
    /// Unique identifier.
    let id: String

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

    /// Total number of additions.
    var additions: Int {
        hunks.reduce(0) { $0 + $1.additionCount }
    }

    /// Total number of deletions.
    var deletions: Int {
        hunks.reduce(0) { $0 + $1.deletionCount }
    }

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
        id: String = UUID().uuidString,
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
        self.id = id
        self.path = path
        self.oldPath = oldPath
        self.changeType = changeType
        self.isBinary = isBinary
        self.hunks = hunks
        self.oldMode = oldMode
        self.newMode = newMode
        self.oldHash = oldHash
        self.newHash = newHash
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
