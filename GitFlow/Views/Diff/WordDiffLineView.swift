import SwiftUI

/// A view that displays a diff line with word-level highlighting.
struct WordDiffLineView: View {
    let line: DiffLine
    let pairContent: String?
    let showLineNumbers: Bool
    let wrapLines: Bool

    /// Computed word diff segments for this line.
    private var wordDiffSegments: [WordDiffSegment] {
        guard pairContent != nil, line.type == .addition || line.type == .deletion else {
            return []
        }
        return WordDiff.computeForLine(
            content: line.content,
            pairContent: pairContent,
            isAddition: line.type == .addition
        )
    }

    private var shouldShowWordDiff: Bool {
        pairContent != nil && (line.type == .addition || line.type == .deletion)
    }

    var body: some View {
        HStack(spacing: 0) {
            // Line numbers
            if showLineNumbers {
                lineNumbersView
            }

            // Line content with word highlighting
            lineContentView
        }
        .background(backgroundColor)
    }

    // MARK: - Line Numbers

    private var lineNumbersView: some View {
        HStack(spacing: 0) {
            // Old line number
            Text(line.oldLineNumber.map { String($0) } ?? "")
                .frame(width: 40, alignment: .trailing)
                .foregroundStyle(.secondary)

            Text(" ")
                .frame(width: 8)

            // New line number
            Text(line.newLineNumber.map { String($0) } ?? "")
                .frame(width: 40, alignment: .trailing)
                .foregroundStyle(.secondary)

            Text(" ")
                .frame(width: 8)
        }
        .font(.system(.caption, design: .monospaced))
        .background(lineNumberBackground)
    }

    private var lineNumberBackground: Color {
        switch line.type {
        case .addition:
            return Color.green.opacity(0.1)
        case .deletion:
            return Color.red.opacity(0.1)
        default:
            return Color.clear
        }
    }

    // MARK: - Line Content

    @ViewBuilder
    private var lineContentView: some View {
        if shouldShowWordDiff && !wordDiffSegments.isEmpty {
            // Word-level highlighting
            wordDiffContent
        } else {
            // Regular line content
            regularContent
        }
    }

    private var wordDiffContent: some View {
        HStack(spacing: 0) {
            // Line type indicator
            Text(linePrefix)
                .foregroundStyle(prefixColor)

            // Word-level highlighted content (same for both modes)
            inlineWordDiffText

            Spacer(minLength: 0)
        }
        .font(.system(.body, design: .monospaced))
        .textSelection(.enabled)
    }

    private var inlineWordDiffText: some View {
        HStack(spacing: 0) {
            ForEach(wordDiffSegments) { segment in
                Text(segment.text)
                    .background(backgroundForSegment(segment.type))
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var wrappedWordDiffText: some View {
        // Using HStack for wrapped layout with word highlighting
        let content = HStack(spacing: 0) {
            ForEach(wordDiffSegments) { segment in
                Text(segment.text)
                    .background(backgroundForSegment(segment.type))
            }
        }
        return content
    }

    private var regularContent: some View {
        HStack(spacing: 0) {
            Text(linePrefix)
                .foregroundStyle(prefixColor)

            if wrapLines {
                Text(line.content)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(line.content)
                    .fixedSize(horizontal: true, vertical: false)
            }

            Spacer(minLength: 0)
        }
        .font(.system(.body, design: .monospaced))
        .textSelection(.enabled)
    }

    // MARK: - Styling

    private var linePrefix: String {
        switch line.type {
        case .addition: return "+"
        case .deletion: return "-"
        case .context: return " "
        case .hunkHeader, .header: return ""
        }
    }

    private var prefixColor: Color {
        switch line.type {
        case .addition: return .green
        case .deletion: return .red
        default: return .secondary
        }
    }

    private var backgroundColor: Color {
        switch line.type {
        case .addition:
            return Color.green.opacity(0.1)
        case .deletion:
            return Color.red.opacity(0.1)
        case .hunkHeader:
            return Color.blue.opacity(0.05)
        default:
            return Color.clear
        }
    }

    private func backgroundForSegment(_ type: WordDiffSegment.SegmentType) -> Color {
        switch type {
        case .added:
            return Color.green.opacity(0.35)
        case .removed:
            return Color.red.opacity(0.35)
        case .unchanged:
            return Color.clear
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(alignment: .leading, spacing: 0) {
        WordDiffLineView(
            line: DiffLine(
                id: "1",
                content: "    let result = calculateTotal(items, discount)",
                type: .deletion,
                oldLineNumber: 42,
                newLineNumber: nil
            ),
            pairContent: "    let result = computeTotal(items, discount, tax)",
            showLineNumbers: true,
            wrapLines: false
        )

        WordDiffLineView(
            line: DiffLine(
                id: "2",
                content: "    let result = computeTotal(items, discount, tax)",
                type: .addition,
                oldLineNumber: nil,
                newLineNumber: 42
            ),
            pairContent: "    let result = calculateTotal(items, discount)",
            showLineNumbers: true,
            wrapLines: false
        )

        WordDiffLineView(
            line: DiffLine(
                id: "3",
                content: "    return result",
                type: .context,
                oldLineNumber: 43,
                newLineNumber: 43
            ),
            pairContent: nil,
            showLineNumbers: true,
            wrapLines: false
        )
    }
    .padding()
}
