import SwiftUI

/// View displaying all keyboard shortcuts organized by category.
struct KeyboardShortcutsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedCategory: ShortcutCategory?

    var body: some View {
        NavigationSplitView {
            // Categories sidebar
            List(ShortcutCategory.allCases, selection: $selectedCategory) { category in
                Label(category.rawValue, systemImage: category.icon)
                    .tag(category)
            }
            .listStyle(.sidebar)
            .frame(minWidth: 150)
        } detail: {
            // Shortcuts list
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search shortcuts...", text: $searchText)
                        .textFieldStyle(.plain)
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.borderless)
                        .help("Clear search")
                    }
                }
                .padding(8)
                .background(Color(nsColor: .controlBackgroundColor))

                Divider()

                // Shortcuts
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        ForEach(filteredCategories, id: \.self) { category in
                            shortcutSection(for: category)
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(minWidth: 700, minHeight: 500)
        .navigationTitle("Keyboard Shortcuts")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
    }

    private var filteredCategories: [ShortcutCategory] {
        if let selected = selectedCategory {
            return [selected]
        }
        if searchText.isEmpty {
            return ShortcutCategory.allCases
        }
        return ShortcutCategory.allCases.filter { category in
            ShortcutData.shortcuts(for: category).contains { shortcut in
                shortcut.description.localizedCaseInsensitiveContains(searchText) ||
                shortcut.keys.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    @ViewBuilder
    private func shortcutSection(for category: ShortcutCategory) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: category.icon)
                    .foregroundColor(.accentColor)
                Text(category.rawValue)
                    .font(.headline)
            }

            Divider()

            ForEach(filteredShortcuts(for: category)) { shortcut in
                shortcutRow(shortcut)
            }
        }
    }

    private func filteredShortcuts(for category: ShortcutCategory) -> [ShortcutInfo] {
        let shortcuts = ShortcutData.shortcuts(for: category)
        if searchText.isEmpty {
            return shortcuts
        }
        return shortcuts.filter { shortcut in
            shortcut.description.localizedCaseInsensitiveContains(searchText) ||
            shortcut.keys.localizedCaseInsensitiveContains(searchText)
        }
    }

    @ViewBuilder
    private func shortcutRow(_ shortcut: ShortcutInfo) -> some View {
        HStack {
            Text(shortcut.description)
                .frame(maxWidth: .infinity, alignment: .leading)

            KeyCombinationView(keys: shortcut.keys)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Key Combination View

struct KeyCombinationView: View {
    let keys: String

    var body: some View {
        HStack(spacing: 4) {
            ForEach(keyParts, id: \.self) { part in
                KeyCapView(key: part)
            }
        }
    }

    private var keyParts: [String] {
        keys.components(separatedBy: "+").map { $0.trimmingCharacters(in: .whitespaces) }
    }
}

struct KeyCapView: View {
    let key: String

    var body: some View {
        Text(displayKey)
            .font(.system(.body, design: .rounded))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
            )
    }

    private var displayKey: String {
        switch key.lowercased() {
        case "cmd", "command": return "⌘"
        case "opt", "option", "alt": return "⌥"
        case "ctrl", "control": return "⌃"
        case "shift": return "⇧"
        case "enter", "return": return "↩"
        case "delete", "backspace": return "⌫"
        case "tab": return "⇥"
        case "esc", "escape": return "⎋"
        case "space": return "Space"
        case "up": return "↑"
        case "down": return "↓"
        case "left": return "←"
        case "right": return "→"
        default: return key.uppercased()
        }
    }
}

// MARK: - Shortcut Data

enum ShortcutCategory: String, CaseIterable, Identifiable {
    case general = "General"
    case navigation = "Navigation"
    case staging = "Staging"
    case commit = "Commit"
    case branches = "Branches"
    case stash = "Stash"
    case history = "History"
    case diff = "Diff"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: return "command"
        case .navigation: return "arrow.left.arrow.right"
        case .staging: return "tray.and.arrow.down"
        case .commit: return "checkmark.circle"
        case .branches: return "arrow.triangle.branch"
        case .stash: return "archivebox"
        case .history: return "clock"
        case .diff: return "doc.text.magnifyingglass"
        }
    }
}

struct ShortcutInfo: Identifiable {
    let id = UUID()
    let keys: String
    let description: String
}

enum ShortcutData {
    static func shortcuts(for category: ShortcutCategory) -> [ShortcutInfo] {
        switch category {
        case .general:
            return [
                ShortcutInfo(keys: "Cmd + ,", description: "Open Settings"),
                ShortcutInfo(keys: "Cmd + Q", description: "Quit GitFlow"),
                ShortcutInfo(keys: "Cmd + W", description: "Close Window"),
                ShortcutInfo(keys: "Cmd + N", description: "New Window"),
                ShortcutInfo(keys: "Cmd + O", description: "Open Repository"),
                ShortcutInfo(keys: "Cmd + K", description: "Open Command Palette"),
                ShortcutInfo(keys: "Cmd + Shift + N", description: "New Repository"),
                ShortcutInfo(keys: "Cmd + Shift + O", description: "Clone Repository"),
                ShortcutInfo(keys: "Cmd + R", description: "Refresh"),
                ShortcutInfo(keys: "Cmd + F", description: "Find"),
                ShortcutInfo(keys: "Esc", description: "Cancel / Close Dialog"),
            ]
        case .navigation:
            return [
                ShortcutInfo(keys: "Cmd + 1", description: "Show Working Copy"),
                ShortcutInfo(keys: "Cmd + 2", description: "Show History"),
                ShortcutInfo(keys: "Cmd + 3", description: "Show Stashes"),
                ShortcutInfo(keys: "Cmd + 4", description: "Show Pull Requests"),
                ShortcutInfo(keys: "Cmd + 5", description: "Show Reflog"),
                ShortcutInfo(keys: "Cmd + 0", description: "Jump to HEAD"),
                ShortcutInfo(keys: "Cmd + [", description: "Navigate Back"),
                ShortcutInfo(keys: "Cmd + ]", description: "Navigate Forward"),
                ShortcutInfo(keys: "Up / Down", description: "Navigate List"),
                ShortcutInfo(keys: "Enter", description: "Select / Open"),
                ShortcutInfo(keys: "Space", description: "Toggle Selection / Preview"),
            ]
        case .staging:
            return [
                ShortcutInfo(keys: "Space", description: "Stage / Unstage File"),
                ShortcutInfo(keys: "Cmd + Shift + A", description: "Stage All"),
                ShortcutInfo(keys: "Cmd + Shift + U", description: "Unstage All"),
                ShortcutInfo(keys: "Cmd + Delete", description: "Discard Changes"),
                ShortcutInfo(keys: "Cmd + D", description: "View Diff"),
            ]
        case .commit:
            return [
                ShortcutInfo(keys: "Cmd + Enter", description: "Commit"),
                ShortcutInfo(keys: "Cmd + Shift + Enter", description: "Commit and Push"),
                ShortcutInfo(keys: "Cmd + Shift + A", description: "Amend Last Commit"),
            ]
        case .branches:
            return [
                ShortcutInfo(keys: "Cmd + B", description: "Create Branch"),
                ShortcutInfo(keys: "Cmd + Shift + B", description: "Switch Branch"),
                ShortcutInfo(keys: "Cmd + Shift + M", description: "Merge Branch"),
                ShortcutInfo(keys: "Cmd + Shift + R", description: "Rebase Branch"),
                ShortcutInfo(keys: "Cmd + Shift + P", description: "Push"),
                ShortcutInfo(keys: "Cmd + Shift + L", description: "Pull"),
                ShortcutInfo(keys: "Cmd + Shift + F", description: "Fetch"),
            ]
        case .stash:
            return [
                ShortcutInfo(keys: "Cmd + Shift + S", description: "Stash Changes"),
                ShortcutInfo(keys: "Cmd + Shift + Alt + S", description: "Pop Stash"),
            ]
        case .history:
            return [
                ShortcutInfo(keys: "Cmd + G", description: "Go to Commit"),
                ShortcutInfo(keys: "Cmd + C", description: "Copy Commit Hash"),
                ShortcutInfo(keys: "Cmd + Shift + C", description: "Cherry-pick Commit"),
                ShortcutInfo(keys: "Cmd + Shift + V", description: "Revert Commit"),
            ]
        case .diff:
            return [
                ShortcutInfo(keys: "Cmd + F", description: "Search in Diff"),
                ShortcutInfo(keys: "Cmd + G", description: "Find Next"),
                ShortcutInfo(keys: "Cmd + Shift + G", description: "Find Previous"),
                ShortcutInfo(keys: "Cmd + +", description: "Increase Font Size"),
                ShortcutInfo(keys: "Cmd + -", description: "Decrease Font Size"),
                ShortcutInfo(keys: "Cmd + 0", description: "Reset Font Size"),
            ]
        }
    }
}

#Preview {
    KeyboardShortcutsView()
}
