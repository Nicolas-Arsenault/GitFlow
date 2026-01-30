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

    /// Similarity percentage for renamed/copied files (0-100).
    /// Git reports this when using -M (rename detection) or -C (copy detection).
    let similarityPercentage: Int?

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

    /// The original file name for renamed files.
    var originalFileName: String? {
        oldPath.map { ($0 as NSString).lastPathComponent }
    }

    /// Whether this file has any changes to display.
    var hasChanges: Bool {
        !hunks.isEmpty || isBinary
    }

    /// Whether this is a pure rename (100% similar, no content changes).
    var isPureRename: Bool {
        changeType == .renamed && similarityPercentage == 100
    }

    /// Whether this is a rename with content modifications.
    var isRenameWithChanges: Bool {
        changeType == .renamed && (similarityPercentage ?? 100) < 100
    }

    /// Whether this is a pure copy (100% similar).
    var isPureCopy: Bool {
        changeType == .copied && similarityPercentage == 100
    }

    /// Whether this file is likely a generated file (lockfiles, build artifacts, etc.).
    var isGeneratedFile: Bool {
        let name = fileName.lowercased()
        let generatedPatterns = [
            "package-lock.json",
            "yarn.lock",
            "pnpm-lock.yaml",
            "podfile.lock",
            "packages.resolved",
            "composer.lock",
            "gemfile.lock",
            "cargo.lock",
            "poetry.lock"
        ]

        // Exact matches for lockfiles
        if generatedPatterns.contains(name) {
            return true
        }

        // Pattern matches for generated code
        let generatedSuffixes = [
            ".generated.swift",
            ".pb.swift",
            ".pb.go",
            ".g.dart",
            ".freezed.dart",
            ".gen.go",
            ".generated.ts"
        ]

        for suffix in generatedSuffixes {
            if path.lowercased().hasSuffix(suffix) {
                return true
            }
        }

        return false
    }

    /// Whether this file is a lockfile.
    var isLockfile: Bool {
        let name = fileName.lowercased()
        return name.hasSuffix(".lock") ||
               name.hasSuffix("-lock.json") ||
               name.hasSuffix("-lock.yaml") ||
               name == "packages.resolved"
    }

    /// File extension (lowercase, without dot).
    var fileExtension: String {
        let ext = (path as NSString).pathExtension.lowercased()
        return ext
    }

    /// Display string for similarity (e.g., "98% similar").
    var similarityDisplay: String? {
        guard let percent = similarityPercentage else { return nil }
        return "\(percent)% similar"
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
        newHash: String? = nil,
        similarityPercentage: Int? = nil
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
        self.similarityPercentage = similarityPercentage
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
