import Foundation

/// Parses git stash list output into Stash objects.
enum StashParser {
    /// Parses git stash list --format output.
    /// Expected format: %gd|%H|%gs|%aI
    /// Example: stash@{0}|abc123|On main: WIP|2024-01-15T10:30:00+00:00
    /// - Parameter output: The raw stash list output.
    /// - Returns: An array of Stash objects.
    static func parse(_ output: String) -> [Stash] {
        guard !output.isEmpty else { return [] }

        var stashes: [Stash] = []
        let lines = output.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            let parts = trimmed.components(separatedBy: "|")
            guard parts.count >= 3 else { continue }

            let refName = parts[0]
            let commitHash = parts[1]
            let message = parts[2]
            let dateStr = parts.count > 3 ? parts[3] : nil

            // Extract index from refName (stash@{0} -> 0)
            let index = extractIndex(from: refName) ?? stashes.count

            // Extract branch from message (On branch: message -> branch)
            let (branch, cleanMessage) = extractBranchAndMessage(from: message)

            // Parse date
            let date = dateStr.flatMap { parseISO8601Date($0) } ?? Date()

            let stash = Stash(
                index: index,
                commitHash: commitHash,
                branch: branch,
                message: cleanMessage,
                date: date
            )

            stashes.append(stash)
        }

        return stashes
    }

    /// Extracts the index number from a stash reference.
    private static func extractIndex(from refName: String) -> Int? {
        // Pattern: stash@{N}
        let pattern = #"stash@\{(\d+)\}"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: refName, range: NSRange(refName.startIndex..., in: refName)),
              let range = Range(match.range(at: 1), in: refName) else {
            return nil
        }
        return Int(refName[range])
    }

    /// Extracts branch name and clean message from stash message.
    /// Format: "On branch: message" or "WIP on branch: hash message"
    private static func extractBranchAndMessage(from message: String) -> (branch: String?, message: String) {
        // Pattern: "On <branch>: <message>" or "WIP on <branch>: <message>"
        let patterns = [
            #"^On ([^:]+): (.+)$"#,
            #"^WIP on ([^:]+): (.+)$"#
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: message, range: NSRange(message.startIndex..., in: message)) {

                var branch: String?
                var cleanMessage = message

                if let branchRange = Range(match.range(at: 1), in: message) {
                    branch = String(message[branchRange])
                }

                if let messageRange = Range(match.range(at: 2), in: message) {
                    cleanMessage = String(message[messageRange])
                }

                return (branch, cleanMessage)
            }
        }

        return (nil, message)
    }

    /// Parses an ISO 8601 date string.
    private static func parseISO8601Date(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }
}
