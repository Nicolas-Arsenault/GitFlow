import SwiftUI

/// View for Gitea/Forgejo integration - browsing repos and managing PRs.
struct GiteaView: View {
    @StateObject private var viewModel = GiteaViewModel()
    @State private var selectedSection: GiteaSection = .repositories
    @State private var showingAddAccountSheet = false

    var body: some View {
        NavigationSplitView {
            // Sidebar
            List(selection: $selectedSection) {
                Section("Gitea") {
                    ForEach(GiteaSection.allCases) { section in
                        Label(section.title, systemImage: section.icon)
                            .tag(section)
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("Gitea")
        } detail: {
            if viewModel.isAuthenticated {
                switch selectedSection {
                case .repositories:
                    GiteaRepositoriesView(viewModel: viewModel)
                case .pullRequests:
                    GiteaPullRequestsView(viewModel: viewModel)
                case .organizations:
                    GiteaOrganizationsView(viewModel: viewModel)
                }
            } else {
                GiteaSignInView(viewModel: viewModel)
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if viewModel.isAuthenticated {
                    Menu {
                        ForEach(viewModel.accounts) { account in
                            Button(action: { viewModel.switchAccount(account) }) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(account.displayName)
                                        Text(account.serverDisplayName)
                                            .font(.caption)
                                    }
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
                        Label(viewModel.currentAccount?.displayName ?? "Account", systemImage: "person.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddAccountSheet) {
            GiteaAddAccountSheet(viewModel: viewModel)
        }
    }
}

// MARK: - Sections

enum GiteaSection: String, CaseIterable, Identifiable {
    case repositories
    case pullRequests
    case organizations

    var id: String { rawValue }

    var title: String {
        switch self {
        case .repositories: return "Repositories"
        case .pullRequests: return "Pull Requests"
        case .organizations: return "Organizations"
        }
    }

    var icon: String {
        switch self {
        case .repositories: return "folder"
        case .pullRequests: return "arrow.triangle.pull"
        case .organizations: return "building.2"
        }
    }
}

// MARK: - Sign In View

struct GiteaSignInView: View {
    @ObservedObject var viewModel: GiteaViewModel

    @State private var serverURL = "https://"
    @State private var token = ""
    @State private var isAuthenticating = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 24) {
            // Gitea logo placeholder
            Image(systemName: "cup.and.saucer.fill")
                .font(.system(size: 64))
                .foregroundColor(.orange)

            Text("Connect to Gitea")
                .font(.title)
                .fontWeight(.bold)

            Text("Sign in with a Personal Access Token to browse repositories and manage pull requests from your Gitea or Forgejo instance.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)

            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Server URL")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("https://gitea.example.com", text: $serverURL)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Personal Access Token")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    SecureField("Token with repo scope", text: $token)
                        .textFieldStyle(.roundedBorder)
                }

                Text("Create a token in Settings → Applications → Generate New Token")
                    .font(.caption)
                    .foregroundColor(.secondary)
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
            .tint(.orange)
            .disabled(serverURL.isEmpty || token.isEmpty || isAuthenticating)

            VStack(spacing: 8) {
                Text("Supported platforms:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                HStack(spacing: 16) {
                    Label("Gitea", systemImage: "cup.and.saucer")
                    Label("Forgejo", systemImage: "leaf")
                    Label("Codeberg", systemImage: "mountain.2")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
        .padding(40)
    }

    private func authenticate() {
        isAuthenticating = true
        errorMessage = nil

        Task {
            do {
                try await viewModel.authenticate(serverURL: serverURL, token: token)
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

struct GiteaAddAccountSheet: View {
    @ObservedObject var viewModel: GiteaViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var serverURL = "https://"
    @State private var token = ""
    @State private var isAuthenticating = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Add Gitea Account")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
            }
            .padding()

            Divider()

            Form {
                Section {
                    TextField("Server URL", text: $serverURL)
                        .textFieldStyle(.roundedBorder)

                    SecureField("Personal Access Token", text: $token)
                        .textFieldStyle(.roundedBorder)
                }

                Section {
                    Text("Popular Gitea instances:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack(spacing: 8) {
                        Button("Codeberg") {
                            serverURL = "https://codeberg.org"
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Button("Gitea.com") {
                            serverURL = "https://gitea.com"
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
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
                .tint(.orange)
                .disabled(serverURL.isEmpty || token.isEmpty || isAuthenticating)
            }
            .padding()
        }
        .frame(width: 400, height: 380)
    }

    private func addAccount() {
        isAuthenticating = true
        errorMessage = nil

        Task {
            do {
                try await viewModel.addAccount(serverURL: serverURL, token: token)
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

struct GiteaRepositoriesView: View {
    @ObservedObject var viewModel: GiteaViewModel
    @State private var searchText = ""
    @State private var selectedRepo: GiteaRepository?

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
            }
            .padding(8)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            if viewModel.repositories.isEmpty && !viewModel.isLoading {
                emptyStateView
            } else {
                List(filteredRepositories, selection: $selectedRepo) { repo in
                    GiteaRepoRow(repository: repo, onClone: { cloneRepository(repo) })
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

    private var filteredRepositories: [GiteaRepository] {
        if searchText.isEmpty {
            return viewModel.repositories
        }
        return viewModel.repositories.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            ($0.description?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No Repositories")
                .font(.headline)

            Text("No repositories found in your Gitea account.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func cloneRepository(_ repo: GiteaRepository) {
        if let cloneUrl = repo.cloneUrl {
            NotificationCenter.default.post(
                name: .cloneRepository,
                object: nil,
                userInfo: ["url": cloneUrl]
            )
        }
    }
}

struct GiteaRepoRow: View {
    let repository: GiteaRepository
    let onClone: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: repository.isPrivate == true ? "lock.fill" : "folder.fill")
                .font(.title2)
                .foregroundColor(.orange)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(repository.name)
                        .font(.headline)

                    if repository.isFork == true {
                        Image(systemName: "tuningfork")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if repository.archived == true {
                        Text("Archived")
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.secondary.opacity(0.2))
                            .cornerRadius(3)
                    }
                }

                if let description = repository.description, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                HStack(spacing: 12) {
                    if let stars = repository.starsCount, stars > 0 {
                        Label("\(stars)", systemImage: "star")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if let forks = repository.forksCount, forks > 0 {
                        Label("\(forks)", systemImage: "tuningfork")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if let branch = repository.defaultBranch {
                        Label(branch, systemImage: "arrow.triangle.branch")
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
                .tint(.orange)
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

struct GiteaPullRequestsView: View {
    @ObservedObject var viewModel: GiteaViewModel
    @State private var selectedPR: GiteaPullRequest?
    @State private var stateFilter: GiteaPRState = .open

    var body: some View {
        HSplitView {
            // PR List
            VStack(spacing: 0) {
                // Filter
                HStack {
                    Picker("State", selection: $stateFilter) {
                        Text("Open").tag(GiteaPRState.open)
                        Text("Closed").tag(GiteaPRState.closed)
                        Text("All").tag(GiteaPRState.all)
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 200)

                    Spacer()

                    if viewModel.isLoading {
                        ProgressView()
                            .scaleEffect(0.7)
                    }

                    Button(action: { Task { await viewModel.loadPullRequests(state: stateFilter) } }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.borderless)
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

                        Text("No \(stateFilter.rawValue) pull requests found.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(viewModel.pullRequests, selection: $selectedPR) { pr in
                        GiteaPRRow(pullRequest: pr)
                    }
                    .listStyle(.inset)
                }
            }
            .frame(minWidth: 300)

            // PR Detail
            if let pr = selectedPR {
                GiteaPRDetailView(pullRequest: pr, viewModel: viewModel)
            } else {
                VStack {
                    Text("Select a pull request")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Pull Requests")
        .onChange(of: stateFilter) { newValue in
            Task { await viewModel.loadPullRequests(state: newValue) }
        }
        .task {
            if viewModel.pullRequests.isEmpty {
                await viewModel.loadPullRequests(state: stateFilter)
            }
        }
    }
}

struct GiteaPRRow: View {
    let pullRequest: GiteaPullRequest

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("#\(pullRequest.number)")
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
                if let head = pullRequest.head {
                    Label(head.ref, systemImage: "arrow.triangle.branch")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if let base = pullRequest.base {
                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Label(base.ref, systemImage: "arrow.triangle.branch")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if let user = pullRequest.user {
                    Text(user.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
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
        if pullRequest.merged == true {
            return (.purple, "Merged")
        }
        switch pullRequest.state {
        case "open":
            return (.green, "Open")
        case "closed":
            return (.red, "Closed")
        default:
            return (.secondary, pullRequest.state)
        }
    }
}

struct GiteaPRDetailView: View {
    let pullRequest: GiteaPullRequest
    @ObservedObject var viewModel: GiteaViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("#\(pullRequest.number)")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text(pullRequest.title)
                            .font(.title2)
                            .fontWeight(.bold)
                    }

                    HStack(spacing: 16) {
                        if let user = pullRequest.user {
                            Label(user.displayName, systemImage: "person")
                        }
                        if let created = pullRequest.createdAt {
                            Label(created, systemImage: "calendar")
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }

                Divider()

                // Branches
                HStack(spacing: 16) {
                    if let head = pullRequest.head {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Source")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Label(head.ref, systemImage: "arrow.triangle.branch")
                                .font(.subheadline)
                        }
                    }

                    Image(systemName: "arrow.right")
                        .foregroundColor(.secondary)

                    if let base = pullRequest.base {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Target")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Label(base.ref, systemImage: "arrow.triangle.branch")
                                .font(.subheadline)
                        }
                    }
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)

                // Description
                if let body = pullRequest.body, !body.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description")
                            .font(.headline)

                        Text(body)
                            .font(.body)
                    }
                }

                Divider()

                // Actions
                if pullRequest.state == "open" {
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

                        if pullRequest.mergeable == true {
                            Button("Merge") {
                                // Add merge action
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.purple)
                        }
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Organizations View

struct GiteaOrganizationsView: View {
    @ObservedObject var viewModel: GiteaViewModel

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.organizations.isEmpty && !viewModel.isLoading {
                VStack(spacing: 12) {
                    Image(systemName: "building.2")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)

                    Text("No Organizations")
                        .font(.headline)

                    Text("You're not a member of any organizations.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(viewModel.organizations) { org in
                    HStack(spacing: 12) {
                        if let avatarUrl = org.avatarUrl, let url = URL(string: avatarUrl) {
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Image(systemName: "building.2.fill")
                                    .foregroundColor(.orange)
                            }
                            .frame(width: 40, height: 40)
                            .cornerRadius(8)
                        } else {
                            Image(systemName: "building.2.fill")
                                .font(.title2)
                                .foregroundColor(.orange)
                                .frame(width: 40, height: 40)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(org.displayName)
                                .font(.headline)

                            if let description = org.description, !description.isEmpty {
                                Text(description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                        }

                        Spacer()

                        if let visibility = org.visibility {
                            Text(visibility)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(.inset)
            }
        }
        .navigationTitle("Organizations")
        .task {
            if viewModel.organizations.isEmpty {
                await viewModel.loadOrganizations()
            }
        }
    }
}

// MARK: - View Model

@MainActor
class GiteaViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var currentAccount: GiteaAccount?
    @Published var accounts: [GiteaAccount] = []
    @Published var repositories: [GiteaRepository] = []
    @Published var pullRequests: [GiteaPullRequest] = []
    @Published var organizations: [GiteaOrganization] = []
    @Published var error: String?

    private let service = GiteaService.shared
    private let accountStore = GiteaAccountStore.shared

    init() {
        accounts = accountStore.accounts
        if let current = accountStore.currentAccount {
            currentAccount = current
            Task {
                _ = try? await service.authenticate(serverURL: current.serverURL, token: current.token)
                await MainActor.run {
                    isAuthenticated = true
                }
            }
        }
    }

    func authenticate(serverURL: String, token: String) async throws {
        isLoading = true
        defer { isLoading = false }

        let user = try await service.authenticate(serverURL: serverURL, token: token)

        let account = GiteaAccount(
            serverURL: serverURL,
            username: user.login,
            displayName: user.displayName,
            email: user.email,
            token: token
        )

        accountStore.addAccount(account)
        accounts = accountStore.accounts
        currentAccount = account
        isAuthenticated = true
    }

    func addAccount(serverURL: String, token: String) async throws {
        try await authenticate(serverURL: serverURL, token: token)
    }

    func switchAccount(_ account: GiteaAccount) {
        accountStore.switchToAccount(account)
        currentAccount = account

        Task {
            _ = try? await service.authenticate(serverURL: account.serverURL, token: account.token)

            // Reload data for new account
            await loadRepositories()
            await loadPullRequests(state: .open)
            await loadOrganizations()
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
        organizations = []
    }

    func loadRepositories() async {
        isLoading = true
        defer { isLoading = false }

        do {
            repositories = try await service.listUserRepositories()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func loadPullRequests(state: GiteaPRState) async {
        isLoading = true
        defer { isLoading = false }

        // Would need to iterate over repos to get all PRs
        // For now, just clear the list
        pullRequests = []
    }

    func loadOrganizations() async {
        isLoading = true
        defer { isLoading = false }

        do {
            organizations = try await service.listOrganizations()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

#Preview {
    GiteaView()
        .frame(width: 900, height: 600)
}
