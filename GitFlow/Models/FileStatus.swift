import Foundation

/// Represents the status of a single file in the working tree.
struct FileStatus: Identifiable, Equatable, Hashable {
    /// The file path relative to the repository root.
    let path: String

    /// The change type in the index (staged area).
    let indexStatus: FileChangeType?

    /// The change type in the working tree (unstaged).
    let workTreeStatus: FileChangeType?

    /// The original path if the file was renamed or copied.
    let originalPath: String?

    /// Unique identifier based on the file path.
    var id: String { path }

    /// The file name without directory path.
    var fileName: String {
        (path as NSString).lastPathComponent
    }

    /// The directory containing the file.
    var directory: String {
        let dir = (path as NSString).deletingLastPathComponent
        return dir.isEmpty ? "" : dir
    }

    /// Whether the file has staged changes.
    var isStaged: Bool {
        indexStatus != nil && indexStatus != .untracked && indexStatus != .ignored
    }

    /// Whether the file has unstaged changes.
    var isUnstaged: Bool {
        workTreeStatus != nil && workTreeStatus != .untracked && workTreeStatus != .ignored
    }

    /// Whether the file is untracked.
    var isUntracked: Bool {
        indexStatus == .untracked || workTreeStatus == .untracked
    }

    /// Whether the file has a merge conflict.
    var hasConflict: Bool {
        indexStatus == .unmerged || workTreeStatus == .unmerged
    }

    /// The primary change type to display (prefers index status if staged).
    var displayChangeType: FileChangeType {
        if isStaged, let indexStatus {
            return indexStatus
        }
        if let workTreeStatus {
            return workTreeStatus
        }
        return .modified
    }

    /// Creates a FileStatus from git status porcelain v1 output.
    /// - Parameters:
    ///   - indexChar: The character representing index status.
    ///   - workTreeChar: The character representing work tree status.
    ///   - path: The file path.
    ///   - originalPath: The original path for renamed/copied files.
    static func from(
        indexChar: Character,
        workTreeChar: Character,
        path: String,
        originalPath: String? = nil
    ) -> FileStatus {
        let indexStatus: FileChangeType?
        let workTreeStatus: FileChangeType?

        // Handle special cases
        if indexChar == "?" && workTreeChar == "?" {
            // Untracked file
            indexStatus = .untracked
            workTreeStatus = .untracked
        } else if indexChar == "!" && workTreeChar == "!" {
            // Ignored file
            indexStatus = .ignored
            workTreeStatus = .ignored
        } else {
            indexStatus = indexChar == " " ? nil : FileChangeType.from(character: indexChar)
            workTreeStatus = workTreeChar == " " ? nil : FileChangeType.from(character: workTreeChar)
        }

        return FileStatus(
            path: path,
            indexStatus: indexStatus,
            workTreeStatus: workTreeStatus,
            originalPath: originalPath
        )
    }
}
