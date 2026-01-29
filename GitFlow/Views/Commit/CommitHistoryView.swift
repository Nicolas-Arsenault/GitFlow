import SwiftUI

/// View displaying commit history as a list.
struct CommitHistoryView: View {
    @ObservedObject var viewModel: HistoryViewModel

    @State private var showFilters: Bool = false
    @State private var searchText: String = ""
    @State private var showGraph: Bool = true
    @State private var graphNodes: [CommitGraphNode] = []

    private let graphBuilder = CommitGraphBuilder()
    private let rowHeight: CGFloat = 44

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("History")
                    .font(.headline)

                if viewModel.hasActiveFilters {
                    Button(action: {
                        Task { await viewModel.clearAllFilters() }
                    }) {
                        Label("Clear Filters", systemImage: "xmark.circle.fill")
                            .labelStyle(.iconOnly)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Clear all filters")
                }

                Spacer()

                Button(action: { showGraph.toggle() }) {
                    Image(systemName: showGraph ? "point.3.connected.trianglepath.dotted" : "point.3.filled.connected.trianglepath.dotted")
                }
                .buttonStyle(.plain)
                .foregroundStyle(showGraph ? .blue : .secondary)
                .help("Toggle commit graph")

                Button(action: { showFilters.toggle() }) {
                    Image(systemName: showFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                }
                .buttonStyle(.plain)
                .foregroundStyle(viewModel.hasActiveFilters ? .blue : .secondary)
                .help("Filter commits")

                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.6)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Search commits...", text: $searchText)
                    .textFieldStyle(.plain)
                    .onSubmit {
                        Task { await viewModel.searchByMessage(searchText) }
                    }

                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                        Task { await viewModel.searchByMessage("") }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Clear search")
                }
            }
            .padding(8)
            .background(Color(NSColor.textBackgroundColor))
            .cornerRadius(6)
            .padding(.horizontal)
            .padding(.bottom, 8)

            // Filter panel
            if showFilters {
                CommitFilterPanel(viewModel: viewModel)
            }

            // Active filters summary
            if let summary = viewModel.filterSummary {
                HStack {
                    Image(systemName: "line.3.horizontal.decrease")
                        .foregroundStyle(.blue)
                    Text(summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.1))
            }

            Divider()

            // Commit list
            if viewModel.commits.isEmpty && !viewModel.isLoading {
                if viewModel.hasActiveFilters {
                    EmptyStateView(
                        "No Matching Commits",
                        systemImage: "magnifyingglass",
                        description: "No commits match your search criteria"
                    )
                } else {
                    EmptyStateView(
                        "No Commits",
                        systemImage: "clock",
                        description: "This repository has no commits yet"
                    )
                }
            } else {
                ScrollViewReader { scrollProxy in
                    ScrollView {
                        HStack(alignment: .top, spacing: 0) {
                            // Commit graph
                            if showGraph && !graphNodes.isEmpty {
                                CommitGraphView(
                                    nodes: graphNodes,
                                    selectedCommitId: viewModel.selectedCommit?.hash,
                                    rowHeight: rowHeight
                                )
                                .padding(.leading, 8)
                            }

                            // Commit rows
                            LazyVStack(alignment: .leading, spacing: 0) {
                                ForEach(viewModel.commits) { commit in
                                    CommitRow(commit: commit)
                                        .frame(height: rowHeight)
                                        .background(
                                            viewModel.selectedCommit?.hash == commit.hash
                                                ? Color.accentColor.opacity(0.2)
                                                : Color.clear
                                        )
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            viewModel.selectedCommit = commit
                                        }
                                        .id(commit.hash)
                                        .onAppear {
                                            // Load more when approaching the end
                                            if commit.hash == viewModel.commits.last?.hash && viewModel.hasMore {
                                                Task { await viewModel.loadMore() }
                                            }
                                        }
                                }

                                // Loading indicator at bottom
                                if viewModel.hasMore {
                                    HStack {
                                        Spacer()
                                        ProgressView()
                                            .scaleEffect(0.7)
                                        Text("Loading more...")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                    }
                                    .frame(height: rowHeight)
                                }
                            }
                        }
                    }
                    .onChange(of: viewModel.selectedCommit) { newValue in
                        if let hash = newValue?.hash {
                            withAnimation {
                                scrollProxy.scrollTo(hash, anchor: .center)
                            }
                        }
                    }
                }
            }
        }
        .onChange(of: viewModel.commits) { newCommits in
            // Rebuild graph when commits change (async to not block UI)
            if showGraph {
                Task {
                    let commits = newCommits
                    let builder = graphBuilder
                    let nodes = await Task.detached(priority: .userInitiated) {
                        builder.buildGraph(from: commits)
                    }.value
                    graphNodes = nodes
                }
            }
        }
        .onAppear {
            if showGraph && graphNodes.isEmpty {
                Task {
                    let commits = viewModel.commits
                    let builder = graphBuilder
                    let nodes = await Task.detached(priority: .userInitiated) {
                        builder.buildGraph(from: commits)
                    }.value
                    graphNodes = nodes
                }
            }
        }
        .onChange(of: showGraph) { newValue in
            if newValue && graphNodes.isEmpty {
                Task {
                    let commits = viewModel.commits
                    let builder = graphBuilder
                    let nodes = await Task.detached(priority: .userInitiated) {
                        builder.buildGraph(from: commits)
                    }.value
                    graphNodes = nodes
                }
            }
        }
        .onChange(of: searchText) { newValue in
            // Debounce search - only search after typing stops
            Task {
                try? await Task.sleep(nanoseconds: 300_000_000) // 300ms
                if searchText == newValue && !newValue.isEmpty {
                    await viewModel.searchByMessage(newValue)
                }
            }
        }
    }
}

/// Filter panel for commit history.
private struct CommitFilterPanel: View {
    @ObservedObject var viewModel: HistoryViewModel

    @State private var authorInput: String = ""
    @State private var sinceDate: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var untilDate: Date = Date()
    @State private var useDateFilter: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Author filter
            HStack {
                Text("Author:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 60, alignment: .trailing)

                TextField("Filter by author...", text: $authorInput)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        Task { await viewModel.filterByAuthor(authorInput) }
                    }
            }

            // Date range filter
            HStack(alignment: .top) {
                Text("Date:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 60, alignment: .trailing)

                VStack(alignment: .leading, spacing: 4) {
                    Toggle("Filter by date range", isOn: $useDateFilter)
                        .toggleStyle(.checkbox)

                    if useDateFilter {
                        HStack {
                            DatePicker("From", selection: $sinceDate, displayedComponents: .date)
                                .labelsHidden()

                            Text("to")
                                .foregroundStyle(.secondary)

                            DatePicker("To", selection: $untilDate, displayedComponents: .date)
                                .labelsHidden()
                        }
                    }
                }
            }

            // Apply button
            HStack {
                Spacer()

                Button("Clear") {
                    authorInput = ""
                    useDateFilter = false
                    Task { await viewModel.clearAllFilters() }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                Button("Apply Filters") {
                    Task {
                        viewModel.authorFilter = authorInput
                        viewModel.sinceDate = useDateFilter ? sinceDate : nil
                        viewModel.untilDate = useDateFilter ? untilDate : nil
                        await viewModel.applyFilters()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))

        Divider()
    }
}

#Preview {
    CommitHistoryView(
        viewModel: HistoryViewModel(
            repository: Repository(rootURL: URL(fileURLWithPath: "/tmp")),
            gitService: GitService()
        )
    )
    .frame(width: 350, height: 400)
}
