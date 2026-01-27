import SwiftUI

/// Row displaying a single commit in the history list.
struct CommitRow: View {
    let commit: Commit

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Subject line
            Text(commit.subject)
                .fontWeight(.medium)
                .lineLimit(1)

            // Metadata
            HStack(spacing: 8) {
                // Hash
                Text(commit.shortHash)
                    .font(.caption)
                    .fontDesign(.monospaced)
                    .foregroundStyle(.secondary)

                // Author
                Text(commit.authorName)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                // Date
                Text(commit.authorDate.formatted(.relative(presentation: .named)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Merge indicator
            if commit.isMerge {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.merge")
                        .font(.caption2)
                    Text("Merge commit")
                        .font(.caption2)
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

/// Compact commit row for inline display.
struct CompactCommitRow: View {
    let commit: Commit

    var body: some View {
        HStack(spacing: 8) {
            Text(commit.shortHash)
                .font(.caption)
                .fontDesign(.monospaced)
                .foregroundStyle(.secondary)

            Text(commit.subject)
                .lineLimit(1)

            Spacer()

            Text(commit.authorDate.formatted(.relative(presentation: .named)))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    VStack {
        CommitRow(commit: Commit(
            hash: "abc123def456789012345678901234567890abcd",
            subject: "Add new feature for user authentication",
            authorName: "John Doe",
            authorEmail: "john@example.com",
            authorDate: Date().addingTimeInterval(-3600)
        ))

        Divider()

        CommitRow(commit: Commit(
            hash: "def456abc789012345678901234567890abcdef12",
            subject: "Merge branch 'feature' into main",
            authorName: "Jane Smith",
            authorEmail: "jane@example.com",
            authorDate: Date().addingTimeInterval(-86400),
            parentHashes: ["abc123", "def456"]
        ))
    }
    .padding()
}
