import SwiftUI

/// Toolbar for diff view controls.
struct DiffToolbar: View {
    @ObservedObject var viewModel: DiffViewModel
    var onSearchTap: (() -> Void)?

    // Local state to avoid "Publishing changes from within view updates" warning
    @State private var localViewMode: DiffViewModel.ViewMode = .unified

    init(viewModel: DiffViewModel, onSearchTap: (() -> Void)? = nil) {
        self.viewModel = viewModel
        self.onSearchTap = onSearchTap
    }

    var body: some View {
        HStack(spacing: 8) {
            // File header (flexible, shrinks to fit)
            if viewModel.hasDiff {
                DiffFileHeader(viewModel: viewModel)
            } else {
                Text("Diff")
                    .font(.headline)
            }

            Spacer(minLength: 4)

            // Controls - grouped together, won't shrink
            if viewModel.hasDiff {
                HStack(spacing: 8) {
                // Stats (compact)
                if let diff = viewModel.currentDiff {
                    HStack(spacing: 4) {
                        Text("+\(diff.additions)")
                            .foregroundStyle(DSColors.addition)
                        Text("-\(diff.deletions)")
                            .foregroundStyle(DSColors.deletion)
                    }
                    .font(.caption)
                    .fontDesign(.monospaced)
                    .fixedSize()
                }

                // Hunk navigation (compact)
                if viewModel.totalHunks > 1 {
                    HStack(spacing: 0) {
                        Button(action: { viewModel.navigateToPreviousHunk() }) {
                            Image(systemName: "chevron.up")
                        }
                        .buttonStyle(.borderless)

                        Text("\(viewModel.focusedHunkIndex + 1)/\(viewModel.totalHunks)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(minWidth: 24)

                        Button(action: { viewModel.navigateToNextHunk() }) {
                            Image(systemName: "chevron.down")
                        }
                        .buttonStyle(.borderless)
                    }
                    .fixedSize()
                }

                Divider()
                    .frame(height: 16)

                // View mode picker (menu style to save space)
                Menu {
                    Picker("View Mode", selection: $localViewMode) {
                        ForEach(DiffViewModel.ViewMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(localViewMode.rawValue)
                            .font(.caption)
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                    }
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .onChange(of: localViewMode) { newValue in
                    Task { @MainActor in
                        viewModel.viewMode = newValue
                    }
                }

                Divider()
                    .frame(height: 16)

                // Line staging actions (shown when lines are selected)
                if viewModel.canStageHunks || viewModel.canUnstageHunks {
                    if !viewModel.selectedLineIds.isEmpty {
                        Text("\(viewModel.selectedLineIds.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if viewModel.canStageSelectedLines {
                            Button {
                                Task { await viewModel.stageSelectedLines() }
                            } label: {
                                Image(systemName: "plus.circle.fill")
                            }
                            .buttonStyle(.borderless)
                            .foregroundStyle(.green)
                            .help("Stage selected lines")
                        }

                        if viewModel.canUnstageSelectedLines {
                            Button {
                                Task { await viewModel.unstageSelectedLines() }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                            }
                            .buttonStyle(.borderless)
                            .foregroundStyle(.orange)
                            .help("Unstage selected lines")
                        }

                        Button {
                            viewModel.clearLineSelection()
                        } label: {
                            Image(systemName: "xmark.circle")
                        }
                        .buttonStyle(.borderless)
                        .help("Clear selection")

                        Divider()
                            .frame(height: 16)
                    }
                }

                // Search button
                Button {
                    onSearchTap?()
                } label: {
                    Image(systemName: "magnifyingglass")
                }
                .buttonStyle(.borderless)
                .help("Search in diff (⌘F)")

                // Options menu (includes blame toggle)
                Menu {
                    // Blame toggle at top
                    Toggle(isOn: Binding(
                        get: { viewModel.showBlame },
                        set: { newValue in
                            viewModel.showBlame = newValue
                            if newValue && viewModel.blameLines.isEmpty {
                                Task { await viewModel.loadBlame() }
                            }
                        }
                    )) {
                        Label("Show Blame", systemImage: "person")
                    }

                    Divider()

                    Section("Display") {
                        Toggle("Show Line Numbers", isOn: $viewModel.showLineNumbers)
                        Toggle("Wrap Lines", isOn: $viewModel.wrapLines)
                        Toggle("Show Whitespace", isOn: $viewModel.showWhitespace)
                    }

                    Section("Noise Suppression") {
                        Toggle("Hide Generated Files", isOn: $viewModel.noiseOptions.hideGeneratedFiles)
                        Toggle("Hide Lockfiles", isOn: $viewModel.noiseOptions.hideLockfiles)
                        Toggle("Collapse Renames", isOn: $viewModel.noiseOptions.collapseRenames)
                        Toggle("Hide Comment Changes", isOn: $viewModel.noiseOptions.hideCommentChanges)
                        Toggle("Hide Import Changes", isOn: $viewModel.noiseOptions.hideImportChanges)
                    }

                    Section("Whitespace") {
                        Toggle("Ignore Whitespace", isOn: Binding(
                            get: { viewModel.ignoreWhitespace },
                            set: { newValue in
                                viewModel.ignoreWhitespace = newValue
                                Task { await viewModel.reloadWithOptions() }
                            }
                        ))
                        Toggle("Ignore Blank Lines", isOn: Binding(
                            get: { viewModel.ignoreBlankLines },
                            set: { newValue in
                                viewModel.ignoreBlankLines = newValue
                                Task { await viewModel.reloadWithOptions() }
                            }
                        ))
                    }

                    Section("Sort Order") {
                        Picker("Sort By", selection: $viewModel.noiseOptions.sortOrder) {
                            ForEach(NoiseSuppressionOptions.SortOrder.allCases) { order in
                                Text(order.rawValue).tag(order)
                            }
                        }
                    }

                    Divider()

                    Button(action: {
                        Task { await viewModel.copyDiffToClipboard() }
                    }) {
                        Label("Copy Diff to Clipboard", systemImage: "doc.on.doc")
                    }

                    Button(action: { viewModel.openInExternalEditor() }) {
                        Label("Open in Editor", systemImage: "square.and.pencil")
                    }

                    Button(action: { viewModel.revealInFinder() }) {
                        Label("Reveal in Finder", systemImage: "folder")
                    }
                } label: {
                    Image(systemName: viewModel.showBlame ? "gearshape.fill" : "gearshape")
                }
                .menuStyle(.borderlessButton)
                .frame(width: 24)
                .help("Diff options")
                }
                .fixedSize()
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .onAppear {
            localViewMode = viewModel.viewMode
        }
        .onChange(of: viewModel.viewMode) { newValue in
            // Sync from view model to local state (for external changes)
            if localViewMode != newValue {
                localViewMode = newValue
            }
        }
    }
}

#Preview {
    VStack {
        DiffToolbar(
            viewModel: DiffViewModel(
                repository: Repository(rootURL: URL(fileURLWithPath: "/tmp")),
                gitService: GitService()
            )
        )
        Divider()
        Spacer()
    }
    .frame(width: 600, height: 100)
}
