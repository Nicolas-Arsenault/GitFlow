import SwiftUI

/// Main diff view container.
struct DiffView: View {
    @ObservedObject var viewModel: DiffViewModel
    @Binding var isFullscreen: Bool

    @State private var showSearch: Bool = false
    @State private var searchText: String = ""
    @State private var currentMatchIndex: Int = 0
    @State private var totalMatches: Int = 0

    init(viewModel: DiffViewModel, isFullscreen: Binding<Bool> = .constant(false)) {
        self.viewModel = viewModel
        self._isFullscreen = isFullscreen
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            DiffToolbar(viewModel: viewModel, onSearchTap: { showSearch.toggle() }, isFullscreen: $isFullscreen)

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
                                }
                            )
                        case .split:
                            SplitDiffView(
                                diff: diff,
                                showLineNumbers: viewModel.showLineNumbers,
                                searchText: searchText
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
