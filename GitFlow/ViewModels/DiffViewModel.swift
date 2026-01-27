import Foundation

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

    // MARK: - Dependencies

    private let repository: Repository
    private let gitService: GitService

    // MARK: - Initialization

    init(repository: Repository, gitService: GitService) {
        self.repository = repository
        self.gitService = gitService
    }

    // MARK: - Public Methods

    /// Loads diff for a file status.
    func loadDiff(for fileStatus: FileStatus) async {
        isLoading = true
        defer { isLoading = false }

        do {
            if fileStatus.isStaged {
                diffSource = .staged(path: fileStatus.path)
                allDiffs = try await gitService.getStagedDiff(in: repository, filePath: fileStatus.path)
            } else {
                diffSource = .unstaged(path: fileStatus.path)
                allDiffs = try await gitService.getUnstagedDiff(in: repository, filePath: fileStatus.path)
            }

            currentDiff = allDiffs.first
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
            allDiffs = try await gitService.getStagedDiff(in: repository, filePath: path)
            currentDiff = allDiffs.first
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
            allDiffs = try await gitService.getUnstagedDiff(in: repository, filePath: path)
            currentDiff = allDiffs.first
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
            allDiffs = try await gitService.getCommitDiff(commitHash: commitHash, in: repository)
            currentDiff = allDiffs.first
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
