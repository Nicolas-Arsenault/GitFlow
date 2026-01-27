import SwiftUI

/// View for creating a new commit.
struct CommitCreationView: View {
    @ObservedObject var viewModel: CommitViewModel
    let canCommit: Bool

    @FocusState private var isMessageFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Text("Commit")
                    .font(.headline)

                Spacer()

                // Character count
                Text(viewModel.subjectLengthIndicator)
                    .font(.caption)
                    .foregroundStyle(subjectLengthColor)
            }
            .padding(.horizontal)
            .padding(.top, 8)

            // Message input
            TextEditor(text: $viewModel.commitMessage)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 80, maxHeight: 150)
                .focused($isMessageFocused)
                .scrollContentBackground(.hidden)
                .padding(4)
                .background(Color(NSColor.textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(alignment: .topLeading) {
                    if viewModel.commitMessage.isEmpty {
                        Text("Enter commit message...")
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.tertiary)
                            .padding(.leading, 5)
                            .padding(.top, 8)
                            .allowsHitTesting(false)
                    }
                }
                .padding(.horizontal)

            // Guidelines
            if !viewModel.commitMessage.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    if viewModel.isSubjectTooLong {
                        Label(
                            viewModel.isSubjectWayTooLong
                                ? "Subject should be under 72 characters"
                                : "Subject ideally under 50 characters",
                            systemImage: "exclamationmark.triangle"
                        )
                        .font(.caption2)
                        .foregroundStyle(viewModel.isSubjectWayTooLong ? .red : .orange)
                    }
                }
                .padding(.horizontal)
            }

            // Actions
            HStack {
                Button("Clear Message") {
                    viewModel.clearMessage()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .disabled(viewModel.commitMessage.isEmpty)

                Spacer()

                Button(action: {
                    Task {
                        await viewModel.createCommit()
                    }
                }) {
                    if viewModel.isCommitting {
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(width: 60)
                    } else {
                        Text("Commit")
                            .frame(width: 60)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canCommit || !viewModel.isMessageValid || viewModel.isCommitting)
                .keyboardShortcut(.return, modifiers: .command)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .background(Color(NSColor.controlBackgroundColor))
        .alert("Commit failed", isPresented: .init(
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

    private var subjectLengthColor: Color {
        if viewModel.isSubjectWayTooLong {
            return .red
        } else if viewModel.isSubjectTooLong {
            return .orange
        }
        return .secondary
    }
}

#Preview {
    VStack {
        Spacer()
        CommitCreationView(
            viewModel: CommitViewModel(
                repository: Repository(rootURL: URL(fileURLWithPath: "/tmp")),
                gitService: GitService()
            ),
            canCommit: true
        )
    }
    .frame(width: 300, height: 300)
}
