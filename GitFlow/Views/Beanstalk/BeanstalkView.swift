import SwiftUI

/// View for Beanstalk integration - browsing repos and managing code reviews.
struct BeanstalkView: View {
    @StateObject private var viewModel = BeanstalkViewModel()
    @State private var selectedSection: BeanstalkSection = .repositories
    @State private var showingAddAccountSheet = false

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedSection) {
                Section("Beanstalk") {
                    ForEach(BeanstalkSection.allCases) { section in
                        Label(section.title, systemImage: section.icon)
                            .tag(section)
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("Beanstalk")
        } detail: {
            if viewModel.isAuthenticated {
                switch selectedSection {
                case .repositories:
                    BeanstalkRepositoriesView(viewModel: viewModel)
                case .codeReviews:
                    BeanstalkCodeReviewsView(viewModel: viewModel)
                }
            } else {
                BeanstalkSignInView(viewModel: viewModel)
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
                                        Text(account.domain)
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
            BeanstalkAddAccountSheet(viewModel: viewModel)
        }
    }
}

// MARK: - Sections

enum BeanstalkSection: String, CaseIterable, Identifiable {
    case repositories
    case codeReviews

    var id: String { rawValue }

    var title: String {
        switch self {
        case .repositories: return "Repositories"
        case .codeReviews: return "Code Reviews"
        }
    }

    var icon: String {
        switch self {
        case .repositories: return "folder"
        case .codeReviews: return "doc.text.magnifyingglass"
        }
    }
}

// MARK: - Sign In View

struct BeanstalkSignInView: View {
    @ObservedObject var viewModel: BeanstalkViewModel

    @State private var domain = ""
    @State private var username = ""
    @State private var token = ""
    @State private var isAuthenticating = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "leaf.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)

            Text("Connect to Beanstalk")
                .font(.title)
                .fontWeight(.bold)

            Text("Sign in with your Beanstalk credentials to browse repositories and manage code reviews.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)

            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Account Domain")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack {
                        TextField("your-account", text: $domain)
                            .textFieldStyle(.roundedBorder)
                        Text(".beanstalkapp.com")
                            .foregroundColor(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Username")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("Your login username", text: $username)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Access Token")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    SecureField("Your access token", text: $token)
                        .textFieldStyle(.roundedBorder)
                }

                Text("Find your access token in Account Settings → Access Tokens")
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
            .tint(.green)
            .disabled(domain.isEmpty || username.isEmpty || token.isEmpty || isAuthenticating)
        }
        .padding(40)
    }

    private func authenticate() {
        isAuthenticating = true
        errorMessage = nil

        Task {
            do {
                try await viewModel.authenticate(domain: domain, username: username, token: token)
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

struct BeanstalkAddAccountSheet: View {
    @ObservedObject var viewModel: BeanstalkViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var domain = ""
    @State private var username = ""
    @State private var token = ""
    @State private var isAuthenticating = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Add Beanstalk Account")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
            }
            .padding()

            Divider()

            Form {
                Section {
                    HStack {
                        TextField("Account Domain", text: $domain)
                            .textFieldStyle(.roundedBorder)
                        Text(".beanstalkapp.com")
                            .foregroundColor(.secondary)
                    }

                    TextField("Username", text: $username)
                        .textFieldStyle(.roundedBorder)

                    SecureField("Access Token", text: $token)
                        .textFieldStyle(.roundedBorder)
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
                .tint(.green)
                .disabled(domain.isEmpty || username.isEmpty || token.isEmpty || isAuthenticating)
            }
            .padding()
        }
        .frame(width: 420, height: 360)
    }

    private func addAccount() {
        isAuthenticating = true
        errorMessage = nil

        Task {
            do {
                try await viewModel.addAccount(domain: domain, username: username, token: token)
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

struct BeanstalkRepositoriesView: View {
    @ObservedObject var viewModel: BeanstalkViewModel
    @State private var searchText = ""

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
                List(filteredRepositories) { repo in
                    BeanstalkRepoRow(repository: repo, onClone: { cloneRepository(repo) })
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

    private var filteredRepositories: [BeanstalkRepository] {
        if searchText.isEmpty {
            return viewModel.repositories
        }
        return viewModel.repositories.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            ($0.title?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No Repositories")
                .font(.headline)

            Text("No repositories found in your Beanstalk account.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func cloneRepository(_ repo: BeanstalkRepository) {
        if let cloneUrl = repo.cloneUrl {
            NotificationCenter.default.post(
                name: .cloneRepository,
                object: nil,
                userInfo: ["url": cloneUrl]
            )
        }
    }
}

struct BeanstalkRepoRow: View {
    let repository: BeanstalkRepository
    let onClone: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: repository.isGit ? "arrow.triangle.branch" : "folder.fill")
                .font(.title2)
                .foregroundColor(.green)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(repository.title ?? repository.name)
                        .font(.headline)

                    Text(repository.type.uppercased())
                        .font(.caption2)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(repository.isGit ? Color.blue.opacity(0.2) : Color.orange.opacity(0.2))
                        .foregroundColor(repository.isGit ? .blue : .orange)
                        .cornerRadius(3)
                }

                Text(repository.name)
                    .font(.caption)
                    .foregroundColor(.secondary)

                if let lastCommit = repository.lastCommitAt {
                    Text("Last commit: \(lastCommit)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if isHovering && repository.isGit {
                Button("Clone") {
                    onClone()
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
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

// MARK: - Code Reviews View

struct BeanstalkCodeReviewsView: View {
    @ObservedObject var viewModel: BeanstalkViewModel
    @State private var stateFilter: BeanstalkCodeReviewState = .pending

    var body: some View {
        VStack(spacing: 0) {
            // Filter
            HStack {
                Picker("State", selection: $stateFilter) {
                    Text("Pending").tag(BeanstalkCodeReviewState.pending)
                    Text("Approved").tag(BeanstalkCodeReviewState.approved)
                    Text("Rejected").tag(BeanstalkCodeReviewState.rejected)
                    Text("All").tag(BeanstalkCodeReviewState.all)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 300)

                Spacer()

                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                }

                Button(action: { Task { await viewModel.loadCodeReviews(state: stateFilter) } }) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
            }
            .padding(8)

            Divider()

            if viewModel.codeReviews.isEmpty && !viewModel.isLoading {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)

                    Text("No Code Reviews")
                        .font(.headline)

                    Text("No \(stateFilter.rawValue) code reviews found.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(viewModel.codeReviews) { review in
                    BeanstalkCodeReviewRow(review: review)
                }
                .listStyle(.inset)
            }
        }
        .navigationTitle("Code Reviews")
        .onChange(of: stateFilter) { newValue in
            Task { await viewModel.loadCodeReviews(state: newValue) }
        }
        .task {
            if viewModel.codeReviews.isEmpty {
                await viewModel.loadCodeReviews(state: stateFilter)
            }
        }
    }
}

struct BeanstalkCodeReviewRow: View {
    let review: BeanstalkCodeReview

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("#\(review.id)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(review.description ?? "No description")
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                statusBadge
            }

            HStack(spacing: 12) {
                Label("\(review.revisionList.count) revisions", systemImage: "clock.arrow.circlepath")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if let created = review.createdAt {
                    Text(created)
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
        switch review.state {
        case "pending":
            return (.orange, "Pending")
        case "approved":
            return (.green, "Approved")
        case "rejected":
            return (.red, "Rejected")
        default:
            return (.secondary, review.state)
        }
    }
}

// MARK: - View Model

@MainActor
class BeanstalkViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var currentAccount: BeanstalkAccount?
    @Published var accounts: [BeanstalkAccount] = []
    @Published var repositories: [BeanstalkRepository] = []
    @Published var codeReviews: [BeanstalkCodeReview] = []
    @Published var error: String?

    private let service = BeanstalkService.shared
    private let accountStore = BeanstalkAccountStore.shared

    init() {
        accounts = accountStore.accounts
        if let current = accountStore.currentAccount {
            currentAccount = current
            Task {
                _ = try? await service.authenticate(domain: current.domain, username: current.username, token: current.token)
                await MainActor.run {
                    isAuthenticated = true
                }
            }
        }
    }

    func authenticate(domain: String, username: String, token: String) async throws {
        isLoading = true
        defer { isLoading = false }

        let user = try await service.authenticate(domain: domain, username: username, token: token)

        let account = BeanstalkAccount(
            domain: domain,
            username: username,
            displayName: user.displayName,
            email: user.email,
            token: token
        )

        accountStore.addAccount(account)
        accounts = accountStore.accounts
        currentAccount = account
        isAuthenticated = true
    }

    func addAccount(domain: String, username: String, token: String) async throws {
        try await authenticate(domain: domain, username: username, token: token)
    }

    func switchAccount(_ account: BeanstalkAccount) {
        accountStore.switchToAccount(account)
        currentAccount = account

        Task {
            _ = try? await service.authenticate(domain: account.domain, username: account.username, token: account.token)
            await loadRepositories()
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
        codeReviews = []
    }

    func loadRepositories() async {
        isLoading = true
        defer { isLoading = false }

        do {
            repositories = try await service.listRepositories()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func loadCodeReviews(state: BeanstalkCodeReviewState) async {
        isLoading = true
        defer { isLoading = false }

        // Would need to iterate over repos to get code reviews
        // For simplicity, just clear the list for now
        codeReviews = []
    }
}

#Preview {
    BeanstalkView()
        .frame(width: 800, height: 600)
}
