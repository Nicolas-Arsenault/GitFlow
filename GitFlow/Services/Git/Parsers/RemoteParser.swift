import Foundation

/// Parses git remote output into Remote objects.
enum RemoteParser {
    /// Parses git remote -v output.
    /// Format: name\turl (fetch|push)
    /// - Parameter output: The raw remote output.
    /// - Returns: An array of Remote objects.
    static func parse(_ output: String) -> [Remote] {
        guard !output.isEmpty else { return [] }

        var remotesByName: [String: (fetch: String?, push: String?)] = [:]
        let lines = output.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            // Format: origin	https://github.com/user/repo.git (fetch)
            let parts = trimmed.components(separatedBy: "\t")
            guard parts.count >= 2 else { continue }

            let name = parts[0]
            let urlAndType = parts[1]

            // Extract URL and type
            let urlParts = urlAndType.components(separatedBy: " ")
            guard !urlParts.isEmpty else { continue }

            let url = urlParts[0]
            let isFetch = urlAndType.contains("(fetch)")

            var entry = remotesByName[name] ?? (fetch: nil, push: nil)
            if isFetch {
                entry.fetch = url
            } else {
                entry.push = url
            }
            remotesByName[name] = entry
        }

        return remotesByName.compactMap { name, urls -> Remote? in
            guard let fetchURL = urls.fetch else { return nil }
            return Remote(
                name: name,
                fetchURL: fetchURL,
                pushURL: urls.push
            )
        }.sorted { $0.name < $1.name }
    }
}
