import Foundation

/// Command to list all stashes.
struct ListStashesCommand: GitCommand {
    typealias Result = [Stash]

    var arguments: [String] {
        ["stash", "list", "--format=%gd|%H|%gs|%aI"]
    }

    func parse(output: String) throws -> [Stash] {
        StashParser.parse(output)
    }
}

/// Command to create a new stash.
struct CreateStashCommand: VoidGitCommand {
    let message: String?
    let includeUntracked: Bool

    init(message: String? = nil, includeUntracked: Bool = false) {
        self.message = message
        self.includeUntracked = includeUntracked
    }

    var arguments: [String] {
        var args = ["stash", "push"]
        if includeUntracked {
            args.append("--include-untracked")
        }
        if let message {
            args.append("-m")
            args.append(message)
        }
        return args
    }
}

/// Command to apply a stash without removing it.
struct ApplyStashCommand: VoidGitCommand {
    let stashRef: String

    init(stashRef: String = "stash@{0}") {
        self.stashRef = stashRef
    }

    var arguments: [String] {
        ["stash", "apply", stashRef]
    }
}

/// Command to pop a stash (apply and remove).
struct PopStashCommand: VoidGitCommand {
    let stashRef: String

    init(stashRef: String = "stash@{0}") {
        self.stashRef = stashRef
    }

    var arguments: [String] {
        ["stash", "pop", stashRef]
    }
}

/// Command to drop a stash.
struct DropStashCommand: VoidGitCommand {
    let stashRef: String

    var arguments: [String] {
        ["stash", "drop", stashRef]
    }
}

/// Command to clear all stashes.
struct ClearStashesCommand: VoidGitCommand {
    var arguments: [String] {
        ["stash", "clear"]
    }
}

/// Command to show stash contents.
struct ShowStashCommand: GitCommand {
    typealias Result = [FileDiff]

    let stashRef: String

    init(stashRef: String = "stash@{0}") {
        self.stashRef = stashRef
    }

    var arguments: [String] {
        ["stash", "show", "-p", "--no-color", stashRef]
    }

    func parse(output: String) throws -> [FileDiff] {
        DiffParser.parse(output)
    }
}
