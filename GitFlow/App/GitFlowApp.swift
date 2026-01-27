import SwiftUI

/// Main entry point for the GitFlow application.
/// A macOS Git GUI focused on excellent diff visualization.
@main
struct GitFlowApp: App {
    @StateObject private var appState = AppState()
    @AppStorage("com.gitflow.theme") private var theme: String = "system"

    init() {
        // Apply saved theme on launch
        applyTheme()
    }

    private func applyTheme() {
        switch theme {
        case "light":
            NSApp.appearance = NSAppearance(named: .aqua)
        case "dark":
            NSApp.appearance = NSAppearance(named: .darkAqua)
        default:
            NSApp.appearance = nil
        }
    }

    var body: some Scene {
        WindowGroup {
            MainWindow()
                .environmentObject(appState)
        }
        .windowStyle(.automatic)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open Repository...") {
                    appState.showOpenRepositoryPanel()
                }
                .keyboardShortcut("o", modifiers: .command)

                Button("Close Repository") {
                    appState.closeRepository()
                }
                .keyboardShortcut("w", modifiers: [.command, .shift])
                .disabled(appState.currentRepository == nil)

                Divider()

                Menu("Recent Repositories") {
                    ForEach(appState.recentRepositories, id: \.self) { path in
                        Button(path.lastPathComponent) {
                            appState.openRepository(at: path)
                        }
                    }

                    if !appState.recentRepositories.isEmpty {
                        Divider()
                        Button("Clear Recent") {
                            appState.clearRecentRepositories()
                        }
                    }
                }
            }

            CommandGroup(after: .sidebar) {
                Button("Refresh") {
                    Task {
                        await appState.repositoryViewModel?.refresh()
                    }
                }
                .keyboardShortcut("r", modifiers: .command)
            }
        }

        Settings {
            SettingsView()
        }
    }
}
