import Foundation

/// Command to stage files.
struct StageCommand: VoidGitCommand {
    let paths: [String]

    var arguments: [String] {
        ["add", "--"] + paths
    }
}

/// Command to stage all changes.
struct StageAllCommand: VoidGitCommand {
    var arguments: [String] {
        ["add", "-A"]
    }
}

/// Command to unstage files.
struct UnstageCommand: VoidGitCommand {
    let paths: [String]

    var arguments: [String] {
        ["reset", "HEAD", "--"] + paths
    }
}

/// Command to unstage all files.
struct UnstageAllCommand: VoidGitCommand {
    var arguments: [String] {
        ["reset", "HEAD"]
    }
}

/// Command to discard changes in a file.
struct DiscardChangesCommand: VoidGitCommand {
    let paths: [String]

    var arguments: [String] {
        ["checkout", "--"] + paths
    }
}

/// Command to discard all unstaged changes.
struct DiscardAllChangesCommand: VoidGitCommand {
    var arguments: [String] {
        ["checkout", "--", "."]
    }
}

/// Command to stage a specific hunk using a patch.
/// Note: This command requires the patch content to be passed via stdin.
struct StageHunkCommand: VoidGitCommand {
    var arguments: [String] {
        ["apply", "--cached", "--unidiff-zero", "-"]
    }
}

/// Command to unstage a specific hunk using a patch (reverse apply).
/// Note: This command requires the patch content to be passed via stdin.
struct UnstageHunkCommand: VoidGitCommand {
    var arguments: [String] {
        ["apply", "--cached", "--unidiff-zero", "--reverse", "-"]
    }
}
