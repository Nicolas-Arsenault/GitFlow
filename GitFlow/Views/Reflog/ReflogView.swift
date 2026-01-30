import SwiftUI

/// View displaying the Git reflog.
/// Shows a chronological list of reference updates that can be used to recover lost commits.
struct ReflogView: View {
    @ObservedObject var viewModel: ReflogViewModel

    @State private var showCreateBranchSheet: Bool = false
    @State private var entryForBranch: ReflogEntry?
    @State private var showCheckoutConfirmation: Bool = false
    @State private var entryToCheckout: ReflogEntry?

    // Local selection state to avoid "Publishing changes from within view updates" warning
    @State private var localSelectedEntry: ReflogEntry?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            ReflogHeaderView(viewModel: viewModel)

            Divider()

            // Filter bar (when entries exist)
            if viewModel.hasEntries {
                ReflogFilterBar(viewModel: viewModel)
                Divider()
            }

            // Content
            if viewModel.isLoading && viewModel.entries.isEmpty {
                LoadingView("Loading reflog...")
            } else if viewModel.entries.isEmpty {
                EmptyStateView(
                    "No Reflog Entries",
                    systemImage: "clock.arrow.circlepath",
                    description: "The reflog records when branch tips are updated"
                )
            } else {
                List(viewModel.filteredEntries, selection: $localSelectedEntry) { entry in
                    ReflogEntryRow(entry: entry)
                        .tag(entry)
                        .contextMenu {
                            contextMenuItems(for: entry)
                        }
                }
                .listStyle(.inset)
                .onChange(of: localSelectedEntry) { newValue in
                    // Defer sync to view model to avoid "Publishing changes from within view updates"
                    Task { @MainActor in
                        viewModel.selectedEntry = newValue
                    }
                }
            }

            // Footer
            if viewModel.hasEntries {
                Divider()
                ReflogFooterView(viewModel: viewModel)
            }
        }
        .sheet(item: $entryForBranch) { entry in
            CreateBranchFromReflogSheet(
                viewModel: viewModel,
                entry: entry,
                isPresented: .init(
                    get: { entryForBranch != nil },
                    set: { if !$0 { entryForBranch = nil } }
                )
            )
        }
        .confirmationDialog(
            "Checkout Commit",
            isPresented: $showCheckoutConfirmation,
            presenting: entryToCheckout
        ) { entry in
            Button("Checkout") {
                Task { await viewModel.checkoutEntry(entry) }
            }
            Button("Cancel", role: .cancel) { }
        } message: { entry in
            Text("This will put your repository in a 'detached HEAD' state at commit \(entry.shortHash). You may want to create a branch first.")
        }
        .alert("Error", isPresented: .init(
            get: { viewModel.error != nil },
            set: { if !$0 { viewModel.error = nil } }
        )) {
            Button("OK") { viewModel.error = nil }
        } message: {
            if let error = viewModel.error {
                Text(error.localizedDescription)
            }
        }
    }

    @ViewBuilder
    private func contextMenuItems(for entry: ReflogEntry) -> some View {
        Button {
            entryToCheckout = entry
            showCheckoutConfirmation = true
        } label: {
            Label("Checkout", systemImage: "arrow.uturn.right")
        }

        Button {
            entryForBranch = entry
        } label: {
            Label("Create Branch From Here", systemImage: "arrow.triangle.branch")
        }

        Divider()

        Button {
            Task { await viewModel.cherryPickEntry(entry) }
        } label: {
            Label("Cherry-pick", systemImage: "arrow.right.doc.on.clipboard")
        }

        Divider()

        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(entry.hash, forType: .string)
        } label: {
            Label("Copy Full Hash", systemImage: "doc.on.doc")
        }

        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(entry.shortHash, forType: .string)
        } label: {
            Label("Copy Short Hash", systemImage: "doc.on.doc")
        }
    }
}

/// Header view for the reflog.
struct ReflogHeaderView: View {
    @ObservedObject var viewModel: ReflogViewModel

    var body: some View {
        HStack {
            Text("Reflog")
                .font(.headline)

            if let branch = viewModel.branchFilter {
                Text("(\(branch))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button {
                    viewModel.branchFilter = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Show all reflog entries")
            }

            Spacer()

            Button {
                Task { await viewModel.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help("Refresh reflog")
            .disabled(viewModel.isLoading)

            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(0.6)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

/// Filter bar for searching and filtering reflog entries.
struct ReflogFilterBar: View {
    @ObservedObject var viewModel: ReflogViewModel

    var body: some View {
        HStack(spacing: DSSpacing.sm) {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Filter reflog...", text: $viewModel.searchQuery)
                    .textFieldStyle(.plain)

                if !viewModel.searchQuery.isEmpty {
                    Button {
                        viewModel.searchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(6)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(DSRadius.sm)

            // Action type filter
            Picker("Action", selection: $viewModel.actionFilter) {
                Text("All Actions").tag(nil as ReflogAction?)
                Divider()
                ForEach(viewModel.availableActions, id: \.self) { action in
                    Label(action.description, systemImage: action.iconName)
                        .tag(action as ReflogAction?)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 150)

            // Clear filters button
            if viewModel.hasActiveFilter {
                Button("Clear") {
                    viewModel.clearFilters()
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, DSSpacing.sm)
    }
}

/// Footer view showing entry count.
struct ReflogFooterView: View {
    @ObservedObject var viewModel: ReflogViewModel

    var body: some View {
        HStack {
            if viewModel.hasActiveFilter {
                Text("\(viewModel.entryCount) of \(viewModel.totalEntryCount) entries")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("\(viewModel.entryCount) entries")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Load More") {
                Task { await viewModel.loadMore() }
            }
            .buttonStyle(.borderless)
            .font(.caption)
            .disabled(viewModel.isLoading)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

/// Row displaying a single reflog entry.
struct ReflogEntryRow: View {
    let entry: ReflogEntry

    var body: some View {
        HStack(alignment: .top, spacing: DSSpacing.sm) {
            // Action icon
            Image(systemName: entry.action.iconName)
                .foregroundStyle(actionColor)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                // Top row: action, selector, time
                HStack {
                    Text(entry.action.description)
                        .font(DSTypography.secondaryContent())
                        .fontWeight(.medium)

                    Text(entry.selector)
                        .font(.caption)
                        .fontDesign(.monospaced)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text(entry.date.formatted(.relative(presentation: .named)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Message
                Text(entry.shortSummary)
                    .font(DSTypography.primaryContent())
                    .lineLimit(2)

                // Bottom row: hash and author
                HStack {
                    Text(entry.shortHash)
                        .font(.caption)
                        .fontDesign(.monospaced)
                        .foregroundStyle(.secondary)

                    Text("by \(entry.authorName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var actionColor: Color {
        switch entry.action {
        case .commit, .commitInitial, .commitAmend, .commitMerge:
            return DSColors.addition
        case .checkout, .branch:
            return DSColors.info
        case .reset, .rebaseAbort:
            return DSColors.warning
        case .merge, .cherryPick:
            return DSColors.modification
        case .rebase, .rebaseInteractive, .rebaseFinish:
            return DSColors.rename
        default:
            return .secondary
        }
    }
}

/// Sheet for creating a branch from a reflog entry.
struct CreateBranchFromReflogSheet: View {
    @ObservedObject var viewModel: ReflogViewModel
    let entry: ReflogEntry
    @Binding var isPresented: Bool

    @State private var branchName: String = ""

    var body: some View {
        VStack(spacing: DSSpacing.lg) {
            Text("Create Branch")
                .font(.headline)

            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                Text("Create a new branch from this reflog entry:")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                // Entry info
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(entry.shortHash)
                            .fontDesign(.monospaced)
                        Text(entry.action.description)
                            .foregroundStyle(.secondary)
                    }
                    Text(entry.shortSummary)
                        .lineLimit(2)
                        .foregroundStyle(.secondary)
                }
                .padding(DSSpacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(DSRadius.sm)

                TextField("Branch name", text: $branchName)
                    .textFieldStyle(.roundedBorder)

                if !branchName.isEmpty && !isValidBranchName {
                    Text("Invalid branch name")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Create Branch") {
                    Task {
                        await viewModel.createBranch(named: branchName, from: entry)
                        isPresented = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(branchName.isEmpty || !isValidBranchName || viewModel.isOperationInProgress)
            }
        }
        .padding()
        .frame(width: 400)
    }

    private var isValidBranchName: Bool {
        // Basic validation for branch names
        let invalidCharacters = CharacterSet(charactersIn: " ~^:?*[\\")
        return branchName.rangeOfCharacter(from: invalidCharacters) == nil &&
               !branchName.hasPrefix("-") &&
               !branchName.hasPrefix(".") &&
               !branchName.hasSuffix(".lock") &&
               !branchName.contains("..")
    }
}

#Preview {
    ReflogView(
        viewModel: ReflogViewModel(
            repository: Repository(rootURL: URL(fileURLWithPath: "/tmp")),
            gitService: GitService()
        )
    )
    .frame(width: 500, height: 600)
}
