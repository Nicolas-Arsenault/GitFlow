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
    /// Uses a lightweight string based on line numbers instead of UUID for performance.
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

    /// Thread-safe counter for generating unique IDs when line numbers aren't available.
    private static let idCounter = AtomicCounter()

    /// Creates a diff line.
    init(
        id: String? = nil,
        content: String,
        type: LineType,
        oldLineNumber: Int? = nil,
        newLineNumber: Int? = nil,
        hasNewline: Bool = true,
        rawLine: String? = nil
    ) {
        // Generate a lightweight ID based on line numbers or a simple counter
        if let id = id {
            self.id = id
        } else if let old = oldLineNumber, let new = newLineNumber {
            self.id = "\(old)-\(new)"
        } else if let old = oldLineNumber {
            self.id = "o\(old)"
        } else if let new = newLineNumber {
            self.id = "n\(new)"
        } else {
            self.id = "x\(Self.idCounter.next())"
        }
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

/// A simple thread-safe counter for generating unique IDs.
final class AtomicCounter: @unchecked Sendable {
    private var value: Int = 0
    private let lock = NSLock()

    func next() -> Int {
        lock.lock()
        defer { lock.unlock() }
        value += 1
        return value
    }
}
