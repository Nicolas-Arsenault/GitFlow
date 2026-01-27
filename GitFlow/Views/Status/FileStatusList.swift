import SwiftUI

/// List of files with their status.
/// Follows UX principle: No destructive action without confirmation.
struct FileStatusList: View {
    @ObservedObject var viewModel: StatusViewModel

    @State private var fileToDiscard: FileStatus?
    @State private var showDiscardAllConfirmation: Bool = false

    var body: some View {
        List(selection: $viewModel.selectedFile) {
            // Staged files
            if !viewModel.status.stagedFiles.isEmpty {
                Section {
                    ForEach(viewModel.status.stagedFiles) { file in
                        FileStatusRow(file: file, isStaged: true)
                            .tag(file)
                            .contextMenu {
                                Button {
                                    Task { await viewModel.unstageFiles([file.path]) }
                                } label: {
                                    Label("Unstage \(file.fileName)", systemImage: "minus.circle")
                                }
                            }
                    }
                } header: {
                    FileListSectionHeader(
                        title: "Staged Changes",
                        count: viewModel.status.stagedFiles.count,
                        actionLabel: "Unstage All"
                    ) {
                        Task { await viewModel.unstageAll() }
                    }
                }
            }

            // Unstaged files
            if !viewModel.status.unstagedFiles.isEmpty {
                Section {
                    ForEach(viewModel.status.unstagedFiles) { file in
                        FileStatusRow(file: file, isStaged: false)
                            .tag(file)
                            .contextMenu {
                                Button {
                                    Task { await viewModel.stageFiles([file.path]) }
                                } label: {
                                    Label("Stage \(file.fileName)", systemImage: "plus.circle")
                                }

                                Divider()

                                // Destructive action requires confirmation
                                Button(role: .destructive) {
                                    fileToDiscard = file
                                } label: {
                                    Label("Discard Changes...", systemImage: "trash")
                                }
                            }
                    }
                } header: {
                    FileListSectionHeader(
                        title: "Changes",
                        count: viewModel.status.unstagedFiles.count,
                        actionLabel: "Stage All"
                    ) {
                        Task { await viewModel.stageAll() }
                    }
                }
            }

            // Untracked files
            if !viewModel.status.untrackedFiles.isEmpty {
                Section {
                    ForEach(viewModel.status.untrackedFiles) { file in
                        FileStatusRow(file: file, isStaged: false)
                            .tag(file)
                            .contextMenu {
                                Button {
                                    Task { await viewModel.stageFiles([file.path]) }
                                } label: {
                                    Label("Stage \(file.fileName)", systemImage: "plus.circle")
                                }
                            }
                    }
                } header: {
                    FileListSectionHeader(
                        title: "Untracked Files",
                        count: viewModel.status.untrackedFiles.count,
                        actionLabel: "Stage All"
                    ) {
                        let paths = viewModel.status.untrackedFiles.map(\.path)
                        Task { await viewModel.stageFiles(paths) }
                    }
                }
            }

            // Conflicted files with calm warning
            if !viewModel.status.conflictedFiles.isEmpty {
                Section {
                    ForEach(viewModel.status.conflictedFiles) { file in
                        FileStatusRow(file: file, isStaged: false)
                            .tag(file)
                            .contextMenu {
                                Button {
                                    Task { await viewModel.stageFiles([file.path]) }
                                } label: {
                                    Label("Mark as Resolved", systemImage: "checkmark.circle")
                                }
                            }
                    }
                } header: {
                    HStack(spacing: DSSpacing.sm) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(DSColors.warning)
                        Text("Conflicts")
                            .font(DSTypography.tertiaryContent())
                        Text("(\(viewModel.status.conflictedFiles.count))")
                            .font(DSTypography.smallLabel())
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Empty state when no changes
            if viewModel.status.totalChangedFiles == 0 && !viewModel.isLoading {
                EmptyStateView(
                    "Working Tree Clean",
                    systemImage: "checkmark.circle",
                    description: "No changes to commit"
                )
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.inset)
        // Confirmation dialog for discarding single file
        .confirmationDialog(
            "Discard Changes",
            isPresented: .init(
                get: { fileToDiscard != nil },
                set: { if !$0 { fileToDiscard = nil } }
            ),
            titleVisibility: .visible,
            presenting: fileToDiscard
        ) { file in
            Button("Discard Changes to \(file.fileName)", role: .destructive) {
                Task { await viewModel.discardChanges([file.path]) }
            }
            Button("Cancel", role: .cancel) { }
        } message: { file in
            Text("This will permanently discard all changes to '\(file.fileName)'. This cannot be undone.")
        }
    }
}

// MARK: - Section Header

/// Reusable section header with count and action button.
private struct FileListSectionHeader: View {
    let title: String
    let count: Int
    let actionLabel: String
    let action: () -> Void

    var body: some View {
        HStack {
            Text(title)
                .font(DSTypography.tertiaryContent())

            Text("(\(count))")
                .font(DSTypography.smallLabel())
                .foregroundStyle(.secondary)

            Spacer()

            Button(actionLabel) {
                action()
            }
            .buttonStyle(.plain)
            .font(DSTypography.tertiaryContent())
            .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    FileStatusList(
        viewModel: StatusViewModel(
            repository: Repository(rootURL: URL(fileURLWithPath: "/tmp")),
            gitService: GitService()
        )
    )
}
