import SwiftUI

/// Main diff view container.
struct DiffView: View {
    @ObservedObject var viewModel: DiffViewModel

    @State private var showSearch: Bool = false
    @State private var searchText: String = ""
    @State private var currentMatchIndex: Int = 0
    @State private var totalMatches: Int = 0

    init(viewModel: DiffViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            DiffToolbar(viewModel: viewModel, onSearchTap: { showSearch.toggle() })

            // Search bar
            if showSearch {
                DiffSearchBar(
                    searchText: $searchText,
                    currentMatch: currentMatchIndex,
                    totalMatches: totalMatches,
                    onPrevious: { navigateMatch(direction: -1) },
                    onNext: { navigateMatch(direction: 1) },
                    onClose: {
                        showSearch = false
                        searchText = ""
                    }
                )
            }

            Divider()

            // Content
            if viewModel.isLoading {
                SkeletonDiff()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let diff = viewModel.currentDiff {
                if diff.isBinary {
                    BinaryFileView(diff: diff)
                } else if diff.hunks.isEmpty {
                    EmptyStateView(
                        "No Changes",
                        systemImage: "doc.text",
                        description: "This file has no text changes to display"
                    )
                } else {
                    Group {
                        // Use virtualized view for large files (not in structure mode)
                        if viewModel.needsVirtualizedRendering && viewModel.viewMode != .structure {
                            VStack(spacing: 0) {
                                // Large file warning
                                HStack {
                                    Image(systemName: "exclamationmark.triangle")
                                        .foregroundStyle(.orange)
                                    Text("Large file (\(totalLineCount(diff)) lines) - Using optimized rendering")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                }
                                .padding(8)
                                .background(Color.orange.opacity(0.1))

                                VirtualizedDiffView(
                                    diff: diff,
                                    showLineNumbers: viewModel.showLineNumbers,
                                    wrapLines: viewModel.wrapLines
                                )
                            }
                        } else {
                            switch viewModel.viewMode {
                            case .unified:
                                UnifiedDiffView(
                                    diff: diff,
                                    showLineNumbers: viewModel.showLineNumbers,
                                    wrapLines: viewModel.wrapLines,
                                    searchText: searchText,
                                    currentMatchIndex: currentMatchIndex,
                                    onMatchCountChanged: { totalMatches = $0 },
                                    canStageHunks: viewModel.canStageHunks,
                                    canUnstageHunks: viewModel.canUnstageHunks,
                                    onStageHunk: { hunk in
                                        Task {
                                            await viewModel.stageHunk(hunk, filePath: diff.path)
                                        }
                                    },
                                    onUnstageHunk: { hunk in
                                        Task {
                                            await viewModel.unstageHunk(hunk, filePath: diff.path)
                                        }
                                    },
                                    isLineSelectionMode: viewModel.isLineSelectionMode,
                                    selectedLineIds: $viewModel.selectedLineIds,
                                    onToggleLineSelection: { lineId in
                                        viewModel.toggleLineSelection(lineId)
                                    }
                                )
                            case .split:
                                SplitDiffView(
                                    diff: diff,
                                    showLineNumbers: viewModel.showLineNumbers,
                                    searchText: searchText
                                )
                            case .structure:
                                structuralDiffContent(diff: diff)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onChange(of: viewModel.viewMode) { newMode in
                        if newMode == .structure {
                            Task { await viewModel.performStructuralAnalysis() }
                        }
                    }
                }
            } else {
                EmptyStateView(
                    "No File Selected",
                    systemImage: "doc.text.magnifyingglass",
                    description: "Select a file from the list to view its changes"
                )
            }
        }
        .keyboardShortcut(for: .find) {
            showSearch.toggle()
        }
        .onChange(of: searchText) { _ in
            currentMatchIndex = 0
        }
        .onChange(of: viewModel.currentDiff?.path) { _ in
            // Reset search when file changes
            currentMatchIndex = 0
            totalMatches = 0
        }
        .alert("Something went wrong", isPresented: .init(
            get: { viewModel.error != nil },
            set: { if !$0 { viewModel.error = nil } }
        )) {
            Button("Dismiss") { viewModel.error = nil }
        } message: {
            if let error = viewModel.error {
                Text(error.localizedDescription)
            }
        }
    }

    private func navigateMatch(direction: Int) {
        guard totalMatches > 0 else { return }
        currentMatchIndex = (currentMatchIndex + direction + totalMatches) % totalMatches
    }

    private func totalLineCount(_ diff: FileDiff) -> Int {
        diff.hunks.reduce(0) { $0 + $1.lines.count }
    }

    // MARK: - Structural Diff View

    @ViewBuilder
    private func structuralDiffContent(diff: FileDiff) -> some View {
        if viewModel.isStructuralAnalysisLoading {
            VStack(spacing: 16) {
                ProgressView()
                    .controlSize(.large)
                Text("Analyzing code structure...")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if !diff.path.hasSuffix(".swift") {
            VStack(spacing: 16) {
                Image(systemName: "doc.text")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("Structural Analysis")
                    .font(.headline)
                Text("Structural analysis is currently only available for Swift files.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Semantic Equivalence Analysis
                    if !viewModel.semanticEquivalences.isEmpty {
                        SemanticEquivalenceView(equivalences: viewModel.semanticEquivalences)
                            .padding(.horizontal)
                    }

                    // Change Impact Analysis
                    if let impact = viewModel.changeImpact {
                        ChangeImpactView(impact: impact)
                            .padding(.horizontal)
                    }

                    // Structural Changes
                    StructuralDiffView(
                        changes: viewModel.structuralChanges,
                        oldEntities: viewModel.oldEntities,
                        newEntities: viewModel.newEntities,
                        onSelectChange: { change in
                            // Navigate to the hunk containing this change
                            navigateToStructuralChange(change, in: diff)
                        }
                    )
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
        }
    }

    private func navigateToStructuralChange(_ change: StructuralChange, in diff: FileDiff) {
        // Find the hunk that contains the line range of this change
        let targetLine = change.entity.lineRange.lowerBound + 1
        for (index, hunk) in diff.hunks.enumerated() {
            // Check if this hunk contains the target line
            if let firstLine = hunk.lines.first(where: { $0.newLineNumber != nil }),
               let lastLine = hunk.lines.last(where: { $0.newLineNumber != nil }),
               let first = firstLine.newLineNumber,
               let last = lastLine.newLineNumber {
                if targetLine >= first && targetLine <= last {
                    viewModel.focusedHunkIndex = index
                    // Switch to unified view to show the actual diff
                    viewModel.viewMode = .unified
                    break
                }
            }
        }
    }
}

// MARK: - Search Bar

struct DiffSearchBar: View {
    @Binding var searchText: String
    let currentMatch: Int
    let totalMatches: Int
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onClose: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: DSSpacing.sm) {
            // Search field
            HStack(spacing: DSSpacing.xs) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Search in diff...", text: $searchText)
                    .textFieldStyle(.plain)
                    .focused($isFocused)
                    .onSubmit { onNext() }

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Clear search")
                }
            }
            .padding(.horizontal, DSSpacing.sm)
            .padding(.vertical, DSSpacing.xs)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.md))

            // Match count
            if !searchText.isEmpty {
                Text(totalMatches > 0 ? "\(currentMatch + 1) of \(totalMatches)" : "No matches")
                    .font(DSTypography.tertiaryContent())
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 80)
            }

            // Navigation buttons
            if totalMatches > 0 {
                HStack(spacing: 2) {
                    Button(action: onPrevious) {
                        Image(systemName: "chevron.up")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Previous match (⇧↩)")

                    Button(action: onNext) {
                        Image(systemName: "chevron.down")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Next match (↩)")
                }
            }

            Spacer()

            // Close button
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Close search (Esc)")
        }
        .padding(.horizontal, DSSpacing.contentPaddingH)
        .padding(.vertical, DSSpacing.sm)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear { isFocused = true }
        .onExitCommand { onClose() }
    }
}

// MARK: - Keyboard Shortcut Modifier

struct KeyboardShortcutModifier: ViewModifier {
    let key: KeyEquivalent
    let modifiers: EventModifiers
    let action: () -> Void

    func body(content: Content) -> some View {
        content
            .background(
                Button("") { action() }
                    .keyboardShortcut(key, modifiers: modifiers)
                    .hidden()
            )
    }
}

enum KeyboardShortcutType {
    case find

    var key: KeyEquivalent {
        switch self {
        case .find: return "f"
        }
    }

    var modifiers: EventModifiers {
        switch self {
        case .find: return .command
        }
    }
}

extension View {
    func keyboardShortcut(for type: KeyboardShortcutType, action: @escaping () -> Void) -> some View {
        modifier(KeyboardShortcutModifier(key: type.key, modifiers: type.modifiers, action: action))
    }
}

/// View shown for binary files.
struct BinaryFileView: View {
    let diff: FileDiff

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("Binary File")
                .font(.headline)

            Text(diff.fileName)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Binary files cannot be displayed as text diff")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    DiffView(
        viewModel: DiffViewModel(
            repository: Repository(rootURL: URL(fileURLWithPath: "/tmp")),
            gitService: GitService()
        )
    )
}
