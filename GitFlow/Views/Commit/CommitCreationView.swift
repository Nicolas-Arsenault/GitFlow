import SwiftUI

/// View for creating a new commit.
struct CommitCreationView: View {
    @ObservedObject var viewModel: CommitViewModel
    let canCommit: Bool

    @FocusState private var isMessageFocused: Bool
    @State private var showAdvancedOptions: Bool = false
    @State private var showAuthorSheet: Bool = false
    @State private var showTemplatePicker: Bool = false
    @State private var selectedTemplate: CommitTemplate?
    @State private var showPlaceholderSheet: Bool = false
    @StateObject private var templateStore = TemplatePickerStore()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Text(viewModel.modeIndicator)
                    .font(.headline)

                if viewModel.isAmending {
                    Button(action: { viewModel.cancelAmending() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Cancel amending")
                }

                Spacer()

                // Character count
                Text(viewModel.subjectLengthIndicator)
                    .font(.caption)
                    .foregroundStyle(subjectLengthColor)

                // Options button
                Button(action: { showAdvancedOptions.toggle() }) {
                    Image(systemName: "ellipsis.circle")
                }
                .buttonStyle(.plain)
                .help("Commit options")
            }
            .padding(.horizontal)
            .padding(.top, 8)

            // Advanced options (when expanded)
            if showAdvancedOptions {
                VStack(alignment: .leading, spacing: 8) {
                    // GPG signing
                    if viewModel.gpgSigningAvailable {
                        Toggle(isOn: $viewModel.signWithGPG) {
                            HStack {
                                Image(systemName: "signature")
                                Text("Sign with GPG")
                                if let keyId = viewModel.gpgKeyId {
                                    Text("(\(keyId.prefix(8))...)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .toggleStyle(.checkbox)
                    }

                    // Author override
                    HStack {
                        if let author = viewModel.authorOverride {
                            Label(author, systemImage: "person.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Button("Clear") {
                                viewModel.clearAuthorOverride()
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.blue)
                            .font(.caption)
                        } else {
                            Button(action: { showAuthorSheet = true }) {
                                Label("Override Author", systemImage: "person")
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                        }
                    }

                    // Amend option
                    if !viewModel.isAmending {
                        Button(action: {
                            Task { await viewModel.startAmending() }
                        }) {
                            Label("Amend Last Commit", systemImage: "arrow.uturn.backward")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 4)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            }

            // Message input with spell checking enabled
            SpellCheckTextEditor(text: $viewModel.commitMessage, placeholder: viewModel.isAmending ? "Enter new commit message..." : "Enter commit message...")
                .frame(minHeight: 80, maxHeight: 150)
                .focused($isMessageFocused)
                .padding(.horizontal)

            // Guidelines
            if !viewModel.commitMessage.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    if viewModel.isSubjectTooLong {
                        Label(
                            viewModel.isSubjectWayTooLong
                                ? "Subject should be under 72 characters"
                                : "Subject ideally under 50 characters",
                            systemImage: "exclamationmark.triangle"
                        )
                        .font(.caption2)
                        .foregroundStyle(viewModel.isSubjectWayTooLong ? .red : .orange)
                    }
                }
                .padding(.horizontal)
            }

            // Actions
            HStack {
                Button("Clear") {
                    viewModel.clearMessage()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .disabled(viewModel.commitMessage.isEmpty)

                // Template picker menu
                Menu {
                    if templateStore.templates.isEmpty {
                        Text("No templates available")
                    } else {
                        ForEach(CommitTemplate.Category.allCases) { category in
                            let categoryTemplates = templateStore.templates.filter { $0.category == category }
                            if !categoryTemplates.isEmpty {
                                Section(category.rawValue) {
                                    ForEach(categoryTemplates) { template in
                                        Button {
                                            applyTemplate(template)
                                        } label: {
                                            Label(template.name, systemImage: category.icon)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Divider()

                    Button {
                        NSWorkspace.shared.open(URL(string: "gitflow://settings/templates")!)
                    } label: {
                        Label("Manage Templates...", systemImage: "gear")
                    }
                } label: {
                    Label("Template", systemImage: "doc.text")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .task {
                    templateStore.loadTemplates()
                }

                Spacer()

                // Amend without message change button
                if viewModel.isAmending {
                    Button("Amend (keep message)") {
                        Task { await viewModel.amendNoEdit() }
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.isCommitting)
                }

                Button(action: {
                    Task {
                        await viewModel.createCommit()
                    }
                }) {
                    if viewModel.isCommitting {
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(width: 80)
                    } else {
                        Text(viewModel.isAmending ? "Amend" : "Commit")
                            .frame(width: 80)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canCommit || !viewModel.isMessageValid || viewModel.isCommitting)
                .keyboardShortcut(.return, modifiers: .command)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .background(Color(NSColor.controlBackgroundColor))
        .alert("Commit failed", isPresented: .init(
            get: { viewModel.error != nil },
            set: { if !$0 { viewModel.error = nil } }
        )) {
            Button("Dismiss") { viewModel.error = nil }
        } message: {
            if let error = viewModel.error {
                Text(error.localizedDescription)
            }
        }
        .sheet(isPresented: $showAuthorSheet) {
            AuthorOverrideSheet(viewModel: viewModel, isPresented: $showAuthorSheet)
        }
        .sheet(isPresented: $showPlaceholderSheet) {
            if let template = selectedTemplate {
                TemplatePlaceholderSheet(
                    template: template,
                    isPresented: $showPlaceholderSheet,
                    onApply: { content in
                        viewModel.commitMessage = content
                    }
                )
            }
        }
        .task {
            await viewModel.loadInitialData()
        }
    }

    private func applyTemplate(_ template: CommitTemplate) {
        // Defer state changes to avoid "Publishing changes from within view updates" warning
        Task { @MainActor in
            if template.hasPlaceholders {
                selectedTemplate = template
                showPlaceholderSheet = true
            } else {
                viewModel.commitMessage = template.content
            }
        }
    }

    private var subjectLengthColor: Color {
        if viewModel.isSubjectWayTooLong {
            return .red
        } else if viewModel.isSubjectTooLong {
            return .orange
        }
        return .secondary
    }
}

/// Sheet for overriding commit author.
private struct AuthorOverrideSheet: View {
    @ObservedObject var viewModel: CommitViewModel
    @Binding var isPresented: Bool

    @State private var name: String = ""
    @State private var email: String = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Override Author")
                    .font(.headline)
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Close")
            }
            .padding()

            Divider()

            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Name")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Author Name", text: $name)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Email")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("author@example.com", text: $email)
                        .textFieldStyle(.roundedBorder)
                }
            }
            .padding()

            Divider()

            HStack {
                Spacer()

                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Button("Apply") {
                    viewModel.setAuthor(name: name, email: email)
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty || email.isEmpty)
            }
            .padding()
        }
        .frame(width: 300)
    }
}

// MARK: - Template Picker Store

/// Simple store for loading templates in commit view.
@MainActor
private final class TemplatePickerStore: ObservableObject {
    @Published var templates: [CommitTemplate] = []

    private let store = CommitTemplateStore()

    func loadTemplates() {
        templates = store.loadAll()
    }
}

// MARK: - Template Placeholder Sheet

/// Sheet for filling in template placeholders.
private struct TemplatePlaceholderSheet: View {
    let template: CommitTemplate
    @Binding var isPresented: Bool
    let onApply: (String) -> Void

    @State private var placeholderValues: [String: String] = [:]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Fill in Template")
                    .font(.headline)

                Spacer()

                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Close")
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: DSSpacing.md) {
                    // Template info
                    HStack {
                        Image(systemName: template.category.icon)
                            .foregroundStyle(.secondary)
                        Text(template.name)
                            .fontWeight(.medium)
                        Spacer()
                    }
                    .padding(.bottom, DSSpacing.sm)

                    // Placeholder fields
                    ForEach(template.placeholderNames, id: \.self) { placeholder in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(placeholder.capitalized)
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            if placeholder.lowercased().contains("description") ||
                               placeholder.lowercased().contains("body") ||
                               placeholder.lowercased().contains("message") {
                                TextEditor(text: binding(for: placeholder))
                                    .font(.system(.body, design: .monospaced))
                                    .frame(minHeight: 60, maxHeight: 100)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4)
                                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                                    )
                            } else {
                                TextField("Enter \(placeholder)...", text: binding(for: placeholder))
                                    .textFieldStyle(.roundedBorder)
                            }
                        }
                    }

                    // Preview
                    if !placeholderValues.isEmpty {
                        Divider()
                            .padding(.vertical, DSSpacing.sm)

                        Text("Preview")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(previewContent)
                            .font(.system(.body, design: .monospaced))
                            .padding(DSSpacing.sm)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(DSRadius.sm)
                    }
                }
                .padding()
            }

            Divider()

            // Footer
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Apply Template") {
                    let content = template.apply(placeholders: placeholderValues)
                    onApply(content)
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 400, height: 450)
        .onAppear {
            // Initialize placeholder values
            for name in template.placeholderNames {
                placeholderValues[name] = ""
            }
        }
    }

    private func binding(for placeholder: String) -> Binding<String> {
        Binding(
            get: { placeholderValues[placeholder] ?? "" },
            set: { placeholderValues[placeholder] = $0 }
        )
    }

    private var previewContent: String {
        template.apply(placeholders: placeholderValues)
    }
}

#Preview {
    VStack {
        Spacer()
        CommitCreationView(
            viewModel: CommitViewModel(
                repository: Repository(rootURL: URL(fileURLWithPath: "/tmp")),
                gitService: GitService()
            ),
            canCommit: true
        )
    }
    .frame(width: 300, height: 300)
}

#Preview {
    VStack {
        Spacer()
        CommitCreationView(
            viewModel: CommitViewModel(
                repository: Repository(rootURL: URL(fileURLWithPath: "/tmp")),
                gitService: GitService()
            ),
            canCommit: true
        )
    }
    .frame(width: 300, height: 300)
}
