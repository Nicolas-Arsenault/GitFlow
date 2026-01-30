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
        case structure = "Structure"

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

    /// Selected line IDs for line-level staging.
    @Published var selectedLineIds: Set<String> = []

    /// Whether line selection mode is active.
    @Published var isLineSelectionMode: Bool = false

    /// Noise suppression options for filtering diffs.
    @Published var noiseOptions: NoiseSuppressionOptions = .default

    // MARK: - Structural Analysis

    /// Structural changes detected in the current diff.
    @Published private(set) var structuralChanges: [StructuralChange] = []

    /// Code entities from the old version.
    @Published private(set) var oldEntities: [CodeEntity] = []

    /// Code entities from the new version.
    @Published private(set) var newEntities: [CodeEntity] = []

    /// Semantic equivalences detected in the current diff.
    @Published private(set) var semanticEquivalences: [SemanticEquivalence] = []

    /// Change impact analysis for the current diff.
    @Published private(set) var changeImpact: ChangeImpactAnalysis?

    /// Whether structural analysis is loading.
    @Published private(set) var isStructuralAnalysisLoading: Bool = false

    // MARK: - Computed Properties for Filtered Diffs

    /// All diffs after applying noise suppression filters.
    var filteredDiffs: [FileDiff] {
        noiseOptions.apply(to: allDiffs)
    }

    /// Count of hidden files due to noise suppression.
    var hiddenFileCount: Int {
        allDiffs.count - filteredDiffs.count
    }

    /// Whether any files are currently hidden.
    var hasHiddenFiles: Bool {
        hiddenFileCount > 0
    }

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
        // Small yield to ensure we're not in a view update cycle
        await Task.yield()
        isLoading = true

        do {
            let isStaged = fileStatus.isStaged
            let path = fileStatus.path
            let options = currentDiffOptions

            if isStaged {
                diffSource = .staged(path: path)
                // Load diff in background to avoid blocking UI during parsing
                let diffs = try await Task.detached(priority: .userInitiated) { [gitService, repository] in
                    try await gitService.getStagedDiff(in: repository, filePath: path, options: options)
                }.value
                allDiffs = diffs
            } else {
                diffSource = .unstaged(path: path)
                // Load diff in background to avoid blocking UI during parsing
                let diffs = try await Task.detached(priority: .userInitiated) { [gitService, repository] in
                    try await gitService.getUnstagedDiff(in: repository, filePath: path, options: options)
                }.value
                allDiffs = diffs
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

        isLoading = false
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
        // Small yield to ensure we're not in a view update cycle
        await Task.yield()
        isLoading = true

        do {
            diffSource = .commit(hash: commitHash)
            // Load diff in background to avoid blocking UI during parsing
            let options = currentDiffOptions
            let diffs = try await Task.detached(priority: .userInitiated) { [gitService, repository] in
                try await gitService.getCommitDiff(commitHash: commitHash, in: repository, options: options)
            }.value
            allDiffs = diffs
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

        isLoading = false
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

    // MARK: - Structural Analysis

    /// Performs structural analysis on the current diff.
    /// This analyzes code structure changes (classes, functions, etc.) and detects semantic equivalences.
    func performStructuralAnalysis() async {
        guard let diff = currentDiff else { return }

        // Only analyze Swift files for now
        guard diff.path.hasSuffix(".swift") else {
            structuralChanges = []
            oldEntities = []
            newEntities = []
            semanticEquivalences = []
            changeImpact = nil
            return
        }

        isStructuralAnalysisLoading = true
        defer { isStructuralAnalysisLoading = false }

        // Get old and new file contents
        let oldContent: String
        let newContent: String

        switch diffSource {
        case .commit(let hash):
            // Get content from parent commit and current commit
            oldContent = (try? await gitService.getFileContent(
                at: "\(hash)^",
                path: diff.oldPath ?? diff.path,
                in: repository
            )) ?? ""
            newContent = (try? await gitService.getFileContent(
                at: hash,
                path: diff.path,
                in: repository
            )) ?? ""
        case .staged:
            // Get content from HEAD and index
            oldContent = (try? await gitService.getFileContent(
                at: "HEAD",
                path: diff.oldPath ?? diff.path,
                in: repository
            )) ?? ""
            newContent = (try? await gitService.getFileContent(
                at: ":0",  // Index/staged version
                path: diff.path,
                in: repository
            )) ?? ""
        case .unstaged:
            // Get content from index and working tree
            let indexContent = try? await gitService.getFileContent(
                at: ":0",
                path: diff.path,
                in: repository
            )
            if let index = indexContent {
                oldContent = index
            } else {
                oldContent = (try? await gitService.getFileContent(
                    at: "HEAD",
                    path: diff.path,
                    in: repository
                )) ?? ""
            }
            // Read working tree file directly
            let fileURL = repository.rootURL.appendingPathComponent(diff.path)
            newContent = (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
        case .none:
            oldContent = ""
            newContent = ""
        }

        // Parse structures
        let parser = SwiftStructureParser()
        oldEntities = parser.parse(oldContent)
        newEntities = parser.parse(newContent)

        // Compute structural changes
        let diffComputer = StructuralDiffComputer()
        structuralChanges = diffComputer.computeDiff(
            oldSource: oldContent,
            newSource: newContent
        )

        // Detect semantic equivalences
        let detector = SemanticEquivalenceDetector()
        semanticEquivalences = detector.detect(in: allDiffs)

        // Analyze change impact
        let impactAnalyzer = ChangeImpactAnalyzer()
        changeImpact = impactAnalyzer.analyze(
            diffs: allDiffs,
            structuralChanges: structuralChanges,
            repositoryFiles: []  // Would need to get list of files in repo for full analysis
        )
    }

    /// Clears structural analysis data.
    func clearStructuralAnalysis() {
        structuralChanges = []
        oldEntities = []
        newEntities = []
        semanticEquivalences = []
        changeImpact = nil
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

    // MARK: - Line-Level Staging

    /// Toggles selection of a line.
    func toggleLineSelection(_ lineId: String) {
        if selectedLineIds.contains(lineId) {
            selectedLineIds.remove(lineId)
        } else {
            selectedLineIds.insert(lineId)
        }
    }

    /// Selects all lines in a hunk.
    func selectAllLines(in hunk: DiffHunk) {
        for line in hunk.lines where line.type == .addition || line.type == .deletion {
            selectedLineIds.insert(line.id)
        }
    }

    /// Deselects all lines.
    func clearLineSelection() {
        selectedLineIds.removeAll()
    }

    /// Toggles line selection mode.
    func toggleLineSelectionMode() {
        isLineSelectionMode.toggle()
        if !isLineSelectionMode {
            clearLineSelection()
        }
    }

    /// Stages the selected lines.
    func stageSelectedLines() async {
        guard let diff = currentDiff, !selectedLineIds.isEmpty else { return }

        do {
            for hunk in diff.hunks {
                let hunkLineIds = Set(hunk.lines.map(\.id)).intersection(selectedLineIds)
                if !hunkLineIds.isEmpty {
                    try await gitService.stageLines(hunk, lineIds: hunkLineIds, filePath: diff.path, in: repository)
                }
            }
            clearLineSelection()
            isLineSelectionMode = false
            onStatusChanged?()

            // Reload diff to reflect changes
            if case .unstaged(let path) = diffSource {
                await loadUnstagedDiff(for: path)
            }
        } catch let gitError as GitError {
            error = gitError
        } catch {
            self.error = .unknown(message: error.localizedDescription)
        }
    }

    /// Unstages the selected lines.
    func unstageSelectedLines() async {
        guard let diff = currentDiff, !selectedLineIds.isEmpty else { return }

        do {
            for hunk in diff.hunks {
                let hunkLineIds = Set(hunk.lines.map(\.id)).intersection(selectedLineIds)
                if !hunkLineIds.isEmpty {
                    try await gitService.unstageLines(hunk, lineIds: hunkLineIds, filePath: diff.path, in: repository)
                }
            }
            clearLineSelection()
            isLineSelectionMode = false
            onStatusChanged?()

            // Reload diff to reflect changes
            if case .staged(let path) = diffSource {
                await loadStagedDiff(for: path)
            }
        } catch let gitError as GitError {
            error = gitError
        } catch {
            self.error = .unknown(message: error.localizedDescription)
        }
    }

    /// Whether there are selected lines that can be staged.
    var canStageSelectedLines: Bool {
        canStageHunks && !selectedLineIds.isEmpty
    }

    /// Whether there are selected lines that can be unstaged.
    var canUnstageSelectedLines: Bool {
        canUnstageHunks && !selectedLineIds.isEmpty
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
