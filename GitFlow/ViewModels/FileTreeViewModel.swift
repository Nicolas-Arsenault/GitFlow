import Foundation
import AppKit
import UniformTypeIdentifiers

/// View model for the file tree browser.
@MainActor
final class FileTreeViewModel: ObservableObject {
    // MARK: - Published State

    /// The root node of the file tree.
    @Published private(set) var rootNode: FileTreeNode?

    /// The currently selected file.
    @Published var selectedFile: FileTreeNode?

    /// Whether files are loading.
    @Published private(set) var isLoading: Bool = false

    /// Current error, if any.
    @Published var error: Error?

    /// Configuration for the file tree.
    @Published var config = FileTreeConfig() {
        didSet {
            Task { await refresh() }
        }
    }

    /// Search filter text.
    @Published var searchText: String = ""

    /// Files matching the search (for quick navigation).
    @Published private(set) var searchResults: [FileTreeNode] = []

    // MARK: - Dependencies

    private let repository: Repository
    private let gitService: GitService
    private var fileStatuses: [String: FileGitStatus] = [:]

    // MARK: - Initialization

    init(repository: Repository, gitService: GitService) {
        self.repository = repository
        self.gitService = gitService
    }

    // MARK: - Public Methods

    /// Loads the file tree.
    func loadTree() async {
        isLoading = true
        defer { isLoading = false }

        do {
            // Load git status first
            await loadGitStatus()

            // Create root node
            let root = FileTreeNode.root(from: repository)
            await loadChildren(for: root)
            root.isExpanded = true
            root.isLoaded = true
            rootNode = root
            error = nil
        } catch {
            self.error = error
        }
    }

    /// Refreshes the file tree.
    func refresh() async {
        await loadTree()
    }

    /// Loads children for a node.
    func loadChildren(for node: FileTreeNode) async {
        guard node.isDirectory, !node.isLoaded else { return }

        do {
            let fileManager = FileManager.default
            let contents = try fileManager.contentsOfDirectory(
                at: node.url,
                includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
                options: config.showHiddenFiles ? [] : [.skipsHiddenFiles]
            )

            var children: [FileTreeNode] = []

            for url in contents {
                let name = url.lastPathComponent

                // Skip excluded patterns
                if config.excludePatterns.contains(name) {
                    continue
                }

                let relativePath = node.relativePath.isEmpty
                    ? name
                    : node.relativePath + "/" + name

                let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false

                let child = FileTreeNode(
                    name: name,
                    relativePath: relativePath,
                    url: url,
                    isDirectory: isDirectory,
                    depth: node.depth + 1
                )

                // Apply git status
                if let status = fileStatuses[relativePath] {
                    child.gitStatus = status
                }

                // Filter based on config
                if config.showOnlyChangedFiles {
                    if isDirectory {
                        // Include directories that may contain changed files
                        // (we'd need to check recursively, so include for now)
                        children.append(child)
                    } else if child.gitStatus != .unmodified {
                        children.append(child)
                    }
                } else {
                    children.append(child)
                }
            }

            // Sort children
            children = sortNodes(children)
            node.children = children
            node.isLoaded = true
        } catch {
            self.error = error
        }
    }

    /// Expands or collapses a node.
    func toggleExpanded(_ node: FileTreeNode) async {
        guard node.isDirectory else { return }

        if !node.isLoaded {
            await loadChildren(for: node)
        }

        node.isExpanded.toggle()
    }

    /// Expands all nodes.
    func expandAll() async {
        guard let root = rootNode else { return }
        await expandRecursively(root)
    }

    /// Collapses all nodes.
    func collapseAll() {
        guard let root = rootNode else { return }
        collapseRecursively(root)
        root.isExpanded = true // Keep root expanded
    }

    /// Searches for files matching the query.
    func search(_ query: String) {
        guard !query.isEmpty, let root = rootNode else {
            searchResults = []
            return
        }

        var results: [FileTreeNode] = []
        searchRecursively(query.lowercased(), in: root, results: &results)
        searchResults = results
    }

    /// Reveals a file in Finder.
    func revealInFinder(_ node: FileTreeNode) {
        NSWorkspace.shared.selectFile(node.url.path, inFileViewerRootedAtPath: "")
    }

    /// Opens a file in the default application.
    func openFile(_ node: FileTreeNode) {
        guard !node.isDirectory else { return }
        NSWorkspace.shared.open(node.url)
    }

    /// Opens a file in a specific application.
    func openFile(_ node: FileTreeNode, with appURL: URL) {
        guard !node.isDirectory else { return }
        NSWorkspace.shared.open([node.url], withApplicationAt: appURL, configuration: .init())
    }

    /// Opens a file in the user's preferred editor.
    func openInEditor(_ node: FileTreeNode) {
        guard !node.isDirectory else { return }

        // Try to find common editors
        let editors = [
            "/Applications/Visual Studio Code.app",
            "/Applications/Sublime Text.app",
            "/Applications/Atom.app",
            "/Applications/TextMate.app",
            "/Applications/BBEdit.app",
            "/usr/local/bin/code",  // VS Code CLI
        ]

        for editor in editors {
            let url = URL(fileURLWithPath: editor)
            if FileManager.default.fileExists(atPath: editor) {
                if editor.hasSuffix(".app") {
                    NSWorkspace.shared.open([node.url], withApplicationAt: url, configuration: .init())
                } else {
                    // CLI tool
                    let process = Process()
                    process.executableURL = url
                    process.arguments = [node.url.path]
                    try? process.run()
                }
                return
            }
        }

        // Fall back to default text editor
        NSWorkspace.shared.open(node.url)
    }

    /// Copies the file path to clipboard.
    func copyPath(_ node: FileTreeNode, absolute: Bool = false) {
        let path = absolute ? node.url.path : node.relativePath
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(path, forType: .string)
    }

    /// Creates a new file in the specified directory.
    func createFile(name: String, in directory: FileTreeNode) async -> FileOperationResult {
        guard directory.isDirectory else { return .failure(FileTreeError.notADirectory) }

        let fileURL = directory.url.appendingPathComponent(name)

        do {
            FileManager.default.createFile(atPath: fileURL.path, contents: nil)
            await loadChildren(for: directory)
            return .success
        } catch {
            return .failure(error)
        }
    }

    /// Creates a new folder in the specified directory.
    func createFolder(name: String, in directory: FileTreeNode) async -> FileOperationResult {
        guard directory.isDirectory else { return .failure(FileTreeError.notADirectory) }

        let folderURL = directory.url.appendingPathComponent(name)

        do {
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: false)
            await loadChildren(for: directory)
            return .success
        } catch {
            return .failure(error)
        }
    }

    /// Deletes a file or folder.
    func delete(_ node: FileTreeNode) async -> FileOperationResult {
        do {
            try FileManager.default.removeItem(at: node.url)
            await refresh()
            return .success
        } catch {
            return .failure(error)
        }
    }

    /// Renames a file or folder.
    func rename(_ node: FileTreeNode, to newName: String) async -> FileOperationResult {
        let newURL = node.url.deletingLastPathComponent().appendingPathComponent(newName)

        do {
            try FileManager.default.moveItem(at: node.url, to: newURL)
            await refresh()
            return .success
        } catch {
            return .failure(error)
        }
    }

    // MARK: - Private Methods

    private func loadGitStatus() async {
        do {
            let status = try await gitService.getStatus(in: repository)
            fileStatuses = [:]

            for file in status.stagedFiles {
                fileStatuses[file.path] = mapStatusType(file.type)
            }

            for file in status.unstagedFiles {
                fileStatuses[file.path] = mapStatusType(file.type)
            }

            for file in status.untrackedFiles {
                fileStatuses[file] = .untracked
            }
        } catch {
            // Continue without status
        }
    }

    private func mapStatusType(_ type: FileStatusType) -> FileGitStatus {
        switch type {
        case .added: return .added
        case .modified: return .modified
        case .deleted: return .deleted
        case .renamed: return .renamed
        case .copied: return .copied
        case .untracked: return .untracked
        }
    }

    private func sortNodes(_ nodes: [FileTreeNode]) -> [FileTreeNode] {
        switch config.sortOrder {
        case .nameAscending:
            return nodes.sorted { n1, n2 in
                if n1.isDirectory != n2.isDirectory {
                    return n1.isDirectory
                }
                return n1.name.localizedCaseInsensitiveCompare(n2.name) == .orderedAscending
            }
        case .nameDescending:
            return nodes.sorted { n1, n2 in
                if n1.isDirectory != n2.isDirectory {
                    return n1.isDirectory
                }
                return n1.name.localizedCaseInsensitiveCompare(n2.name) == .orderedDescending
            }
        case .typeFirst:
            return nodes.sorted { n1, n2 in
                if n1.isDirectory != n2.isDirectory {
                    return n1.isDirectory
                }
                if n1.fileExtension != n2.fileExtension {
                    return (n1.fileExtension ?? "") < (n2.fileExtension ?? "")
                }
                return n1.name.localizedCaseInsensitiveCompare(n2.name) == .orderedAscending
            }
        case .modifiedDate:
            return nodes.sorted { n1, n2 in
                if n1.isDirectory != n2.isDirectory {
                    return n1.isDirectory
                }
                let date1 = (try? n1.url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
                let date2 = (try? n2.url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
                return (date1 ?? .distantPast) > (date2 ?? .distantPast)
            }
        }
    }

    private func expandRecursively(_ node: FileTreeNode) async {
        guard node.isDirectory else { return }

        if !node.isLoaded {
            await loadChildren(for: node)
        }
        node.isExpanded = true

        for child in node.children where child.isDirectory {
            await expandRecursively(child)
        }
    }

    private func collapseRecursively(_ node: FileTreeNode) {
        node.isExpanded = false
        for child in node.children {
            collapseRecursively(child)
        }
    }

    private func searchRecursively(_ query: String, in node: FileTreeNode, results: inout [FileTreeNode]) {
        if node.name.lowercased().contains(query) {
            results.append(node)
        }

        for child in node.children {
            searchRecursively(query, in: child, results: &results)
        }
    }
}

/// Errors that can occur during file operations.
enum FileTreeError: LocalizedError {
    case notADirectory
    case fileExists
    case accessDenied

    var errorDescription: String? {
        switch self {
        case .notADirectory:
            return "Target is not a directory"
        case .fileExists:
            return "A file with that name already exists"
        case .accessDenied:
            return "Access denied"
        }
    }
}
