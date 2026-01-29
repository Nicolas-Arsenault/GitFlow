import SwiftUI
import Carbon.HIToolbox

/// Settings view for customizing keyboard shortcuts.
struct KeyboardShortcutsSettingsView: View {
    @StateObject private var viewModel = KeyboardShortcutsSettingsViewModel()
    @State private var editingShortcut: CustomizableShortcut?
    @State private var showingResetConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Keyboard Shortcuts")
                    .font(.headline)

                Spacer()

                Button("Reset to Defaults") {
                    showingResetConfirmation = true
                }
            }
            .padding()

            Divider()

            // Shortcuts list
            List {
                ForEach(ShortcutCategory.allCases) { category in
                    Section(category.rawValue) {
                        ForEach(viewModel.shortcuts(for: category)) { shortcut in
                            ShortcutRow(
                                shortcut: shortcut,
                                customBinding: viewModel.customBinding(for: shortcut.id),
                                onEdit: { editingShortcut = shortcut }
                            )
                        }
                    }
                }
            }
            .listStyle(.inset)
        }
        .sheet(item: $editingShortcut) { shortcut in
            ShortcutEditSheet(
                shortcut: shortcut,
                currentBinding: viewModel.customBinding(for: shortcut.id),
                onSave: { newBinding in
                    viewModel.setCustomBinding(newBinding, for: shortcut.id)
                },
                onClear: {
                    viewModel.clearCustomBinding(for: shortcut.id)
                }
            )
        }
        .alert("Reset Shortcuts?", isPresented: $showingResetConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                viewModel.resetToDefaults()
            }
        } message: {
            Text("This will reset all keyboard shortcuts to their default values. This action cannot be undone.")
        }
    }
}

// MARK: - Shortcut Row

struct ShortcutRow: View {
    let shortcut: CustomizableShortcut
    let customBinding: KeyBinding?
    let onEdit: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(shortcut.name)
                    .font(.body)

                if let description = shortcut.description {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Show current binding
            if let binding = customBinding ?? shortcut.defaultBinding {
                KeyBindingView(binding: binding)
                    .foregroundColor(customBinding != nil ? .accentColor : .primary)
            } else {
                Text("None")
                    .foregroundColor(.secondary)
            }

            Button(action: onEdit) {
                Image(systemName: "pencil")
            }
            .buttonStyle(.borderless)
            .help("Edit shortcut")
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Key Binding View

struct KeyBindingView: View {
    let binding: KeyBinding

    var body: some View {
        HStack(spacing: 2) {
            if binding.modifiers.contains(.command) {
                KeyCapView(key: "⌘")
            }
            if binding.modifiers.contains(.shift) {
                KeyCapView(key: "⇧")
            }
            if binding.modifiers.contains(.option) {
                KeyCapView(key: "⌥")
            }
            if binding.modifiers.contains(.control) {
                KeyCapView(key: "⌃")
            }
            KeyCapView(key: binding.keyDisplay)
        }
    }
}

// MARK: - Shortcut Edit Sheet

struct ShortcutEditSheet: View {
    let shortcut: CustomizableShortcut
    let currentBinding: KeyBinding?
    let onSave: (KeyBinding) -> Void
    let onClear: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isRecording = false
    @State private var recordedBinding: KeyBinding?
    @State private var conflictWarning: String?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Edit Shortcut")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
            }
            .padding()

            Divider()

            VStack(spacing: 24) {
                // Shortcut info
                VStack(spacing: 8) {
                    Text(shortcut.name)
                        .font(.title2)
                        .fontWeight(.semibold)

                    if let description = shortcut.description {
                        Text(description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                // Current binding
                VStack(spacing: 8) {
                    Text("Current Shortcut")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if let binding = recordedBinding ?? currentBinding ?? shortcut.defaultBinding {
                        KeyBindingView(binding: binding)
                            .font(.title)
                    } else {
                        Text("None")
                            .foregroundColor(.secondary)
                    }
                }

                // Recording area
                VStack(spacing: 12) {
                    Button(action: { isRecording.toggle() }) {
                        HStack {
                            Image(systemName: isRecording ? "record.circle.fill" : "record.circle")
                                .foregroundColor(isRecording ? .red : .primary)
                            Text(isRecording ? "Press keys..." : "Record New Shortcut")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(nsColor: .controlBackgroundColor))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.none)

                    if isRecording {
                        Text("Press the key combination you want to use")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .background(
                    KeyRecorder(isRecording: $isRecording, onRecord: { binding in
                        recordedBinding = binding
                        isRecording = false
                        checkForConflicts(binding)
                    })
                )

                // Conflict warning
                if let warning = conflictWarning {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                        Text(warning)
                            .font(.caption)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                }

                // Default binding info
                if let defaultBinding = shortcut.defaultBinding {
                    VStack(spacing: 4) {
                        Text("Default:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        KeyBindingView(binding: defaultBinding)
                            .font(.caption)
                    }
                }

                Spacer()
            }
            .padding()

            Divider()

            // Footer
            HStack {
                Button("Clear Shortcut") {
                    onClear()
                    dismiss()
                }
                .foregroundColor(.red)

                Spacer()

                Button("Use Default") {
                    if let defaultBinding = shortcut.defaultBinding {
                        onSave(defaultBinding)
                    } else {
                        onClear()
                    }
                    dismiss()
                }

                Button("Save") {
                    if let binding = recordedBinding {
                        onSave(binding)
                    }
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(recordedBinding == nil)
            }
            .padding()
        }
        .frame(width: 400, height: 450)
    }

    private func checkForConflicts(_ binding: KeyBinding) {
        // Check if this binding conflicts with another shortcut
        // This would need to check against all registered shortcuts
        conflictWarning = nil
    }
}

// MARK: - Key Recorder

struct KeyRecorder: NSViewRepresentable {
    @Binding var isRecording: Bool
    let onRecord: (KeyBinding) -> Void

    func makeNSView(context: Context) -> KeyRecorderView {
        let view = KeyRecorderView()
        view.onRecord = onRecord
        return view
    }

    func updateNSView(_ nsView: KeyRecorderView, context: Context) {
        nsView.isRecording = isRecording
        if isRecording {
            nsView.window?.makeFirstResponder(nsView)
        }
    }
}

class KeyRecorderView: NSView {
    var isRecording = false
    var onRecord: ((KeyBinding) -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }

        let modifiers = KeyModifiers(event.modifierFlags)
        guard !modifiers.isEmpty else { return }

        let key = keyCodeToString(event.keyCode)
        let binding = KeyBinding(key: key, modifiers: modifiers)
        onRecord?(binding)
    }

    private func keyCodeToString(_ keyCode: UInt16) -> String {
        switch Int(keyCode) {
        case kVK_Return: return "Return"
        case kVK_Tab: return "Tab"
        case kVK_Space: return "Space"
        case kVK_Delete: return "Delete"
        case kVK_Escape: return "Escape"
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"
        case kVK_UpArrow: return "↑"
        case kVK_DownArrow: return "↓"
        case kVK_F1: return "F1"
        case kVK_F2: return "F2"
        case kVK_F3: return "F3"
        case kVK_F4: return "F4"
        case kVK_F5: return "F5"
        case kVK_F6: return "F6"
        case kVK_F7: return "F7"
        case kVK_F8: return "F8"
        case kVK_F9: return "F9"
        case kVK_F10: return "F10"
        case kVK_F11: return "F11"
        case kVK_F12: return "F12"
        default:
            if let chars = NSEvent.keyEvent(
                with: .keyDown,
                location: .zero,
                modifierFlags: [],
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                characters: "",
                charactersIgnoringModifiers: "",
                isARepeat: false,
                keyCode: keyCode
            )?.charactersIgnoringModifiers?.uppercased() {
                return chars
            }
            return "?"
        }
    }
}

// MARK: - Data Models

struct KeyBinding: Codable, Equatable {
    let key: String
    let modifiers: KeyModifiers

    var keyDisplay: String {
        key.uppercased()
    }
}

struct KeyModifiers: OptionSet, Codable {
    let rawValue: Int

    static let command = KeyModifiers(rawValue: 1 << 0)
    static let shift = KeyModifiers(rawValue: 1 << 1)
    static let option = KeyModifiers(rawValue: 1 << 2)
    static let control = KeyModifiers(rawValue: 1 << 3)

    init(rawValue: Int) {
        self.rawValue = rawValue
    }

    init(_ flags: NSEvent.ModifierFlags) {
        var value = 0
        if flags.contains(.command) { value |= KeyModifiers.command.rawValue }
        if flags.contains(.shift) { value |= KeyModifiers.shift.rawValue }
        if flags.contains(.option) { value |= KeyModifiers.option.rawValue }
        if flags.contains(.control) { value |= KeyModifiers.control.rawValue }
        self.rawValue = value
    }
}

struct CustomizableShortcut: Identifiable {
    let id: String
    let name: String
    let description: String?
    let category: ShortcutCategory
    let defaultBinding: KeyBinding?
}

// MARK: - View Model

@MainActor
class KeyboardShortcutsSettingsViewModel: ObservableObject {
    @Published private var customBindings: [String: KeyBinding] = [:]

    private let storageKey = "customKeyboardShortcuts"

    init() {
        loadCustomBindings()
    }

    func shortcuts(for category: ShortcutCategory) -> [CustomizableShortcut] {
        allShortcuts.filter { $0.category == category }
    }

    func customBinding(for id: String) -> KeyBinding? {
        customBindings[id]
    }

    func setCustomBinding(_ binding: KeyBinding, for id: String) {
        customBindings[id] = binding
        saveCustomBindings()
    }

    func clearCustomBinding(for id: String) {
        customBindings.removeValue(forKey: id)
        saveCustomBindings()
    }

    func resetToDefaults() {
        customBindings.removeAll()
        saveCustomBindings()
    }

    private func loadCustomBindings() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let bindings = try? JSONDecoder().decode([String: KeyBinding].self, from: data) else {
            return
        }
        customBindings = bindings
    }

    private func saveCustomBindings() {
        if let data = try? JSONEncoder().encode(customBindings) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    // MARK: - All Shortcuts

    private var allShortcuts: [CustomizableShortcut] {
        [
            // General
            CustomizableShortcut(id: "open-settings", name: "Open Settings", description: nil, category: .general,
                                defaultBinding: KeyBinding(key: ",", modifiers: .command)),
            CustomizableShortcut(id: "command-palette", name: "Command Palette", description: nil, category: .general,
                                defaultBinding: KeyBinding(key: "K", modifiers: .command)),
            CustomizableShortcut(id: "open-repository", name: "Open Repository", description: nil, category: .general,
                                defaultBinding: KeyBinding(key: "O", modifiers: .command)),
            CustomizableShortcut(id: "clone-repository", name: "Clone Repository", description: nil, category: .general,
                                defaultBinding: KeyBinding(key: "O", modifiers: [.command, .shift])),
            CustomizableShortcut(id: "refresh", name: "Refresh", description: nil, category: .general,
                                defaultBinding: KeyBinding(key: "R", modifiers: .command)),

            // Navigation
            CustomizableShortcut(id: "view-working-copy", name: "Show Working Copy", description: nil, category: .navigation,
                                defaultBinding: KeyBinding(key: "1", modifiers: .command)),
            CustomizableShortcut(id: "view-history", name: "Show History", description: nil, category: .navigation,
                                defaultBinding: KeyBinding(key: "2", modifiers: .command)),
            CustomizableShortcut(id: "view-stashes", name: "Show Stashes", description: nil, category: .navigation,
                                defaultBinding: KeyBinding(key: "3", modifiers: .command)),
            CustomizableShortcut(id: "view-pull-requests", name: "Show Pull Requests", description: nil, category: .navigation,
                                defaultBinding: KeyBinding(key: "4", modifiers: .command)),
            CustomizableShortcut(id: "view-reflog", name: "Show Reflog", description: nil, category: .navigation,
                                defaultBinding: KeyBinding(key: "5", modifiers: .command)),
            CustomizableShortcut(id: "navigate-back", name: "Navigate Back", description: nil, category: .navigation,
                                defaultBinding: KeyBinding(key: "[", modifiers: .command)),
            CustomizableShortcut(id: "navigate-forward", name: "Navigate Forward", description: nil, category: .navigation,
                                defaultBinding: KeyBinding(key: "]", modifiers: .command)),

            // Staging
            CustomizableShortcut(id: "stage-all", name: "Stage All", description: nil, category: .staging,
                                defaultBinding: KeyBinding(key: "A", modifiers: [.command, .shift])),
            CustomizableShortcut(id: "unstage-all", name: "Unstage All", description: nil, category: .staging,
                                defaultBinding: KeyBinding(key: "U", modifiers: [.command, .shift])),
            CustomizableShortcut(id: "discard-changes", name: "Discard Changes", description: nil, category: .staging,
                                defaultBinding: KeyBinding(key: "Delete", modifiers: .command)),

            // Commit
            CustomizableShortcut(id: "commit", name: "Commit", description: nil, category: .commit,
                                defaultBinding: KeyBinding(key: "Return", modifiers: .command)),
            CustomizableShortcut(id: "commit-and-push", name: "Commit and Push", description: nil, category: .commit,
                                defaultBinding: KeyBinding(key: "Return", modifiers: [.command, .shift])),
            CustomizableShortcut(id: "amend-commit", name: "Amend Last Commit", description: nil, category: .commit,
                                defaultBinding: KeyBinding(key: "A", modifiers: [.command, .shift])),

            // Branches
            CustomizableShortcut(id: "create-branch", name: "Create Branch", description: nil, category: .branches,
                                defaultBinding: KeyBinding(key: "B", modifiers: .command)),
            CustomizableShortcut(id: "switch-branch", name: "Switch Branch", description: nil, category: .branches,
                                defaultBinding: KeyBinding(key: "B", modifiers: [.command, .shift])),
            CustomizableShortcut(id: "merge-branch", name: "Merge Branch", description: nil, category: .branches,
                                defaultBinding: KeyBinding(key: "M", modifiers: [.command, .shift])),
            CustomizableShortcut(id: "rebase-branch", name: "Rebase Branch", description: nil, category: .branches,
                                defaultBinding: KeyBinding(key: "R", modifiers: [.command, .shift])),
            CustomizableShortcut(id: "push", name: "Push", description: nil, category: .branches,
                                defaultBinding: KeyBinding(key: "P", modifiers: [.command, .shift])),
            CustomizableShortcut(id: "pull", name: "Pull", description: nil, category: .branches,
                                defaultBinding: KeyBinding(key: "L", modifiers: [.command, .shift])),
            CustomizableShortcut(id: "fetch", name: "Fetch", description: nil, category: .branches,
                                defaultBinding: KeyBinding(key: "F", modifiers: [.command, .shift])),

            // Stash
            CustomizableShortcut(id: "stash-changes", name: "Stash Changes", description: nil, category: .stash,
                                defaultBinding: KeyBinding(key: "S", modifiers: [.command, .shift])),
            CustomizableShortcut(id: "pop-stash", name: "Pop Stash", description: nil, category: .stash,
                                defaultBinding: KeyBinding(key: "S", modifiers: [.command, .shift, .option])),
        ]
    }
}

#Preview {
    KeyboardShortcutsSettingsView()
        .frame(width: 600, height: 500)
}
