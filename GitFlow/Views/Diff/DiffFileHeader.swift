import SwiftUI

/// Header showing the current diff file information.
struct DiffFileHeader: View {
    @ObservedObject var viewModel: DiffViewModel

    var body: some View {
        HStack(spacing: 8) {
            if let diff = viewModel.currentDiff {
                // Change type icon
                ChangeTypeIcon(changeType: diff.changeType)

                // File name
                VStack(alignment: .leading, spacing: 0) {
                    Text(diff.fileName)
                        .font(.headline)
                        .lineLimit(1)

                    if !diff.directory.isEmpty {
                        Text(diff.directory)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }

                // Renamed indicator
                if let oldPath = diff.oldPath {
                    Image(systemName: "arrow.left")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(oldPath)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }
}

/// Compact file header for multi-file diffs.
struct CompactDiffFileHeader: View {
    let diff: FileDiff
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 6) {
            ChangeTypeIcon(changeType: diff.changeType)

            Text(diff.fileName)
                .lineLimit(1)

            Spacer()

            HStack(spacing: 4) {
                Text("+\(diff.additions)")
                    .foregroundStyle(.green)
                Text("-\(diff.deletions)")
                    .foregroundStyle(.red)
            }
            .font(.caption2)
            .fontDesign(.monospaced)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 8) {
        CompactDiffFileHeader(
            diff: FileDiff(
                path: "src/components/Button.swift",
                changeType: .modified,
                hunks: []
            ),
            isSelected: true
        )
        CompactDiffFileHeader(
            diff: FileDiff(
                path: "README.md",
                changeType: .added,
                hunks: []
            ),
            isSelected: false
        )
    }
    .padding()
}
