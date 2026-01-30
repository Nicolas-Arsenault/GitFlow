import SwiftUI

/// Combined view for commit detail, file tree, and diff content.
/// Used in the History section when a commit is selected.
struct CommitDiffContentView: View {
    let commit: Commit
    @ObservedObject var diffViewModel: DiffViewModel
    @Binding var selectedFileDiff: FileDiff?
    let onBack: () -> Void

    @State private var isFileListExpanded: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            StackNavigationHeader(
                title: commit.subject,
                subtitle: String(commit.hash.prefix(8)),
                onBack: onBack
            )

            Divider()

            // Commit details
            CommitDetailView(commit: commit)
                .frame(height: 120)

            // Commit analysis summary
            if !diffViewModel.allDiffs.isEmpty {
                CommitSummaryView(
                    analysis: CommitAnalyzer.analyze(
                        diffs: diffViewModel.allDiffs,
                        message: commit.subject
                    ),
                    commit: commit
                )
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }

            Divider()

            // File list header (clickable to expand/collapse)
            HStack {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isFileListExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isFileListExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 12)

                        Text("Files")
                            .font(.headline)

                        Text("(\(diffViewModel.filteredDiffs.count))")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if diffViewModel.hasHiddenFiles {
                            Text("• \(diffViewModel.hiddenFileCount) hidden")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))

            // File tree (collapsible)
            if isFileListExpanded {
                Divider()

                DiffFileTreeView(
                    diffs: diffViewModel.allDiffs,
                    selectedDiff: $selectedFileDiff,
                    noiseOptions: diffViewModel.noiseOptions
                )
                .frame(maxHeight: 200)
            }

            Divider()

            // Diff content
            DiffView(viewModel: diffViewModel)
        }
        .onExitCommand { onBack() }
    }
}

#Preview {
    CommitDiffContentView(
        commit: Commit(
            hash: "abc123def456789",
            shortHash: "abc123d",
            subject: "Fix bug in authentication flow",
            body: "This commit fixes a critical bug...",
            authorName: "John Doe",
            authorEmail: "john@example.com",
            authorDate: Date(),
            committerName: "John Doe",
            committerEmail: "john@example.com",
            commitDate: Date(),
            parentHashes: ["parent123"]
        ),
        diffViewModel: DiffViewModel(
            repository: Repository(rootURL: URL(fileURLWithPath: "/tmp")),
            gitService: GitService()
        ),
        selectedFileDiff: .constant(nil),
        onBack: {}
    )
    .frame(width: 800, height: 600)
}
