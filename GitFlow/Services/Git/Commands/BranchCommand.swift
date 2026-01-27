import Foundation

/// Command to list all branches.
struct ListBranchesCommand: GitCommand {
    typealias Result = [Branch]

    /// Whether to include remote branches.
    let includeRemote: Bool

    init(includeRemote: Bool = true) {
        self.includeRemote = includeRemote
    }

    var arguments: [String] {
        var args = [
            "branch",
            "--format=%(HEAD)|%(refname)|%(refname:short)|%(objectname)|%(upstream:short)|%(upstream:track,nobracket)"
        ]

        if includeRemote {
            args.append("-a")
        }

        return args
    }

    func parse(output: String) throws -> [Branch] {
        BranchParser.parse(output)
    }
}

/// Command to get the current branch name.
struct CurrentBranchCommand: GitCommand {
    typealias Result = String?

    var arguments: [String] {
        ["rev-parse", "--abbrev-ref", "HEAD"]
    }

    func parse(output: String) throws -> String? {
        let name = output.trimmingCharacters(in: .whitespacesAndNewlines)
        // Returns "HEAD" when in detached state
        return name == "HEAD" ? nil : name
    }
}

/// Command to checkout a branch.
struct CheckoutCommand: VoidGitCommand {
    let branchName: String

    var arguments: [String] {
        ["checkout", branchName]
    }
}

/// Command to create a new branch.
struct CreateBranchCommand: VoidGitCommand {
    let branchName: String
    let startPoint: String?

    init(branchName: String, startPoint: String? = nil) {
        self.branchName = branchName
        self.startPoint = startPoint
    }

    var arguments: [String] {
        var args = ["checkout", "-b", branchName]
        if let startPoint {
            args.append(startPoint)
        }
        return args
    }
}

/// Command to delete a branch.
struct DeleteBranchCommand: VoidGitCommand {
    let branchName: String
    let force: Bool

    init(branchName: String, force: Bool = false) {
        self.branchName = branchName
        self.force = force
    }

    var arguments: [String] {
        ["branch", force ? "-D" : "-d", branchName]
    }
}
