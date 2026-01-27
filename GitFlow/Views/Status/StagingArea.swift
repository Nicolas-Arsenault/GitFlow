import SwiftUI

/// View for staging area with stage/unstage controls.
struct StagingArea: View {
    @ObservedObject var viewModel: StatusViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Staging toolbar
            HStack {
                Text("Staging")
                    .font(.headline)

                Spacer()

                Menu {
                    Button("Stage All") {
                        Task { await viewModel.stageAll() }
                    }
                    Button("Unstage All") {
                        Task { await viewModel.unstageAll() }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            // Split view for staged/unstaged
            HSplitView {
                // Unstaged section
                VStack(alignment: .leading, spacing: 0) {
                    SectionHeader(
                        title: "Changes",
                        count: viewModel.stagingCandidates.count,
                        action: {
                            Task { await viewModel.stageAll() }
                        },
                        actionLabel: "Stage All"
                    )

                    List(viewModel.stagingCandidates, selection: $viewModel.selectedFile) { file in
                        FileStatusRow(file: file, isStaged: false)
                            .tag(file)
                    }
                    .listStyle(.plain)
                }

                // Staged section
                VStack(alignment: .leading, spacing: 0) {
                    SectionHeader(
                        title: "Staged",
                        count: viewModel.status.stagedFiles.count,
                        action: {
                            Task { await viewModel.unstageAll() }
                        },
                        actionLabel: "Unstage All"
                    )

                    List(viewModel.status.stagedFiles, selection: $viewModel.selectedFile) { file in
                        FileStatusRow(file: file, isStaged: true)
                            .tag(file)
                    }
                    .listStyle(.plain)
                }
            }
        }
    }
}

/// Section header with count and action button.
struct SectionHeader: View {
    let title: String
    let count: Int
    let action: () -> Void
    let actionLabel: String

    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)

            Text("(\(count))")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            if count > 0 {
                Button(action: action) {
                    Text(actionLabel)
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(Color(NSColor.controlBackgroundColor))
    }
}

#Preview {
    StagingArea(
        viewModel: StatusViewModel(
            repository: Repository(rootURL: URL(fileURLWithPath: "/tmp")),
            gitService: GitService()
        )
    )
}
