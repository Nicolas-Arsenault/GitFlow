import SwiftUI

/// Main application window containing the primary user interface.
struct MainWindow: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            if let viewModel = appState.repositoryViewModel {
                RepositoryView(viewModel: viewModel)
            } else {
                WelcomeView()
            }
        }
        .frame(minWidth: 1200, minHeight: 600)
        .alert(
            "Something went wrong",
            isPresented: .init(
                get: { appState.currentError != nil },
                set: { if !$0 { appState.currentError = nil } }
            )
        ) {
            Button("Dismiss") {
                appState.currentError = nil
            }
        } message: {
            if let error = appState.currentError {
                Text(error.localizedDescription)
            }
        }
    }
}

/// View displayed when no repository is open.
/// Follows UX principle: Empty states teach users what to do next.
struct WelcomeView: View {
    @EnvironmentObject private var appState: AppState
    @State private var showCloneSheet: Bool = false

    var body: some View {
        VStack(spacing: DSSpacing.xl) {
            Spacer()

            // App icon and branding
            VStack(spacing: DSSpacing.md) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 56))
                    .foregroundStyle(.tertiary)

                Text("GitFlow")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("A simple, powerful Git client")
                    .font(DSTypography.secondaryContent())
                    .foregroundStyle(.secondary)
            }

            // Primary actions
            VStack(spacing: DSSpacing.md) {
                Button(action: {
                    appState.showOpenRepositoryPanel()
                }) {
                    Label("Open Repository", systemImage: "folder")
                        .frame(width: 200)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button(action: {
                    showCloneSheet = true
                }) {
                    Label("Clone Repository", systemImage: "arrow.down.circle")
                        .frame(width: 200)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .sheet(isPresented: $showCloneSheet) {
                CloneRepositorySheet(isPresented: $showCloneSheet) { repoURL in
                    appState.openRepository(at: repoURL)
                }
            }

            // Recent repositories
            if !appState.recentRepositories.isEmpty {
                Divider()
                    .frame(width: 320)
                    .padding(.vertical, DSSpacing.sm)

                VStack(alignment: .leading, spacing: DSSpacing.sm) {
                    Text("Recent Repositories")
                        .font(DSTypography.subsectionTitle())
                        .padding(.horizontal, DSSpacing.sm)

                    ForEach(appState.recentRepositories.prefix(5), id: \.self) { url in
                        Button(action: {
                            appState.openRepository(at: url)
                        }) {
                            HStack(spacing: DSSpacing.iconTextSpacing) {
                                Image(systemName: "folder.fill")
                                    .foregroundStyle(.tertiary)

                                VStack(alignment: .leading, spacing: DSSpacing.xs) {
                                    Text(url.lastPathComponent)
                                        .font(DSTypography.primaryContent())
                                        .fontWeight(.medium)
                                    Text(url.path)
                                        .font(DSTypography.tertiaryContent())
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.horizontal, DSSpacing.sm)
                            .padding(.vertical, DSSpacing.xs)
                            .frame(width: 320)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .background(
                            RoundedRectangle(cornerRadius: DSRadius.sm)
                                .fill(Color.primary.opacity(0.03))
                        )
                    }
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

/// Main repository view with navigation and content.
struct RepositoryView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject var viewModel: RepositoryViewModel

    @State private var selectedSection: SidebarSection = .changes
    @State private var showSettings: Bool = false

    /// Navigation history for browser-style back/forward.
    @StateObject private var navigationHistory = NavigationHistory()

    /// Flag to prevent recording navigation when programmatically navigating.
    @State private var isProgrammaticNavigation: Bool = false

    var body: some View {
        NavigationSplitView {
            Sidebar(
                selectedSection: $selectedSection,
                viewModel: viewModel
            )
            .frame(minWidth: 240)
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 0) {
                    Divider()
                    Button(action: {
                        appState.closeRepository()
                    }) {
                        HStack(spacing: DSSpacing.iconTextSpacing) {
                            Image(systemName: "chevron.left")
                            Text("Change Repository")
                        }
                        .font(DSTypography.secondaryContent())
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, DSSpacing.md)
                        .padding(.vertical, DSSpacing.md)
                    }
                    .buttonStyle(.plain)
                }
                .background(Color(NSColor.windowBackgroundColor))
            }
        } detail: {
            ContentArea(
                selectedSection: selectedSection,
                viewModel: viewModel
            )
        }
        .navigationTitle(viewModel.repository.name)
        .toolbar {
            // Navigation back/forward buttons
            ToolbarItemGroup(placement: .navigation) {
                Button(action: goBack) {
                    Image(systemName: "chevron.left")
                }
                .tooltip("Back")
                .disabled(!navigationHistory.canGoBack)
                .keyboardShortcut("[", modifiers: .command)

                Button(action: goForward) {
                    Image(systemName: "chevron.right")
                }
                .tooltip("Forward")
                .disabled(!navigationHistory.canGoForward)
                .keyboardShortcut("]", modifiers: .command)

                Divider()

                Button(action: {
                    appState.closeRepository()
                }) {
                    Image(systemName: "folder")
                }
                .tooltip("Change Repository")
            }

            // Branch and sync operations
            ToolbarItemGroup(placement: .primaryAction) {
                // Branch selector dropdown
                Menu {
                    ForEach(viewModel.branchViewModel.localBranches, id: \.name) { branch in
                        Button(branch.name) {
                            Task { await viewModel.branchViewModel.checkout(branchName: branch.name) }
                        }
                    }

                    Divider()

                    Button("New Branch...") {
                        appState.showNewBranch = true
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.branch")
                        Text(viewModel.currentBranch ?? "No Branch")
                            .fontWeight(.medium)
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                    }
                }
                .tooltip("Current branch - click to switch")

                Divider()

                // Fetch button
                Button(action: {
                    Task { await viewModel.fetch() }
                }) {
                    Image(systemName: "arrow.down.circle")
                }
                .tooltip("Fetch from all remotes")
                .disabled(viewModel.isLoading)

                // Pull button
                Button(action: {
                    Task { await viewModel.pull() }
                }) {
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.down")
                        if viewModel.branchViewModel.currentBranchBehind > 0 {
                            Text("\(viewModel.branchViewModel.currentBranchBehind)")
                                .font(.caption2)
                        }
                    }
                }
                .tooltip("Pull changes from remote")
                .disabled(viewModel.isLoading)

                // Push button
                Button(action: {
                    Task { await viewModel.push() }
                }) {
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.up")
                        if viewModel.branchViewModel.currentBranchAhead > 0 {
                            Text("\(viewModel.branchViewModel.currentBranchAhead)")
                                .font(.caption2)
                        }
                    }
                }
                .tooltip("Push changes to remote")
                .disabled(viewModel.isLoading)

                // Sync button (Pull + Push)
                Button(action: {
                    Task {
                        await viewModel.fetch()
                        await viewModel.pull()
                        await viewModel.push()
                    }
                }) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                }
                .tooltip("Sync (Fetch, Pull, Push)")
                .disabled(viewModel.isLoading)

                Divider()

                // Stash button
                Button(action: {
                    appState.showCreateStash = true
                }) {
                    Image(systemName: "tray.and.arrow.down")
                }
                .tooltip("Stash changes")
                .disabled(viewModel.statusViewModel.status.totalChangedFiles == 0)

                Divider()

                Button(action: {
                    Task { await viewModel.refresh() }
                }) {
                    Image(systemName: "arrow.clockwise")
                }
                .tooltip("Refresh")
                .disabled(viewModel.isLoading)

                Button(action: {
                    showSettings = true
                }) {
                    Image(systemName: "gearshape")
                }
                .tooltip("Settings")
            }
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(0.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding()
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(showDismissButton: true)
        }
        .onChange(of: selectedSection) { newSection in
            // Record navigation unless it's programmatic
            if !isProgrammaticNavigation {
                navigationHistory.push(section: newSection.rawValue)
            }
            isProgrammaticNavigation = false
        }
        .onAppear {
            // Initialize navigation history with current section
            navigationHistory.push(section: selectedSection.rawValue)
        }
    }

    // MARK: - Navigation Methods

    private func goBack() {
        guard let state = navigationHistory.goBack(),
              let section = SidebarSection(rawValue: state.section) else {
            return
        }
        isProgrammaticNavigation = true
        selectedSection = section
    }

    private func goForward() {
        guard let state = navigationHistory.goForward(),
              let section = SidebarSection(rawValue: state.section) else {
            return
        }
        isProgrammaticNavigation = true
        selectedSection = section
    }
}

#Preview {
    MainWindow()
        .environmentObject(AppState())
}
