import SwiftUI

/// Applies the specified theme to the application.
/// - Parameter themeValue: The theme value ("system", "light", or "dark")
func applyTheme(_ themeValue: String) {
    switch themeValue {
    case "light":
        NSApp.appearance = NSAppearance(named: .aqua)
    case "dark":
        NSApp.appearance = NSAppearance(named: .darkAqua)
    default:
        NSApp.appearance = nil
    }
}

/// Main entry point for the GitFlow application.
/// A macOS Git GUI focused on excellent diff visualization.
@main
struct GitFlowApp: App {
    @StateObject private var appState = AppState()
    @AppStorage("com.gitflow.theme") private var theme: String = "system"

    var body: some Scene {
        WindowGroup {
            MainWindow()
                .environmentObject(appState)
                .onAppear {
                    applyTheme(theme)
                }
                .onChange(of: theme) { newTheme in
                    applyTheme(newTheme)
                }
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
