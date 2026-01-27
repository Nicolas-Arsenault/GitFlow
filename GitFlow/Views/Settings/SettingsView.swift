import SwiftUI

/// Main settings view.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    var showDismissButton: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            if showDismissButton {
                HStack {
                    Text("Settings")
                        .font(.headline)
                    Spacer()
                    Button("Done") {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                Divider()
            }

            TabView {
                GeneralSettingsView()
                    .tabItem {
                        Label("General", systemImage: "gear")
                    }

                DiffSettingsView()
                    .tabItem {
                        Label("Diff", systemImage: "text.alignleft")
                    }

                GitSettingsView()
                    .tabItem {
                        Label("Git", systemImage: "chevron.left.forwardslash.chevron.right")
                    }
            }
        }
        .frame(width: 450, height: showDismissButton ? 350 : 300)
    }
}

/// Theme options for the app.
enum AppTheme: String, CaseIterable {
    case system = "system"
    case light = "light"
    case dark = "dark"

    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var appearance: NSAppearance? {
        switch self {
        case .system: return nil
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        }
    }
}

/// General application settings.
struct GeneralSettingsView: View {
    @AppStorage("com.gitflow.showRemoteBranches") private var showRemoteBranches: Bool = true
    @AppStorage("com.gitflow.confirmDestructiveActions") private var confirmDestructiveActions: Bool = true
    @AppStorage("com.gitflow.theme") private var theme: String = "system"

    var body: some View {
        Form {
            Section {
                Picker("Appearance", selection: $theme) {
                    ForEach(AppTheme.allCases, id: \.rawValue) { appTheme in
                        Text(appTheme.displayName).tag(appTheme.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: theme) { newValue in
                    applyTheme(newValue)
                }
            } header: {
                Text("Theme")
            }

            Section {
                Toggle("Show remote branches in branch list", isOn: $showRemoteBranches)
                Toggle("Confirm destructive actions", isOn: $confirmDestructiveActions)
            } header: {
                Text("Behavior")
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            applyTheme(theme)
        }
    }
}

/// Diff display settings.
struct DiffSettingsView: View {
    @AppStorage("com.gitflow.diffViewMode") private var diffViewMode: String = "unified"
    @AppStorage("com.gitflow.showLineNumbers") private var showLineNumbers: Bool = true
    @AppStorage("com.gitflow.wrapLines") private var wrapLines: Bool = false
    @AppStorage("com.gitflow.fontSize") private var fontSize: Double = 12.0

    var body: some View {
        Form {
            Section {
                Picker("Default view mode", selection: $diffViewMode) {
                    Text("Unified").tag("unified")
                    Text("Split (Side-by-Side)").tag("split")
                }
                .pickerStyle(.segmented)

                Toggle("Show line numbers", isOn: $showLineNumbers)
                Toggle("Wrap long lines", isOn: $wrapLines)
            } header: {
                Text("Display")
            }

            Section {
                HStack {
                    Text("Font size")
                    Slider(value: $fontSize, in: 9...18, step: 1) {
                        Text("Font size")
                    }
                    Text("\(Int(fontSize)) pt")
                        .frame(width: 40)
                }
            } header: {
                Text("Font")
            }

            Section {
                // Preview of the font size
                Text("func example() { return true }")
                    .font(.system(size: fontSize, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(nsColor: .textBackgroundColor))
                    .cornerRadius(4)
            } header: {
                Text("Preview")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

/// Git executable settings.
struct GitSettingsView: View {
    @AppStorage("com.gitflow.gitPath") private var gitPath: String = "/usr/bin/git"
    @State private var gitVersion: String = ""
    @State private var isValidGitPath: Bool = true

    var body: some View {
        Form {
            Section {
                HStack {
                    TextField("Git executable path", text: $gitPath)
                        .textFieldStyle(.roundedBorder)
                        .fontDesign(.monospaced)

                    Button("Browse...") {
                        browseForGit()
                    }
                }

                if !isValidGitPath {
                    Label("Invalid Git path", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                        .font(.caption)
                }

                if !gitVersion.isEmpty {
                    Text(gitVersion)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button("Detect Git") {
                    detectGit()
                }
            } header: {
                Text("Git Executable")
            } footer: {
                Text("GitFlow uses the system Git executable for all operations. You can specify a custom path if needed.")
            }

            Section {
                Button("Reset to Default") {
                    gitPath = "/usr/bin/git"
                    validateGitPath()
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            validateGitPath()
        }
        .onChange(of: gitPath) { _ in
            validateGitPath()
        }
    }

    private func browseForGit() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.message = "Select the Git executable"
        panel.prompt = "Select"

        if panel.runModal() == .OK, let url = panel.url {
            gitPath = url.path
        }
    }

    private func detectGit() {
        // Try common Git locations
        let commonPaths = [
            "/usr/bin/git",
            "/usr/local/bin/git",
            "/opt/homebrew/bin/git",
            "/opt/local/bin/git"
        ]

        for path in commonPaths {
            if FileManager.default.isExecutableFile(atPath: path) {
                gitPath = path
                return
            }
        }
    }

    private func validateGitPath() {
        let fileManager = FileManager.default
        isValidGitPath = fileManager.isExecutableFile(atPath: gitPath)

        if isValidGitPath {
            // Get Git version
            let process = Process()
            process.executableURL = URL(fileURLWithPath: gitPath)
            process.arguments = ["--version"]

            let pipe = Pipe()
            process.standardOutput = pipe

            do {
                try process.run()
                process.waitUntilExit()

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8) {
                    gitVersion = output.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            } catch {
                gitVersion = ""
            }
        } else {
            gitVersion = ""
        }
    }
}

#Preview {
    SettingsView()
}
