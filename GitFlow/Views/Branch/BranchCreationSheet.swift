import SwiftUI

/// Sheet for creating a new branch.
struct BranchCreationSheet: View {
    @ObservedObject var viewModel: BranchViewModel
    @Binding var isPresented: Bool

    @State private var branchName: String = ""
    @State private var startPoint: String = ""
    @State private var useStartPoint: Bool = false

    var body: some View {
        VStack(spacing: 16) {
            Text("Create New Branch")
                .font(.headline)

            Form {
                TextField("Branch name", text: $branchName)
                    .textFieldStyle(.roundedBorder)

                Toggle("From specific commit/branch", isOn: $useStartPoint)

                if useStartPoint {
                    TextField("Start point (commit or branch)", text: $startPoint)
                        .textFieldStyle(.roundedBorder)
                }
            }

            // Validation messages
            if !branchName.isEmpty {
                if !isValidBranchName {
                    Label("Invalid branch name", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Create") {
                    createBranch()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!canCreate)
            }
        }
        .padding()
        .frame(width: 350)
    }

    private var isValidBranchName: Bool {
        guard !branchName.isEmpty else { return false }

        // Basic Git branch name validation
        let invalidPatterns = [
            "..",        // No consecutive dots
            "~", "^",    // No special characters
            ":", "?",
            "*", "[",
            "\\",
            " ",         // No spaces
            "@{",        // No reflog syntax
        ]

        for pattern in invalidPatterns {
            if branchName.contains(pattern) {
                return false
            }
        }

        // Cannot start or end with dot or slash
        if branchName.hasPrefix(".") || branchName.hasSuffix(".") ||
           branchName.hasPrefix("/") || branchName.hasSuffix("/") {
            return false
        }

        // Cannot end with .lock
        if branchName.hasSuffix(".lock") {
            return false
        }

        return true
    }

    private var canCreate: Bool {
        isValidBranchName && !viewModel.isOperationInProgress
    }

    private func createBranch() {
        Task {
            await viewModel.createBranch(
                name: branchName,
                startPoint: useStartPoint && !startPoint.isEmpty ? startPoint : nil
            )

            if viewModel.error == nil {
                isPresented = false
            }
        }
    }
}

#Preview {
    BranchCreationSheet(
        viewModel: BranchViewModel(
            repository: Repository(rootURL: URL(fileURLWithPath: "/tmp")),
            gitService: GitService()
        ),
        isPresented: .constant(true)
    )
}
