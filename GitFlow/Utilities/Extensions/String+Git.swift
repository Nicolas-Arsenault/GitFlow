import Foundation

extension String {
    /// Returns the string with leading and trailing whitespace and newlines removed.
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Returns true if this looks like a valid Git commit hash (7-40 hex characters).
    var isValidCommitHash: Bool {
        guard count >= 7, count <= 40 else { return false }
        return allSatisfy { $0.isHexDigit }
    }

    /// Returns true if this looks like a valid Git branch name.
    var isValidBranchName: Bool {
        guard !isEmpty else { return false }

        // Invalid patterns
        let invalidPatterns = [
            "..",        // No consecutive dots
            "~", "^",    // No reflog/revision characters
            ":", "?",    // No special characters
            "*", "[",
            "\\",
            " ",         // No spaces
            "@{",        // No reflog syntax
        ]

        for pattern in invalidPatterns {
            if contains(pattern) {
                return false
            }
        }

        // Cannot start or end with dot or slash
        if hasPrefix(".") || hasSuffix(".") ||
           hasPrefix("/") || hasSuffix("/") {
            return false
        }

        // Cannot end with .lock
        if hasSuffix(".lock") {
            return false
        }

        return true
    }

    /// Returns the abbreviated version of a commit hash (first 7 characters).
    var abbreviatedHash: String {
        String(prefix(7))
    }

    /// Returns the file extension, if any.
    var fileExtension: String? {
        let parts = split(separator: ".")
        guard parts.count > 1 else { return nil }
        return String(parts.last!)
    }

    /// Returns the file name without extension.
    var fileNameWithoutExtension: String {
        let name = (self as NSString).lastPathComponent
        let ext = (name as NSString).pathExtension
        if ext.isEmpty {
            return name
        }
        return String(name.dropLast(ext.count + 1))
    }

    /// Splits the string into lines, preserving empty lines.
    var lines: [String] {
        components(separatedBy: .newlines)
    }

    /// Returns the first line of the string.
    var firstLine: String {
        lines.first ?? self
    }
}

extension Character {
    /// Returns true if this character is a hexadecimal digit.
    var isHexDigit: Bool {
        switch self {
        case "0"..."9", "a"..."f", "A"..."F":
            return true
        default:
            return false
        }
    }
}
