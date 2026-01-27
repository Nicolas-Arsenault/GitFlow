import Foundation

/// Errors that can occur during Git operations.
enum GitError: Error, LocalizedError, Equatable {
    /// The specified path is not a Git repository.
    case notARepository(path: String)

    /// Git executable was not found on the system.
    case gitNotFound

    /// A Git command failed with an exit code and message.
    case commandFailed(command: String, exitCode: Int32, message: String)

    /// Failed to parse Git output.
    case parseError(context: String, raw: String)

    /// The specified branch does not exist.
    case branchNotFound(name: String)

    /// The specified commit does not exist.
    case commitNotFound(hash: String)

    /// The working directory has uncommitted changes that would be overwritten.
    case uncommittedChanges

    /// A merge conflict occurred.
    case mergeConflict(files: [String])

    /// The operation was cancelled.
    case cancelled

    /// An unknown error occurred.
    case unknown(message: String)

    var errorDescription: String? {
        switch self {
        case .notARepository(let path):
            return "'\(path)' is not a Git repository"
        case .gitNotFound:
            return "Git executable not found. Please install Git."
        case .commandFailed(let command, let exitCode, let message):
            return "Git command '\(command)' failed (exit code \(exitCode)): \(message)"
        case .parseError(let context, _):
            return "Failed to parse Git output: \(context)"
        case .branchNotFound(let name):
            return "Branch '\(name)' not found"
        case .commitNotFound(let hash):
            return "Commit '\(hash)' not found"
        case .uncommittedChanges:
            return "You have uncommitted changes that would be overwritten"
        case .mergeConflict(let files):
            return "Merge conflict in \(files.count) file(s)"
        case .cancelled:
            return "Operation cancelled"
        case .unknown(let message):
            return message
        }
    }

    static func == (lhs: GitError, rhs: GitError) -> Bool {
        switch (lhs, rhs) {
        case (.notARepository(let l), .notARepository(let r)):
            return l == r
        case (.gitNotFound, .gitNotFound):
            return true
        case (.commandFailed(let lCmd, let lCode, let lMsg), .commandFailed(let rCmd, let rCode, let rMsg)):
            return lCmd == rCmd && lCode == rCode && lMsg == rMsg
        case (.parseError(let lCtx, let lRaw), .parseError(let rCtx, let rRaw)):
            return lCtx == rCtx && lRaw == rRaw
        case (.branchNotFound(let l), .branchNotFound(let r)):
            return l == r
        case (.commitNotFound(let l), .commitNotFound(let r)):
            return l == r
        case (.uncommittedChanges, .uncommittedChanges):
            return true
        case (.mergeConflict(let l), .mergeConflict(let r)):
            return l == r
        case (.cancelled, .cancelled):
            return true
        case (.unknown(let l), .unknown(let r)):
            return l == r
        default:
            return false
        }
    }
}
