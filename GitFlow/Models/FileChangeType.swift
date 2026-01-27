import Foundation

/// The type of change for a file in the working tree or index.
enum FileChangeType: String, Equatable, CaseIterable {
    /// File was added (new file).
    case added = "A"

    /// File was modified.
    case modified = "M"

    /// File was deleted.
    case deleted = "D"

    /// File was renamed.
    case renamed = "R"

    /// File was copied.
    case copied = "C"

    /// File has unmerged conflicts.
    case unmerged = "U"

    /// File type changed (e.g., regular file to symlink).
    case typeChanged = "T"

    /// File is untracked.
    case untracked = "?"

    /// File is ignored.
    case ignored = "!"

    /// A human-readable description of the change type.
    var description: String {
        switch self {
        case .added: return "Added"
        case .modified: return "Modified"
        case .deleted: return "Deleted"
        case .renamed: return "Renamed"
        case .copied: return "Copied"
        case .unmerged: return "Conflict"
        case .typeChanged: return "Type Changed"
        case .untracked: return "Untracked"
        case .ignored: return "Ignored"
        }
    }

    /// SF Symbol name for this change type.
    var symbolName: String {
        switch self {
        case .added: return "plus.circle.fill"
        case .modified: return "pencil.circle.fill"
        case .deleted: return "minus.circle.fill"
        case .renamed: return "arrow.right.circle.fill"
        case .copied: return "doc.on.doc.fill"
        case .unmerged: return "exclamationmark.triangle.fill"
        case .typeChanged: return "arrow.triangle.2.circlepath.circle.fill"
        case .untracked: return "questionmark.circle.fill"
        case .ignored: return "eye.slash.circle.fill"
        }
    }

    /// Creates a FileChangeType from a Git status character.
    /// - Parameter character: The single character from git status output.
    /// - Returns: The corresponding FileChangeType, or nil if unknown.
    static func from(character: Character) -> FileChangeType? {
        FileChangeType(rawValue: String(character))
    }
}
