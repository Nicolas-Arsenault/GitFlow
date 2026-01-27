import Foundation

/// Parses git log output into Commit objects.
enum LogParser {
    /// The format string for git log --format.
    /// Fields are separated by ASCII record separator (0x1E).
    /// Records are separated by ASCII unit separator (0x1F).
    static let formatString = "%H\u{1E}%h\u{1E}%s\u{1E}%b\u{1E}%an\u{1E}%ae\u{1E}%aI\u{1E}%cn\u{1E}%ce\u{1E}%cI\u{1E}%P\u{1F}"

    /// Field separator (record separator character).
    private static let fieldSeparator = "\u{1E}"

    /// Record separator (unit separator character).
    private static let recordSeparator = "\u{1F}"

    /// Parses git log output.
    /// - Parameter output: The raw log output using the custom format.
    /// - Returns: An array of Commit objects.
    /// - Throws: GitError if parsing fails.
    static func parse(_ output: String) throws -> [Commit] {
        guard !output.isEmpty else { return [] }

        var commits: [Commit] = []
        let records = output.components(separatedBy: recordSeparator)

        for record in records {
            let trimmed = record.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            let fields = trimmed.components(separatedBy: fieldSeparator)
            guard fields.count >= 10 else {
                throw GitError.parseError(context: "Invalid commit record", raw: record)
            }

            let hash = fields[0]
            let shortHash = fields[1]
            let subject = fields[2]
            let body = fields[3].trimmingCharacters(in: .whitespacesAndNewlines)
            let authorName = fields[4]
            let authorEmail = fields[5]
            let authorDateStr = fields[6]
            let committerName = fields[7]
            let committerEmail = fields[8]
            let committerDateStr = fields[9]
            let parentHashesStr = fields.count > 10 ? fields[10] : ""

            guard let authorDate = parseISO8601Date(authorDateStr) else {
                throw GitError.parseError(context: "Invalid author date", raw: authorDateStr)
            }

            guard let committerDate = parseISO8601Date(committerDateStr) else {
                throw GitError.parseError(context: "Invalid committer date", raw: committerDateStr)
            }

            let parentHashes = parentHashesStr
                .split(separator: " ")
                .map(String.init)
                .filter { !$0.isEmpty }

            let commit = Commit(
                hash: hash,
                shortHash: shortHash,
                subject: subject,
                body: body,
                authorName: authorName,
                authorEmail: authorEmail,
                authorDate: authorDate,
                committerName: committerName,
                committerEmail: committerEmail,
                commitDate: committerDate,
                parentHashes: parentHashes
            )

            commits.append(commit)
        }

        return commits
    }

    /// Parses an ISO 8601 date string.
    private static func parseISO8601Date(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) {
            return date
        }

        // Try without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }
}
