import Foundation

/// Command to create a commit.
struct CreateCommitCommand: VoidGitCommand {
    let message: String
    let amend: Bool

    init(message: String, amend: Bool = false) {
        self.message = message
        self.amend = amend
    }

    var arguments: [String] {
        var args = ["commit", "-m", message]
        if amend {
            args.append("--amend")
        }
        return args
    }
}

/// Command to create a commit with a message from a file.
struct CreateCommitFromFileCommand: VoidGitCommand {
    let messageFilePath: String
    let amend: Bool

    init(messageFilePath: String, amend: Bool = false) {
        self.messageFilePath = messageFilePath
        self.amend = amend
    }

    var arguments: [String] {
        var args = ["commit", "-F", messageFilePath]
        if amend {
            args.append("--amend")
        }
        return args
    }
}
