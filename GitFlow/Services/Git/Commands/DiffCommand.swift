import Foundation

/// Command to get diff for staged changes.
struct StagedDiffCommand: GitCommand {
    typealias Result = [FileDiff]

    /// Optional file path to get diff for a specific file.
    let filePath: String?

    init(filePath: String? = nil) {
        self.filePath = filePath
    }

    var arguments: [String] {
        var args = ["diff", "--cached", "--no-color", "--no-ext-diff"]
        if let filePath {
            args.append("--")
            args.append(filePath)
        }
        return args
    }

    func parse(output: String) throws -> [FileDiff] {
        DiffParser.parse(output)
    }
}

/// Command to get diff for unstaged changes.
struct UnstagedDiffCommand: GitCommand {
    typealias Result = [FileDiff]

    /// Optional file path to get diff for a specific file.
    let filePath: String?

    init(filePath: String? = nil) {
        self.filePath = filePath
    }

    var arguments: [String] {
        var args = ["diff", "--no-color", "--no-ext-diff"]
        if let filePath {
            args.append("--")
            args.append(filePath)
        }
        return args
    }

    func parse(output: String) throws -> [FileDiff] {
        DiffParser.parse(output)
    }
}

/// Command to get diff between two commits.
struct CommitDiffCommand: GitCommand {
    typealias Result = [FileDiff]

    /// The commit or range to diff.
    let commitRange: String

    /// Optional file path to get diff for a specific file.
    let filePath: String?

    init(commitRange: String, filePath: String? = nil) {
        self.commitRange = commitRange
        self.filePath = filePath
    }

    var arguments: [String] {
        var args = ["diff", "--no-color", "--no-ext-diff", commitRange]
        if let filePath {
            args.append("--")
            args.append(filePath)
        }
        return args
    }

    func parse(output: String) throws -> [FileDiff] {
        DiffParser.parse(output)
    }
}

/// Command to show changes in a specific commit.
struct ShowCommitDiffCommand: GitCommand {
    typealias Result = [FileDiff]

    let commitHash: String

    var arguments: [String] {
        ["show", "--no-color", "--no-ext-diff", "--format=", commitHash]
    }

    func parse(output: String) throws -> [FileDiff] {
        DiffParser.parse(output)
    }
}
