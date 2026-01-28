import Foundation
import UniformTypeIdentifiers

/// Represents a node in the file tree.
final class FileTreeNode: Identifiable, ObservableObject {
    let id = UUID()

    /// The file name.
    let name: String

    /// The full path relative to repository root.
    let relativePath: String

    /// The absolute URL.
    let url: URL

    /// Whether this is a directory.
    let isDirectory: Bool

    /// Child nodes (for directories).
    @Published var children: [FileTreeNode] = []

    /// Whether the node is expanded.
    @Published var isExpanded: Bool = false

    /// The git status of this file.
    @Published var gitStatus: FileGitStatus = .unmodified

    /// Whether children have been loaded (lazy loading).
    @Published var isLoaded: Bool = false

    /// The file extension.
    var fileExtension: String? {
        isDirectory ? nil : url.pathExtension.isEmpty ? nil : url.pathExtension
    }

    /// The file type.
    var fileType: UTType? {
        guard !isDirectory else { return .folder }
        return UTType(filenameExtension: url.pathExtension) ?? .data
    }

    /// Depth in the tree (for indentation).
    let depth: Int

    init(
        name: String,
        relativePath: String,
        url: URL,
        isDirectory: Bool,
        depth: Int = 0
    ) {
        self.name = name
        self.relativePath = relativePath
        self.url = url
        self.isDirectory = isDirectory
        self.depth = depth
    }

    /// Creates a root node from a repository.
    static func root(from repository: Repository) -> FileTreeNode {
        FileTreeNode(
            name: repository.rootURL.lastPathComponent,
            relativePath: "",
            url: repository.rootURL,
            isDirectory: true,
            depth: 0
        )
    }
}

/// Git status for a file.
enum FileGitStatus: String, CaseIterable {
    case unmodified = ""
    case modified = "M"
    case added = "A"
    case deleted = "D"
    case renamed = "R"
    case copied = "C"
    case untracked = "?"
    case ignored = "!"
    case conflict = "U"

    var displayName: String {
        switch self {
        case .unmodified: return "Unmodified"
        case .modified: return "Modified"
        case .added: return "Added"
        case .deleted: return "Deleted"
        case .renamed: return "Renamed"
        case .copied: return "Copied"
        case .untracked: return "Untracked"
        case .ignored: return "Ignored"
        case .conflict: return "Conflict"
        }
    }

    var iconName: String {
        switch self {
        case .unmodified: return "doc"
        case .modified: return "pencil.circle.fill"
        case .added: return "plus.circle.fill"
        case .deleted: return "minus.circle.fill"
        case .renamed: return "arrow.right.circle.fill"
        case .copied: return "doc.on.doc.fill"
        case .untracked: return "questionmark.circle.fill"
        case .ignored: return "eye.slash.circle.fill"
        case .conflict: return "exclamationmark.triangle.fill"
        }
    }

    var color: String {
        switch self {
        case .unmodified: return "primary"
        case .modified: return "orange"
        case .added: return "green"
        case .deleted: return "red"
        case .renamed: return "blue"
        case .copied: return "blue"
        case .untracked: return "gray"
        case .ignored: return "gray"
        case .conflict: return "red"
        }
    }
}

/// Configuration for the file tree display.
struct FileTreeConfig {
    /// Whether to show hidden files.
    var showHiddenFiles: Bool = false

    /// Whether to show ignored files.
    var showIgnoredFiles: Bool = false

    /// Whether to show only changed files.
    var showOnlyChangedFiles: Bool = false

    /// File patterns to exclude.
    var excludePatterns: [String] = [".git", ".DS_Store", "Thumbs.db"]

    /// Sort order for files.
    var sortOrder: SortOrder = .nameAscending

    enum SortOrder {
        case nameAscending
        case nameDescending
        case typeFirst
        case modifiedDate
    }
}

/// Result of a file operation.
enum FileOperationResult {
    case success
    case failure(Error)
    case cancelled
}
