import Foundation

/// View model specifically for staging area operations.
/// Provides additional functionality for fine-grained staging control.
@MainActor
final class StagingViewModel: ObservableObject {
    // MARK: - Types

    /// Represents a staging operation mode.
    enum StagingMode {
        /// Stage/unstage entire files.
        case file
        /// Stage/unstage individual hunks.
        case hunk
        /// Stage/unstage individual lines (not yet implemented).
        case line
    }

    // MARK: - Published State

    /// Current staging mode.
    @Published var stagingMode: StagingMode = .file

    /// Whether an operation is in progress.
    @Published private(set) var isProcessing: Bool = false

    /// Current error, if any.
    @Published var error: GitError?

    // MARK: - Dependencies

    private let repository: Repository
    private let gitService: GitService

    // MARK: - Initialization

    init(repository: Repository, gitService: GitService) {
        self.repository = repository
        self.gitService = gitService
    }

    // MARK: - File-Level Operations

    /// Stages multiple files at once.
    func stageFiles(_ paths: [String]) async {
        guard !paths.isEmpty else { return }
        isProcessing = true
        defer { isProcessing = false }

        do {
            try await gitService.stage(files: paths, in: repository)
            error = nil
        } catch let gitError as GitError {
            error = gitError
        } catch {
            self.error = .unknown(message: error.localizedDescription)
        }
    }

    /// Unstages multiple files at once.
    func unstageFiles(_ paths: [String]) async {
        guard !paths.isEmpty else { return }
        isProcessing = true
        defer { isProcessing = false }

        do {
            try await gitService.unstage(files: paths, in: repository)
            error = nil
        } catch let gitError as GitError {
            error = gitError
        } catch {
            self.error = .unknown(message: error.localizedDescription)
        }
    }

    /// Discards changes in multiple files.
    func discardChanges(_ paths: [String]) async {
        guard !paths.isEmpty else { return }
        isProcessing = true
        defer { isProcessing = false }

        do {
            try await gitService.discardChanges(files: paths, in: repository)
            error = nil
        } catch let gitError as GitError {
            error = gitError
        } catch {
            self.error = .unknown(message: error.localizedDescription)
        }
    }

    // MARK: - Batch Operations

    /// Stages all changes.
    func stageAll() async {
        isProcessing = true
        defer { isProcessing = false }

        do {
            try await gitService.stageAll(in: repository)
            error = nil
        } catch let gitError as GitError {
            error = gitError
        } catch {
            self.error = .unknown(message: error.localizedDescription)
        }
    }

    /// Unstages all files.
    func unstageAll() async {
        isProcessing = true
        defer { isProcessing = false }

        do {
            try await gitService.unstageAll(in: repository)
            error = nil
        } catch let gitError as GitError {
            error = gitError
        } catch {
            self.error = .unknown(message: error.localizedDescription)
        }
    }
}
