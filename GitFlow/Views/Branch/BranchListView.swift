import SwiftUI

/// View displaying all branches.
struct BranchListView: View {
    @ObservedObject var viewModel: BranchViewModel

    @State private var showCreateBranch: Bool = false
    @State private var branchToDelete: Branch?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Branches")
                    .font(.headline)

                Spacer()

                Toggle("Remote", isOn: $viewModel.showRemoteBranches)
                    .toggleStyle(.checkbox)
                    .controlSize(.small)

                Button(action: { showCreateBranch = true }) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                .help("Create new branch")

                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.6)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            // Branch list
            if viewModel.displayBranches.isEmpty && !viewModel.isLoading {
                EmptyStateView(
                    "No Branches",
                    systemImage: "arrow.triangle.branch",
                    description: "No branches found in this repository"
                )
            } else {
                List(selection: $viewModel.selectedBranch) {
                    // Local branches
                    Section("Local") {
                        ForEach(viewModel.localBranches) { branch in
                            BranchRow(branch: branch)
                                .tag(branch)
                                .contextMenu {
                                    if !branch.isCurrent {
                                        Button("Checkout") {
                                            Task { await viewModel.checkout(branch: branch) }
                                        }
                                        Divider()
                                        Button("Delete", role: .destructive) {
                                            branchToDelete = branch
                                        }
                                    }
                                }
                        }
                    }

                    // Remote branches
                    if viewModel.showRemoteBranches && !viewModel.remoteBranches.isEmpty {
                        Section("Remote") {
                            ForEach(viewModel.remoteBranches) { branch in
                                BranchRow(branch: branch)
                                    .tag(branch)
                                    .contextMenu {
                                        Button("Checkout") {
                                            Task { await viewModel.checkout(branchName: branch.name) }
                                        }
                                    }
                            }
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
        .sheet(isPresented: $showCreateBranch) {
            BranchCreationSheet(viewModel: viewModel, isPresented: $showCreateBranch)
        }
        .confirmationDialog(
            "Delete Branch",
            isPresented: .init(
                get: { branchToDelete != nil },
                set: { if !$0 { branchToDelete = nil } }
            ),
            presenting: branchToDelete
        ) { branch in
            Button("Delete", role: .destructive) {
                Task { await viewModel.deleteBranch(name: branch.name) }
            }
            Button("Cancel", role: .cancel) { }
        } message: { branch in
            Text("Are you sure you want to delete the branch '\(branch.name)'?")
        }
        .alert("Something went wrong", isPresented: .init(
            get: { viewModel.error != nil },
            set: { if !$0 { viewModel.error = nil } }
        )) {
            Button("Dismiss") { viewModel.error = nil }
        } message: {
            if let error = viewModel.error {
                Text(error.localizedDescription)
            }
        }
    }
}

#Preview {
    BranchListView(
        viewModel: BranchViewModel(
            repository: Repository(rootURL: URL(fileURLWithPath: "/tmp")),
            gitService: GitService()
        )
    )
    .frame(width: 300, height: 400)
}
