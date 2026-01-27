import SwiftUI

/// Sheet for cloning a repository from a URL.
struct CloneRepositorySheet: View {
    @Binding var isPresented: Bool
    let onClone: (URL) -> Void

    @State private var url: String = ""
    @State private var destinationPath: String = ""
    @State private var branch: String = ""
    @State private var isCloning: Bool = false
    @State private var error: String?

    private let gitService = GitService()

    var body: some View {
        VStack(spacing: 20) {
            // Header
            Text("Clone Repository")
                .font(.headline)

            // URL field
            VStack(alignment: .leading, spacing: 4) {
                Text("Repository URL")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                TextField("https://github.com/user/repo.git", text: $url)
                    .textFieldStyle(.roundedBorder)
                    .fontDesign(.monospaced)
            }

            // Destination field
            VStack(alignment: .leading, spacing: 4) {
                Text("Destination")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack {
                    TextField("Choose a folder", text: $destinationPath)
                        .textFieldStyle(.roundedBorder)
                        .fontDesign(.monospaced)

                    Button("Browse...") {
                        browseForDestination()
                    }
                }
            }

            // Branch field (optional)
            VStack(alignment: .leading, spacing: 4) {
                Text("Branch (optional)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                TextField("Leave empty for default branch", text: $branch)
                    .textFieldStyle(.roundedBorder)
            }

            // Error message
            if let error = error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            // Buttons
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Clone") {
                    performClone()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!canClone || isCloning)
            }

            // Progress indicator
            if isCloning {
                HStack {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Cloning repository...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .frame(width: 450)
        .onAppear {
            setDefaultDestination()
        }
    }

    // MARK: - Computed Properties

    private var canClone: Bool {
        !url.isEmpty && !destinationPath.isEmpty && isValidURL
    }

    private var isValidURL: Bool {
        // Basic URL validation
        url.hasPrefix("https://") ||
        url.hasPrefix("http://") ||
        url.hasPrefix("git@") ||
        url.hasPrefix("ssh://") ||
        url.hasPrefix("git://") ||
        url.hasPrefix("/") // Local path
    }

    // MARK: - Actions

    private func setDefaultDestination() {
        // Default to user's home directory/Developer or Documents
        let homeURL = FileManager.default.homeDirectoryForCurrentUser
        let developerURL = homeURL.appendingPathComponent("Developer")
        let documentsURL = homeURL.appendingPathComponent("Documents")

        if FileManager.default.fileExists(atPath: developerURL.path) {
            destinationPath = developerURL.path
        } else {
            destinationPath = documentsURL.path
        }
    }

    private func browseForDestination() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Choose"
        panel.message = "Select a folder to clone into"

        if !destinationPath.isEmpty {
            panel.directoryURL = URL(fileURLWithPath: destinationPath)
        }

        if panel.runModal() == .OK, let url = panel.url {
            destinationPath = url.path
        }
    }

    private func performClone() {
        guard canClone else { return }

        isCloning = true
        error = nil

        let destinationURL = URL(fileURLWithPath: destinationPath)
        let cloneBranch = branch.isEmpty ? nil : branch

        Task {
            do {
                let repoURL = try await gitService.clone(
                    url: url,
                    to: destinationURL,
                    branch: cloneBranch
                )

                await MainActor.run {
                    isCloning = false
                    isPresented = false
                    onClone(repoURL)
                }
            } catch let gitError as GitError {
                await MainActor.run {
                    isCloning = false
                    error = gitError.localizedDescription
                }
            } catch {
                await MainActor.run {
                    isCloning = false
                    self.error = error.localizedDescription
                }
            }
        }
    }
}

#Preview {
    CloneRepositorySheet(isPresented: .constant(true)) { _ in }
}
