import Foundation

/// Represents a Git tag.
struct Tag: Identifiable, Equatable, Hashable {
    /// The tag name.
    let name: String

    /// The commit hash this tag points to.
    let commitHash: String

    /// The tag message (for annotated tags).
    let message: String?

    /// The tagger name (for annotated tags).
    let taggerName: String?

    /// The tagger email (for annotated tags).
    let taggerEmail: String?

    /// The tag date (for annotated tags).
    let tagDate: Date?

    /// Whether this is an annotated tag.
    var isAnnotated: Bool {
        message != nil
    }

    var id: String { name }

    /// Creates a lightweight tag.
    static func lightweight(name: String, commitHash: String) -> Tag {
        Tag(
            name: name,
            commitHash: commitHash,
            message: nil,
            taggerName: nil,
            taggerEmail: nil,
            tagDate: nil
        )
    }

    /// Creates an annotated tag.
    static func annotated(
        name: String,
        commitHash: String,
        message: String,
        taggerName: String,
        taggerEmail: String,
        tagDate: Date
    ) -> Tag {
        Tag(
            name: name,
            commitHash: commitHash,
            message: message,
            taggerName: taggerName,
            taggerEmail: taggerEmail,
            tagDate: tagDate
        )
    }
}
