import Foundation

/// Parses git branch output into Branch objects.
enum BranchParser {
    /// Parses git branch --format output.
    /// Expected format: %(HEAD)|%(refname)|%(refname:short)|%(objectname)|%(upstream:short)|%(upstream:track,nobracket)
    /// - Parameter output: The raw branch output.
    /// - Returns: An array of Branch objects.
    static func parse(_ output: String) -> [Branch] {
        guard !output.isEmpty else { return [] }

        var branches: [Branch] = []
        let lines = output.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            let parts = trimmed.components(separatedBy: "|")
            guard parts.count >= 4 else { continue }

            let isCurrent = parts[0] == "*"
            let refName = parts[1]
            let shortName = parts[2]
            let commitHash = parts[3]
            let upstream = parts.count > 4 ? (parts[4].isEmpty ? nil : parts[4]) : nil
            let trackInfo = parts.count > 5 ? parts[5] : ""

            // Parse ahead/behind from track info
            let (ahead, behind) = parseTrackInfo(trackInfo)

            // Determine if remote branch
            let isRemote = refName.hasPrefix("refs/remotes/")

            // Extract remote name for remote branches
            var remoteName: String?
            var displayName = shortName

            if isRemote {
                // Remote branch format: refs/remotes/origin/main -> origin, main
                let remotePrefix = "refs/remotes/"
                let remotePath = String(refName.dropFirst(remotePrefix.count))
                if let slashIndex = remotePath.firstIndex(of: "/") {
                    remoteName = String(remotePath[..<slashIndex])
                    displayName = shortName // Already formatted as "origin/main"
                }
            }

            let branch = Branch(
                refName: refName,
                name: displayName,
                isCurrent: isCurrent,
                isRemote: isRemote,
                remoteName: remoteName,
                commitHash: commitHash,
                upstream: upstream,
                ahead: ahead,
                behind: behind
            )

            branches.append(branch)
        }

        return branches
    }

    /// Parses the track info string to extract ahead/behind counts.
    /// Format examples: "ahead 3", "behind 2", "ahead 3, behind 2"
    private static func parseTrackInfo(_ info: String) -> (ahead: Int, behind: Int) {
        var ahead = 0
        var behind = 0

        let aheadPattern = #"ahead (\d+)"#
        let behindPattern = #"behind (\d+)"#

        if let aheadRegex = try? NSRegularExpression(pattern: aheadPattern),
           let match = aheadRegex.firstMatch(in: info, range: NSRange(info.startIndex..., in: info)),
           let range = Range(match.range(at: 1), in: info) {
            ahead = Int(info[range]) ?? 0
        }

        if let behindRegex = try? NSRegularExpression(pattern: behindPattern),
           let match = behindRegex.firstMatch(in: info, range: NSRange(info.startIndex..., in: info)),
           let range = Range(match.range(at: 1), in: info) {
            behind = Int(info[range]) ?? 0
        }

        return (ahead, behind)
    }
}
