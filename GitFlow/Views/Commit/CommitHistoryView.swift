import SwiftUI

/// View displaying commit history as a list.
struct CommitHistoryView: View {
    @ObservedObject var viewModel: HistoryViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("History")
                    .font(.headline)

                Spacer()

                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.6)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            // Commit list
            if viewModel.commits.isEmpty && !viewModel.isLoading {
                EmptyStateView(
                    "No Commits",
                    systemImage: "clock",
                    description: "This repository has no commits yet"
                )
            } else {
                List(viewModel.commits, selection: $viewModel.selectedCommit) { commit in
                    CommitRow(commit: commit)
                        .tag(commit)
                }
                .listStyle(.plain)
            }
        }
    }
}

#Preview {
    CommitHistoryView(
        viewModel: HistoryViewModel(
            repository: Repository(rootURL: URL(fileURLWithPath: "/tmp")),
            gitService: GitService()
        )
    )
    .frame(width: 350, height: 400)
}
