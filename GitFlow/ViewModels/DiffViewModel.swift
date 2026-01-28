import Foundation
import AppKit

/// View model for diff display and operations.
@MainActor
final class DiffViewModel: ObservableObject {
    // MARK: - Types

    /// The diff view mode.
    enum ViewMode: String, CaseIterable, Identifiable {
        case unified = "Unified"
        case split = "Split"

        var id: String { rawValue }
    }

    /// Source of the diff being displayed.
    enum DiffSource: Equatable {
        case staged(path: String)
        case unstaged(path: String)
        case commit(hash: String)
        case none
    }

    // MARK: - Published State

    /// The current view mode.
    @Published var viewMode: ViewMode = .unified

    /// The current diff being displayed.
    @Published private(set) var currentDiff: FileDiff?

    /// All diffs for the current selection (may contain multiple files).
    @Published private(set) var allDiffs: [FileDiff] = []

    /// The source of the current diff.
    @Published private(set) var diffSource: DiffSource = .none

    /// Whether diff is currently loading.
    @Published private(set) var isLoading: Bool = false

    /// Current error, if any.
    @Published var error: GitError?

    /// Context lines to show around changes.
    @Published var contextLines: Int = 3

    /// Whether to show line numbers.
    @Published var showLineNumbers: Bool = true

    /// Whether to wrap long lines.
    @Published var wrapLines: Bool = false

    /// Whether to show whitespace characters.
    @Published var showWhitespace: Bool = false

    /// Whether to ignore whitespace changes in diff.
    @Published var ignoreWhitespace: Bool = false

    /// Whether to ignore blank lines in diff.
    @Published var ignoreBlankLines: Bool = false

    /// Blame information for the current file.
    @Published private(set) var blameLines: [BlameLine] = []

    /// Whether blame is currently loading.
    @Published private(set) var isBlameLoading: Bool = false

    /// Whether to show inline blame annotations.
    @Published var showBlame: Bool = false

    /// The index of the currently focused hunk.
    @Published var focusedHunkIndex: Int = 0

    /// Total number of hunks in the current diff.
    @Published private(set) var totalHunks: Int = 0

    // MARK: - Dependencies

    private let repository: Repository
    private let gitService: GitService

    // MARK: - Initialization

    init(repository: Repository, gitService: GitService) {
        self.repository = repository
        self.gitService = gitService
    }

    // MARK: - Diff Options

    /// Current diff options based on settings.
    var currentDiffOptions: DiffOptions {
        var options = DiffOptions()
        options.ignoreWhitespace = ignoreWhitespace
        options.ignoreBlankLines = ignoreBlankLines
        options.contextLines = contextLines
        return options
    }

    // MARK: - Public Methods

    /// Loads diff for a file status.
    func loadDiff(for fileStatus: FileStatus) async {
        isLoading = true
        defer { isLoading = false }

        do {
            if fileStatus.isStaged {
                diffSource = .staged(path: fileStatus.path)
                allDiffs = try await gitService.getStagedDiff(in: repository, filePath: fileStatus.path, options: currentDiffOptions)
            } else {
                diffSource = .unstaged(path: fileStatus.path)
                allDiffs = try await gitService.getUnstagedDiff(in: repository, filePath: fileStatus.path, options: currentDiffOptions)
            }

            currentDiff = allDiffs.first
            updateHunkCount(currentDiff?.hunks.count ?? 0)
            focusedHunkIndex = 0
            clearBlame()
            error = nil

        } catch let gitError as GitError {
            error = gitError
            clearDiff()
        } catch {
            self.error = .unknown(message: error.localizedDescription)
            clearDiff()
        }
    }

    /// Loads staged diff for a file.
    func loadStagedDiff(for path: String) async {
        isLoading = true
        defer { isLoading = false }

        do {
            diffSource = .staged(path: path)
            allDiffs = try await gitService.getStagedDiff(in: repository, filePath: path, options: currentDiffOptions)
            currentDiff = allDiffs.first
            updateHunkCount(currentDiff?.hunks.count ?? 0)
            focusedHunkIndex = 0
            clearBlame()
            error = nil
        } catch let gitError as GitError {
            error = gitError
            clearDiff()
        } catch {
            self.error = .unknown(message: error.localizedDescription)
            clearDiff()
        }
    }

    /// Loads unstaged diff for a file.
    func loadUnstagedDiff(for path: String) async {
        isLoading = true
        defer { isLoading = false }

        do {
            diffSource = .unstaged(path: path)
            allDiffs = try await gitService.getUnstagedDiff(in: repository, filePath: path, options: currentDiffOptions)
            currentDiff = allDiffs.first
            updateHunkCount(currentDiff?.hunks.count ?? 0)
            focusedHunkIndex = 0
            clearBlame()
            error = nil
        } catch let gitError as GitError {
            error = gitError
            clearDiff()
        } catch {
            self.error = .unknown(message: error.localizedDescription)
            clearDiff()
        }
    }

    /// Loads diff for a commit.
    func loadCommitDiff(for commitHash: String) async {
        isLoading = true
        defer { isLoading = false }

        do {
            diffSource = .commit(hash: commitHash)
            allDiffs = try await gitService.getCommitDiff(commitHash: commitHash, in: repository, options: currentDiffOptions)
            currentDiff = allDiffs.first
            updateHunkCount(currentDiff?.hunks.count ?? 0)
            focusedHunkIndex = 0
            clearBlame()
            error = nil
        } catch let gitError as GitError {
            error = gitError
            clearDiff()
        } catch {
            self.error = .unknown(message: error.localizedDescription)
            clearDiff()
        }
    }

    /// Selects a specific file diff from the loaded diffs.
    func selectFileDiff(_ diff: FileDiff) {
        currentDiff = diff
    }

    /// Clears the current diff.
    func clearDiff() {
        currentDiff = nil
        allDiffs = []
        diffSource = .none
    }

    /// Toggles between unified and split view modes.
    func toggleViewMode() {
        viewMode = viewMode == .unified ? .split : .unified
    }

    /// Reloads the current diff with updated options.
    func reloadWithOptions() async {
        switch diffSource {
        case .staged(let path):
            await loadStagedDiff(for: path)
        case .unstaged(let path):
            await loadUnstagedDiff(for: path)
        case .commit(let hash):
            await loadCommitDiff(for: hash)
        case .none:
            break
        }
    }

    // MARK: - Blame Operations

    /// Loads blame information for the current file.
    func loadBlame() async {
        guard let diff = currentDiff else { return }

        isBlameLoading = true
        defer { isBlameLoading = false }

        do {
            blameLines = try await gitService.getBlame(for: diff.path, in: repository)
        } catch {
            // Silently fail - blame is optional
            blameLines = []
        }
    }

    /// Clears blame information.
    func clearBlame() {
        blameLines = []
        showBlame = false
    }

    // MARK: - Navigation

    /// Navigates to the next hunk.
    func navigateToNextHunk() {
        guard totalHunks > 0 else { return }
        focusedHunkIndex = (focusedHunkIndex + 1) % totalHunks
    }

    /// Navigates to the previous hunk.
    func navigateToPreviousHunk() {
        guard totalHunks > 0 else { return }
        focusedHunkIndex = (focusedHunkIndex - 1 + totalHunks) % totalHunks
    }

    /// Updates the total hunk count (called by views).
    func updateHunkCount(_ count: Int) {
        totalHunks = count
        if focusedHunkIndex >= count {
            focusedHunkIndex = max(0, count - 1)
        }
    }

    // MARK: - Clipboard Operations

    /// Copies the current diff to the clipboard.
    func copyDiffToClipboard() async {
        do {
            let patch: String
            switch diffSource {
            case .staged(let path):
                patch = try await gitService.getStagedPatch(in: repository, filePath: path)
            case .unstaged(let path):
                patch = try await gitService.getUnstagedPatch(in: repository, filePath: path)
            case .commit(let hash):
                patch = try await gitService.getCommitPatch(commitHash: hash, in: repository)
            case .none:
                return
            }

            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(patch, forType: .string)
        } catch {
            // Silently fail
        }
    }

    /// Copies a specific hunk to the clipboard.
    func copyHunkToClipboard(_ hunk: DiffHunk, filePath: String) {
        let patch = hunk.toPatchString(filePath: filePath)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(patch, forType: .string)
    }

    // MARK: - File Operations

    /// Opens the current file in the default external editor.
    func openInExternalEditor() {
        guard let diff = currentDiff else { return }
        let fileURL = repository.rootURL.appendingPathComponent(diff.path)
        NSWorkspace.shared.open(fileURL)
    }

    /// Reveals the current file in Finder.
    func revealInFinder() {
        guard let diff = currentDiff else { return }
        let fileURL = repository.rootURL.appendingPathComponent(diff.path)
        NSWorkspace.shared.selectFile(fileURL.path, inFileViewerRootedAtPath: "")
    }

    // MARK: - Hunk-Level Staging

    /// Callback invoked when hunk staging changes the working tree status.
    var onStatusChanged: (() -> Void)?

    /// Stages a specific hunk.
    /// - Parameters:
    ///   - hunk: The hunk to stage.
    ///   - filePath: The path of the file containing the hunk.
    func stageHunk(_ hunk: DiffHunk, filePath: String) async {
        do {
            try await gitService.stageHunk(hunk, filePath: filePath, in: repository)
            onStatusChanged?()
            // Reload diff to reflect the change
            if case .unstaged(let path) = diffSource, path == filePath {
                await loadUnstagedDiff(for: path)
            }
        } catch let gitError as GitError {
            error = gitError
        } catch {
            self.error = .unknown(message: error.localizedDescription)
        }
    }

    /// Unstages a specific hunk.
    /// - Parameters:
    ///   - hunk: The hunk to unstage.
    ///   - filePath: The path of the file containing the hunk.
    func unstageHunk(_ hunk: DiffHunk, filePath: String) async {
        do {
            try await gitService.unstageHunk(hunk, filePath: filePath, in: repository)
            onStatusChanged?()
            // Reload diff to reflect the change
            if case .staged(let path) = diffSource, path == filePath {
                await loadStagedDiff(for: path)
            }
        } catch let gitError as GitError {
            error = gitError
        } catch {
            self.error = .unknown(message: error.localizedDescription)
        }
    }

    /// Whether hunk-level staging is available for the current diff.
    var canStageHunks: Bool {
        guard let diff = currentDiff else { return false }
        switch diffSource {
        case .unstaged:
            return !diff.isBinary && !diff.hunks.isEmpty
        case .staged:
            return false  // Can only stage from unstaged
        default:
            return false
        }
    }

    /// Whether hunk-level unstaging is available for the current diff.
    var canUnstageHunks: Bool {
        guard let diff = currentDiff else { return false }
        switch diffSource {
        case .staged:
            return !diff.isBinary && !diff.hunks.isEmpty
        case .unstaged:
            return false  // Can only unstage from staged
        default:
            return false
        }
    }

    // MARK: - Computed Properties

    /// Whether there is a diff to display.
    var hasDiff: Bool {
        currentDiff != nil
    }

    /// The title for the diff (file name or source description).
    var diffTitle: String {
        if let diff = currentDiff {
            return diff.fileName
        }
        switch diffSource {
        case .staged(let path):
            return (path as NSString).lastPathComponent
        case .unstaged(let path):
            return (path as NSString).lastPathComponent
        case .commit(let hash):
            return "Commit \(String(hash.prefix(7)))"
        case .none:
            return "No diff selected"
        }
    }

    /// Summary of additions and deletions.
    var diffSummary: String {
        guard let diff = currentDiff else { return "" }
        return "+\(diff.additions) -\(diff.deletions)"
    }
}
