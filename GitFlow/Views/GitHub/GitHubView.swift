import SwiftUI

/// Main view for GitHub integration.
struct GitHubView: View {
    @ObservedObject var viewModel: GitHubViewModel

    @State private var selectedTab: Tab = .pullRequests
    @State private var showTokenSheet: Bool = false

    enum Tab: String, CaseIterable, Identifiable {
        case pullRequests = "Pull Requests"
        case issues = "Issues"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .pullRequests: return "arrow.triangle.pull"
            case .issues: return "exclamationmark.circle"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            GitHubHeader(
                viewModel: viewModel,
                showTokenSheet: $showTokenSheet
            )

            Divider()

            // Content
            if !viewModel.isGitHubRepository {
                notGitHubView
            } else if !viewModel.isAuthenticated {
                notAuthenticatedView
            } else {
                authenticatedContent
            }
        }
        .task {
            await viewModel.initialize()
        }
        .sheet(isPresented: $showTokenSheet) {
            GitHubTokenSheet(token: $viewModel.githubToken, isPresented: $showTokenSheet)
        }
        .alert("GitHub Error", isPresented: .init(
            get: { viewModel.error != nil },
            set: { if !$0 { viewModel.error = nil } }
        )) {
            Button("Dismiss") { viewModel.error = nil }
        } message: {
            if let error = viewModel.error {
                Text(error.localizedDescription)
            }
        }
    }

    private var notGitHubView: some View {
        EmptyStateView(
            "Not a GitHub Repository",
            systemImage: "xmark.octagon",
            description: "This repository is not hosted on GitHub"
        )
    }

    private var notAuthenticatedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.shield")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("GitHub Authentication Required")
                .font(.headline)

            Text("Add a GitHub personal access token to view issues and pull requests.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Add Token") {
                showTokenSheet = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var authenticatedContent: some View {
        VStack(spacing: 0) {
            // Tab picker
            Picker("Tab", selection: $selectedTab) {
                ForEach(Tab.allCases) { tab in
                    Label(tab.rawValue, systemImage: tab.icon)
                        .tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            // State filter
            Picker("State", selection: $viewModel.stateFilter) {
                ForEach(GitHubViewModel.StateFilter.allCases) { filter in
                    Text(filter.displayName).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            Divider()
                .padding(.top, 8)

            // Content based on tab
            switch selectedTab {
            case .pullRequests:
                PullRequestsListView(viewModel: viewModel)
            case .issues:
                IssuesListView(viewModel: viewModel)
            }
        }
    }
}

// MARK: - Header

private struct GitHubHeader: View {
    @ObservedObject var viewModel: GitHubViewModel
    @Binding var showTokenSheet: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Image(systemName: "square.grid.3x1.folder.badge.plus")
                    Text("GitHub")
                        .font(.headline)
                }

                if let info = viewModel.githubInfo {
                    Text("\(info.owner)/\(info.repo)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Status
            Text(viewModel.statusSummary)
                .font(.caption)
                .foregroundStyle(.secondary)

            // Actions
            if viewModel.isGitHubRepository {
                Menu {
                    Button(action: { viewModel.openRepositoryInBrowser() }) {
                        Label("Open in Browser", systemImage: "safari")
                    }

                    Button(action: { viewModel.openActionsInBrowser() }) {
                        Label("View Actions", systemImage: "play.circle")
                    }

                    Divider()

                    Button(action: { showTokenSheet = true }) {
                        Label(viewModel.isAuthenticated ? "Change Token" : "Add Token", systemImage: "key")
                    }

                    if viewModel.isAuthenticated {
                        Button(action: { Task { await viewModel.refresh() } }) {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
                .frame(width: 24)
            }

            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(0.6)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

// MARK: - Pull Requests List

private struct PullRequestsListView: View {
    @ObservedObject var viewModel: GitHubViewModel

    var body: some View {
        Group {
            if viewModel.pullRequests.isEmpty && !viewModel.isLoading {
                EmptyStateView(
                    "No Pull Requests",
                    systemImage: "arrow.triangle.pull",
                    description: "No \(viewModel.stateFilter.rawValue) pull requests"
                )
            } else {
                List(viewModel.pullRequests) { pr in
                    PullRequestRow(pr: pr)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            viewModel.openPullRequestInBrowser(pr)
                        }
                        .contextMenu {
                            Button("Open in Browser") {
                                viewModel.openPullRequestInBrowser(pr)
                            }
                        }
                }
                .listStyle(.inset)
            }
        }
        .task {
            await viewModel.loadPullRequests()
        }
        .onChange(of: viewModel.stateFilter) {
            Task { await viewModel.loadPullRequests() }
        }
    }
}

private struct PullRequestRow: View {
    let pr: GitHubPullRequest

    var body: some View {
        HStack(spacing: 12) {
            // Status icon
            Image(systemName: statusIcon)
                .foregroundStyle(statusColor)

            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text("#\(pr.number)")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)

                    Text(pr.title)
                        .lineLimit(1)
                }

                HStack(spacing: 8) {
                    Text(pr.user.login)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(pr.head.ref)
                        .font(.caption.monospaced())
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(4)

                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Text(pr.base.ref)
                        .font(.caption.monospaced())
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(4)
                }

                // Labels
                if !pr.labels.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(pr.labels.prefix(3)) { label in
                            Text(label.name)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(hex: label.color)?.opacity(0.2) ?? Color.secondary.opacity(0.1))
                                .cornerRadius(4)
                        }
                        if pr.labels.count > 3 {
                            Text("+\(pr.labels.count - 3)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Spacer()

            // Stats
            if let additions = pr.additions, let deletions = pr.deletions {
                HStack(spacing: 4) {
                    Text("+\(additions)")
                        .font(.caption.monospaced())
                        .foregroundStyle(.green)
                    Text("-\(deletions)")
                        .font(.caption.monospaced())
                        .foregroundStyle(.red)
                }
            }

            // Draft badge
            if pr.isDraft {
                Text("Draft")
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(4)
            }
        }
        .padding(.vertical, 4)
    }

    private var statusIcon: String {
        if pr.isMerged {
            return "arrow.triangle.merge"
        } else if pr.isOpen {
            return "arrow.triangle.pull"
        } else {
            return "xmark.circle"
        }
    }

    private var statusColor: Color {
        if pr.isMerged {
            return .purple
        } else if pr.isOpen {
            return .green
        } else {
            return .red
        }
    }
}

// MARK: - Issues List

private struct IssuesListView: View {
    @ObservedObject var viewModel: GitHubViewModel

    var body: some View {
        Group {
            if viewModel.issues.isEmpty && !viewModel.isLoading {
                EmptyStateView(
                    "No Issues",
                    systemImage: "exclamationmark.circle",
                    description: "No \(viewModel.stateFilter.rawValue) issues"
                )
            } else {
                List(viewModel.issues) { issue in
                    IssueRow(issue: issue)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            viewModel.openIssueInBrowser(issue)
                        }
                        .contextMenu {
                            Button("Open in Browser") {
                                viewModel.openIssueInBrowser(issue)
                            }
                        }
                }
                .listStyle(.inset)
            }
        }
        .task {
            await viewModel.loadIssues()
        }
        .onChange(of: viewModel.stateFilter) {
            Task { await viewModel.loadIssues() }
        }
    }
}

private struct IssueRow: View {
    let issue: GitHubIssue

    var body: some View {
        HStack(spacing: 12) {
            // Status icon
            Image(systemName: issue.isOpen ? "exclamationmark.circle" : "checkmark.circle")
                .foregroundStyle(issue.isOpen ? .green : .purple)

            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text("#\(issue.number)")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)

                    Text(issue.title)
                        .lineLimit(1)
                }

                HStack(spacing: 8) {
                    Text(issue.user.login)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(issue.createdAt, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Labels
                if !issue.labels.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(issue.labels.prefix(3)) { label in
                            Text(label.name)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(hex: label.color)?.opacity(0.2) ?? Color.secondary.opacity(0.1))
                                .cornerRadius(4)
                        }
                        if issue.labels.count > 3 {
                            Text("+\(issue.labels.count - 3)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Spacer()

            // Assignees
            if !issue.assignees.isEmpty {
                HStack(spacing: -8) {
                    ForEach(issue.assignees.prefix(3)) { assignee in
                        AsyncImage(url: URL(string: assignee.avatarUrl)) { image in
                            image.resizable()
                        } placeholder: {
                            Circle().fill(Color.secondary.opacity(0.3))
                        }
                        .frame(width: 24, height: 24)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.primary.opacity(0.1), lineWidth: 1))
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Token Sheet

private struct GitHubTokenSheet: View {
    @Binding var token: String
    @Binding var isPresented: Bool

    @State private var tempToken: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("GitHub Personal Access Token")
                    .font(.headline)
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // Content
            VStack(alignment: .leading, spacing: 16) {
                Text("Enter your GitHub personal access token to access issues and pull requests.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                SecureField("Token", text: $tempToken)
                    .textFieldStyle(.roundedBorder)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Required scopes:")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        ForEach(["repo", "read:org"], id: \.self) { scope in
                            Text(scope)
                                .font(.caption.monospaced())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                }

                Link("Create a new token on GitHub", destination: URL(string: "https://github.com/settings/tokens/new")!)
                    .font(.caption)
            }
            .padding()

            Divider()

            // Actions
            HStack {
                if !token.isEmpty {
                    Button("Remove Token", role: .destructive) {
                        token = ""
                        isPresented = false
                    }
                }

                Spacer()

                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Button("Save") {
                    token = tempToken
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(tempToken.isEmpty)
            }
            .padding()
        }
        .frame(width: 450)
        .onAppear {
            tempToken = token
        }
    }
}

// MARK: - Color Extension

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else {
            return nil
        }

        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Preview

#Preview {
    GitHubView(
        viewModel: GitHubViewModel(
            repository: Repository(rootURL: URL(fileURLWithPath: "/tmp")),
            gitService: GitService()
        )
    )
    .frame(width: 500, height: 600)
}
