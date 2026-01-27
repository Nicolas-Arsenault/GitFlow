import Foundation

/// Main facade for Git operations.
/// Provides a high-level interface for all Git commands.
actor GitService {
    private let executor: GitExecutor

    init(executor: GitExecutor = GitExecutor()) {
        self.executor = executor
    }

    // MARK: - Repository Operations

    /// Checks if the specified path is inside a Git repository.
    func isGitRepository(at url: URL) async throws -> Bool {
        let command = IsRepositoryCommand()
        let result = try await executor.execute(
            arguments: command.arguments,
            workingDirectory: url
        )
        return result.succeeded && (try? command.parse(output: result.stdout)) == true
    }

    /// Gets the root directory of the repository.
    func getRepositoryRoot(at url: URL) async throws -> URL {
        let command = GetRootCommand()
        let output = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: url
        )
        let path = try command.parse(output: output)
        return URL(fileURLWithPath: path)
    }

    // MARK: - Status Operations

    /// Gets the current working tree status.
    func getStatus(in repository: Repository) async throws -> WorkingTreeStatus {
        let command = StatusCommand()
        let output = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
        let files = try command.parse(output: output)
        return WorkingTreeStatus.from(files: files)
    }

    // MARK: - Staging Operations

    /// Stages the specified files.
    func stage(files: [String], in repository: Repository) async throws {
        guard !files.isEmpty else { return }
        let command = StageCommand(paths: files)
        _ = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
    }

    /// Stages all changes.
    func stageAll(in repository: Repository) async throws {
        let command = StageAllCommand()
        _ = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
    }

    /// Unstages the specified files.
    func unstage(files: [String], in repository: Repository) async throws {
        guard !files.isEmpty else { return }
        let command = UnstageCommand(paths: files)
        _ = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
    }

    /// Unstages all files.
    func unstageAll(in repository: Repository) async throws {
        let command = UnstageAllCommand()
        _ = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
    }

    /// Discards changes in the specified files.
    func discardChanges(files: [String], in repository: Repository) async throws {
        guard !files.isEmpty else { return }
        let command = DiscardChangesCommand(paths: files)
        _ = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
    }

    /// Stages a specific hunk from a file.
    /// - Parameters:
    ///   - hunk: The hunk to stage.
    ///   - filePath: The path of the file containing the hunk.
    ///   - repository: The repository.
    func stageHunk(_ hunk: DiffHunk, filePath: String, in repository: Repository) async throws {
        let patchContent = hunk.toPatchString(filePath: filePath)
        let command = StageHunkCommand()
        _ = try await executor.executeWithStdinOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL,
            stdinContent: patchContent
        )
    }

    /// Unstages a specific hunk from a file.
    /// - Parameters:
    ///   - hunk: The hunk to unstage.
    ///   - filePath: The path of the file containing the hunk.
    ///   - repository: The repository.
    func unstageHunk(_ hunk: DiffHunk, filePath: String, in repository: Repository) async throws {
        let patchContent = hunk.toPatchString(filePath: filePath)
        let command = UnstageHunkCommand()
        _ = try await executor.executeWithStdinOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL,
            stdinContent: patchContent
        )
    }

    // MARK: - Diff Operations

    /// Gets the diff for staged changes.
    func getStagedDiff(in repository: Repository, filePath: String? = nil) async throws -> [FileDiff] {
        let command = StagedDiffCommand(filePath: filePath)
        let output = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
        return try command.parse(output: output)
    }

    /// Gets the diff for unstaged changes.
    func getUnstagedDiff(in repository: Repository, filePath: String? = nil) async throws -> [FileDiff] {
        let command = UnstagedDiffCommand(filePath: filePath)
        let output = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
        return try command.parse(output: output)
    }

    /// Gets the diff for a specific commit.
    func getCommitDiff(commitHash: String, in repository: Repository) async throws -> [FileDiff] {
        let command = ShowCommitDiffCommand(commitHash: commitHash)
        let output = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
        return try command.parse(output: output)
    }

    // MARK: - Commit Operations

    /// Creates a new commit with the specified message.
    func commit(message: String, in repository: Repository) async throws {
        let command = CreateCommitCommand(message: message)
        _ = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
    }

    /// Gets the commit history.
    func getHistory(in repository: Repository, limit: Int = 100, ref: String? = nil) async throws -> [Commit] {
        let command = LogCommand(limit: limit, ref: ref)
        let output = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
        return try command.parse(output: output)
    }

    /// Gets a specific commit by hash.
    func getCommit(hash: String, in repository: Repository) async throws -> Commit {
        let command = ShowCommitCommand(commitHash: hash)
        let output = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
        return try command.parse(output: output)
    }

    /// Gets the current HEAD commit hash.
    func getHead(in repository: Repository) async throws -> String? {
        let command = HeadCommand()
        let result = try await executor.execute(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
        guard result.succeeded else { return nil }
        return try command.parse(output: result.stdout)
    }

    // MARK: - Branch Operations

    /// Gets all branches.
    func getBranches(in repository: Repository, includeRemote: Bool = true) async throws -> [Branch] {
        let command = ListBranchesCommand(includeRemote: includeRemote)
        let output = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
        return try command.parse(output: output)
    }

    /// Gets the current branch name.
    func getCurrentBranch(in repository: Repository) async throws -> String? {
        let command = CurrentBranchCommand()
        let result = try await executor.execute(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
        guard result.succeeded else { return nil }
        return try command.parse(output: result.stdout)
    }

    /// Checks out the specified branch.
    func checkout(branch: String, in repository: Repository) async throws {
        let command = CheckoutCommand(branchName: branch)
        _ = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
    }

    /// Creates a new branch.
    func createBranch(name: String, startPoint: String? = nil, in repository: Repository) async throws {
        let command = CreateBranchCommand(branchName: name, startPoint: startPoint)
        _ = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
    }

    /// Deletes a branch.
    func deleteBranch(name: String, force: Bool = false, in repository: Repository) async throws {
        let command = DeleteBranchCommand(branchName: name, force: force)
        _ = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
    }

    // MARK: - Stash Operations

    /// Gets all stashes.
    func getStashes(in repository: Repository) async throws -> [Stash] {
        let command = ListStashesCommand()
        let output = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
        return try command.parse(output: output)
    }

    /// Creates a new stash.
    func createStash(message: String? = nil, includeUntracked: Bool = false, in repository: Repository) async throws {
        let command = CreateStashCommand(message: message, includeUntracked: includeUntracked)
        _ = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
    }

    /// Applies a stash without removing it.
    func applyStash(_ stashRef: String = "stash@{0}", in repository: Repository) async throws {
        let command = ApplyStashCommand(stashRef: stashRef)
        _ = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
    }

    /// Pops a stash (apply and remove).
    func popStash(_ stashRef: String = "stash@{0}", in repository: Repository) async throws {
        let command = PopStashCommand(stashRef: stashRef)
        _ = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
    }

    /// Drops a stash.
    func dropStash(_ stashRef: String, in repository: Repository) async throws {
        let command = DropStashCommand(stashRef: stashRef)
        _ = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
    }

    /// Clears all stashes.
    func clearStashes(in repository: Repository) async throws {
        let command = ClearStashesCommand()
        _ = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
    }

    /// Shows the diff for a stash.
    func getStashDiff(_ stashRef: String = "stash@{0}", in repository: Repository) async throws -> [FileDiff] {
        let command = ShowStashCommand(stashRef: stashRef)
        let output = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
        return try command.parse(output: output)
    }

    // MARK: - Remote Operations

    /// Fetches from all remotes.
    func fetch(in repository: Repository, remote: String? = nil, prune: Bool = false) async throws {
        let command = FetchCommand(remote: remote, prune: prune)
        _ = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
    }

    /// Pulls changes from remote.
    func pull(in repository: Repository, remote: String? = nil, branch: String? = nil, rebase: Bool = false) async throws {
        let command = PullCommand(remote: remote, branch: branch, rebase: rebase)
        _ = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
    }

    /// Pushes changes to remote.
    func push(in repository: Repository, remote: String? = nil, branch: String? = nil, setUpstream: Bool = false, force: Bool = false) async throws {
        let command = PushCommand(remote: remote, branch: branch, setUpstream: setUpstream, force: force)
        _ = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
    }

    /// Gets list of remotes.
    func getRemotes(in repository: Repository) async throws -> [Remote] {
        let command = ListRemotesCommand()
        let output = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
        return try command.parse(output: output)
    }

    // MARK: - Tag Operations

    /// Gets all tags.
    func getTags(in repository: Repository) async throws -> [Tag] {
        let command = ListTagsCommand()
        let output = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
        return try command.parse(output: output)
    }

    /// Creates a new tag.
    func createTag(name: String, message: String? = nil, commitHash: String? = nil, in repository: Repository) async throws {
        let command = CreateTagCommand(name: name, message: message, commitHash: commitHash)
        _ = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
    }

    /// Deletes a tag.
    func deleteTag(name: String, in repository: Repository) async throws {
        let command = DeleteTagCommand(name: name)
        _ = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
    }

    /// Pushes a tag to remote.
    func pushTag(name: String, remote: String = "origin", in repository: Repository) async throws {
        let command = PushTagCommand(name: name, remote: remote)
        _ = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
    }

    // MARK: - Clone Operations

    /// Clones a repository to the specified destination.
    /// - Parameters:
    ///   - url: The URL of the repository to clone.
    ///   - destination: The local directory to clone into (the repository folder will be created inside).
    ///   - branch: Optional specific branch to clone.
    /// - Returns: The URL of the cloned repository.
    func clone(url: String, to destination: URL, branch: String? = nil) async throws -> URL {
        let command = CloneCommand(url: url, branch: branch)

        // Append the folder name derived from the URL to the destination
        var args = command.arguments
        let repoName = Self.extractRepoName(from: url)
        let repoPath = destination.appendingPathComponent(repoName)
        args.append(repoPath.path)

        _ = try await executor.executeOrThrow(
            arguments: args,
            workingDirectory: destination
        )

        return repoPath
    }

    /// Extracts the repository name from a Git URL.
    private static func extractRepoName(from url: String) -> String {
        // Handle various URL formats:
        // https://github.com/user/repo.git -> repo
        // git@github.com:user/repo.git -> repo
        // /path/to/repo.git -> repo
        // /path/to/repo -> repo

        var name = url

        // Remove trailing slash
        if name.hasSuffix("/") {
            name = String(name.dropLast())
        }

        // Remove .git suffix
        if name.hasSuffix(".git") {
            name = String(name.dropLast(4))
        }

        // Get the last path component
        if let lastSlash = name.lastIndex(of: "/") {
            name = String(name[name.index(after: lastSlash)...])
        } else if let lastColon = name.lastIndex(of: ":") {
            name = String(name[name.index(after: lastColon)...])
        }

        return name.isEmpty ? "repository" : name
    }
}
