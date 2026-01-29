import SwiftUI

/// View for displaying and adding comments on a pull request.
struct PRCommentView: View {
    @ObservedObject var viewModel: GitHubViewModel
    let pullRequest: GitHubPullRequest

    @State private var comments: [GitHubComment] = []
    @State private var newCommentText: String = ""
    @State private var isLoading: Bool = false
    @State private var isSubmitting: Bool = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Comments")
                    .font(.headline)

                Spacer()

                if isLoading {
                    ProgressView()
                        .scaleEffect(0.6)
                }

                Button {
                    Task { await loadComments() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Refresh comments")
                .disabled(isLoading)
            }
            .padding()

            Divider()

            // Comments list
            if comments.isEmpty && !isLoading {
                VStack(spacing: DSSpacing.md) {
                    Image(systemName: "text.bubble")
                        .font(.largeTitle)
                        .foregroundStyle(.tertiary)
                    Text("No comments yet")
                        .foregroundStyle(.secondary)
                }
                .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: DSSpacing.md) {
                        ForEach(comments) { comment in
                            CommentRow(comment: comment)
                        }
                    }
                    .padding()
                }
            }

            Divider()

            // New comment input
            VStack(spacing: DSSpacing.sm) {
                TextEditor(text: $newCommentText)
                    .font(.body)
                    .frame(height: 80)
                    .padding(4)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(DSRadius.sm)
                    .overlay(
                        RoundedRectangle(cornerRadius: DSRadius.sm)
                            .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                    )
                    .overlay(alignment: .topLeading) {
                        if newCommentText.isEmpty {
                            Text("Leave a comment...")
                                .foregroundStyle(.tertiary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 8)
                                .allowsHitTesting(false)
                        }
                    }

                HStack {
                    if let error = error {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    Spacer()

                    Button("Comment") {
                        Task { await submitComment() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
                }
            }
            .padding()
        }
        .task {
            await loadComments()
        }
    }

    private func loadComments() async {
        guard let info = viewModel.remoteInfo else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            comments = try await viewModel.githubService.getComments(
                owner: info.owner,
                repo: info.repo,
                pullNumber: pullRequest.number
            )
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func submitComment() async {
        guard let info = viewModel.remoteInfo else { return }

        let text = newCommentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        isSubmitting = true
        error = nil

        do {
            let comment = try await viewModel.githubService.addComment(
                owner: info.owner,
                repo: info.repo,
                issueNumber: pullRequest.number,
                body: text
            )
            comments.append(comment)
            newCommentText = ""
        } catch {
            self.error = error.localizedDescription
        }

        isSubmitting = false
    }
}

/// Row displaying a single comment.
struct CommentRow: View {
    let comment: GitHubComment

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            HStack(spacing: DSSpacing.sm) {
                // Avatar
                AsyncImage(url: URL(string: comment.user.avatarUrl)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                }
                .frame(width: 24, height: 24)
                .clipShape(Circle())

                Text(comment.user.login)
                    .fontWeight(.medium)

                Text(comment.createdAt.formatted(.relative(presentation: .named)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(comment.body)
                .textSelection(.enabled)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(DSRadius.md)
    }
}

#Preview {
    PRCommentView(
        viewModel: GitHubViewModel(
            repository: Repository(rootURL: URL(fileURLWithPath: "/tmp")),
            gitService: GitService()
        ),
        pullRequest: GitHubPullRequest(
            id: 1,
            number: 123,
            title: "Test PR",
            body: nil,
            state: "open",
            htmlUrl: "https://github.com",
            user: GitHubUser(id: 1, login: "test", avatarUrl: "", htmlUrl: "", type: "User"),
            labels: [],
            assignees: [],
            createdAt: Date(),
            updatedAt: Date(),
            closedAt: nil,
            mergedAt: nil,
            head: GitHubBranchRef(ref: "feature", sha: "abc", repo: nil),
            base: GitHubBranchRef(ref: "main", sha: "def", repo: nil),
            isDraft: false,
            mergeable: true,
            additions: nil,
            deletions: nil,
            changedFiles: nil
        )
    )
    .frame(width: 400, height: 500)
}
