import SwiftUI

/// Row displaying a single branch.
struct BranchRow: View {
    let branch: Branch

    var body: some View {
        HStack(spacing: 8) {
            // Current branch indicator
            Image(systemName: branch.isCurrent ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(branch.isCurrent ? .green : .secondary)
                .font(.caption)

            // Branch icon
            Image(systemName: branch.isRemote ? "cloud" : "arrow.triangle.branch")
                .foregroundStyle(.secondary)
                .font(.caption)

            // Branch name
            VStack(alignment: .leading, spacing: 2) {
                Text(branch.name)
                    .fontWeight(branch.isCurrent ? .semibold : .regular)

                // Upstream info
                if let upstream = branch.upstream {
                    Text("→ \(upstream)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Ahead/behind indicators
            if branch.ahead > 0 || branch.behind > 0 {
                HStack(spacing: 4) {
                    if branch.ahead > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "arrow.up")
                            Text("\(branch.ahead)")
                        }
                        .foregroundStyle(.green)
                    }
                    if branch.behind > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "arrow.down")
                            Text("\(branch.behind)")
                        }
                        .foregroundStyle(.orange)
                    }
                }
                .font(.caption2)
            }

            // Commit hash
            Text(String(branch.commitHash.prefix(7)))
                .font(.caption)
                .fontDesign(.monospaced)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

/// Compact branch row for inline display.
struct CompactBranchRow: View {
    let branch: Branch

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: branch.isCurrent ? "checkmark.circle.fill" : "arrow.triangle.branch")
                .font(.caption)
                .foregroundStyle(branch.isCurrent ? .green : .secondary)

            Text(branch.name)
                .lineLimit(1)

            if branch.ahead > 0 {
                Text("↑\(branch.ahead)")
                    .font(.caption2)
                    .foregroundStyle(.green)
            }
            if branch.behind > 0 {
                Text("↓\(branch.behind)")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
    }
}

#Preview {
    VStack {
        BranchRow(branch: Branch.local(
            name: "main",
            commitHash: "abc123def456",
            isCurrent: true,
            upstream: "origin/main",
            ahead: 2,
            behind: 1
        ))

        BranchRow(branch: Branch.local(
            name: "feature/new-ui",
            commitHash: "def456abc789",
            isCurrent: false
        ))

        BranchRow(branch: Branch.remote(
            name: "main",
            remoteName: "origin",
            commitHash: "abc123def456"
        ))
    }
    .padding()
}
