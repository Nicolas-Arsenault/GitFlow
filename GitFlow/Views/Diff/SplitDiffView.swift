import SwiftUI

/// Split (side-by-side) diff view showing old and new versions in two columns.
struct SplitDiffView: View {
    let diff: FileDiff
    let showLineNumbers: Bool
    var searchText: String = ""

    @State private var scrollPosition: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            ScrollView([.vertical, .horizontal]) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(diff.hunks) { hunk in
                        SplitHunkView(
                            hunk: hunk,
                            showLineNumbers: showLineNumbers,
                            width: max(geometry.size.width, 600)
                        )
                    }
                }
                .frame(minWidth: geometry.size.width, alignment: .leading)
                .fontDesign(.monospaced)
                .font(.system(size: 12))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.textBackgroundColor))
    }
}

/// Split view for a single hunk.
struct SplitHunkView: View {
    let hunk: DiffHunk
    let showLineNumbers: Bool
    let width: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Hunk header spanning both columns
            HStack(spacing: 0) {
                Text(hunk.rawHeader)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                Spacer()
            }
            .background(Color.blue.opacity(0.1))

            // Split content
            ForEach(Array(pairedLines.enumerated()), id: \.offset) { _, pair in
                SplitLineRow(
                    leftLine: pair.left,
                    rightLine: pair.right,
                    showLineNumbers: showLineNumbers,
                    columnWidth: (width - 2) / 2
                )
            }
        }
    }

    /// Pairs up deletion/addition lines for side-by-side display.
    private var pairedLines: [LinePair] {
        var pairs: [LinePair] = []
        var deletions: [DiffLine] = []
        var additions: [DiffLine] = []

        for line in hunk.lines {
            switch line.type {
            case .context:
                // Flush any pending deletions/additions
                pairs.append(contentsOf: flushPending(&deletions, &additions))
                pairs.append(LinePair(left: line, right: line))

            case .deletion:
                deletions.append(line)

            case .addition:
                additions.append(line)

            default:
                break
            }
        }

        // Flush remaining
        pairs.append(contentsOf: flushPending(&deletions, &additions))

        return pairs
    }

    private func flushPending(_ deletions: inout [DiffLine], _ additions: inout [DiffLine]) -> [LinePair] {
        var pairs: [LinePair] = []

        let maxCount = max(deletions.count, additions.count)
        for i in 0..<maxCount {
            let left = i < deletions.count ? deletions[i] : nil
            let right = i < additions.count ? additions[i] : nil
            pairs.append(LinePair(left: left, right: right))
        }

        deletions.removeAll()
        additions.removeAll()

        return pairs
    }
}

/// A pair of lines for split view display.
struct LinePair {
    let left: DiffLine?
    let right: DiffLine?
}

/// A row in the split diff view showing left and right columns.
struct SplitLineRow: View {
    let leftLine: DiffLine?
    let rightLine: DiffLine?
    let showLineNumbers: Bool
    let columnWidth: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            // Left column (old)
            SplitLineColumn(
                line: leftLine,
                showLineNumbers: showLineNumbers,
                isLeft: true
            )
            .frame(width: columnWidth)

            // Divider
            Rectangle()
                .fill(Color.secondary.opacity(0.2))
                .frame(width: 1)

            // Right column (new)
            SplitLineColumn(
                line: rightLine,
                showLineNumbers: showLineNumbers,
                isLeft: false
            )
            .frame(width: columnWidth)
        }
    }
}

/// A single column in the split view.
struct SplitLineColumn: View {
    let line: DiffLine?
    let showLineNumbers: Bool
    let isLeft: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            if showLineNumbers {
                let lineNum = isLeft ? line?.oldLineNumber : line?.newLineNumber
                Text(lineNum.map { String($0) } ?? "")
                    .frame(width: 45, alignment: .trailing)
                    .foregroundStyle(.secondary)
                    .padding(.trailing, 8)
            }

            if let line {
                Text(line.prefix)
                    .foregroundStyle(prefixColor(for: line))
                    .frame(width: 16)

                Text(line.content)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 1)
        .background(backgroundColor)
    }

    private func prefixColor(for line: DiffLine) -> Color {
        switch line.type {
        case .addition: return .green
        case .deletion: return .red
        default: return .secondary
        }
    }

    private var backgroundColor: Color {
        guard let line else { return Color.secondary.opacity(0.05) }

        switch line.type {
        case .addition: return .green.opacity(0.15)
        case .deletion: return .red.opacity(0.15)
        default: return .clear
        }
    }
}

#Preview {
    let hunk = DiffHunk(
        oldStart: 1,
        oldCount: 3,
        newStart: 1,
        newCount: 4,
        header: "func example()",
        lines: [
            DiffLine(content: "import Foundation", type: .context, oldLineNumber: 1, newLineNumber: 1),
            DiffLine(content: "", type: .context, oldLineNumber: 2, newLineNumber: 2),
            DiffLine(content: "let oldValue = 1", type: .deletion, oldLineNumber: 3, newLineNumber: nil),
            DiffLine(content: "let newValue = 2", type: .addition, oldLineNumber: nil, newLineNumber: 3),
            DiffLine(content: "let anotherNew = 3", type: .addition, oldLineNumber: nil, newLineNumber: 4),
        ],
        rawHeader: "@@ -1,3 +1,4 @@ func example()"
    )

    let diff = FileDiff(
        path: "example.swift",
        hunks: [hunk]
    )

    SplitDiffView(diff: diff, showLineNumbers: true)
        .frame(width: 800, height: 300)
}
