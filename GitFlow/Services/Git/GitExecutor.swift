import Foundation

/// Executes Git commands asynchronously using the system Git installation.
actor GitExecutor {
    /// The path to the Git executable.
    private let gitPath: String

    /// Default timeout for Git commands (30 seconds).
    private let defaultTimeout: TimeInterval = 30.0

    /// Creates a GitExecutor with the specified Git path.
    /// - Parameter gitPath: Path to the Git executable. Defaults to "/usr/bin/git".
    init(gitPath: String = "/usr/bin/git") {
        self.gitPath = gitPath
    }

    /// Result of a Git command execution.
    struct ExecutionResult {
        /// The standard output.
        let stdout: String
        /// The standard error.
        let stderr: String
        /// The exit code.
        let exitCode: Int32
        /// Whether the command succeeded (exit code 0).
        var succeeded: Bool { exitCode == 0 }
    }

    /// Executes a Git command.
    /// - Parameters:
    ///   - arguments: The Git command arguments (e.g., ["status", "--porcelain"]).
    ///   - workingDirectory: The directory to run the command in.
    ///   - timeout: Maximum time to wait for the command to complete.
    /// - Returns: The execution result.
    /// - Throws: GitError if the command fails to execute.
    func execute(
        arguments: [String],
        workingDirectory: URL,
        timeout: TimeInterval? = nil
    ) async throws -> ExecutionResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: gitPath)
        process.arguments = arguments
        process.currentDirectoryURL = workingDirectory

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        // Set up environment
        var environment = ProcessInfo.processInfo.environment
        environment["GIT_TERMINAL_PROMPT"] = "0"  // Disable prompts
        environment["LC_ALL"] = "C"  // Consistent output format
        process.environment = environment

        do {
            try process.run()
        } catch {
            throw GitError.gitNotFound
        }

        // Handle timeout
        let effectiveTimeout = timeout ?? defaultTimeout
        let timeoutTask = Task {
            try await Task.sleep(nanoseconds: UInt64(effectiveTimeout * 1_000_000_000))
            if process.isRunning {
                process.terminate()
            }
        }

        // Read output BEFORE waitUntilExit to avoid pipe buffer deadlock.
        // When output is large, the pipe buffer fills up and the process blocks
        // waiting for buffer space. If we wait for exit first, we deadlock.
        var stdoutData = Data()
        var stderrData = Data()

        let stdoutHandle = stdoutPipe.fileHandleForReading
        let stderrHandle = stderrPipe.fileHandleForReading

        // Read both pipes concurrently to prevent deadlock
        let readGroup = DispatchGroup()

        readGroup.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            stdoutData = stdoutHandle.readDataToEndOfFile()
            readGroup.leave()
        }

        readGroup.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            stderrData = stderrHandle.readDataToEndOfFile()
            readGroup.leave()
        }

        // Wait for reads to complete
        readGroup.wait()

        // Now wait for process to exit (should be immediate since pipes are drained)
        process.waitUntilExit()
        timeoutTask.cancel()

        let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderr = String(data: stderrData, encoding: .utf8) ?? ""

        return ExecutionResult(
            stdout: stdout,
            stderr: stderr,
            exitCode: process.terminationStatus
        )
    }

    /// Executes a Git command with additional environment variables.
    /// - Parameters:
    ///   - arguments: The Git command arguments (e.g., ["status", "--porcelain"]).
    ///   - workingDirectory: The directory to run the command in.
    ///   - environment: Additional environment variables to set.
    ///   - timeout: Maximum time to wait for the command to complete.
    /// - Returns: The execution result.
    /// - Throws: GitError if the command fails to execute.
    func execute(
        arguments: [String],
        workingDirectory: URL,
        environment additionalEnvironment: [String: String],
        timeout: TimeInterval? = nil
    ) async throws -> ExecutionResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: gitPath)
        process.arguments = arguments
        process.currentDirectoryURL = workingDirectory

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        // Set up environment with additional variables
        var environment = ProcessInfo.processInfo.environment
        environment["GIT_TERMINAL_PROMPT"] = "0"  // Disable prompts
        environment["LC_ALL"] = "C"  // Consistent output format
        for (key, value) in additionalEnvironment {
            environment[key] = value
        }
        process.environment = environment

        do {
            try process.run()
        } catch {
            throw GitError.gitNotFound
        }

        // Handle timeout
        let effectiveTimeout = timeout ?? defaultTimeout
        let timeoutTask = Task {
            try await Task.sleep(nanoseconds: UInt64(effectiveTimeout * 1_000_000_000))
            if process.isRunning {
                process.terminate()
            }
        }

        // Read output BEFORE waitUntilExit to avoid pipe buffer deadlock
        var stdoutData = Data()
        var stderrData = Data()

        let stdoutHandle = stdoutPipe.fileHandleForReading
        let stderrHandle = stderrPipe.fileHandleForReading

        let readGroup = DispatchGroup()

        readGroup.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            stdoutData = stdoutHandle.readDataToEndOfFile()
            readGroup.leave()
        }

        readGroup.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            stderrData = stderrHandle.readDataToEndOfFile()
            readGroup.leave()
        }

        readGroup.wait()
        process.waitUntilExit()
        timeoutTask.cancel()

        let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderr = String(data: stderrData, encoding: .utf8) ?? ""

        return ExecutionResult(
            stdout: stdout,
            stderr: stderr,
            exitCode: process.terminationStatus
        )
    }

    /// Executes a Git command and returns the stdout if successful.
    /// - Parameters:
    ///   - arguments: The Git command arguments.
    ///   - workingDirectory: The directory to run the command in.
    ///   - timeout: Maximum time to wait for the command to complete.
    /// - Returns: The standard output.
    /// - Throws: GitError if the command fails.
    func executeOrThrow(
        arguments: [String],
        workingDirectory: URL,
        timeout: TimeInterval? = nil
    ) async throws -> String {
        let result = try await execute(
            arguments: arguments,
            workingDirectory: workingDirectory,
            timeout: timeout
        )

        guard result.succeeded else {
            let command = "git " + arguments.joined(separator: " ")
            throw GitError.commandFailed(
                command: command,
                exitCode: result.exitCode,
                message: result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }

        return result.stdout
    }

    /// Checks if Git is available on the system.
    /// - Returns: True if Git is available.
    func isGitAvailable() async -> Bool {
        do {
            let result = try await execute(
                arguments: ["--version"],
                workingDirectory: URL(fileURLWithPath: "/")
            )
            return result.succeeded
        } catch {
            return false
        }
    }

    /// Executes a Git command with stdin input.
    /// - Parameters:
    ///   - arguments: The Git command arguments.
    ///   - workingDirectory: The directory to run the command in.
    ///   - stdinContent: The content to pass to stdin.
    ///   - timeout: Maximum time to wait for the command to complete.
    /// - Returns: The execution result.
    /// - Throws: GitError if the command fails to execute.
    func executeWithStdin(
        arguments: [String],
        workingDirectory: URL,
        stdinContent: String,
        timeout: TimeInterval? = nil
    ) async throws -> ExecutionResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: gitPath)
        process.arguments = arguments
        process.currentDirectoryURL = workingDirectory

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        let stdinPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        process.standardInput = stdinPipe

        // Set up environment
        var environment = ProcessInfo.processInfo.environment
        environment["GIT_TERMINAL_PROMPT"] = "0"  // Disable prompts
        environment["LC_ALL"] = "C"  // Consistent output format
        process.environment = environment

        do {
            try process.run()
        } catch {
            throw GitError.gitNotFound
        }

        // Write stdin content
        if let stdinData = stdinContent.data(using: .utf8) {
            stdinPipe.fileHandleForWriting.write(stdinData)
        }
        stdinPipe.fileHandleForWriting.closeFile()

        // Handle timeout
        let effectiveTimeout = timeout ?? defaultTimeout
        let timeoutTask = Task {
            try await Task.sleep(nanoseconds: UInt64(effectiveTimeout * 1_000_000_000))
            if process.isRunning {
                process.terminate()
            }
        }

        // Read output BEFORE waitUntilExit to avoid pipe buffer deadlock
        var stdoutData = Data()
        var stderrData = Data()

        let stdoutHandle = stdoutPipe.fileHandleForReading
        let stderrHandle = stderrPipe.fileHandleForReading

        let readGroup = DispatchGroup()

        readGroup.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            stdoutData = stdoutHandle.readDataToEndOfFile()
            readGroup.leave()
        }

        readGroup.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            stderrData = stderrHandle.readDataToEndOfFile()
            readGroup.leave()
        }

        readGroup.wait()
        process.waitUntilExit()
        timeoutTask.cancel()

        let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderr = String(data: stderrData, encoding: .utf8) ?? ""

        return ExecutionResult(
            stdout: stdout,
            stderr: stderr,
            exitCode: process.terminationStatus
        )
    }

    /// Executes a Git command with stdin input and throws if it fails.
    /// - Parameters:
    ///   - arguments: The Git command arguments.
    ///   - workingDirectory: The directory to run the command in.
    ///   - stdinContent: The content to pass to stdin.
    /// - Returns: The standard output.
    /// - Throws: GitError if the command fails.
    func executeWithStdinOrThrow(
        arguments: [String],
        workingDirectory: URL,
        stdinContent: String
    ) async throws -> String {
        let result = try await executeWithStdin(
            arguments: arguments,
            workingDirectory: workingDirectory,
            stdinContent: stdinContent
        )

        guard result.succeeded else {
            let command = "git " + arguments.joined(separator: " ")
            throw GitError.commandFailed(
                command: command,
                exitCode: result.exitCode,
                message: result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }

        return result.stdout
    }
}
