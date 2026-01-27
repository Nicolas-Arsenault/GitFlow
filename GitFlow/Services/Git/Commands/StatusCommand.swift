import Foundation

/// Command to get the working tree status.
struct StatusCommand: GitCommand {
    typealias Result = [FileStatus]

    var arguments: [String] {
        ["status", "--porcelain", "-z"]
    }

    func parse(output: String) throws -> [FileStatus] {
        StatusParser.parse(output)
    }
}

/// Command to check if a directory is a Git repository.
struct IsRepositoryCommand: GitCommand {
    typealias Result = Bool

    var arguments: [String] {
        ["rev-parse", "--is-inside-work-tree"]
    }

    func parse(output: String) throws -> Bool {
        output.trimmingCharacters(in: .whitespacesAndNewlines) == "true"
    }
}

/// Command to get the repository root directory.
struct GetRootCommand: GitCommand {
    typealias Result = String

    var arguments: [String] {
        ["rev-parse", "--show-toplevel"]
    }

    func parse(output: String) throws -> String {
        output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
