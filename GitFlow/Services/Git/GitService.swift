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
    func getStagedDiff(in repository: Repository, filePath: String? = nil, options: DiffOptions = DiffOptions()) async throws -> [FileDiff] {
        let command = StagedDiffCommand(filePath: filePath, options: options)
        let output = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
        return try command.parse(output: output)
    }

    /// Gets the diff for unstaged changes.
    func getUnstagedDiff(in repository: Repository, filePath: String? = nil, options: DiffOptions = DiffOptions()) async throws -> [FileDiff] {
        let command = UnstagedDiffCommand(filePath: filePath, options: options)
        let output = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
        return try command.parse(output: output)
    }

    /// Gets the diff for a specific commit.
    func getCommitDiff(commitHash: String, in repository: Repository, options: DiffOptions = DiffOptions()) async throws -> [FileDiff] {
        let command = ShowCommitDiffCommand(commitHash: commitHash, options: options)
        let output = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
        return try command.parse(output: output)
    }

    // MARK: - Blame Operations

    /// Gets blame information for a file.
    /// - Parameters:
    ///   - filePath: The path to the file.
    ///   - startLine: Optional start line for range.
    ///   - endLine: Optional end line for range.
    ///   - repository: The repository.
    /// - Returns: Array of blame lines.
    func getBlame(for filePath: String, startLine: Int? = nil, endLine: Int? = nil, in repository: Repository) async throws -> [BlameLine] {
        let command = BlameCommand(filePath: filePath, startLine: startLine, endLine: endLine)
        let output = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
        return try command.parse(output: output)
    }

    // MARK: - Patch Operations

    /// Generates a patch for staged changes.
    func getStagedPatch(in repository: Repository, filePath: String? = nil) async throws -> String {
        let command = GenerateStagedPatchCommand(filePath: filePath)
        let output = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
        return try command.parse(output: output)
    }

    /// Generates a patch for unstaged changes.
    func getUnstagedPatch(in repository: Repository, filePath: String? = nil) async throws -> String {
        let command = GenerateUnstagedPatchCommand(filePath: filePath)
        let output = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
        return try command.parse(output: output)
    }

    /// Generates a patch for a commit.
    func getCommitPatch(commitHash: String, in repository: Repository) async throws -> String {
        let command = GenerateCommitPatchCommand(commitHash: commitHash)
        let output = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
        return try command.parse(output: output)
    }

    /// Reverts changes in specified files.
    func revertFiles(_ files: [String], in repository: Repository) async throws {
        let command = RevertFilesCommand(files: files)
        _ = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
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

    /// Creates a commit with full options.
    /// - Parameters:
    ///   - options: The commit options.
    ///   - repository: The repository.
    func commitWithOptions(_ options: CommitOptions, in repository: Repository) async throws {
        let command = CreateCommitWithOptionsCommand(options: options)
        _ = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
    }

    /// Amends the last commit with a new message.
    /// - Parameters:
    ///   - message: The new commit message.
    ///   - repository: The repository.
    func amendCommit(message: String, in repository: Repository) async throws {
        var options = CommitOptions(message: message)
        options.amend = true
        try await commitWithOptions(options, in: repository)
    }

    /// Amends the last commit without changing the message.
    /// - Parameter repository: The repository.
    func amendCommitNoEdit(in repository: Repository) async throws {
        var options = CommitOptions()
        options.amend = true
        options.noEdit = true
        try await commitWithOptions(options, in: repository)
    }

    /// Gets the last commit message.
    /// - Parameter repository: The repository.
    /// - Returns: The last commit message.
    func getLastCommitMessage(in repository: Repository) async throws -> String {
        let command = GetLastCommitMessageCommand()
        let output = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
        return try command.parse(output: output)
    }

    /// Checks if GPG signing is configured.
    /// - Parameter repository: The repository.
    /// - Returns: True if GPG signing is configured.
    func isGPGSigningConfigured(in repository: Repository) async -> Bool {
        let command = CheckGPGSigningCommand()
        let result = try? await executor.execute(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
        guard let result = result, result.succeeded else { return false }
        return (try? command.parse(output: result.stdout)) ?? false
    }

    /// Gets the configured GPG key ID.
    /// - Parameter repository: The repository.
    /// - Returns: The GPG key ID or nil.
    func getGPGKeyId(in repository: Repository) async -> String? {
        let command = GetGPGKeyIdCommand()
        let result = try? await executor.execute(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
        guard let result = result, result.succeeded else { return nil }
        return try? command.parse(output: result.stdout)
    }

    /// Gets the configured commit template.
    /// - Parameter repository: The repository.
    /// - Returns: The template content or nil.
    func getCommitTemplate(in repository: Repository) async -> String? {
        let command = GetCommitTemplateCommand()
        let result = try? await executor.execute(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
        guard let result = result, result.succeeded else { return nil }
        return try? command.parse(output: result.stdout)
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

    /// Gets the commit history with filter options.
    /// - Parameters:
    ///   - repository: The repository.
    ///   - limit: Maximum number of commits.
    ///   - filters: Filter options.
    /// - Returns: Array of commits matching the filters.
    func getHistoryWithFilters(
        in repository: Repository,
        limit: Int = 100,
        filters: LogFilterOptions
    ) async throws -> [Commit] {
        let command = LogWithFiltersCommand(limit: limit, filters: filters)
        let output = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
        return try command.parse(output: output)
    }

    /// Searches commits by message.
    /// - Parameters:
    ///   - query: The search query.
    ///   - limit: Maximum number of results.
    ///   - repository: The repository.
    /// - Returns: Array of matching commits.
    func searchCommits(
        query: String,
        limit: Int = 100,
        in repository: Repository
    ) async throws -> [Commit] {
        let command = SearchCommitsCommand(searchQuery: query, limit: limit)
        let output = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
        return try command.parse(output: output)
    }

    /// Gets commits by a specific author.
    /// - Parameters:
    ///   - author: The author name or email.
    ///   - limit: Maximum number of results.
    ///   - repository: The repository.
    /// - Returns: Array of commits by the author.
    func getCommitsByAuthor(
        author: String,
        limit: Int = 100,
        in repository: Repository
    ) async throws -> [Commit] {
        let command = AuthorCommitsCommand(author: author, limit: limit)
        let output = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
        return try command.parse(output: output)
    }

    /// Gets commits in a date range.
    /// - Parameters:
    ///   - since: Start date (optional).
    ///   - until: End date (optional).
    ///   - limit: Maximum number of results.
    ///   - repository: The repository.
    /// - Returns: Array of commits in the date range.
    func getCommitsInDateRange(
        since: Date? = nil,
        until: Date? = nil,
        limit: Int = 100,
        in repository: Repository
    ) async throws -> [Commit] {
        let command = DateRangeCommitsCommand(since: since, until: until, limit: limit)
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

    /// Renames a local branch.
    /// - Parameters:
    ///   - oldName: The current name of the branch.
    ///   - newName: The new name for the branch.
    ///   - repository: The repository.
    func renameBranch(oldName: String, newName: String, in repository: Repository) async throws {
        let command = RenameBranchCommand(oldName: oldName, newName: newName)
        _ = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
    }

    /// Renames a branch on the remote (deletes old, pushes new).
    /// - Parameters:
    ///   - oldName: The current name of the branch on remote.
    ///   - newName: The new name for the branch.
    ///   - remoteName: The remote name (defaults to "origin").
    ///   - repository: The repository.
    func renameBranchOnRemote(oldName: String, newName: String, remoteName: String = "origin", in repository: Repository) async throws {
        // First rename locally
        try await renameBranch(oldName: oldName, newName: newName, in: repository)

        // Delete old branch on remote
        let deleteCommand = DeleteRemoteBranchCommand(remoteName: remoteName, branchName: oldName)
        _ = try await executor.executeOrThrow(
            arguments: deleteCommand.arguments,
            workingDirectory: repository.rootURL
        )

        // Push new branch to remote
        let pushCommand = PushBranchToRemoteCommand(
            localBranch: newName,
            remoteName: remoteName,
            remoteBranch: newName,
            setUpstream: true
        )
        _ = try await executor.executeOrThrow(
            arguments: pushCommand.arguments,
            workingDirectory: repository.rootURL
        )
    }

    /// Sets the upstream tracking branch.
    /// - Parameters:
    ///   - branchName: The local branch name.
    ///   - upstreamRef: The upstream reference (e.g., "origin/main").
    ///   - repository: The repository.
    func setUpstream(branchName: String, upstreamRef: String, in repository: Repository) async throws {
        let command = SetUpstreamCommand(branchName: branchName, upstreamRef: upstreamRef)
        _ = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
    }

    /// Unsets the upstream tracking branch.
    /// - Parameters:
    ///   - branchName: The local branch name.
    ///   - repository: The repository.
    func unsetUpstream(branchName: String, in repository: Repository) async throws {
        let command = UnsetUpstreamCommand(branchName: branchName)
        _ = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
    }

    // MARK: - Merge Operations

    /// Merges a branch into the current branch.
    /// - Parameters:
    ///   - branchName: The branch to merge.
    ///   - mergeType: The type of merge to perform.
    ///   - message: Optional commit message for the merge.
    ///   - repository: The repository.
    func merge(branchName: String, mergeType: MergeType = .normal, message: String? = nil, in repository: Repository) async throws {
        let command = MergeCommand(branchName: branchName, mergeType: mergeType, message: message)
        _ = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
    }

    /// Aborts a merge in progress.
    func abortMerge(in repository: Repository) async throws {
        let command = AbortMergeCommand()
        _ = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
    }

    /// Continues a merge after conflicts have been resolved.
    func continueMerge(in repository: Repository) async throws {
        let command = ContinueMergeCommand()
        _ = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
    }

    // MARK: - Rebase Operations

    /// Rebases the current branch onto another branch.
    /// - Parameters:
    ///   - ontoBranch: The branch to rebase onto.
    ///   - repository: The repository.
    func rebase(ontoBranch: String, in repository: Repository) async throws {
        let command = RebaseCommand(ontoBranch: ontoBranch, interactive: false)
        _ = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
    }

    /// Aborts a rebase in progress.
    func abortRebase(in repository: Repository) async throws {
        let command = AbortRebaseCommand()
        _ = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
    }

    /// Continues a rebase after conflicts have been resolved.
    func continueRebase(in repository: Repository) async throws {
        let command = ContinueRebaseCommand()
        _ = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
    }

    /// Skips the current commit during a rebase.
    func skipRebase(in repository: Repository) async throws {
        let command = SkipRebaseCommand()
        _ = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
    }

    // MARK: - Branch Comparison Operations

    /// Gets the diff between two branches.
    /// - Parameters:
    ///   - baseBranch: The base branch for comparison.
    ///   - compareBranch: The branch to compare against.
    ///   - repository: The repository.
    /// - Returns: Array of file diffs between the branches.
    func getBranchDiff(baseBranch: String, compareBranch: String, in repository: Repository) async throws -> [FileDiff] {
        let command = BranchDiffCommand(baseBranch: baseBranch, compareBranch: compareBranch)
        let output = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
        return try command.parse(output: output)
    }

    /// Gets the commits that exist in compareBranch but not in baseBranch.
    /// - Parameters:
    ///   - baseBranch: The base branch for comparison.
    ///   - compareBranch: The branch to compare against.
    ///   - limit: Maximum number of commits to return.
    ///   - repository: The repository.
    /// - Returns: Array of commits unique to compareBranch.
    func getBranchCommitDiff(baseBranch: String, compareBranch: String, limit: Int = 100, in repository: Repository) async throws -> [Commit] {
        let command = BranchLogDiffCommand(baseBranch: baseBranch, compareBranch: compareBranch, limit: limit)
        let output = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
        return try command.parse(output: output)
    }

    /// Checks if the repository is in a merging or rebasing state.
    func getRepositoryState(in repository: Repository) async throws -> RepositoryState {
        var state = RepositoryState()

        // Check for current branch
        if let currentBranch = try await getCurrentBranch(in: repository) {
            state.currentBranch = currentBranch
        } else {
            state.isDetachedHead = true
        }

        // Check for merge state by looking for MERGE_HEAD file
        let mergeHeadURL = repository.rootURL.appendingPathComponent(".git/MERGE_HEAD")
        state.isMerging = FileManager.default.fileExists(atPath: mergeHeadURL.path)

        // Check for rebase state by looking for rebase directory
        let rebaseApplyURL = repository.rootURL.appendingPathComponent(".git/rebase-apply")
        let rebaseMergeURL = repository.rootURL.appendingPathComponent(".git/rebase-merge")
        state.isRebasing = FileManager.default.fileExists(atPath: rebaseApplyURL.path)
            || FileManager.default.fileExists(atPath: rebaseMergeURL.path)

        return state
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

    /// Adds a new remote.
    func addRemote(name: String, url: String, in repository: Repository) async throws {
        let command = AddRemoteCommand(name: name, url: url)
        _ = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
    }

    /// Removes a remote.
    func removeRemote(name: String, in repository: Repository) async throws {
        let command = RemoveRemoteCommand(name: name)
        _ = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
    }

    /// Renames a remote.
    func renameRemote(oldName: String, newName: String, in repository: Repository) async throws {
        let command = RenameRemoteCommand(oldName: oldName, newName: newName)
        _ = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
    }

    /// Sets the URL of a remote.
    func setRemoteURL(name: String, url: String, pushURL: Bool = false, in repository: Repository) async throws {
        let command = SetRemoteURLCommand(name: name, url: url, pushURL: pushURL)
        _ = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
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
