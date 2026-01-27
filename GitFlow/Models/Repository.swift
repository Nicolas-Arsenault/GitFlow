import Foundation

/// Represents a Git repository.
struct Repository: Identifiable, Equatable {
    /// Unique identifier for this repository instance.
    let id: UUID

    /// The root directory URL of the repository.
    let rootURL: URL

    /// The name of the repository (directory name).
    var name: String {
        rootURL.lastPathComponent
    }

    /// The absolute path to the repository.
    var path: String {
        rootURL.path
    }

    /// Creates a new repository reference.
    /// - Parameter rootURL: The root directory URL of the Git repository.
    init(rootURL: URL) {
        self.id = UUID()
        self.rootURL = rootURL
    }
}
