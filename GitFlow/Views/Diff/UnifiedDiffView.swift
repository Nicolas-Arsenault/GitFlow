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
    // Line selection support
    var isLineSelectionMode: Bool = false
    @Binding var selectedLineIds: Set<String>
    var onToggleLineSelection: ((String) -> Void)?

    @Environment(\.colorScheme) private var colorScheme
    @State private var matchLocations: [MatchLocation] = []

    init(
        diff: FileDiff,
        showLineNumbers: Bool,
        wrapLines: Bool = false,
        searchText: String = "",
        currentMatchIndex: Int = 0,
        onMatchCountChanged: ((Int) -> Void)? = nil,
        canStageHunks: Bool = false,
        canUnstageHunks: Bool = false,
        onStageHunk: ((DiffHunk) -> Void)? = nil,
        onUnstageHunk: ((DiffHunk) -> Void)? = nil,
        isLineSelectionMode: Bool = false,
        selectedLineIds: Binding<Set<String>> = .constant([]),
        onToggleLineSelection: ((String) -> Void)? = nil
    ) {
        self.diff = diff
        self.showLineNumbers = showLineNumbers
        self.wrapLines = wrapLines
        self.searchText = searchText
        self.currentMatchIndex = currentMatchIndex
        self.onMatchCountChanged = onMatchCountChanged
        self.canStageHunks = canStageHunks
        self.canUnstageHunks = canUnstageHunks
        self.onStageHunk = onStageHunk
        self.onUnstageHunk = onUnstageHunk
        self.isLineSelectionMode = isLineSelectionMode
        self._selectedLineIds = selectedLineIds
        self.onToggleLineSelection = onToggleLineSelection
    }

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
                                onUnstage: { onUnstageHunk?(hunk) },
                                isLineSelectionMode: isLineSelectionMode,
                                selectedLineIds: selectedLineIds,
                                onSelectLines: { newSelection in
                                    selectedLineIds = newSelection
                                }
                            )
                            .frame(minWidth: geometry.size.width, alignment: .leading)
                        }
                    }
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

/// Preference key for tracking line frames during drag selection.
struct LineFramePreferenceKey: PreferenceKey {
    static var defaultValue: [Int: CGRect] = [:]

    static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
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
    // Line selection support
    var isLineSelectionMode: Bool = false
    var selectedLineIds: Set<String> = []
    var onSelectLines: ((Set<String>) -> Void)?
    // Word-level diff
    var showWordDiff: Bool = false

    @State private var isHovered: Bool = false
    @State private var isDragging: Bool = false
    @State private var dragStartIndex: Int?
    @State private var lineFrames: [Int: CGRect] = [:]

    /// Cached line pairs for word-level diffing.
    private var linePairs: [String: String] {
        showWordDiff ? hunk.findLinePairs() : [:]
    }

    /// Get selectable line indices (only additions and deletions)
    private var selectableLineIndices: [Int] {
        hunk.lines.enumerated().compactMap { index, line in
            (line.type == .addition || line.type == .deletion) ? index : nil
        }
    }

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

                // Stage/Unstage buttons - use opacity instead of conditional to prevent layout shifts
                if canStage || canUnstage {
                    HStack(spacing: DSSpacing.sm) {
                        if canStage {
                            Button {
                                onStage?()
                            } label: {
                                Label("Stage Hunk", systemImage: "plus.circle")
                                    .labelStyle(.titleAndIcon)
                                    .font(.caption)
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
                                    .font(.caption)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                    .padding(.trailing, DSSpacing.sm)
                    .opacity(isHovered && !isDragging ? 1 : 0)
                }
            }
            .padding(.vertical, DSSpacing.xs)
            .background(DSColors.diffHunkBackground(for: colorScheme))
            .onHover { hovering in
                isHovered = hovering
            }

            // Lines
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(hunk.lines.enumerated()), id: \.element.id) { lineIndex, line in
                    DiffLineView(
                        line: line,
                        lineId: "\(hunkIndex)-\(lineIndex)",
                        showLineNumbers: showLineNumbers,
                        wrapLines: wrapLines,
                        colorScheme: colorScheme,
                        searchText: searchText,
                        isCurrentMatch: isCurrentMatch(hunkIndex: hunkIndex, lineIndex: lineIndex),
                        hasMatch: hasMatch(hunkIndex: hunkIndex, lineIndex: lineIndex),
                        isLineSelectionMode: isLineSelectionMode,
                        isSelected: selectedLineIds.contains(line.id),
                        onToggleSelection: {
                            toggleLine(line.id)
                        },
                        pairContent: linePairs[line.id],
                        showWordDiff: showWordDiff,
                        canSelect: canStage || canUnstage
                    )
                    .id("\(hunkIndex)-\(lineIndex)")
                }
            }
            .background(
                // Only measure frames when drag selection is possible
                (canStage || canUnstage) ?
                GeometryReader { geo in
                    Color.clear.onAppear {
                        // Calculate line frames based on line height
                        let lineHeight = geo.size.height / CGFloat(max(hunk.lines.count, 1))
                        var frames: [Int: CGRect] = [:]
                        for i in 0..<hunk.lines.count {
                            frames[i] = CGRect(
                                x: 0,
                                y: CGFloat(i) * lineHeight,
                                width: geo.size.width,
                                height: lineHeight
                            )
                        }
                        lineFrames = frames
                    }
                } : nil
            )
            .gesture(
                (canStage || canUnstage) ?
                DragGesture(minimumDistance: 10)
                    .onChanged { value in
                        handleDrag(at: value.location, startLocation: value.startLocation)
                    }
                    .onEnded { _ in
                        isDragging = false
                        dragStartIndex = nil
                    }
                : nil
            )
        }
    }

    private func toggleLine(_ lineId: String) {
        var newSelection = selectedLineIds
        if newSelection.contains(lineId) {
            newSelection.remove(lineId)
        } else {
            newSelection.insert(lineId)
        }
        onSelectLines?(newSelection)
    }

    private func handleDrag(at location: CGPoint, startLocation: CGPoint) {
        // Find which line the drag started on
        if dragStartIndex == nil {
            dragStartIndex = lineIndexAt(startLocation)
            isDragging = true
        }

        guard let startIdx = dragStartIndex else { return }

        // Find current line
        guard let currentIdx = lineIndexAt(location) else { return }

        // Select all lines between start and current
        let minIdx = min(startIdx, currentIdx)
        let maxIdx = max(startIdx, currentIdx)

        var newSelection = Set<String>()
        for idx in minIdx...maxIdx {
            let line = hunk.lines[idx]
            if line.type == .addition || line.type == .deletion {
                newSelection.insert(line.id)
            }
        }

        onSelectLines?(newSelection)
    }

    private func lineIndexAt(_ point: CGPoint) -> Int? {
        for (index, frame) in lineFrames {
            if point.y >= frame.minY && point.y <= frame.maxY {
                return index
            }
        }
        // If above all lines, return first; if below, return last
        if point.y < 0 {
            return 0
        }
        if let maxIndex = lineFrames.keys.max() {
            return maxIndex
        }
        return nil
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
    // Line selection support
    var isLineSelectionMode: Bool = false
    var isSelected: Bool = false
    var onToggleSelection: (() -> Void)? = nil
    // Word-level diff support
    var pairContent: String? = nil
    var showWordDiff: Bool = false
    // Selection support
    var canSelect: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Selection indicator (shown when line is selected)
            if canSelect && (line.type == .addition || line.type == .deletion) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 10))
                    .foregroundStyle(isSelected ? .blue : .secondary.opacity(0.3))
                    .frame(width: 16)
            } else if canSelect {
                Color.clear.frame(width: 16)
            }

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

            // Content with word-level diff and/or search highlighting
            if !searchText.isEmpty && hasMatch {
                HighlightedText(
                    text: line.content,
                    searchText: searchText,
                    isCurrentMatch: isCurrentMatch,
                    wrapLines: wrapLines
                )
            } else if showWordDiff && pairContent != nil && (line.type == .addition || line.type == .deletion) {
                WordDiffText(
                    content: line.content,
                    pairContent: pairContent,
                    isAddition: line.type == .addition,
                    colorScheme: colorScheme,
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
        .contentShape(Rectangle())
        .onTapGesture {
            if canSelect && (line.type == .addition || line.type == .deletion) {
                onToggleSelection?()
            }
        }
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

        if isSelected {
            return Color.blue.opacity(0.2)
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

/// View that renders word-level diff highlighting.
struct WordDiffText: View {
    let content: String
    let pairContent: String?
    let isAddition: Bool
    let colorScheme: ColorScheme
    var wrapLines: Bool = false

    var body: some View {
        let segments = WordDiff.computeForLine(
            content: content,
            pairContent: pairContent,
            isAddition: isAddition
        )

        HStack(spacing: 0) {
            ForEach(segments) { segment in
                Text(segment.text)
                    .background(backgroundFor(segment.type))
            }
        }
        .lineLimit(wrapLines ? nil : 1)
        .fixedSize(horizontal: !wrapLines, vertical: false)
    }

    private func backgroundFor(_ type: WordDiffSegment.SegmentType) -> Color {
        switch type {
        case .unchanged:
            return .clear
        case .added:
            // Darker green for word-level additions
            return colorScheme == .dark
                ? Color.green.opacity(0.4)
                : Color.green.opacity(0.35)
        case .removed:
            // Darker red for word-level deletions
            return colorScheme == .dark
                ? Color.red.opacity(0.4)
                : Color.red.opacity(0.35)
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

    UnifiedDiffView(diff: diff, showLineNumbers: true, searchText: "value", canStageHunks: true)
        .frame(width: 600, height: 300)
}
