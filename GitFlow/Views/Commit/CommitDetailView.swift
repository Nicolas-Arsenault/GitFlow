import SwiftUI

/// Detailed view of a single commit.
struct CommitDetailView: View {
    let commit: Commit

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(commit.subject)
                        .font(.headline)

                    if !commit.body.isEmpty {
                        Text(commit.body)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    }
                }

                Spacer()

                // Copy hash button
                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(commit.hash, forType: .string)
                }) {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.borderless)
                .help("Copy commit hash")
            }

            Divider()

            // Metadata grid
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                GridRow {
                    Text("Commit")
                        .foregroundStyle(.secondary)
                    Text(commit.hash)
                        .fontDesign(.monospaced)
                        .textSelection(.enabled)
                }

                GridRow {
                    Text("Author")
                        .foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        AvatarView(
                            name: commit.authorName,
                            email: commit.authorEmail,
                            size: 20
                        )
                        Text(commit.authorName)
                        Text("<\(commit.authorEmail)>")
                            .foregroundStyle(.secondary)
                    }
                }

                GridRow {
                    Text("Date")
                        .foregroundStyle(.secondary)
                    Text(commit.authorDate.formatted(date: .long, time: .shortened))
                }

                if commit.isMerge {
                    GridRow {
                        Text("Parents")
                            .foregroundStyle(.secondary)
                        HStack {
                            ForEach(commit.parentHashes, id: \.self) { hash in
                                Text(String(hash.prefix(7)))
                                    .fontDesign(.monospaced)
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }
            }
            .font(.caption)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }
}

#Preview {
    CommitDetailView(commit: Commit(
        hash: "abc123def456789012345678901234567890abcd",
        subject: "Add new feature for user authentication",
        body: "This commit adds OAuth2 support for user authentication.\n\nFeatures:\n- Token refresh\n- Secure storage",
        authorName: "John Doe",
        authorEmail: "john@example.com",
        authorDate: Date().addingTimeInterval(-3600),
        parentHashes: ["parent1abc", "parent2def"]
    ))
    .frame(width: 500)
}
