import SwiftUI

/// View displaying all tags with creation and management options.
struct TagListView: View {
    @ObservedObject var viewModel: TagViewModel

    @State private var showCreateTag: Bool = false
    @State private var tagToDelete: Tag?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Tags")
                    .font(.headline)

                Spacer()

                Button(action: { showCreateTag = true }) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                .help("Create new tag")

                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.6)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            // Tag list
            if viewModel.tags.isEmpty && !viewModel.isLoading {
                EmptyStateView(
                    "No Tags",
                    systemImage: "tag",
                    description: "Create tags to mark important commits"
                )
            } else {
                List(viewModel.tags, selection: $viewModel.selectedTag) { tag in
                    TagRow(tag: tag)
                        .tag(tag)
                        .contextMenu {
                            Button("Push to Remote") {
                                Task { await viewModel.pushTag(tag) }
                            }
                            Divider()
                            Button("Delete", role: .destructive) {
                                tagToDelete = tag
                            }
                        }
                }
                .listStyle(.inset)
            }

            // Footer
            if viewModel.hasTags {
                Divider()
                HStack {
                    Text("\(viewModel.tagCount) tag(s)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text("\(viewModel.annotatedTags.count) annotated")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
        }
        .sheet(isPresented: $showCreateTag) {
            CreateTagSheet(viewModel: viewModel, isPresented: $showCreateTag)
        }
        .confirmationDialog(
            "Delete Tag",
            isPresented: .init(
                get: { tagToDelete != nil },
                set: { if !$0 { tagToDelete = nil } }
            ),
            presenting: tagToDelete
        ) { tag in
            Button("Delete", role: .destructive) {
                Task { await viewModel.deleteTag(tag) }
            }
            Button("Cancel", role: .cancel) { }
        } message: { tag in
            Text("Are you sure you want to delete tag '\(tag.name)'? This cannot be undone.")
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

/// Row displaying a single tag.
struct TagRow: View {
    let tag: Tag

    var body: some View {
        HStack {
            Image(systemName: tag.isAnnotated ? "tag.fill" : "tag")
                .foregroundStyle(tag.isAnnotated ? .orange : .secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(tag.name)
                    .fontWeight(.medium)

                if let message = tag.message {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Text(String(tag.commitHash.prefix(7)))
                .font(.caption)
                .fontDesign(.monospaced)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

/// Sheet for creating a new tag.
struct CreateTagSheet: View {
    @ObservedObject var viewModel: TagViewModel
    @Binding var isPresented: Bool

    @State private var name: String = ""
    @State private var message: String = ""
    @State private var commitHash: String = ""
    @State private var isAnnotated: Bool = false

    var body: some View {
        VStack(spacing: 16) {
            Text("Create Tag")
                .font(.headline)

            Form {
                TextField("Tag Name", text: $name)
                    .textFieldStyle(.roundedBorder)

                TextField("Commit (optional, defaults to HEAD)", text: $commitHash)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))

                Toggle("Annotated Tag", isOn: $isAnnotated)

                if isAnnotated {
                    TextField("Message", text: $message, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...6)
                }
            }

            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Create") {
                    Task {
                        let hash = commitHash.isEmpty ? nil : commitHash
                        if isAnnotated {
                            await viewModel.createAnnotatedTag(
                                name: name,
                                message: message,
                                commitHash: hash
                            )
                        } else {
                            await viewModel.createLightweightTag(
                                name: name,
                                commitHash: hash
                            )
                        }
                        isPresented = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty || viewModel.isOperationInProgress || (isAnnotated && message.isEmpty))
            }
        }
        .padding()
        .frame(width: 400)
    }
}

#Preview {
    TagListView(
        viewModel: TagViewModel(
            repository: Repository(rootURL: URL(fileURLWithPath: "/tmp")),
            gitService: GitService()
        )
    )
    .frame(width: 300, height: 400)
}
