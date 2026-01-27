import SwiftUI

/// Unified (inline) diff view showing changes in a single column.
struct UnifiedDiffView: View {
    let diff: FileDiff
    let showLineNumbers: Bool
    var wrapLines: Bool = false
    var searchText: String = ""
    var currentMatchIndex: Int = 0
    var onMatchCountChanged: ((Int) -> Void)?
    var canStageHunks: Bool = false
    var canUnstageHunks: Bool = false
    var onStageHunk: ((DiffHunk) -> Void)?
    var onUnstageHunk: ((DiffHunk) -> Void)?

    @Environment(\.colorScheme) private var colorScheme
    @State private var matchLocations: [MatchLocation] = []

    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { scrollProxy in
                ScrollView(wrapLines ? [.vertical] : [.horizontal, .vertical]) {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(diff.hunks.enumerated()), id: \.element.id) { hunkIndex, hunk in
                            DiffHunkView(
                                hunk: hunk,
                                hunkIndex: hunkIndex,
                                showLineNumbers: showLineNumbers,
                                wrapLines: wrapLines,
                                colorScheme: colorScheme,
                                searchText: searchText,
                                currentMatchIndex: currentMatchIndex,
                                matchLocations: matchLocations,
                                canStage: canStageHunks,
                                canUnstage: canUnstageHunks,
                                onStage: { onStageHunk?(hunk) },
                                onUnstage: { onUnstageHunk?(hunk) }
                            )
                        }
                    }
                    .frame(minWidth: wrapLines ? nil : geometry.size.width, minHeight: geometry.size.height, alignment: .topLeading)
                    .frame(maxWidth: wrapLines ? geometry.size.width : nil)
                    .font(DSTypography.code())
                }
                .onChange(of: currentMatchIndex) { newIndex in
                    if newIndex < matchLocations.count {
                        let match = matchLocations[newIndex]
                        withAnimation(.easeInOut(duration: 0.2)) {
                            scrollProxy.scrollTo(match.lineId, anchor: .center)
                        }
                    }
                }
            }
        }
        .background(Color(NSColor.textBackgroundColor))
        .onChange(of: searchText) { _ in
            updateMatchLocations()
        }
        .onChange(of: diff.path) { _ in
            updateMatchLocations()
        }
        .onAppear {
            updateMatchLocations()
        }
    }

    private func updateMatchLocations() {
        guard !searchText.isEmpty else {
            matchLocations = []
            onMatchCountChanged?(0)
            return
        }

        var locations: [MatchLocation] = []
        let searchLower = searchText.lowercased()

        for (hunkIndex, hunk) in diff.hunks.enumerated() {
            for (lineIndex, line) in hunk.lines.enumerated() {
                let content = line.content.lowercased()
                var searchStart = content.startIndex

                while let range = content.range(of: searchLower, range: searchStart..<content.endIndex) {
                    let lineId = "\(hunkIndex)-\(lineIndex)"
                    locations.append(MatchLocation(
                        hunkIndex: hunkIndex,
                        lineIndex: lineIndex,
                        lineId: lineId,
                        range: range
                    ))
                    searchStart = range.upperBound
                }
            }
        }

        matchLocations = locations
        onMatchCountChanged?(locations.count)
    }
}

struct MatchLocation: Equatable {
    let hunkIndex: Int
    let lineIndex: Int
    let lineId: String
    let range: Range<String.Index>
}

/// View for a single diff hunk.
struct DiffHunkView: View {
    let hunk: DiffHunk
    let hunkIndex: Int
    let showLineNumbers: Bool
    var wrapLines: Bool = false
    let colorScheme: ColorScheme
    var searchText: String = ""
    var currentMatchIndex: Int = 0
    var matchLocations: [MatchLocation] = []
    var canStage: Bool = false
    var canUnstage: Bool = false
    var onStage: (() -> Void)?
    var onUnstage: (() -> Void)?

    @State private var isHovered: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Hunk header with staging buttons
            HStack(spacing: 0) {
                HStack(spacing: DSSpacing.xs) {
                    Image(systemName: "minus")
                        .font(.caption2)
                        .foregroundStyle(DSColors.deletion)
                    Text("\(hunk.oldCount)")
                        .foregroundStyle(DSColors.deletion)

                    Image(systemName: "plus")
                        .font(.caption2)
                        .foregroundStyle(DSColors.addition)
                    Text("\(hunk.newCount)")
                        .foregroundStyle(DSColors.addition)
                }
                .font(DSTypography.smallLabel())
                .padding(.leading, DSSpacing.sm)

                Text(hunk.header.isEmpty ? "" : " \(hunk.header)")
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer()

                if isHovered {
                    HStack(spacing: DSSpacing.sm) {
                        if canStage {
                            Button {
                                onStage?()
                            } label: {
                                Label("Stage Hunk", systemImage: "plus.circle")
                                    .labelStyle(.titleAndIcon)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }

                        if canUnstage {
                            Button {
                                onUnstage?()
                            } label: {
                                Label("Unstage Hunk", systemImage: "minus.circle")
                                    .labelStyle(.titleAndIcon)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                    .font(DSTypography.tertiaryContent())
                    .padding(.trailing, DSSpacing.sm)
                }
            }
            .padding(.vertical, DSSpacing.xs)
            .background(DSColors.diffHunkBackground(for: colorScheme))
            .onHover { hovering in
                withAnimation(.fastResponse) {
                    isHovered = hovering
                }
            }

            // Lines
            ForEach(Array(hunk.lines.enumerated()), id: \.element.id) { lineIndex, line in
                DiffLineView(
                    line: line,
                    lineId: "\(hunkIndex)-\(lineIndex)",
                    showLineNumbers: showLineNumbers,
                    wrapLines: wrapLines,
                    colorScheme: colorScheme,
                    searchText: searchText,
                    isCurrentMatch: isCurrentMatch(hunkIndex: hunkIndex, lineIndex: lineIndex),
                    hasMatch: hasMatch(hunkIndex: hunkIndex, lineIndex: lineIndex)
                )
                .id("\(hunkIndex)-\(lineIndex)")
            }
        }
    }

    private func isCurrentMatch(hunkIndex: Int, lineIndex: Int) -> Bool {
        guard currentMatchIndex < matchLocations.count else { return false }
        let match = matchLocations[currentMatchIndex]
        return match.hunkIndex == hunkIndex && match.lineIndex == lineIndex
    }

    private func hasMatch(hunkIndex: Int, lineIndex: Int) -> Bool {
        matchLocations.contains { $0.hunkIndex == hunkIndex && $0.lineIndex == lineIndex }
    }
}

/// View for a single diff line.
struct DiffLineView: View {
    let line: DiffLine
    let lineId: String
    let showLineNumbers: Bool
    var wrapLines: Bool = false
    let colorScheme: ColorScheme
    var searchText: String = ""
    var isCurrentMatch: Bool = false
    var hasMatch: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            if showLineNumbers {
                HStack(spacing: 0) {
                    typeIndicator
                        .frame(width: 12)

                    Text(line.oldLineNumber.map { String($0) } ?? "")
                        .frame(width: 40, alignment: .trailing)
                        .foregroundStyle(.secondary)
                }

                Text(line.newLineNumber.map { String($0) } ?? "")
                    .frame(width: 40, alignment: .trailing)
                    .foregroundStyle(.secondary)
                    .padding(.trailing, DSSpacing.sm)
            } else {
                typeIndicator
                    .frame(width: 16)
            }

            Text(line.prefix)
                .foregroundStyle(prefixColor)
                .frame(width: 14)

            // Content with search highlighting
            if !searchText.isEmpty && hasMatch {
                HighlightedText(
                    text: line.content,
                    searchText: searchText,
                    isCurrentMatch: isCurrentMatch,
                    wrapLines: wrapLines
                )
            } else {
                Text(line.content + (line.hasNewline ? "" : " "))
                    .foregroundStyle(line.hasNewline ? .primary : .secondary)
                    .lineLimit(wrapLines ? nil : 1)
                    .fixedSize(horizontal: !wrapLines, vertical: false)
            }

            if !line.hasNewline {
                Text("No newline at end of file")
                    .font(DSTypography.smallLabel())
                    .foregroundStyle(.tertiary)
                    .italic()
            }

            if !wrapLines {
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, DSSpacing.sm)
        .padding(.vertical, 1)
        .background(backgroundColor)
    }

    @ViewBuilder
    private var typeIndicator: some View {
        switch line.type {
        case .addition:
            Image(systemName: "plus")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(DSColors.addition)
        case .deletion:
            Image(systemName: "minus")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(DSColors.deletion)
        default:
            Color.clear
        }
    }

    private var prefixColor: Color {
        switch line.type {
        case .addition: return DSColors.addition
        case .deletion: return DSColors.deletion
        default: return .secondary
        }
    }

    private var backgroundColor: Color {
        if isCurrentMatch {
            return Color.yellow.opacity(0.3)
        }

        switch line.type {
        case .addition:
            return DSColors.diffAdditionBackground(for: colorScheme)
        case .deletion:
            return DSColors.diffDeletionBackground(for: colorScheme)
        case .hunkHeader:
            return DSColors.diffHunkBackground(for: colorScheme)
        default:
            return .clear
        }
    }
}

/// Text view with search term highlighting.
struct HighlightedText: View {
    let text: String
    let searchText: String
    let isCurrentMatch: Bool
    var wrapLines: Bool = false

    var body: some View {
        let parts = highlightedParts()
        HStack(spacing: 0) {
            ForEach(Array(parts.enumerated()), id: \.offset) { _, part in
                Text(part.text)
                    .background(part.isHighlighted ? (isCurrentMatch ? Color.orange : Color.yellow).opacity(0.5) : Color.clear)
            }
        }
        .lineLimit(wrapLines ? nil : 1)
        .fixedSize(horizontal: !wrapLines, vertical: false)
    }

    private func highlightedParts() -> [HighlightPart] {
        guard !searchText.isEmpty else {
            return [HighlightPart(text: text, isHighlighted: false)]
        }

        var parts: [HighlightPart] = []
        let textLower = text.lowercased()
        let searchLower = searchText.lowercased()
        var currentIndex = text.startIndex

        while currentIndex < text.endIndex {
            if let range = textLower.range(of: searchLower, range: currentIndex..<textLower.endIndex) {
                // Add non-highlighted part before match
                if currentIndex < range.lowerBound {
                    let beforeRange = currentIndex..<range.lowerBound
                    parts.append(HighlightPart(text: String(text[beforeRange]), isHighlighted: false))
                }

                // Add highlighted match
                let matchRange = range.lowerBound..<range.upperBound
                parts.append(HighlightPart(text: String(text[matchRange]), isHighlighted: true))

                currentIndex = range.upperBound
            } else {
                // Add remaining text
                let remainingRange = currentIndex..<text.endIndex
                parts.append(HighlightPart(text: String(text[remainingRange]), isHighlighted: false))
                break
            }
        }

        return parts.isEmpty ? [HighlightPart(text: text, isHighlighted: false)] : parts
    }
}

struct HighlightPart {
    let text: String
    let isHighlighted: Bool
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

    UnifiedDiffView(diff: diff, showLineNumbers: true, searchText: "value", canStageHunks: true)
        .frame(width: 600, height: 300)
}
