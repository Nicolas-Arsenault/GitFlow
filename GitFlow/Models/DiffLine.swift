import Foundation

/// Represents a single line in a diff.
struct DiffLine: Identifiable, Equatable {
    /// The type of diff line.
    enum LineType: Equatable {
        /// Context line (unchanged).
        case context
        /// Line was added.
        case addition
        /// Line was deleted.
        case deletion
        /// Hunk header line (e.g., @@ -1,3 +1,4 @@).
        case hunkHeader
        /// File header or other metadata.
        case header
    }

    /// Unique identifier for this line within the diff.
    let id: String

    /// The line content (without the leading +/-/ character).
    let content: String

    /// The type of this line.
    let type: LineType

    /// The line number in the old (left) file, if applicable.
    let oldLineNumber: Int?

    /// The line number in the new (right) file, if applicable.
    let newLineNumber: Int?

    /// Whether this line has a trailing newline.
    let hasNewline: Bool

    /// The raw line from Git output (including prefix).
    let rawLine: String

    /// Creates a diff line.
    init(
        id: String = UUID().uuidString,
        content: String,
        type: LineType,
        oldLineNumber: Int? = nil,
        newLineNumber: Int? = nil,
        hasNewline: Bool = true,
        rawLine: String? = nil
    ) {
        self.id = id
        self.content = content
        self.type = type
        self.oldLineNumber = oldLineNumber
        self.newLineNumber = newLineNumber
        self.hasNewline = hasNewline
        self.rawLine = rawLine ?? content
    }

    /// The prefix character for this line type.
    var prefix: String {
        switch type {
        case .context: return " "
        case .addition: return "+"
        case .deletion: return "-"
        case .hunkHeader, .header: return ""
        }
    }
}
