import Foundation

/// Options for filtering "noise" from diff displays.
///
/// Noise suppression helps reviewers focus on meaningful changes by hiding
/// or de-emphasizing changes that don't affect behavior (formatting, generated files, etc.).
struct NoiseSuppressionOptions: Codable, Equatable {
    // MARK: - File Filtering

    /// Hide generated files from the diff list.
    /// Examples: package-lock.json, *.pb.swift, *.generated.swift
    var hideGeneratedFiles: Bool = true

    /// Hide lockfiles from the diff list.
    /// Examples: yarn.lock, Podfile.lock, Cargo.lock
    var hideLockfiles: Bool = true

    /// Custom patterns to hide (glob-style).
    var customHiddenPatterns: [String] = []

    // MARK: - Rename/Move Handling

    /// Collapse pure renames (100% similar) into a single entry.
    /// When true, shows "renamed: oldname → newname" instead of delete + add.
    var collapseRenames: Bool = true

    /// Minimum similarity percentage to treat as a rename (0-100).
    /// Files below this threshold are shown as delete + add.
    var renameThreshold: Int = 50

    // MARK: - Content Filtering (Applied via Git)

    /// Ignore all whitespace changes.
    /// Uses git diff -w flag.
    var ignoreWhitespace: Bool = false

    /// Ignore changes in amount of whitespace.
    /// Uses git diff -b flag.
    var ignoreWhitespaceAmount: Bool = false

    /// Ignore whitespace at end of lines.
    /// Uses git diff --ignore-space-at-eol flag.
    var ignoreWhitespaceAtEOL: Bool = false

    /// Ignore changes that only add/remove blank lines.
    /// Uses git diff --ignore-blank-lines flag.
    var ignoreBlankLines: Bool = false

    // MARK: - Line-Level Filtering (Visual Only)

    /// Hide comment-only changes in the diff display.
    /// When true, lines that only contain comments are de-emphasized or hidden.
    var hideCommentChanges: Bool = false

    /// Hide import/include statement changes.
    /// Useful for focusing on logic changes vs dependency reorganization.
    var hideImportChanges: Bool = false

    // MARK: - Display Preferences

    /// Group files by directory in the file list.
    var groupByDirectory: Bool = true

    /// Sort order for files in the diff list.
    var sortOrder: SortOrder = .byPath

    /// File sort order options.
    enum SortOrder: String, Codable, CaseIterable, Identifiable {
        case byPath = "Path"
        case byChangeType = "Change Type"
        case bySize = "Change Size"

        var id: String { rawValue }
    }

    // MARK: - Default Configuration

    /// Default options with sensible noise suppression enabled.
    static let `default` = NoiseSuppressionOptions()

    /// Options with no filtering (show everything).
    static let showAll = NoiseSuppressionOptions(
        hideGeneratedFiles: false,
        hideLockfiles: false,
        collapseRenames: false
    )

    // MARK: - Filtering Logic

    /// Determines if a file should be hidden based on current options.
    /// - Parameter diff: The file diff to evaluate.
    /// - Returns: True if the file should be hidden from the list.
    func shouldHide(_ diff: FileDiff) -> Bool {
        if hideGeneratedFiles && diff.isGeneratedFile {
            return true
        }

        if hideLockfiles && diff.isLockfile {
            return true
        }

        // Check custom patterns
        for pattern in customHiddenPatterns {
            if matchesPattern(diff.path, pattern: pattern) {
                return true
            }
        }

        return false
    }

    /// Filters a list of diffs based on current options.
    /// - Parameter diffs: The list of file diffs to filter.
    /// - Returns: Filtered list with hidden files removed.
    func filter(_ diffs: [FileDiff]) -> [FileDiff] {
        diffs.filter { !shouldHide($0) }
    }

    /// Sorts diffs based on current sort order.
    /// - Parameter diffs: The list of file diffs to sort.
    /// - Returns: Sorted list.
    func sort(_ diffs: [FileDiff]) -> [FileDiff] {
        switch sortOrder {
        case .byPath:
            return diffs.sorted { $0.path.localizedCaseInsensitiveCompare($1.path) == .orderedAscending }
        case .byChangeType:
            return diffs.sorted {
                if $0.changeType.sortPriority != $1.changeType.sortPriority {
                    return $0.changeType.sortPriority < $1.changeType.sortPriority
                }
                return $0.path.localizedCaseInsensitiveCompare($1.path) == .orderedAscending
            }
        case .bySize:
            return diffs.sorted {
                let size0 = $0.additions + $0.deletions
                let size1 = $1.additions + $1.deletions
                if size0 != size1 {
                    return size0 > size1 // Largest first
                }
                return $0.path.localizedCaseInsensitiveCompare($1.path) == .orderedAscending
            }
        }
    }

    /// Filters and sorts diffs based on current options.
    /// - Parameter diffs: The list of file diffs to process.
    /// - Returns: Filtered and sorted list.
    func apply(to diffs: [FileDiff]) -> [FileDiff] {
        sort(filter(diffs))
    }

    // MARK: - Private Helpers

    /// Simple glob pattern matching.
    private func matchesPattern(_ path: String, pattern: String) -> Bool {
        // Convert glob to regex
        var regexPattern = NSRegularExpression.escapedPattern(for: pattern)
        regexPattern = regexPattern.replacingOccurrences(of: "\\*\\*", with: ".*")
        regexPattern = regexPattern.replacingOccurrences(of: "\\*", with: "[^/]*")
        regexPattern = regexPattern.replacingOccurrences(of: "\\?", with: ".")
        regexPattern = "^" + regexPattern + "$"

        guard let regex = try? NSRegularExpression(pattern: regexPattern, options: .caseInsensitive) else {
            return false
        }

        let range = NSRange(path.startIndex..., in: path)
        return regex.firstMatch(in: path, range: range) != nil
    }
}

// MARK: - FileChangeType Extension

extension FileChangeType {
    /// Sort priority for organizing files by change type.
    /// Lower numbers appear first.
    var sortPriority: Int {
        switch self {
        case .added: return 0
        case .modified: return 1
        case .renamed: return 2
        case .copied: return 3
        case .deleted: return 4
        case .unmerged: return 5
        case .typeChanged: return 6
        case .untracked: return 7
        case .ignored: return 8
        }
    }
}
