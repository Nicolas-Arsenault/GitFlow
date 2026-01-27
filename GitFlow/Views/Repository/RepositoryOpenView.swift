import SwiftUI

/// View for opening a repository.
struct RepositoryOpenView: View {
    @EnvironmentObject private var appState: AppState

    @State private var repositoryPath: String = ""
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""

    var body: some View {
        VStack(spacing: 20) {
            Text("Open Repository")
                .font(.title2)
                .fontWeight(.semibold)

            HStack {
                TextField("Repository path", text: $repositoryPath)
                    .textFieldStyle(.roundedBorder)

                Button("Browse...") {
                    appState.showOpenRepositoryPanel()
                }
            }

            HStack {
                Button("Cancel") {
                    // Handle cancel
                }
                .keyboardShortcut(.cancelAction)

                Button("Open") {
                    openRepository()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(repositoryPath.isEmpty)
            }
        }
        .padding()
        .frame(width: 400)
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }

    private func openRepository() {
        let url = URL(fileURLWithPath: repositoryPath)
        appState.openRepository(at: url)
    }
}

#Preview {
    RepositoryOpenView()
        .environmentObject(AppState())
}
