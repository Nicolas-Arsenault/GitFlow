import Foundation

/// Command to get commit history.
struct LogCommand: GitCommand {
    typealias Result = [Commit]

    /// Maximum number of commits to retrieve.
    let limit: Int

    /// Optional branch or ref to get history for.
    let ref: String?

    /// Optional file path to get history for.
    let filePath: String?

    init(limit: Int = 100, ref: String? = nil, filePath: String? = nil) {
        self.limit = limit
        self.ref = ref
        self.filePath = filePath
    }

    var arguments: [String] {
        var args = [
            "log",
            "--format=\(LogParser.formatString)",
            "-n", String(limit)
        ]

        if let ref {
            args.append(ref)
        }

        if let filePath {
            args.append("--")
            args.append(filePath)
        }

        return args
    }

    func parse(output: String) throws -> [Commit] {
        try LogParser.parse(output)
    }
}

/// Command to get a single commit by hash.
struct ShowCommitCommand: GitCommand {
    typealias Result = Commit

    let commitHash: String

    var arguments: [String] {
        ["show", "--format=\(LogParser.formatString)", "-s", commitHash]
    }

    func parse(output: String) throws -> Commit {
        let commits = try LogParser.parse(output)
        guard let commit = commits.first else {
            throw GitError.commitNotFound(hash: commitHash)
        }
        return commit
    }
}

/// Command to get the current HEAD commit hash.
struct HeadCommand: GitCommand {
    typealias Result = String?

    var arguments: [String] {
        ["rev-parse", "HEAD"]
    }

    func parse(output: String) throws -> String? {
        let hash = output.trimmingCharacters(in: .whitespacesAndNewlines)
        return hash.isEmpty ? nil : hash
    }
}
