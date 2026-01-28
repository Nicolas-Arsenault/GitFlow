import Foundation

/// Options for diff commands.
struct DiffOptions {
    /// Ignore whitespace changes.
    var ignoreWhitespace: Bool = false

    /// Ignore whitespace at end of lines.
    var ignoreWhitespaceAtEOL: Bool = false

    /// Ignore changes in amount of whitespace.
    var ignoreWhitespaceChange: Bool = false

    /// Ignore blank lines.
    var ignoreBlankLines: Bool = false

    /// Number of context lines to show (default 3).
    var contextLines: Int = 3

    /// Show word-level diff.
    var wordDiff: Bool = false

    /// Detect renames.
    var detectRenames: Bool = true

    /// Detect copies.
    var detectCopies: Bool = false

    /// Generate arguments for git diff.
    var diffArguments: [String] {
        var args: [String] = []

        if ignoreWhitespace {
            args.append("-w")
        }

        if ignoreWhitespaceAtEOL {
            args.append("--ignore-space-at-eol")
        }

        if ignoreWhitespaceChange {
            args.append("-b")
        }

        if ignoreBlankLines {
            args.append("--ignore-blank-lines")
        }

        args.append("-U\(contextLines)")

        if wordDiff {
            args.append("--word-diff=porcelain")
        }

        if detectRenames {
            args.append("-M")
        }

        if detectCopies {
            args.append("-C")
        }

        return args
    }
}

/// Command to get diff for staged changes.
struct StagedDiffCommand: GitCommand {
    typealias Result = [FileDiff]

    /// Optional file path to get diff for a specific file.
    let filePath: String?

    /// Diff options.
    let options: DiffOptions

    init(filePath: String? = nil, options: DiffOptions = DiffOptions()) {
        self.filePath = filePath
        self.options = options
    }

    var arguments: [String] {
        var args = ["diff", "--cached", "--no-color", "--no-ext-diff"]
        args.append(contentsOf: options.diffArguments)
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

    /// Diff options.
    let options: DiffOptions

    init(filePath: String? = nil, options: DiffOptions = DiffOptions()) {
        self.filePath = filePath
        self.options = options
    }

    var arguments: [String] {
        var args = ["diff", "--no-color", "--no-ext-diff"]
        args.append(contentsOf: options.diffArguments)
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
    let options: DiffOptions

    init(commitHash: String, options: DiffOptions = DiffOptions()) {
        self.commitHash = commitHash
        self.options = options
    }

    var arguments: [String] {
        var args = ["show", "--no-color", "--no-ext-diff", "--format="]
        args.append(contentsOf: options.diffArguments)
        args.append(commitHash)
        return args
    }

    func parse(output: String) throws -> [FileDiff] {
        DiffParser.parse(output)
    }
}

// MARK: - Blame Commands

/// A single line of blame output.
struct BlameLine: Identifiable, Equatable {
    let id = UUID()
    let commitHash: String
    let shortHash: String
    let author: String
    let authorEmail: String
    let date: Date
    let lineNumber: Int
    let content: String
    let isUncommitted: Bool

    /// Whether this line is from the current commit (for highlighting).
    var isSameCommit: Bool = false
}

/// Command to get blame information for a file.
struct BlameCommand: GitCommand {
    typealias Result = [BlameLine]

    let filePath: String
    let startLine: Int?
    let endLine: Int?

    init(filePath: String, startLine: Int? = nil, endLine: Int? = nil) {
        self.filePath = filePath
        self.startLine = startLine
        self.endLine = endLine
    }

    var arguments: [String] {
        var args = ["blame", "--porcelain"]

        if let start = startLine, let end = endLine {
            args.append("-L")
            args.append("\(start),\(end)")
        }

        args.append(filePath)
        return args
    }

    func parse(output: String) throws -> [BlameLine] {
        BlameParser.parse(output)
    }
}

/// Parser for git blame output.
enum BlameParser {
    static func parse(_ output: String) -> [BlameLine] {
        var lines: [BlameLine] = []
        let outputLines = output.components(separatedBy: "\n")

        var index = 0
        var currentHash = ""
        var currentAuthor = ""
        var currentAuthorEmail = ""
        var currentDate = Date()
        var lineNumber = 0

        while index < outputLines.count {
            let line = outputLines[index]

            // Header line: hash original-line final-line [count]
            if line.first?.isHexDigit == true && line.count >= 40 {
                let parts = line.split(separator: " ")
                if parts.count >= 3 {
                    currentHash = String(parts[0])
                    lineNumber = Int(parts[2]) ?? 0
                }
            }
            // Author
            else if line.hasPrefix("author ") {
                currentAuthor = String(line.dropFirst(7))
            }
            // Author email
            else if line.hasPrefix("author-mail ") {
                let email = String(line.dropFirst(12))
                currentAuthorEmail = email.trimmingCharacters(in: CharacterSet(charactersIn: "<>"))
            }
            // Author time
            else if line.hasPrefix("author-time ") {
                if let timestamp = TimeInterval(line.dropFirst(12)) {
                    currentDate = Date(timeIntervalSince1970: timestamp)
                }
            }
            // Content line (starts with tab)
            else if line.hasPrefix("\t") {
                let content = String(line.dropFirst())
                let isUncommitted = currentHash.hasPrefix("0000000")

                let blameLine = BlameLine(
                    commitHash: currentHash,
                    shortHash: String(currentHash.prefix(7)),
                    author: currentAuthor,
                    authorEmail: currentAuthorEmail,
                    date: currentDate,
                    lineNumber: lineNumber,
                    content: content,
                    isUncommitted: isUncommitted
                )
                lines.append(blameLine)
            }

            index += 1
        }

        return lines
    }
}

// MARK: - Revert Commands

/// Command to revert changes in a specific hunk.
struct RevertHunkCommand: VoidGitCommand {
    var arguments: [String] {
        ["checkout", "-p", "--"]
    }
}

/// Command to revert changes in specific files.
struct RevertFilesCommand: VoidGitCommand {
    let files: [String]

    var arguments: [String] {
        var args = ["checkout", "--"]
        args.append(contentsOf: files)
        return args
    }
}

// MARK: - Patch Commands

/// Command to generate a patch for staged changes.
struct GenerateStagedPatchCommand: GitCommand {
    typealias Result = String

    let filePath: String?

    init(filePath: String? = nil) {
        self.filePath = filePath
    }

    var arguments: [String] {
        var args = ["diff", "--cached"]
        if let filePath {
            args.append("--")
            args.append(filePath)
        }
        return args
    }

    func parse(output: String) throws -> String {
        output
    }
}

/// Command to generate a patch for unstaged changes.
struct GenerateUnstagedPatchCommand: GitCommand {
    typealias Result = String

    let filePath: String?

    init(filePath: String? = nil) {
        self.filePath = filePath
    }

    var arguments: [String] {
        var args = ["diff"]
        if let filePath {
            args.append("--")
            args.append(filePath)
        }
        return args
    }

    func parse(output: String) throws -> String {
        output
    }
}

/// Command to generate a patch for a commit.
struct GenerateCommitPatchCommand: GitCommand {
    typealias Result = String

    let commitHash: String

    var arguments: [String] {
        ["format-patch", "-1", "--stdout", commitHash]
    }

    func parse(output: String) throws -> String {
        output
    }
}
