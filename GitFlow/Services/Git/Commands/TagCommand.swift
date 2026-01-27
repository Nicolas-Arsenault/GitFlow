import Foundation

/// Command to list tags.
struct ListTagsCommand: GitCommand {
    typealias Result = [Tag]

    var arguments: [String] {
        ["tag", "-l", "--format=%(refname:short)|%(objectname:short)|%(*objectname:short)|%(contents:subject)"]
    }

    func parse(output: String) throws -> [Tag] {
        TagParser.parse(output)
    }
}

/// Command to create a tag.
struct CreateTagCommand: VoidGitCommand {
    let name: String
    let message: String?
    let commitHash: String?

    init(name: String, message: String? = nil, commitHash: String? = nil) {
        self.name = name
        self.message = message
        self.commitHash = commitHash
    }

    var arguments: [String] {
        var args = ["tag"]
        if let message {
            args.append("-a")
            args.append(name)
            args.append("-m")
            args.append(message)
        } else {
            args.append(name)
        }
        if let commitHash {
            args.append(commitHash)
        }
        return args
    }
}

/// Command to delete a tag.
struct DeleteTagCommand: VoidGitCommand {
    let name: String

    var arguments: [String] {
        ["tag", "-d", name]
    }
}

/// Command to push a tag to remote.
struct PushTagCommand: VoidGitCommand {
    let name: String
    let remote: String

    init(name: String, remote: String = "origin") {
        self.name = name
        self.remote = remote
    }

    var arguments: [String] {
        ["push", remote, name]
    }
}

/// Command to delete a tag from remote.
struct DeleteRemoteTagCommand: VoidGitCommand {
    let name: String
    let remote: String

    init(name: String, remote: String = "origin") {
        self.name = name
        self.remote = remote
    }

    var arguments: [String] {
        ["push", remote, "--delete", name]
    }
}
