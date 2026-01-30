import Foundation

/// Parses git diff output into structured FileDiff objects.
enum DiffParser {
    /// Parses git diff output.
    /// - Parameter output: The raw diff output.
    /// - Returns: An array of FileDiff objects.
    static func parse(_ output: String) -> [FileDiff] {
        guard !output.isEmpty else { return [] }

        var fileDiffs: [FileDiff] = []

        var currentFile: FileDiffBuilder?
        var currentHunk: DiffHunkBuilder?

        // Use enumerateLines for better memory efficiency with large diffs
        output.enumerateLines { line, _ in
            // New file diff header
            if line.hasPrefix("diff --git") {
                // Save current file if exists
                if let builder = currentFile {
                    if let hunk = currentHunk {
                        builder.hunks.append(hunk.build())
                    }
                    fileDiffs.append(builder.build())
                }

                currentFile = FileDiffBuilder()
                currentHunk = nil
                currentFile?.parseDiffHeader(line)
            }
            // Old file mode
            else if line.hasPrefix("old mode ") {
                currentFile?.oldMode = String(line.dropFirst(9))
            }
            // New file mode
            else if line.hasPrefix("new mode ") {
                currentFile?.newMode = String(line.dropFirst(9))
            }
            // Deleted file mode
            else if line.hasPrefix("deleted file mode ") {
                currentFile?.newMode = String(line.dropFirst(18))
                currentFile?.changeType = .deleted
            }
            // New file mode
            else if line.hasPrefix("new file mode ") {
                currentFile?.newMode = String(line.dropFirst(14))
                currentFile?.changeType = .added
            }
            // Similarity index (for renames/copies)
            // Format: "similarity index 98%"
            else if line.hasPrefix("similarity index ") {
                let percentStr = line.dropFirst(17).dropLast() // Remove "similarity index " and "%"
                currentFile?.similarityPercentage = Int(percentStr)
            }
            // Rename from (explicit rename detection)
            // Format: "rename from oldpath"
            else if line.hasPrefix("rename from ") {
                currentFile?.oldPath = String(line.dropFirst(12))
                currentFile?.changeType = .renamed
            }
            // Rename to
            // Format: "rename to newpath"
            else if line.hasPrefix("rename to ") {
                currentFile?.path = String(line.dropFirst(10))
            }
            // Copy from (copy detection)
            // Format: "copy from sourcepath"
            else if line.hasPrefix("copy from ") {
                currentFile?.oldPath = String(line.dropFirst(10))
                currentFile?.changeType = .copied
            }
            // Copy to
            // Format: "copy to destpath"
            else if line.hasPrefix("copy to ") {
                currentFile?.path = String(line.dropFirst(8))
            }
            // Dissimilarity index (for rewrites)
            // Format: "dissimilarity index 85%"
            else if line.hasPrefix("dissimilarity index ") {
                let percentStr = line.dropFirst(20).dropLast() // Remove "dissimilarity index " and "%"
                if let dissimilarity = Int(percentStr) {
                    // Convert dissimilarity to similarity
                    currentFile?.similarityPercentage = 100 - dissimilarity
                }
            }
            // Index line (hash info)
            else if line.hasPrefix("index ") {
                currentFile?.parseIndexLine(line)
            }
            // Binary file
            else if line.hasPrefix("Binary files") {
                currentFile?.isBinary = true
            }
            // Old file name
            else if line.hasPrefix("--- ") {
                let path = String(line.dropFirst(4))
                if path != "/dev/null" {
                    currentFile?.oldPath = path.hasPrefix("a/") ? String(path.dropFirst(2)) : path
                }
            }
            // New file name
            else if line.hasPrefix("+++ ") {
                let path = String(line.dropFirst(4))
                if path != "/dev/null" {
                    currentFile?.path = path.hasPrefix("b/") ? String(path.dropFirst(2)) : path
                } else {
                    currentFile?.changeType = .deleted
                }
            }
            // Hunk header
            else if line.hasPrefix("@@") {
                // Save current hunk if exists
                if let hunk = currentHunk {
                    currentFile?.hunks.append(hunk.build())
                }

                currentHunk = DiffHunkBuilder()
                currentHunk?.parseHeader(line)
            }
            // Content lines
            else if let hunk = currentHunk {
                if line.hasPrefix("+") {
                    hunk.addLine(type: .addition, content: String(line.dropFirst()), rawLine: line)
                } else if line.hasPrefix("-") {
                    hunk.addLine(type: .deletion, content: String(line.dropFirst()), rawLine: line)
                } else if line.hasPrefix(" ") || line.isEmpty {
                    hunk.addLine(type: .context, content: line.isEmpty ? "" : String(line.dropFirst()), rawLine: line)
                } else if line == "\\ No newline at end of file" {
                    hunk.markNoNewline()
                }
            }
        }

        // Save final file and hunk
        if let builder = currentFile {
            if let hunk = currentHunk {
                builder.hunks.append(hunk.build())
            }
            fileDiffs.append(builder.build())
        }

        return fileDiffs
    }
}

// MARK: - Builder Classes

private class FileDiffBuilder {
    var path: String = ""
    var oldPath: String?
    var changeType: FileChangeType = .modified
    var isBinary: Bool = false
    var hunks: [DiffHunk] = []
    var oldMode: String?
    var newMode: String?
    var oldHash: String?
    var newHash: String?
    var similarityPercentage: Int?

    // Static regex to avoid recompilation for each diff
    private static let diffHeaderRegex: NSRegularExpression? = {
        try? NSRegularExpression(pattern: #"^diff --git a/(.+) b/(.+)$"#)
    }()

    func parseDiffHeader(_ line: String) {
        // Format: diff --git a/path b/path
        guard let regex = Self.diffHeaderRegex,
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) else {
            return
        }
        if let oldRange = Range(match.range(at: 1), in: line) {
            oldPath = String(line[oldRange])
        }
        if let newRange = Range(match.range(at: 2), in: line) {
            path = String(line[newRange])
        }
    }

    func parseIndexLine(_ line: String) {
        // Format: index abc123..def456 100644
        let parts = line.dropFirst(6).split(separator: " ")
        if let hashPart = parts.first {
            let hashes = hashPart.split(separator: ".")
            if hashes.count >= 2 {
                oldHash = String(hashes[0])
                newHash = String(hashes[hashes.count - 1])
            }
        }
    }

    func build() -> FileDiff {
        // Determine change type from context if not set
        if changeType == .modified {
            if oldPath != nil && oldPath != path {
                changeType = .renamed
            }
        }

        return FileDiff(
            path: path,
            oldPath: oldPath != path ? oldPath : nil,
            changeType: changeType,
            isBinary: isBinary,
            hunks: hunks,
            oldMode: oldMode,
            newMode: newMode,
            oldHash: oldHash,
            newHash: newHash,
            similarityPercentage: similarityPercentage
        )
    }
}

private class DiffHunkBuilder {
    var oldStart: Int = 0
    var oldCount: Int = 0
    var newStart: Int = 0
    var newCount: Int = 0
    var header: String = ""
    var rawHeader: String = ""
    var lines: [DiffLine] = []

    private var currentOldLine: Int = 0
    private var currentNewLine: Int = 0

    func parseHeader(_ line: String) {
        rawHeader = line
        if let parsed = DiffHunk.parseHeader(line) {
            oldStart = parsed.oldStart
            oldCount = parsed.oldCount
            newStart = parsed.newStart
            newCount = parsed.newCount
            header = parsed.header
            currentOldLine = oldStart
            currentNewLine = newStart
        }
    }

    func addLine(type: DiffLine.LineType, content: String, rawLine: String) {
        let oldLineNum: Int?
        let newLineNum: Int?

        switch type {
        case .context:
            oldLineNum = currentOldLine
            newLineNum = currentNewLine
            currentOldLine += 1
            currentNewLine += 1
        case .addition:
            oldLineNum = nil
            newLineNum = currentNewLine
            currentNewLine += 1
        case .deletion:
            oldLineNum = currentOldLine
            newLineNum = nil
            currentOldLine += 1
        default:
            oldLineNum = nil
            newLineNum = nil
        }

        let diffLine = DiffLine(
            content: content,
            type: type,
            oldLineNumber: oldLineNum,
            newLineNumber: newLineNum,
            rawLine: rawLine
        )
        lines.append(diffLine)
    }

    func markNoNewline() {
        if var lastLine = lines.popLast() {
            lastLine = DiffLine(
                id: lastLine.id,
                content: lastLine.content,
                type: lastLine.type,
                oldLineNumber: lastLine.oldLineNumber,
                newLineNumber: lastLine.newLineNumber,
                hasNewline: false,
                rawLine: lastLine.rawLine
            )
            lines.append(lastLine)
        }
    }

    func build() -> DiffHunk {
        DiffHunk(
            oldStart: oldStart,
            oldCount: oldCount,
            newStart: newStart,
            newCount: newCount,
            header: header,
            lines: lines,
            rawHeader: rawHeader
        )
    }
}
