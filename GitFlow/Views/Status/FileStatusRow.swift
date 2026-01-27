import SwiftUI

/// Row displaying a single file's status.
/// Follows UX principle: Color supports meaning, never replaces it.
struct FileStatusRow: View {
    let file: FileStatus
    let isStaged: Bool

    var body: some View {
        HStack(spacing: DSSpacing.iconTextSpacing) {
            // Change type indicator with icon (not just color)
            ChangeTypeIcon(changeType: file.displayChangeType)

            // File info
            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                Text(file.fileName)
                    .font(DSTypography.primaryContent())
                    .fontWeight(.medium)
                    .lineLimit(1)

                if !file.directory.isEmpty {
                    Text(file.directory)
                        .font(DSTypography.tertiaryContent())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Spacer()

            // Status badge
            StatusIndicator(file: file, isStaged: isStaged)
        }
        .padding(.vertical, DSSpacing.xs)
        .contentShape(Rectangle())
    }
}

/// Icon representing the type of change.
/// Uses both icon AND color for accessibility (never color alone).
struct ChangeTypeIcon: View {
    let changeType: FileChangeType

    var body: some View {
        Image(systemName: symbolName)
            .font(.system(size: 14))
            .foregroundStyle(color)
            .frame(width: 20)
            .help(changeType.description)
    }

    private var symbolName: String {
        switch changeType {
        case .added:
            return "plus.circle.fill"
        case .modified:
            return "pencil.circle.fill"
        case .deleted:
            return "minus.circle.fill"
        case .renamed:
            return "arrow.right.circle.fill"
        case .copied:
            return "doc.on.doc.fill"
        case .unmerged:
            return "exclamationmark.triangle.fill"
        case .typeChanged:
            return "arrow.triangle.2.circlepath.circle.fill"
        case .untracked:
            return "questionmark.circle"
        case .ignored:
            return "eye.slash.circle"
        }
    }

    private var color: Color {
        switch changeType {
        case .added:
            return DSColors.addition
        case .modified:
            return DSColors.modification
        case .deleted:
            return DSColors.deletion
        case .renamed:
            return DSColors.rename
        case .copied:
            return DSColors.info
        case .unmerged:
            return DSColors.warning
        case .typeChanged:
            return DSColors.warning
        case .untracked:
            return .secondary
        case .ignored:
            return Color.gray.opacity(0.5)
        }
    }
}

/// Indicator showing staged/unstaged status and conflicts.
struct StatusIndicator: View {
    let file: FileStatus
    let isStaged: Bool

    var body: some View {
        if file.hasConflict {
            // Conflict badge - important but not alarming
            Text("CONFLICT")
                .font(DSTypography.smallLabel())
                .fontWeight(.semibold)
                .foregroundStyle(DSColors.warning)
                .padding(.horizontal, DSSpacing.sm)
                .padding(.vertical, DSSpacing.xs)
                .background(DSColors.warningBadgeBackground)
                .clipShape(Capsule())
        } else if file.isStaged && file.isUnstaged {
            // Partially staged indicator with tooltip
            HStack(spacing: 2) {
                Circle()
                    .fill(DSColors.success)
                    .frame(width: 6, height: 6)
                Circle()
                    .fill(DSColors.modification)
                    .frame(width: 6, height: 6)
            }
            .help("File has both staged and unstaged changes")
        }
    }
}

#Preview {
    VStack(spacing: 0) {
        FileStatusRow(
            file: FileStatus(
                path: "src/components/Button.swift",
                indexStatus: .modified,
                workTreeStatus: nil,
                originalPath: nil
            ),
            isStaged: true
        )
        Divider()
        FileStatusRow(
            file: FileStatus(
                path: "README.md",
                indexStatus: nil,
                workTreeStatus: .modified,
                originalPath: nil
            ),
            isStaged: false
        )
        Divider()
        FileStatusRow(
            file: FileStatus(
                path: "new-file.txt",
                indexStatus: .untracked,
                workTreeStatus: .untracked,
                originalPath: nil
            ),
            isStaged: false
        )
        Divider()
        FileStatusRow(
            file: FileStatus(
                path: "deleted-file.swift",
                indexStatus: .deleted,
                workTreeStatus: nil,
                originalPath: nil
            ),
            isStaged: true
        )
    }
    .padding()
    .frame(width: 350)
}
