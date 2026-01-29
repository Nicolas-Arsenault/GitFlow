import SwiftUI

/// View for Azure DevOps integration - browsing repos and managing PRs.
struct AzureDevOpsView: View {
    @StateObject private var viewModel = AzureDevOpsViewModel()
    @State private var selectedSection: AzureDevOpsSection = .repositories
    @State private var showingAddAccountSheet = false

    var body: some View {
        NavigationSplitView {
            // Sidebar
            List(selection: $selectedSection) {
                Section("Azure DevOps") {
                    ForEach(AzureDevOpsSection.allCases) { section in
                        Label(section.title, systemImage: section.icon)
                            .tag(section)
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("Azure DevOps")
        } detail: {
            if viewModel.isAuthenticated {
                switch selectedSection {
                case .repositories:
                    AzureDevOpsRepositoriesView(viewModel: viewModel)
                case .pullRequests:
                    AzureDevOpsPullRequestsView(viewModel: viewModel)
                case .projects:
                    AzureDevOpsProjectsView(viewModel: viewModel)
                }
            } else {
                AzureDevOpsSignInView(viewModel: viewModel)
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if viewModel.isAuthenticated {
                    Menu {
                        ForEach(viewModel.accounts) { account in
                            Button(action: { viewModel.switchAccount(account) }) {
                                HStack {
                                    Text(account.organization)
                                    if account.id == viewModel.currentAccount?.id {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }

                        Divider()

                        Button("Add Account...") {
                            showingAddAccountSheet = true
                        }

                        Button("Sign Out") {
                            viewModel.signOut()
                        }
                    } label: {
                        Label(viewModel.currentAccount?.organization ?? "Account", systemImage: "person.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddAccountSheet) {
            AzureDevOpsAddAccountSheet(viewModel: viewModel)
        }
    }
}

// MARK: - Sections

enum AzureDevOpsSection: String, CaseIterable, Identifiable {
    case repositories
    case pullRequests
    case projects

    var id: String { rawValue }

    var title: String {
        switch self {
        case .repositories: return "Repositories"
        case .pullRequests: return "Pull Requests"
        case .projects: return "Projects"
        }
    }

    var icon: String {
        switch self {
        case .repositories: return "folder"
        case .pullRequests: return "arrow.triangle.pull"
        case .projects: return "square.stack.3d.up"
        }
    }
}

// MARK: - Sign In View

struct AzureDevOpsSignInView: View {
    @ObservedObject var viewModel: AzureDevOpsViewModel

    @State private var organization = ""
    @State private var token = ""
    @State private var isAuthenticating = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "cloud.fill")
                .font(.system(size: 64))
                .foregroundColor(.blue)

            Text("Connect to Azure DevOps")
                .font(.title)
                .fontWeight(.bold)

            Text("Sign in with a Personal Access Token to browse repositories and manage pull requests.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)

            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Organization")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("your-organization", text: $organization)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Personal Access Token")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    SecureField("PAT with Code and Pull Requests scope", text: $token)
                        .textFieldStyle(.roundedBorder)
                }

                Link("Create a Personal Access Token", destination: URL(string: "https://dev.azure.com/\(organization.isEmpty ? "YOUR_ORG" : organization)/_usersSettings/tokens")!)
                    .font(.caption)
            }
            .frame(width: 350)

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            Button(action: authenticate) {
                if isAuthenticating {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Text("Sign In")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(organization.isEmpty || token.isEmpty || isAuthenticating)
        }
        .padding(40)
    }

    private func authenticate() {
        isAuthenticating = true
        errorMessage = nil

        Task {
            do {
                try await viewModel.authenticate(organization: organization, token: token)
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
            await MainActor.run {
                isAuthenticating = false
            }
        }
    }
}

// MARK: - Add Account Sheet

struct AzureDevOpsAddAccountSheet: View {
    @ObservedObject var viewModel: AzureDevOpsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var organization = ""
    @State private var token = ""
    @State private var isAuthenticating = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Add Azure DevOps Account")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
            }
            .padding()

            Divider()

            Form {
                Section {
                    TextField("Organization", text: $organization)
                        .textFieldStyle(.roundedBorder)

                    SecureField("Personal Access Token", text: $token)
                        .textFieldStyle(.roundedBorder)

                    Link("Create a Personal Access Token", destination: URL(string: "https://dev.azure.com/\(organization.isEmpty ? "YOUR_ORG" : organization)/_usersSettings/tokens")!)
                        .font(.caption)
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
            }
            .formStyle(.grouped)
            .padding()

            Divider()

            HStack {
                Spacer()

                Button("Add Account") {
                    addAccount()
                }
                .buttonStyle(.borderedProminent)
                .disabled(organization.isEmpty || token.isEmpty || isAuthenticating)
            }
            .padding()
        }
        .frame(width: 400, height: 320)
    }

    private func addAccount() {
        isAuthenticating = true
        errorMessage = nil

        Task {
            do {
                try await viewModel.addAccount(organization: organization, token: token)
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isAuthenticating = false
                }
            }
        }
    }
}

// MARK: - Repositories View

struct AzureDevOpsRepositoriesView: View {
    @ObservedObject var viewModel: AzureDevOpsViewModel
    @State private var searchText = ""
    @State private var selectedRepo: AzureDevOpsRepository?

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search repositories...", text: $searchText)
                    .textFieldStyle(.plain)

                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                }

                Button(action: { Task { await viewModel.loadRepositories() } }) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Refresh repositories")
            }
            .padding(8)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            if viewModel.repositories.isEmpty && !viewModel.isLoading {
                emptyStateView
            } else {
                List(filteredRepositories, selection: $selectedRepo) { repo in
                    AzureDevOpsRepoRow(repository: repo, onClone: { cloneRepository(repo) })
                }
                .listStyle(.inset)
            }
        }
        .navigationTitle("Repositories")
        .task {
            if viewModel.repositories.isEmpty {
                await viewModel.loadRepositories()
            }
        }
    }

    private var filteredRepositories: [AzureDevOpsRepository] {
        if searchText.isEmpty {
            return viewModel.repositories
        }
        return viewModel.repositories.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.project.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No Repositories")
                .font(.headline)

            Text("No repositories found in your Azure DevOps organization.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func cloneRepository(_ repo: AzureDevOpsRepository) {
        // Post notification to trigger clone
        NotificationCenter.default.post(
            name: .cloneRepository,
            object: nil,
            userInfo: ["url": repo.remoteUrl]
        )
    }
}

struct AzureDevOpsRepoRow: View {
    let repository: AzureDevOpsRepository
    let onClone: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "folder.fill")
                .font(.title2)
                .foregroundColor(.blue)

            VStack(alignment: .leading, spacing: 4) {
                Text(repository.name)
                    .font(.headline)

                HStack(spacing: 8) {
                    Label(repository.project.name, systemImage: "square.stack.3d.up")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if let branch = repository.defaultBranch {
                        Label(branch.replacingOccurrences(of: "refs/heads/", with: ""), systemImage: "arrow.triangle.branch")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            if isHovering {
                Button("Clone") {
                    onClone()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

// MARK: - Pull Requests View

struct AzureDevOpsPullRequestsView: View {
    @ObservedObject var viewModel: AzureDevOpsViewModel
    @State private var selectedPR: AzureDevOpsPullRequest?
    @State private var statusFilter: AzureDevOpsPRStatus = .active

    var body: some View {
        HSplitView {
            // PR List
            VStack(spacing: 0) {
                // Filter
                HStack {
                    Picker("Status", selection: $statusFilter) {
                        Text("Active").tag(AzureDevOpsPRStatus.active)
                        Text("Completed").tag(AzureDevOpsPRStatus.completed)
                        Text("Abandoned").tag(AzureDevOpsPRStatus.abandoned)
                        Text("All").tag(AzureDevOpsPRStatus.all)
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 300)

                    Spacer()

                    if viewModel.isLoading {
                        ProgressView()
                            .scaleEffect(0.7)
                    }

                    Button(action: { Task { await viewModel.loadPullRequests(status: statusFilter) } }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.borderless)
                    .help("Refresh pull requests")
                }
                .padding(8)

                Divider()

                if viewModel.pullRequests.isEmpty && !viewModel.isLoading {
                    VStack(spacing: 12) {
                        Image(systemName: "arrow.triangle.pull")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)

                        Text("No Pull Requests")
                            .font(.headline)

                        Text("No \(statusFilter.rawValue) pull requests found.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(viewModel.pullRequests, selection: $selectedPR) { pr in
                        AzureDevOpsPRRow(pullRequest: pr)
                    }
                    .listStyle(.inset)
                }
            }
            .frame(minWidth: 300)

            // PR Detail
            if let pr = selectedPR {
                AzureDevOpsPRDetailView(pullRequest: pr, viewModel: viewModel)
            } else {
                VStack {
                    Text("Select a pull request")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Pull Requests")
        .onChange(of: statusFilter) { newValue in
            Task { await viewModel.loadPullRequests(status: newValue) }
        }
        .task {
            if viewModel.pullRequests.isEmpty {
                await viewModel.loadPullRequests(status: statusFilter)
            }
        }
    }
}

struct AzureDevOpsPRRow: View {
    let pullRequest: AzureDevOpsPullRequest

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("#\(pullRequest.pullRequestId)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(pullRequest.title)
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                if pullRequest.isDraft == true {
                    Text("Draft")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(4)
                }

                statusBadge
            }

            HStack(spacing: 12) {
                Label(pullRequest.sourceBranch, systemImage: "arrow.triangle.branch")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Image(systemName: "arrow.right")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Label(pullRequest.targetBranch, systemImage: "arrow.triangle.branch")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Text(pullRequest.createdBy.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var statusBadge: some View {
        let (color, text) = statusInfo
        Text(text)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(4)
    }

    private var statusInfo: (Color, String) {
        switch pullRequest.status {
        case "active":
            return (.blue, "Active")
        case "completed":
            return (.green, "Completed")
        case "abandoned":
            return (.secondary, "Abandoned")
        default:
            return (.secondary, pullRequest.status)
        }
    }
}

struct AzureDevOpsPRDetailView: View {
    let pullRequest: AzureDevOpsPullRequest
    @ObservedObject var viewModel: AzureDevOpsViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("#\(pullRequest.pullRequestId)")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text(pullRequest.title)
                            .font(.title2)
                            .fontWeight(.bold)
                    }

                    HStack(spacing: 16) {
                        Label(pullRequest.createdBy.displayName, systemImage: "person")
                        Label(pullRequest.creationDate, systemImage: "calendar")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }

                Divider()

                // Branches
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Source")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Label(pullRequest.sourceBranch, systemImage: "arrow.triangle.branch")
                            .font(.subheadline)
                    }

                    Image(systemName: "arrow.right")
                        .foregroundColor(.secondary)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Target")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Label(pullRequest.targetBranch, systemImage: "arrow.triangle.branch")
                            .font(.subheadline)
                    }
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)

                // Description
                if let description = pullRequest.description, !description.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description")
                            .font(.headline)

                        Text(description)
                            .font(.body)
                    }
                }

                // Reviewers
                if let reviewers = pullRequest.reviewers, !reviewers.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Reviewers")
                            .font(.headline)

                        ForEach(reviewers) { reviewer in
                            HStack {
                                Text(reviewer.displayName)
                                Spacer()
                                reviewerVoteBadge(vote: reviewer.vote)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                Divider()

                // Actions
                if pullRequest.status == "active" {
                    HStack {
                        Button("Approve") {
                            // Add approve action
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)

                        Button("Request Changes") {
                            // Add request changes action
                        }
                        .buttonStyle(.bordered)

                        Spacer()

                        Button("Complete") {
                            // Add complete action
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Abandon") {
                            // Add abandon action
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                    }
                }
            }
            .padding()
        }
    }

    @ViewBuilder
    private func reviewerVoteBadge(vote: Int) -> some View {
        let (color, text, icon) = voteInfo(vote)
        Label(text, systemImage: icon)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(4)
    }

    private func voteInfo(_ vote: Int) -> (Color, String, String) {
        switch vote {
        case 10:
            return (.green, "Approved", "checkmark.circle.fill")
        case 5:
            return (.green, "Approved with suggestions", "checkmark.circle")
        case 0:
            return (.secondary, "No vote", "circle")
        case -5:
            return (.orange, "Waiting", "clock")
        case -10:
            return (.red, "Rejected", "xmark.circle.fill")
        default:
            return (.secondary, "Unknown", "questionmark.circle")
        }
    }
}

// MARK: - Projects View

struct AzureDevOpsProjectsView: View {
    @ObservedObject var viewModel: AzureDevOpsViewModel

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.projects.isEmpty && !viewModel.isLoading {
                VStack(spacing: 12) {
                    Image(systemName: "square.stack.3d.up")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)

                    Text("No Projects")
                        .font(.headline)

                    Text("No projects found in your organization.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(viewModel.projects) { project in
                    HStack(spacing: 12) {
                        Image(systemName: "square.stack.3d.up.fill")
                            .font(.title2)
                            .foregroundColor(.purple)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(project.name)
                                .font(.headline)

                            if let description = project.description {
                                Text(description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                        }

                        Spacer()

                        Text(project.state)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(.inset)
            }
        }
        .navigationTitle("Projects")
        .task {
            if viewModel.projects.isEmpty {
                await viewModel.loadProjects()
            }
        }
    }
}

// MARK: - View Model

@MainActor
class AzureDevOpsViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var currentAccount: AzureDevOpsAccount?
    @Published var accounts: [AzureDevOpsAccount] = []
    @Published var repositories: [AzureDevOpsRepository] = []
    @Published var pullRequests: [AzureDevOpsPullRequest] = []
    @Published var projects: [AzureDevOpsProject] = []
    @Published var error: String?

    private let service = AzureDevOpsService.shared
    private let accountStore = AzureDevOpsAccountStore.shared

    init() {
        accounts = accountStore.accounts
        if let current = accountStore.currentAccount {
            currentAccount = current
            Task {
                _ = try? await service.authenticate(organization: current.organization, token: current.token)
                await MainActor.run {
                    isAuthenticated = true
                }
            }
        }
    }

    func authenticate(organization: String, token: String) async throws {
        isLoading = true
        defer { isLoading = false }

        let user = try await service.authenticate(organization: organization, token: token)

        let account = AzureDevOpsAccount(
            organization: organization,
            displayName: user.displayName,
            email: user.emailAddress,
            token: token
        )

        accountStore.addAccount(account)
        accounts = accountStore.accounts
        currentAccount = account
        isAuthenticated = true
    }

    func addAccount(organization: String, token: String) async throws {
        try await authenticate(organization: organization, token: token)
    }

    func switchAccount(_ account: AzureDevOpsAccount) {
        accountStore.switchToAccount(account)
        currentAccount = account

        Task {
            _ = try? await service.authenticate(organization: account.organization, token: account.token)

            // Reload data for new account
            await loadRepositories()
            await loadPullRequests(status: .active)
            await loadProjects()
        }
    }

    func signOut() {
        if let account = currentAccount {
            accountStore.removeAccount(account)
        }
        accounts = accountStore.accounts
        currentAccount = accountStore.currentAccount
        isAuthenticated = accounts.count > 0

        Task {
            await service.signOut()
        }

        repositories = []
        pullRequests = []
        projects = []
    }

    func loadRepositories() async {
        isLoading = true
        defer { isLoading = false }

        do {
            repositories = try await service.listAllRepositories()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func loadPullRequests(status: AzureDevOpsPRStatus) async {
        isLoading = true
        defer { isLoading = false }

        do {
            var allPRs: [AzureDevOpsPullRequest] = []
            for repo in repositories {
                let prs = try await service.listPullRequests(
                    projectId: repo.project.id,
                    repositoryId: repo.id,
                    status: status
                )
                allPRs.append(contentsOf: prs)
            }
            pullRequests = allPRs.sorted { $0.pullRequestId > $1.pullRequestId }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func loadProjects() async {
        isLoading = true
        defer { isLoading = false }

        do {
            projects = try await service.listProjects()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// MARK: - Notification Extension

extension Notification.Name {
    static let cloneRepository = Notification.Name("cloneRepository")
}

#Preview {
    AzureDevOpsView()
        .frame(width: 900, height: 600)
}
