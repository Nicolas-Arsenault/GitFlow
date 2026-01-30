import SwiftUI

// Notification name extension for clone repository action
extension Notification.Name {
    static let cloneRepository = Notification.Name("cloneRepository")
}

/// View for creating a new repository on a remote service (GitHub, GitLab, etc.)
struct CreateRemoteRepositoryView: View {
    @StateObject private var viewModel = CreateRemoteRepositoryViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Create Remote Repository")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
            }
            .padding()

            Divider()

            Form {
                // Service selection
                Section("Service") {
                    Picker("Create on", selection: $viewModel.selectedService) {
                        ForEach(RemoteService.allCases) { service in
                            HStack {
                                Image(systemName: service.icon)
                                    .foregroundColor(service.color)
                                Text(service.displayName)
                            }
                            .tag(service)
                        }
                    }
                    .pickerStyle(.menu)

                    if !viewModel.isServiceAuthenticated {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                            Text("Not signed in to \(viewModel.selectedService.displayName)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Repository details
                Section("Repository") {
                    TextField("Name", text: $viewModel.repositoryName)
                        .textFieldStyle(.roundedBorder)

                    TextField("Description (optional)", text: $viewModel.description, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(2...4)

                    Picker("Visibility", selection: $viewModel.visibility) {
                        Text("Public").tag(RepositoryVisibility.publicRepo)
                        Text("Private").tag(RepositoryVisibility.privateRepo)
                    }
                    .pickerStyle(.segmented)
                }

                // Options
                Section("Options") {
                    Toggle("Initialize with README", isOn: $viewModel.initializeWithReadme)

                    Picker("Add .gitignore", selection: $viewModel.gitignoreTemplate) {
                        Text("None").tag(Optional<String>.none)
                        ForEach(viewModel.gitignoreTemplates, id: \.self) { template in
                            Text(template).tag(Optional(template))
                        }
                    }

                    Picker("License", selection: $viewModel.license) {
                        Text("None").tag(Optional<String>.none)
                        ForEach(viewModel.licenses, id: \.self) { license in
                            Text(license).tag(Optional(license))
                        }
                    }
                }

                // Organization (if applicable)
                if !viewModel.organizations.isEmpty {
                    Section("Owner") {
                        Picker("Organization", selection: $viewModel.selectedOrganization) {
                            Text("Personal account").tag(Optional<String>.none)
                            ForEach(viewModel.organizations, id: \.self) { org in
                                Text(org).tag(Optional(org))
                            }
                        }
                    }
                }

                // Clone after creation
                Section {
                    Toggle("Clone repository after creation", isOn: $viewModel.cloneAfterCreation)

                    if viewModel.cloneAfterCreation {
                        HStack {
                            TextField("Clone location", text: $viewModel.clonePath)
                                .textFieldStyle(.roundedBorder)
                                .disabled(true)

                            Button("Browse...") {
                                viewModel.selectClonePath()
                            }
                        }
                    }
                }

                // Error message
                if let error = viewModel.error {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.circle")
                                .foregroundColor(.red)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .formStyle(.grouped)

            Divider()

            // Footer
            HStack {
                if viewModel.isCreating {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Creating repository...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button("Create Repository") {
                    viewModel.createRepository {
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.canCreate)
            }
            .padding()
        }
        .frame(width: 450, height: 600)
        .task {
            await viewModel.loadInitialData()
        }
    }
}

// MARK: - View Model

@MainActor
class CreateRemoteRepositoryViewModel: ObservableObject {
    @Published var selectedService: RemoteService = .github
    @Published var repositoryName: String = ""
    @Published var description: String = ""
    @Published var visibility: RepositoryVisibility = .publicRepo
    @Published var initializeWithReadme: Bool = true
    @Published var gitignoreTemplate: String?
    @Published var license: String?
    @Published var selectedOrganization: String?
    @Published var cloneAfterCreation: Bool = true
    @Published var clonePath: String = ""

    @Published var isServiceAuthenticated: Bool = false
    @Published var organizations: [String] = []
    @Published var isCreating: Bool = false
    @Published var error: String?

    let gitignoreTemplates = [
        "Swift", "Python", "JavaScript", "TypeScript", "Java", "Kotlin",
        "Go", "Rust", "Ruby", "C", "C++", "Node", "macOS", "Windows"
    ]

    let licenses = [
        "MIT", "Apache-2.0", "GPL-3.0", "BSD-3-Clause", "MPL-2.0",
        "Unlicense", "ISC", "LGPL-3.0"
    ]

    var canCreate: Bool {
        !repositoryName.isEmpty &&
        isServiceAuthenticated &&
        !isCreating &&
        repositoryName.isValidRepositoryName
    }

    init() {
        // Set default clone path
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        clonePath = documentsPath.appendingPathComponent("GitFlow").path
    }

    func loadInitialData() async {
        await checkAuthentication()
        await loadOrganizations()
    }

    func checkAuthentication() async {
        // Check if user is authenticated with the selected service
        switch selectedService {
        case .github:
            // Check GitHub auth
            isServiceAuthenticated = true // Placeholder
        }
    }

    func loadOrganizations() async {
        // Load organizations from the selected service
        switch selectedService {
        case .github:
            // Placeholder - would call GitHub API
            organizations = ["my-org", "other-org"]
        }
    }

    func selectClonePath() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Select"
        panel.message = "Select a location to clone the repository"

        if panel.runModal() == .OK, let url = panel.url {
            clonePath = url.path
        }
    }

    func createRepository(completion: @escaping () -> Void) {
        isCreating = true
        error = nil

        Task {
            do {
                let createdRepo = try await createRemoteRepository()

                if cloneAfterCreation, let cloneURL = createdRepo.cloneURL {
                    // Post notification to clone the repository
                    NotificationCenter.default.post(
                        name: .cloneRepository,
                        object: nil,
                        userInfo: [
                            "url": cloneURL,
                            "path": clonePath
                        ]
                    )
                }

                await MainActor.run {
                    isCreating = false
                    completion()
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    isCreating = false
                }
            }
        }
    }

    private func createRemoteRepository() async throws -> CreatedRepository {
        // Create repository based on selected service
        switch selectedService {
        case .github:
            return try await createGitHubRepository()
        }
    }

    private func createGitHubRepository() async throws -> CreatedRepository {
        // Would call GitHub API to create repository
        // POST /user/repos or POST /orgs/{org}/repos

        // Placeholder implementation
        return CreatedRepository(
            name: repositoryName,
            fullName: selectedOrganization.map { "\($0)/\(repositoryName)" } ?? repositoryName,
            cloneURL: "https://github.com/\(selectedOrganization ?? "user")/\(repositoryName).git",
            htmlURL: "https://github.com/\(selectedOrganization ?? "user")/\(repositoryName)"
        )
    }
}

// MARK: - Data Models

enum RemoteService: String, CaseIterable, Identifiable {
    case github

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .github: return "GitHub"
        }
    }

    var icon: String {
        switch self {
        case .github: return "arrow.triangle.branch"
        }
    }

    var color: Color {
        switch self {
        case .github: return .primary
        }
    }
}

enum RepositoryVisibility {
    case publicRepo
    case privateRepo
}

struct CreatedRepository {
    let name: String
    let fullName: String
    let cloneURL: String?
    let htmlURL: String?
}

// MARK: - String Extension

extension String {
    var isValidRepositoryName: Bool {
        // Repository names can contain alphanumeric characters, hyphens, underscores, and periods
        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
        let nameCharacters = CharacterSet(charactersIn: self)

        return !self.isEmpty &&
               nameCharacters.isSubset(of: allowedCharacters) &&
               !self.hasPrefix(".") &&
               !self.hasSuffix(".") &&
               !self.contains("..")
    }
}

// MARK: - Quick Create Button

struct QuickCreateRemoteRepoButton: View {
    @State private var showingSheet = false

    var body: some View {
        Button(action: { showingSheet = true }) {
            Label("New Remote Repository", systemImage: "plus.circle")
        }
        .sheet(isPresented: $showingSheet) {
            CreateRemoteRepositoryView()
        }
    }
}

#Preview {
    CreateRemoteRepositoryView()
}
