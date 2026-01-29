import SwiftUI

/// Command palette overlay for quick actions and search.
struct CommandPaletteView: View {
    @ObservedObject var viewModel: CommandPaletteViewModel
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        if viewModel.isVisible {
            ZStack {
                // Backdrop
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        viewModel.hide()
                    }

                // Palette
                VStack(spacing: 0) {
                    // Search input
                    CommandPaletteSearchBar(
                        query: $viewModel.query,
                        searchMode: viewModel.searchMode,
                        isFocused: $isSearchFocused
                    )

                    Divider()

                    // Results
                    CommandPaletteResults(viewModel: viewModel)
                }
                .frame(width: 500).frame(maxHeight: 400)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(radius: 20)
                .padding(.top, 100)
                .frame(maxHeight: .infinity, alignment: .top)
            }
            .onAppear {
                isSearchFocused = true
            }
        }
    }
}

// MARK: - Search Bar

private struct CommandPaletteSearchBar: View {
    @Binding var query: String
    let searchMode: CommandPaletteViewModel.SearchMode
    var isFocused: FocusState<Bool>.Binding

    var body: some View {
        HStack(spacing: 12) {
            // Mode indicator
            if searchMode != .all {
                Text(searchMode.rawValue)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.2))
                    .cornerRadius(4)
            }

            // Search icon
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            // Search field
            TextField("Search files, commits, branches, or type / for commands...", text: $query)
                .textFieldStyle(.plain)
                .font(.body)
                .focused(isFocused)

            // Clear button
            if !query.isEmpty {
                Button(action: { query = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Clear search")
            }

            // Hint
            Text("⌘P")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(4)
        }
        .padding()
    }
}

// MARK: - Results

private struct CommandPaletteResults: View {
    @ObservedObject var viewModel: CommandPaletteViewModel

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if viewModel.searchMode == .commands || (viewModel.searchMode == .all && viewModel.query.hasPrefix("/")) {
                        commandsList
                    } else if viewModel.searchMode == .all && viewModel.query.isEmpty {
                        recentActionsList
                    } else {
                        searchResultsList
                    }
                }
            }
            .onChange(of: viewModel.selectedIndex) { newValue in
                withAnimation {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
        }
    }

    private var commandsList: some View {
        ForEach(Array(viewModel.commandsByCategory.enumerated()), id: \.element.category) { categoryIndex, categoryGroup in
            Section {
                ForEach(Array(categoryGroup.commands.enumerated()), id: \.element.id) { commandIndex, command in
                    let index = calculateCommandIndex(categoryIndex: categoryIndex, commandIndex: commandIndex)
                    CommandRow(
                        command: command,
                        isSelected: viewModel.selectedIndex == index
                    )
                    .id(index)
                    .onTapGesture {
                        viewModel.execute(command)
                    }
                }
            } header: {
                Text(categoryGroup.category.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
            }
        }
    }

    private func calculateCommandIndex(categoryIndex: Int, commandIndex: Int) -> Int {
        var index = 0
        for i in 0..<categoryIndex {
            index += viewModel.commandsByCategory[i].commands.count
        }
        return index + commandIndex
    }

    private var recentActionsList: some View {
        Group {
            if viewModel.recentActions.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clock")
                        .font(.title)
                        .foregroundStyle(.secondary)

                    Text("No recent actions")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("Type to search or / for commands")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                Section {
                    ForEach(Array(viewModel.recentActions.enumerated()), id: \.element.id) { index, action in
                        RecentActionRow(
                            action: action,
                            isSelected: viewModel.selectedIndex == index
                        )
                        .id(index)
                    }
                } header: {
                    Text("Recent")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                }
            }
        }
    }

    private var searchResultsList: some View {
        Group {
            if viewModel.isSearching {
                HStack {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Searching...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else if viewModel.searchResults.isEmpty && !viewModel.query.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.title)
                        .foregroundStyle(.secondary)

                    Text("No results found")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                ForEach(Array(viewModel.searchResults.enumerated()), id: \.element.id) { index, result in
                    SearchResultRow(
                        result: result,
                        isSelected: viewModel.selectedIndex == index
                    )
                    .id(index)
                    .onTapGesture {
                        result.action()
                        viewModel.hide()
                    }
                }
            }
        }
    }
}

// MARK: - Command Row

private struct CommandRow: View {
    let command: PaletteCommand
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: command.iconName)
                .frame(width: 20)
                .foregroundStyle(.secondary)

            // Name and description
            VStack(alignment: .leading, spacing: 2) {
                Text(command.name)
                    .font(.body)

                if let description = command.description {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Shortcut
            if let shortcut = command.shortcut {
                Text(shortcut)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(4)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
        .contentShape(Rectangle())
    }
}

// MARK: - Recent Action Row

private struct RecentActionRow: View {
    let action: RecentAction
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: "clock")
                .frame(width: 20)
                .foregroundStyle(.secondary)

            // Name
            Text(action.name)
                .font(.body)

            Spacer()

            // Category
            Text(action.category)
                .font(.caption)
                .foregroundStyle(.secondary)

            // Time
            Text(action.timestamp, style: .relative)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
        .contentShape(Rectangle())
    }
}

// MARK: - Search Result Row

private struct SearchResultRow: View {
    let result: GlobalSearchResult
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Type icon
            Image(systemName: result.type.iconName)
                .frame(width: 20)
                .foregroundStyle(typeColor)

            // Title and subtitle
            VStack(alignment: .leading, spacing: 2) {
                Text(result.title)
                    .font(.body)
                    .lineLimit(1)

                if let subtitle = result.subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Type badge
            Text(result.type.rawValue)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(typeColor.opacity(0.1))
                .cornerRadius(4)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
        .contentShape(Rectangle())
    }

    private var typeColor: Color {
        switch result.type {
        case .file: return .blue
        case .commit: return .green
        case .branch: return .purple
        case .tag: return .orange
        case .stash: return .cyan
        case .command: return .secondary
        }
    }
}

// MARK: - Quick Actions View

/// Quick actions menu (can be used independently).
struct QuickActionsView: View {
    let actions: [QuickAction]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(actions) { action in
                Button(action: action.action) {
                    HStack(spacing: 12) {
                        Image(systemName: action.iconName)
                            .frame(width: 20)

                        Text(action.name)

                        Spacer()

                        if let shortcut = action.shortcut {
                            Text(shortcut)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(width: 200)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(radius: 8)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.gray.opacity(0.5)

        CommandPaletteView(
            viewModel: {
                let vm = CommandPaletteViewModel(
                    repository: Repository(rootURL: URL(fileURLWithPath: "/tmp")),
                    gitService: GitService()
                )
                vm.isVisible = true
                return vm
            }()
        )
    }
    .frame(width: 600, height: 500)
}
