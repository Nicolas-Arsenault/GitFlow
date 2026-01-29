import SwiftUI

/// Defines all keyboard shortcuts used in the app.
/// Add these as modifiers to views or in menu items.
enum KeyboardShortcuts {
    // MARK: - Repository Operations
    static let openRepository = KeyboardShortcut("o", modifiers: .command)
    static let closeRepository = KeyboardShortcut("w", modifiers: .command)
    static let newWindow = KeyboardShortcut("n", modifiers: .command)
    static let refreshRepository = KeyboardShortcut("r", modifiers: .command)
    static let cloneRepository = KeyboardShortcut("n", modifiers: [.command, .shift])

    // MARK: - File Operations
    static let stageAll = KeyboardShortcut("a", modifiers: [.command, .shift])
    static let unstageAll = KeyboardShortcut("u", modifiers: [.command, .shift])
    static let stageSelected = KeyboardShortcut(.return, modifiers: .command)
    static let discardChanges = KeyboardShortcut(.delete, modifiers: [.command, .shift])

    // MARK: - Commit Operations
    static let commit = KeyboardShortcut(.return, modifiers: [.command, .shift])
    static let amendCommit = KeyboardShortcut(.return, modifiers: [.command, .option])
    static let focusCommitMessage = KeyboardShortcut("m", modifiers: .command)

    // MARK: - Branch Operations
    static let newBranch = KeyboardShortcut("b", modifiers: [.command, .shift])
    static let switchBranch = KeyboardShortcut("b", modifiers: .command)
    static let mergeBranch = KeyboardShortcut("m", modifiers: [.command, .shift])
    static let rebaseBranch = KeyboardShortcut("r", modifiers: [.command, .shift])

    // MARK: - Remote Operations
    static let fetch = KeyboardShortcut("f", modifiers: [.command, .shift])
    static let pull = KeyboardShortcut("p", modifiers: [.command, .shift])
    static let push = KeyboardShortcut("p", modifiers: [.command, .option])

    // MARK: - Stash Operations
    static let createStash = KeyboardShortcut("s", modifiers: [.command, .shift])
    static let applyStash = KeyboardShortcut("s", modifiers: [.command, .option])

    // MARK: - Navigation
    static let nextChange = KeyboardShortcut(.downArrow, modifiers: [.command, .option])
    static let previousChange = KeyboardShortcut(.upArrow, modifiers: [.command, .option])
    static let goToCommit = KeyboardShortcut("g", modifiers: .command)
    static let commandPalette = KeyboardShortcut("k", modifiers: .command)
    static let toggleSidebar = KeyboardShortcut("s", modifiers: .command)
    static let focusSidebar = KeyboardShortcut("1", modifiers: .command)
    static let focusContent = KeyboardShortcut("2", modifiers: .command)
    static let focusDiff = KeyboardShortcut("3", modifiers: .command)

    // MARK: - Diff Operations
    static let toggleDiffMode = KeyboardShortcut("d", modifiers: .command)
    static let toggleLineNumbers = KeyboardShortcut("l", modifiers: .command)
    static let toggleWordWrap = KeyboardShortcut("w", modifiers: [.command, .option])
    static let toggleBlame = KeyboardShortcut("b", modifiers: [.command, .option])
    static let searchInDiff = KeyboardShortcut("f", modifiers: .command)
    static let nextMatch = KeyboardShortcut("g", modifiers: .command)
    static let previousMatch = KeyboardShortcut("g", modifiers: [.command, .shift])
    static let copyDiff = KeyboardShortcut("c", modifiers: [.command, .shift])

    // MARK: - View Controls
    static let zoomIn = KeyboardShortcut("+", modifiers: .command)
    static let zoomOut = KeyboardShortcut("-", modifiers: .command)
    static let resetZoom = KeyboardShortcut("0", modifiers: .command)
    static let fullscreen = KeyboardShortcut("f", modifiers: [.command, .control])
    static let toggleTheme = KeyboardShortcut("t", modifiers: [.command, .option])

    // MARK: - Editing
    static let undo = KeyboardShortcut("z", modifiers: .command)
    static let redo = KeyboardShortcut("z", modifiers: [.command, .shift])
    static let selectAll = KeyboardShortcut("a", modifiers: .command)
    static let copy = KeyboardShortcut("c", modifiers: .command)
    static let paste = KeyboardShortcut("v", modifiers: .command)
    static let cut = KeyboardShortcut("x", modifiers: .command)

    // MARK: - Window Management
    static let minimize = KeyboardShortcut("m", modifiers: .command)
    static let closeWindow = KeyboardShortcut("w", modifiers: .command)
    static let cycleWindows = KeyboardShortcut("`", modifiers: .command)
    static let preferences = KeyboardShortcut(",", modifiers: .command)
}

/// Extension to add keyboard shortcut descriptions for documentation.
extension KeyboardShortcut {
    /// Human-readable description of the shortcut.
    var description: String {
        var parts: [String] = []

        if modifiers.contains(.command) { parts.append("⌘") }
        if modifiers.contains(.shift) { parts.append("⇧") }
        if modifiers.contains(.option) { parts.append("⌥") }
        if modifiers.contains(.control) { parts.append("⌃") }

        // Map special keys to symbols using character comparison
        let keyChar = key.character
        let keyString: String
        switch keyChar {
        case "\r": keyString = "↩"           // return
        case "\u{7F}": keyString = "⌫"       // delete
        case "\u{F700}": keyString = "↑"     // up arrow
        case "\u{F701}": keyString = "↓"     // down arrow
        case "\u{F702}": keyString = "←"     // left arrow
        case "\u{F703}": keyString = "→"     // right arrow
        case "\u{1B}": keyString = "⎋"       // escape
        case " ": keyString = "Space"
        case "\t": keyString = "⇥"           // tab
        default:
            keyString = String(keyChar).uppercased()
        }
        parts.append(keyString)

        return parts.joined()
    }
}

/// View modifier that handles common keyboard shortcuts.
struct GlobalKeyboardShortcuts: ViewModifier {
    let onRefresh: () -> Void
    let onStageAll: () -> Void
    let onUnstageAll: () -> Void
    let onCommit: () -> Void
    let onFetch: () -> Void
    let onPull: () -> Void
    let onPush: () -> Void
    let onCommandPalette: () -> Void

    func body(content: Content) -> some View {
        // Note: For global keyboard shortcuts, use Commands in the App definition
        // This modifier is for documentation and potential future use
        content
    }
}
