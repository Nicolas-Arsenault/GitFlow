import SwiftUI

/// Overview of repository state.
struct RepositoryOverview: View {
    @ObservedObject var viewModel: RepositoryViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "folder.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading) {
                    Text(viewModel.repository.name)
                        .font(.headline)
                    Text(viewModel.repository.path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer()
            }

            Divider()

            // Branch info
            if let branch = viewModel.currentBranch {
                HStack {
                    Label(branch, systemImage: "arrow.triangle.branch")
                        .font(.subheadline)

                    if let syncStatus = viewModel.branchViewModel.syncStatus {
                        Text(syncStatus)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Status summary
            HStack(spacing: 16) {
                StatusBadge(
                    count: viewModel.statusViewModel.status.stagedFiles.count,
                    label: "Staged",
                    color: .green
                )
                StatusBadge(
                    count: viewModel.statusViewModel.status.unstagedFiles.count,
                    label: "Modified",
                    color: .orange
                )
                StatusBadge(
                    count: viewModel.statusViewModel.status.untrackedFiles.count,
                    label: "Untracked",
                    color: .gray
                )
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

/// Badge showing a count and label.
struct StatusBadge: View {
    let count: Int
    let label: String
    let color: Color

    var body: some View {
        VStack {
            Text("\(count)")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(count > 0 ? color : .secondary)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 60)
    }
}

#Preview {
    RepositoryOverview(
        viewModel: RepositoryViewModel(
            repository: Repository(rootURL: URL(fileURLWithPath: "/tmp/test-repo")),
            gitService: GitService()
        )
    )
    .frame(width: 400)
    .padding()
}
