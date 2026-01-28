import SwiftUI

/// Toolbar for diff view controls.
struct DiffToolbar: View {
    @ObservedObject var viewModel: DiffViewModel
    var onSearchTap: (() -> Void)?
    @Binding var isFullscreen: Bool

    init(viewModel: DiffViewModel, onSearchTap: (() -> Void)? = nil, isFullscreen: Binding<Bool> = .constant(false)) {
        self.viewModel = viewModel
        self.onSearchTap = onSearchTap
        self._isFullscreen = isFullscreen
    }

    var body: some View {
        HStack {
            // File header
            if viewModel.hasDiff {
                DiffFileHeader(viewModel: viewModel)
            } else {
                Text("Diff")
                    .font(.headline)
            }

            Spacer()

            // Controls
            if viewModel.hasDiff {
                // Hunk navigation
                if viewModel.totalHunks > 1 {
                    HStack(spacing: 2) {
                        Button(action: { viewModel.navigateToPreviousHunk() }) {
                            Image(systemName: "chevron.up")
                        }
                        .buttonStyle(.borderless)
                        .help("Previous change")

                        Text("\(viewModel.focusedHunkIndex + 1)/\(viewModel.totalHunks)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(minWidth: 30)

                        Button(action: { viewModel.navigateToNextHunk() }) {
                            Image(systemName: "chevron.down")
                        }
                        .buttonStyle(.borderless)
                        .help("Next change")
                    }

                    Divider()
                        .frame(height: 16)
                }

                // Stats
                HStack(spacing: 8) {
                    if let diff = viewModel.currentDiff {
                        Text("+\(diff.additions)")
                            .foregroundStyle(DSColors.addition)
                        Text("-\(diff.deletions)")
                            .foregroundStyle(DSColors.deletion)
                    }
                }
                .font(.caption)
                .fontDesign(.monospaced)

                Divider()
                    .frame(height: 16)

                // View mode picker
                Picker("View Mode", selection: $viewModel.viewMode) {
                    ForEach(DiffViewModel.ViewMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 120)

                // Blame toggle
                Button {
                    viewModel.showBlame.toggle()
                    if viewModel.showBlame && viewModel.blameLines.isEmpty {
                        Task { await viewModel.loadBlame() }
                    }
                } label: {
                    Image(systemName: viewModel.showBlame ? "person.fill" : "person")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(viewModel.showBlame ? .blue : .secondary)
                .help("Toggle blame annotations")

                // Search button
                Button {
                    onSearchTap?()
                } label: {
                    Image(systemName: "magnifyingglass")
                }
                .buttonStyle(.borderless)
                .help("Search in diff (⌘F)")

                // Options menu
                Menu {
                    Section("Display") {
                        Toggle("Show Line Numbers", isOn: $viewModel.showLineNumbers)
                        Toggle("Wrap Lines", isOn: $viewModel.wrapLines)
                        Toggle("Show Whitespace", isOn: $viewModel.showWhitespace)
                    }

                    Section("Diff Options") {
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
                    Image(systemName: "gearshape")
                }
                .menuStyle(.borderlessButton)
                .frame(width: 24)

                // Fullscreen toggle
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isFullscreen.toggle()
                    }
                } label: {
                    Image(systemName: isFullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                }
                .buttonStyle(.borderless)
                .help(isFullscreen ? "Exit fullscreen" : "Fullscreen diff")
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
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
