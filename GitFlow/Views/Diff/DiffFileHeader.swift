import SwiftUI

/// Header showing the current diff file information.
struct DiffFileHeader: View {
    @ObservedObject var viewModel: DiffViewModel

    var body: some View {
        HStack(spacing: 8) {
            if let diff = viewModel.currentDiff {
                // Change type icon
                ChangeTypeIcon(changeType: diff.changeType)
                    .fixedSize()

                // File name (truncates to fit available space)
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 6) {
                        Text(diff.fileName)
                            .font(.headline)
                            .lineLimit(1)
                            .truncationMode(.middle)

                        // Similarity badge for renames
                        if diff.changeType == .renamed || diff.changeType == .copied {
                            SimilarityBadge(diff: diff)
                                .fixedSize()
                        }

                        // Generated file badge
                        if diff.isGeneratedFile {
                            Text("Generated")
                                .font(.caption2)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.secondary.opacity(0.2))
                                .foregroundStyle(.secondary)
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                                .fixedSize()
                        }
                    }

                    // Directory path
                    if !diff.directory.isEmpty {
                        Text(diff.directory)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                .frame(maxWidth: 250, alignment: .leading)
            }
        }
    }
}

/// Badge showing similarity percentage for renamed/copied files.
struct SimilarityBadge: View {
    let diff: FileDiff

    var body: some View {
        if let similarity = diff.similarityPercentage {
            HStack(spacing: 2) {
                if diff.isPureRename || diff.isPureCopy {
                    Image(systemName: "equal")
                        .font(.system(size: 8, weight: .bold))
                }
                Text("\(similarity)%")
            }
            .font(.caption2)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(badgeColor.opacity(0.15))
            .foregroundStyle(badgeColor)
            .clipShape(RoundedRectangle(cornerRadius: 3))
            .help(helpText)
        }
    }

    private var badgeColor: Color {
        guard let similarity = diff.similarityPercentage else { return .secondary }
        if similarity == 100 {
            return .green
        } else if similarity >= 90 {
            return .blue
        } else if similarity >= 70 {
            return .orange
        } else {
            return .red
        }
    }

    private var helpText: String {
        let type = diff.changeType == .copied ? "Copy" : "Rename"
        if diff.isPureRename || diff.isPureCopy {
            return "Pure \(type.lowercased()) - no content changes"
        } else if let similarity = diff.similarityPercentage {
            return "\(type) with \(100 - similarity)% content changes"
        }
        return type
    }
}

/// Compact file header for multi-file diffs.
struct CompactDiffFileHeader: View {
    let diff: FileDiff
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 6) {
            ChangeTypeIcon(changeType: diff.changeType)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(diff.fileName)
                        .lineLimit(1)

                    // Similarity badge for renames/copies
                    if (diff.changeType == .renamed || diff.changeType == .copied),
                       let similarity = diff.similarityPercentage {
                        Text("\(similarity)%")
                            .font(.caption2)
                            .foregroundStyle(similarity == 100 ? .green : .orange)
                    }

                    // Generated indicator
                    if diff.isGeneratedFile {
                        Image(systemName: "gearshape")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                // Show old path for renames
                if let oldPath = diff.oldPath {
                    Text("← \((oldPath as NSString).lastPathComponent)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Stats
            if diff.additions > 0 || diff.deletions > 0 {
                HStack(spacing: 4) {
                    if diff.additions > 0 {
                        Text("+\(diff.additions)")
                            .foregroundStyle(.green)
                    }
                    if diff.deletions > 0 {
                        Text("-\(diff.deletions)")
                            .foregroundStyle(.red)
                    }
                }
                .font(.caption2)
                .fontDesign(.monospaced)
            } else if diff.isPureRename || diff.isPureCopy {
                Text("no changes")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
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
