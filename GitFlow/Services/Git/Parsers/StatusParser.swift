import Foundation

/// Parses git status --porcelain output.
enum StatusParser {
    /// Parses git status --porcelain -z output.
    /// - Parameter output: The raw output from git status.
    /// - Returns: An array of FileStatus objects.
    static func parse(_ output: String) -> [FileStatus] {
        guard !output.isEmpty else { return [] }

        var files: [FileStatus] = []

        // Split by null character (used with -z flag)
        let entries = output.split(separator: "\0", omittingEmptySubsequences: false)

        var i = 0
        while i < entries.count {
            let entry = String(entries[i])

            // Skip empty entries
            guard entry.count >= 3 else {
                i += 1
                continue
            }

            let indexChar = entry[entry.startIndex]
            let workTreeChar = entry[entry.index(entry.startIndex, offsetBy: 1)]
            let path = String(entry.dropFirst(3))

            // Handle renamed/copied files (have an original path following)
            var originalPath: String?
            if indexChar == "R" || indexChar == "C" {
                i += 1
                if i < entries.count {
                    originalPath = String(entries[i])
                }
            }

            let fileStatus = FileStatus.from(
                indexChar: indexChar,
                workTreeChar: workTreeChar,
                path: path,
                originalPath: originalPath
            )

            files.append(fileStatus)
            i += 1
        }

        return files
    }

    /// Parses git status --porcelain output (without -z flag).
    /// Used as fallback for simpler parsing needs.
    /// - Parameter output: The raw output from git status.
    /// - Returns: An array of FileStatus objects.
    static func parseLines(_ output: String) -> [FileStatus] {
        guard !output.isEmpty else { return [] }

        var files: [FileStatus] = []
        let lines = output.components(separatedBy: .newlines)

        for line in lines {
            guard line.count >= 3 else { continue }

            let indexChar = line[line.startIndex]
            let workTreeChar = line[line.index(line.startIndex, offsetBy: 1)]

            var path = String(line.dropFirst(3))
            var originalPath: String?

            // Handle renamed files: "R  new_name -> old_name"
            if indexChar == "R" || indexChar == "C",
               let arrowRange = path.range(of: " -> ") {
                originalPath = String(path[arrowRange.upperBound...])
                path = String(path[..<arrowRange.lowerBound])
            }

            let fileStatus = FileStatus.from(
                indexChar: indexChar,
                workTreeChar: workTreeChar,
                path: path,
                originalPath: originalPath
            )

            files.append(fileStatus)
        }

        return files
    }
}
