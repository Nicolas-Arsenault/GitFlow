import Foundation

/// View model for commit creation.
@MainActor
final class CommitViewModel: ObservableObject {
    // MARK: - Published State

    /// The commit message being composed.
    @Published var commitMessage: String = ""

    /// Whether a commit operation is in progress.
    @Published private(set) var isCommitting: Bool = false

    /// Current error, if any.
    @Published var error: GitError?

    /// Whether the last commit succeeded.
    @Published private(set) var lastCommitSucceeded: Bool = false

    /// The subject line (first line) of the commit message.
    var subject: String {
        let lines = commitMessage.components(separatedBy: .newlines)
        return lines.first ?? ""
    }

    /// The body of the commit message (everything after the first line).
    var body: String {
        let lines = commitMessage.components(separatedBy: .newlines)
        guard lines.count > 1 else { return "" }
        return lines.dropFirst().joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Dependencies

    private let repository: Repository
    private let gitService: GitService

    // MARK: - Initialization

    init(repository: Repository, gitService: GitService) {
        self.repository = repository
        self.gitService = gitService
    }

    // MARK: - Public Methods

    /// Creates a commit with the current message.
    func createCommit() async {
        await createCommit(message: commitMessage)
    }

    /// Creates a commit with the specified message.
    func createCommit(message: String) async {
        guard !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            error = .unknown(message: "Commit message cannot be empty")
            return
        }

        isCommitting = true
        lastCommitSucceeded = false
        defer { isCommitting = false }

        do {
            try await gitService.commit(message: message, in: repository)
            commitMessage = ""
            lastCommitSucceeded = true
            error = nil
        } catch let gitError as GitError {
            error = gitError
            lastCommitSucceeded = false
        } catch {
            self.error = .unknown(message: error.localizedDescription)
            lastCommitSucceeded = false
        }
    }

    /// Clears the commit message.
    func clearMessage() {
        commitMessage = ""
    }

    /// Sets a template commit message.
    func setTemplate(_ template: String) {
        commitMessage = template
    }

    // MARK: - Computed Properties

    /// Whether the commit message is valid.
    var isMessageValid: Bool {
        !commitMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// The length of the subject line.
    var subjectLength: Int {
        subject.count
    }

    /// Whether the subject line is too long (over 50 characters).
    var isSubjectTooLong: Bool {
        subjectLength > 50
    }

    /// Whether the subject line is much too long (over 72 characters).
    var isSubjectWayTooLong: Bool {
        subjectLength > 72
    }

    /// A suggested subject line length indicator.
    var subjectLengthIndicator: String {
        if isSubjectWayTooLong {
            return "\(subjectLength) (way too long)"
        } else if isSubjectTooLong {
            return "\(subjectLength) (too long)"
        }
        return "\(subjectLength)"
    }
}
