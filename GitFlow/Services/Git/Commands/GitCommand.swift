import Foundation

/// Protocol for Git commands.
/// Each command encapsulates the arguments and parsing logic for a specific Git operation.
protocol GitCommand {
    /// The type of result this command produces.
    associatedtype Result

    /// The Git command arguments (e.g., ["status", "--porcelain"]).
    var arguments: [String] { get }

    /// Parses the command output into the result type.
    /// - Parameter output: The stdout from the Git command.
    /// - Returns: The parsed result.
    /// - Throws: GitError if parsing fails.
    func parse(output: String) throws -> Result
}

/// A Git command that doesn't produce a parsed result.
protocol VoidGitCommand: GitCommand where Result == Void {
    func parse(output: String) throws
}

extension VoidGitCommand {
    func parse(output: String) throws -> Void {
        // Default implementation does nothing
    }
}
