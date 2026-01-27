import Foundation

/// Aggregate status of the working tree, including staged, unstaged, and untracked files.
struct WorkingTreeStatus: Equatable {
    /// Files with changes staged in the index.
    let stagedFiles: [FileStatus]

    /// Files with unstaged changes in the working tree.
    let unstagedFiles: [FileStatus]

    /// Untracked files.
    let untrackedFiles: [FileStatus]

    /// Files with merge conflicts.
    let conflictedFiles: [FileStatus]

    /// Whether the working tree is clean (no changes).
    var isClean: Bool {
        stagedFiles.isEmpty && unstagedFiles.isEmpty && untrackedFiles.isEmpty && conflictedFiles.isEmpty
    }

    /// Total number of files with any kind of change.
    var totalChangedFiles: Int {
        stagedFiles.count + unstagedFiles.count + untrackedFiles.count + conflictedFiles.count
    }

    /// Whether there are any staged changes ready to commit.
    var hasStaged: Bool {
        !stagedFiles.isEmpty
    }

    /// Whether there are any unstaged changes.
    var hasUnstaged: Bool {
        !unstagedFiles.isEmpty
    }

    /// Whether there are any untracked files.
    var hasUntracked: Bool {
        !untrackedFiles.isEmpty
    }

    /// Whether there are any merge conflicts.
    var hasConflicts: Bool {
        !conflictedFiles.isEmpty
    }

    /// Creates an empty working tree status.
    static var empty: WorkingTreeStatus {
        WorkingTreeStatus(
            stagedFiles: [],
            unstagedFiles: [],
            untrackedFiles: [],
            conflictedFiles: []
        )
    }

    /// Creates a WorkingTreeStatus from a list of FileStatus objects.
    /// - Parameter files: All file statuses from git status.
    /// - Returns: A categorized WorkingTreeStatus.
    static func from(files: [FileStatus]) -> WorkingTreeStatus {
        var staged: [FileStatus] = []
        var unstaged: [FileStatus] = []
        var untracked: [FileStatus] = []
        var conflicted: [FileStatus] = []

        for file in files {
            if file.hasConflict {
                conflicted.append(file)
            } else if file.isUntracked {
                untracked.append(file)
            } else {
                if file.isStaged {
                    staged.append(file)
                }
                if file.isUnstaged {
                    unstaged.append(file)
                }
            }
        }

        return WorkingTreeStatus(
            stagedFiles: staged,
            unstagedFiles: unstaged,
            untrackedFiles: untracked,
            conflictedFiles: conflicted
        )
    }
}
