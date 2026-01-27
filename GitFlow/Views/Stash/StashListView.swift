import SwiftUI

/// View displaying all stashes.
struct StashListView: View {
    @ObservedObject var viewModel: StashViewModel

    @State private var showCreateStash: Bool = false
    @State private var stashToDelete: Stash?
    @State private var showClearConfirmation: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Stashes")
                    .font(.headline)

                Spacer()

                Button(action: { showCreateStash = true }) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                .help("Create new stash")

                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.6)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            // Stash list
            if viewModel.stashes.isEmpty && !viewModel.isLoading {
                EmptyStateView(
                    "No Stashes",
                    systemImage: "tray",
                    description: "Stash your changes to save them for later"
                )
            } else {
                List(viewModel.stashes, selection: $viewModel.selectedStash) { stash in
                    StashRow(stash: stash)
                        .tag(stash)
                        .contextMenu {
                            Button("Apply") {
                                Task { await viewModel.applyStash(stash) }
                            }
                            Button("Pop") {
                                Task { await viewModel.popStash(stash) }
                            }
                            Divider()
                            Button("Drop", role: .destructive) {
                                stashToDelete = stash
                            }
                        }
                }
                .listStyle(.inset)
            }

            // Footer with actions
            if viewModel.hasStashes {
                Divider()
                HStack {
                    Button("Clear All", role: .destructive) {
                        showClearConfirmation = true
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.red)

                    Spacer()

                    Text("\(viewModel.stashCount) stash(es)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
        }
        .sheet(isPresented: $showCreateStash) {
            CreateStashSheet(viewModel: viewModel, isPresented: $showCreateStash)
        }
        .confirmationDialog(
            "Drop Stash",
            isPresented: .init(
                get: { stashToDelete != nil },
                set: { if !$0 { stashToDelete = nil } }
            ),
            presenting: stashToDelete
        ) { stash in
            Button("Drop", role: .destructive) {
                Task { await viewModel.dropStash(stash) }
            }
            Button("Cancel", role: .cancel) { }
        } message: { stash in
            Text("Are you sure you want to drop '\(stash.message)'? This cannot be undone.")
        }
        .confirmationDialog(
            "Clear All Stashes",
            isPresented: $showClearConfirmation
        ) {
            Button("Clear All", role: .destructive) {
                Task { await viewModel.clearAllStashes() }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to clear all \(viewModel.stashCount) stashes? This cannot be undone.")
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
}

/// Row displaying a single stash.
struct StashRow: View {
    let stash: Stash

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(stash.refName)
                    .font(.caption)
                    .fontDesign(.monospaced)
                    .foregroundStyle(.secondary)

                if let branch = stash.branch {
                    Text("on \(branch)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(stash.date.formatted(.relative(presentation: .named)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(stash.message)
                .lineLimit(2)
        }
        .padding(.vertical, 4)
    }
}

/// Sheet for creating a new stash.
struct CreateStashSheet: View {
    @ObservedObject var viewModel: StashViewModel
    @Binding var isPresented: Bool

    @State private var message: String = ""
    @State private var includeUntracked: Bool = false

    var body: some View {
        VStack(spacing: 16) {
            Text("Create Stash")
                .font(.headline)

            Form {
                TextField("Message (optional)", text: $message)
                    .textFieldStyle(.roundedBorder)

                Toggle("Include untracked files", isOn: $includeUntracked)
            }

            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Stash") {
                    Task {
                        await viewModel.createStash(
                            message: message.isEmpty ? nil : message,
                            includeUntracked: includeUntracked
                        )
                        isPresented = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(viewModel.isOperationInProgress)
            }
        }
        .padding()
        .frame(width: 350)
    }
}

#Preview {
    StashListView(
        viewModel: StashViewModel(
            repository: Repository(rootURL: URL(fileURLWithPath: "/tmp")),
            gitService: GitService()
        )
    )
    .frame(width: 300, height: 400)
}
