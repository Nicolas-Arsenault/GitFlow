import Foundation

/// View model for working tree status.
@MainActor
final class StatusViewModel: ObservableObject {
    // MARK: - Published State

    /// The current working tree status.
    @Published private(set) var status: WorkingTreeStatus = .empty

    /// Whether status is currently loading.
    @Published private(set) var isLoading: Bool = false

    /// Current error, if any.
    @Published var error: GitError?

    /// The currently selected file.
    @Published var selectedFile: FileStatus?

    /// Selected files for batch operations.
    @Published var selectedFiles: Set<String> = []

    // MARK: - Dependencies

    private let repository: Repository
    private let gitService: GitService

    // MARK: - Initialization

    init(repository: Repository, gitService: GitService) {
        self.repository = repository
        self.gitService = gitService
    }

    // MARK: - Public Methods

    /// Refreshes the working tree status.
    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        do {
            status = try await gitService.getStatus(in: repository)
            error = nil

            // Clear selection if file no longer exists in status
            if let selected = selectedFile,
               !allFiles.contains(where: { $0.path == selected.path }) {
                selectedFile = nil
            }

        } catch let gitError as GitError {
            error = gitError
        } catch {
            self.error = .unknown(message: error.localizedDescription)
        }
    }

    /// Stages the specified files.
    func stageFiles(_ paths: [String]) async {
        do {
            try await gitService.stage(files: paths, in: repository)
            await refresh()
        } catch let gitError as GitError {
            error = gitError
        } catch {
            self.error = .unknown(message: error.localizedDescription)
        }
    }

    /// Stages all changes.
    func stageAll() async {
        do {
            try await gitService.stageAll(in: repository)
            await refresh()
        } catch let gitError as GitError {
            error = gitError
        } catch {
            self.error = .unknown(message: error.localizedDescription)
        }
    }

    /// Unstages the specified files.
    func unstageFiles(_ paths: [String]) async {
        do {
            try await gitService.unstage(files: paths, in: repository)
            await refresh()
        } catch let gitError as GitError {
            error = gitError
        } catch {
            self.error = .unknown(message: error.localizedDescription)
        }
    }

    /// Unstages all files.
    func unstageAll() async {
        do {
            try await gitService.unstageAll(in: repository)
            await refresh()
        } catch let gitError as GitError {
            error = gitError
        } catch {
            self.error = .unknown(message: error.localizedDescription)
        }
    }

    /// Discards changes in the specified files.
    func discardChanges(_ paths: [String]) async {
        do {
            try await gitService.discardChanges(files: paths, in: repository)
            await refresh()
        } catch let gitError as GitError {
            error = gitError
        } catch {
            self.error = .unknown(message: error.localizedDescription)
        }
    }

    /// Selects a file for viewing.
    func selectFile(_ file: FileStatus) {
        selectedFile = file
    }

    /// Toggles selection of a file for batch operations.
    func toggleSelection(_ file: FileStatus) {
        if selectedFiles.contains(file.path) {
            selectedFiles.remove(file.path)
        } else {
            selectedFiles.insert(file.path)
        }
    }

    /// Clears all selections.
    func clearSelection() {
        selectedFiles.removeAll()
    }

    // MARK: - Computed Properties

    /// All files combined for display.
    var allFiles: [FileStatus] {
        status.conflictedFiles + status.stagedFiles + status.unstagedFiles + status.untrackedFiles
    }

    /// Files available for staging (unstaged + untracked).
    var stagingCandidates: [FileStatus] {
        status.unstagedFiles + status.untrackedFiles
    }

    /// Files available for unstaging.
    var unstagingCandidates: [FileStatus] {
        status.stagedFiles
    }

    /// Whether there are staged changes ready to commit.
    var canCommit: Bool {
        status.hasStaged && !status.hasConflicts
    }
}
