import Foundation

/// Parses git tag output into Tag objects.
enum TagParser {
    /// Parses git tag --format output.
    /// Format: name|shortHash|dereferenceHash|subject
    /// - Parameter output: The raw tag output.
    /// - Returns: An array of Tag objects.
    static func parse(_ output: String) -> [Tag] {
        guard !output.isEmpty else { return [] }

        var tags: [Tag] = []
        let lines = output.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            let parts = trimmed.components(separatedBy: "|")
            guard parts.count >= 2 else { continue }

            let name = parts[0]
            let shortHash = parts[1]
            // For annotated tags, the dereferenced hash points to the commit
            let dereferenceHash = parts.count > 2 && !parts[2].isEmpty ? parts[2] : nil
            let subject = parts.count > 3 ? parts[3] : nil

            // Use dereferenced hash for annotated tags, otherwise use the tag's own hash
            let commitHash = dereferenceHash ?? shortHash
            let isAnnotated = dereferenceHash != nil

            let tag: Tag
            if isAnnotated, let message = subject {
                tag = Tag(
                    name: name,
                    commitHash: commitHash,
                    message: message,
                    taggerName: nil,
                    taggerEmail: nil,
                    tagDate: nil
                )
            } else {
                tag = Tag.lightweight(name: name, commitHash: commitHash)
            }

            tags.append(tag)
        }

        return tags.sorted { $0.name.localizedStandardCompare($1.name) == .orderedDescending }
    }
}
