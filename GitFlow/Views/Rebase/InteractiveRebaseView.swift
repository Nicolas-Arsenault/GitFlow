import SwiftUI

/// Main view for interactive rebase editing.
struct InteractiveRebaseView: View {
    @ObservedObject var viewModel: InteractiveRebaseViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            InteractiveRebaseHeader(viewModel: viewModel, onCancel: { dismiss() })

            Divider()

            // Content
            if viewModel.isLoading {
                ProgressView("Loading commits...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.entries.isEmpty {
                EmptyStateView(
                    "No Commits",
                    systemImage: "arrow.triangle.branch",
                    description: "No commits to rebase onto \(viewModel.ontoBranch)"
                )
            } else {
                VStack(spacing: 0) {
                    // Commit list
                    List {
                        ForEach(viewModel.entries) { entry in
                            RebaseEntryRow(
                                entry: entry,
                                onActionChanged: { action in
                                    viewModel.setAction(action, for: entry)
                                },
                                onMoveUp: {
                                    viewModel.moveUp(entry)
                                },
                                onMoveDown: {
                                    viewModel.moveDown(entry)
                                },
                                canMoveUp: viewModel.entries.first?.id != entry.id,
                                canMoveDown: viewModel.entries.last?.id != entry.id
                            )
                        }
                        .onMove { source, destination in
                            viewModel.moveEntries(from: source, to: destination)
                        }
                    }
                    .listStyle(.inset)

                    Divider()

                    // Footer with summary and actions
                    InteractiveRebaseFooter(viewModel: viewModel, onStart: {
                        Task {
                            await viewModel.startRebase()
                            if viewModel.state == .completed {
                                dismiss()
                            }
                        }
                    })
                }
            }
        }
        .frame(minWidth: 600, minHeight: 400)
        .sheet(isPresented: $viewModel.showRewordSheet) {
            RewordMessageSheet(
                message: $viewModel.rewordMessage,
                originalMessage: viewModel.selectedEntry?.message ?? "",
                onApply: {
                    viewModel.applyRewordMessage()
                },
                onCancel: {
                    viewModel.showRewordSheet = false
                }
            )
        }
        .alert("Rebase Error", isPresented: .init(
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

// MARK: - Header

private struct InteractiveRebaseHeader: View {
    @ObservedObject var viewModel: InteractiveRebaseViewModel
    let onCancel: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Interactive Rebase")
                    .font(.headline)

                if !viewModel.ontoBranch.isEmpty {
                    Text("Rebasing onto \(viewModel.ontoBranch)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Reset button
            Button("Reset") {
                viewModel.resetAll()
            }
            .disabled(!viewModel.hasChanges)

            // Cancel button
            Button("Cancel", action: onCancel)
        }
        .padding()
    }
}

// MARK: - Entry Row

private struct RebaseEntryRow: View {
    let entry: RebaseEntry
    let onActionChanged: (RebaseAction) -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let canMoveUp: Bool
    let canMoveDown: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Reorder buttons
            VStack(spacing: 2) {
                Button(action: onMoveUp) {
                    Image(systemName: "chevron.up")
                        .font(.caption2)
                }
                .buttonStyle(.plain)
                .help("Move up")
                .disabled(!canMoveUp)

                Button(action: onMoveDown) {
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                }
                .buttonStyle(.plain)
                .help("Move down")
                .disabled(!canMoveDown)
            }
            .foregroundStyle(.secondary)

            // Action picker
            Menu {
                ForEach(RebaseAction.allCases) { action in
                    Button {
                        onActionChanged(action)
                    } label: {
                        Label {
                            VStack(alignment: .leading) {
                                Text(action.displayName)
                                Text(action.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: action.iconName)
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: entry.action.iconName)
                    Text(entry.action.displayName)
                        .font(.caption)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(actionColor.opacity(0.1))
                .foregroundStyle(actionColor)
                .cornerRadius(4)
            }
            .menuStyle(.borderlessButton)
            .frame(width: 90)

            // Commit hash
            Text(entry.shortHash)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)

            // Message
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.newMessage ?? entry.message)
                    .lineLimit(1)

                if let author = entry.author {
                    Text(author)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Modified indicator
            if entry.isModified {
                Image(systemName: "pencil.circle.fill")
                    .foregroundStyle(.blue)
                    .font(.caption)
            }
        }
        .padding(.vertical, 4)
        .opacity(entry.action == .drop ? 0.5 : 1.0)
        .strikethrough(entry.action == .drop)
    }

    private var actionColor: Color {
        switch entry.action {
        case .pick: return .green
        case .reword: return .blue
        case .edit: return .orange
        case .squash: return .purple
        case .fixup: return .purple
        case .drop: return .red
        }
    }
}

// MARK: - Footer

private struct InteractiveRebaseFooter: View {
    @ObservedObject var viewModel: InteractiveRebaseViewModel
    let onStart: () -> Void

    var body: some View {
        HStack {
            // Summary
            VStack(alignment: .leading, spacing: 2) {
                Text("\(viewModel.entries.count) commits")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(viewModel.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Quick actions
            Menu {
                Button("Squash All") {
                    for entry in viewModel.entries.dropFirst() {
                        viewModel.setAction(.squash, for: entry)
                    }
                }

                Button("Drop All") {
                    for entry in viewModel.entries {
                        viewModel.setAction(.drop, for: entry)
                    }
                }

                Button("Reset All") {
                    viewModel.resetAll()
                }
            } label: {
                Label("Quick Actions", systemImage: "bolt.circle")
            }
            .menuStyle(.borderlessButton)

            // Start rebase button
            Button("Start Rebase") {
                onStart()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.canStartRebase)
        }
        .padding()
    }
}

// MARK: - Reword Sheet

private struct RewordMessageSheet: View {
    @Binding var message: String
    let originalMessage: String
    let onApply: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Edit Commit Message")
                    .font(.headline)
                Spacer()
                Button(action: onCancel) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // Original message
            VStack(alignment: .leading, spacing: 4) {
                Text("Original message:")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(originalMessage)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(4)
            }
            .padding()

            // New message
            VStack(alignment: .leading, spacing: 4) {
                Text("New message:")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextEditor(text: $message)
                    .font(.body.monospaced())
                    .frame(minHeight: 100)
                    .border(Color.secondary.opacity(0.3))
            }
            .padding(.horizontal)

            Divider()

            // Actions
            HStack {
                Spacer()

                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)

                Button("Apply") {
                    onApply()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(message.isEmpty)
            }
            .padding()
        }
        .frame(width: 500)
    }
}

// MARK: - Rebase In Progress View

/// View shown when a rebase is in progress.
struct RebaseInProgressView: View {
    @ObservedObject var viewModel: InteractiveRebaseViewModel

    var body: some View {
        VStack(spacing: 16) {
            switch viewModel.state {
            case .idle:
                EmptyView()

            case .preparing:
                ProgressView("Preparing rebase...")

            case .inProgress(let current, let total):
                VStack(spacing: 8) {
                    ProgressView(value: Double(current), total: Double(total))
                        .progressViewStyle(.linear)

                    Text("Processing commit \(current) of \(total)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

            case .paused(let reason):
                VStack(spacing: 12) {
                    Image(systemName: "pause.circle.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.orange)

                    switch reason {
                    case .edit(let hash):
                        Text("Stopped for editing commit \(String(hash.prefix(7)))")
                    case .reword(let hash):
                        Text("Edit message for commit \(String(hash.prefix(7)))")
                    case .conflict:
                        Text("Conflicts detected")
                    }

                    HStack(spacing: 12) {
                        Button("Abort") {
                            Task { await viewModel.abortRebase() }
                        }
                        .buttonStyle(.bordered)

                        Button("Skip") {
                            Task { await viewModel.skipCommit() }
                        }
                        .buttonStyle(.bordered)

                        Button("Continue") {
                            Task { await viewModel.continueRebase() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }

            case .completed:
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.green)

                    Text("Rebase completed successfully!")
                }

            case .failed(let error):
                VStack(spacing: 8) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.red)

                    Text("Rebase failed")
                        .font(.headline)

                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button("Abort Rebase") {
                        Task { await viewModel.abortRebase() }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preview

#Preview {
    InteractiveRebaseView(
        viewModel: InteractiveRebaseViewModel(
            repository: Repository(rootURL: URL(fileURLWithPath: "/tmp")),
            gitService: GitService()
        )
    )
}
