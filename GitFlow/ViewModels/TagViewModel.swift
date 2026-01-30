import Foundation

/// View model for tag management.
@MainActor
final class TagViewModel: BaseViewModel {
    // MARK: - Published State

    /// All tags.
    @Published private(set) var tags: [Tag] = []

    /// The currently selected tag.
    @Published var selectedTag: Tag?

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
        await performOperation {
            self.tags = try await self.gitService.getTags(in: self.repository)

            // Clear selection if tag no longer exists
            if let selected = self.selectedTag,
               !self.tags.contains(where: { $0.name == selected.name }) {
                self.selectedTag = nil
            }
        }
    }

    /// Creates a new lightweight tag.
    func createLightweightTag(name: String, commitHash: String? = nil) async {
        await performOperation(showLoading: false) {
            try await self.gitService.createTag(name: name, commitHash: commitHash, in: self.repository)
        }
        await refresh()
    }

    /// Creates a new annotated tag.
    func createAnnotatedTag(name: String, message: String, commitHash: String? = nil) async {
        await performOperation(showLoading: false) {
            try await self.gitService.createTag(name: name, message: message, commitHash: commitHash, in: self.repository)
        }
        await refresh()
    }

    /// Deletes a tag.
    func deleteTag(_ tag: Tag) async {
        await performOperation(showLoading: false) {
            try await self.gitService.deleteTag(name: tag.name, in: self.repository)
        }
        await refresh()
    }

    /// Pushes a tag to remote.
    func pushTag(_ tag: Tag, remote: String = "origin") async {
        await performOperation(showLoading: false) {
            try await self.gitService.pushTag(name: tag.name, remote: remote, in: self.repository)
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
