import SwiftUI

/// Toolbar for diff view controls.
struct DiffToolbar: View {
    @ObservedObject var viewModel: DiffViewModel
    var onSearchTap: (() -> Void)?

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
