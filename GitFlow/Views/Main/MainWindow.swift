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
        .frame(minWidth: 900, minHeight: 600)
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
    @ObservedObject var viewModel: RepositoryViewModel

    @State private var selectedSection: SidebarSection = .changes

    var body: some View {
        NavigationSplitView {
            Sidebar(
                selectedSection: $selectedSection,
                viewModel: viewModel
            )
            .frame(minWidth: 200)
        } detail: {
            ContentArea(
                selectedSection: selectedSection,
                viewModel: viewModel
            )
        }
        .navigationTitle(viewModel.repository.name)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if let branch = viewModel.currentBranch {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.branch")
                        Text(branch)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(.secondary)
                }

                Button(action: {
                    Task { await viewModel.refresh() }
                }) {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh")
                .disabled(viewModel.isLoading)
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
    }
}

#Preview {
    MainWindow()
        .environmentObject(AppState())
}
