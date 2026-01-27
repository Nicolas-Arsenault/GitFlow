import Foundation

/// View model for tag management.
@MainActor
final class TagViewModel: ObservableObject {
    // MARK: - Published State

    /// All tags.
    @Published private(set) var tags: [Tag] = []

    /// The currently selected tag.
    @Published var selectedTag: Tag?

    /// Whether tags are loading.
    @Published private(set) var isLoading: Bool = false

    /// Whether an operation is in progress.
    @Published private(set) var isOperationInProgress: Bool = false

    /// Current error, if any.
    @Published var error: GitError?

    // MARK: - Dependencies

    private let repository: Repository
    private let gitService: GitService

    // MARK: - Initialization

    init(repository: Repository, gitService: GitService) {
        self.repository = repository
        self.gitService = gitService
    }

    // MARK: - Public Methods

    /// Refreshes the tag list.
    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        do {
            tags = try await gitService.getTags(in: repository)
            error = nil

            // Clear selection if tag no longer exists
            if let selected = selectedTag,
               !tags.contains(where: { $0.name == selected.name }) {
                selectedTag = nil
            }
        } catch let gitError as GitError {
            error = gitError
        } catch {
            self.error = .unknown(message: error.localizedDescription)
        }
    }

    /// Creates a new lightweight tag.
    func createLightweightTag(name: String, commitHash: String? = nil) async {
        isOperationInProgress = true
        defer { isOperationInProgress = false }

        do {
            try await gitService.createTag(name: name, commitHash: commitHash, in: repository)
            await refresh()
            error = nil
        } catch let gitError as GitError {
            error = gitError
        } catch {
            self.error = .unknown(message: error.localizedDescription)
        }
    }

    /// Creates a new annotated tag.
    func createAnnotatedTag(name: String, message: String, commitHash: String? = nil) async {
        isOperationInProgress = true
        defer { isOperationInProgress = false }

        do {
            try await gitService.createTag(name: name, message: message, commitHash: commitHash, in: repository)
            await refresh()
            error = nil
        } catch let gitError as GitError {
            error = gitError
        } catch {
            self.error = .unknown(message: error.localizedDescription)
        }
    }

    /// Deletes a tag.
    func deleteTag(_ tag: Tag) async {
        isOperationInProgress = true
        defer { isOperationInProgress = false }

        do {
            try await gitService.deleteTag(name: tag.name, in: repository)
            await refresh()
            error = nil
        } catch let gitError as GitError {
            error = gitError
        } catch {
            self.error = .unknown(message: error.localizedDescription)
        }
    }

    /// Pushes a tag to remote.
    func pushTag(_ tag: Tag, remote: String = "origin") async {
        isOperationInProgress = true
        defer { isOperationInProgress = false }

        do {
            try await gitService.pushTag(name: tag.name, remote: remote, in: repository)
            error = nil
        } catch let gitError as GitError {
            error = gitError
        } catch {
            self.error = .unknown(message: error.localizedDescription)
        }
    }

    // MARK: - Computed Properties

    /// Whether there are any tags.
    var hasTags: Bool {
        !tags.isEmpty
    }

    /// The count of tags.
    var tagCount: Int {
        tags.count
    }

    /// Annotated tags only.
    var annotatedTags: [Tag] {
        tags.filter { $0.isAnnotated }
    }

    /// Lightweight tags only.
    var lightweightTags: [Tag] {
        tags.filter { !$0.isAnnotated }
    }
}
