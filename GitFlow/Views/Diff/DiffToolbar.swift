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
                    Toggle("Show Line Numbers", isOn: $viewModel.showLineNumbers)
                    Toggle("Wrap Lines", isOn: $viewModel.wrapLines)
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
