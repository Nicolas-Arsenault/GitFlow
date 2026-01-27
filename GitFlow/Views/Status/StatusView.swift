import SwiftUI

/// Main status view showing working tree state.
struct StatusView: View {
    @ObservedObject var viewModel: StatusViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Text("Changes")
                    .font(.headline)

                Spacer()

                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.6)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            // File list
            if viewModel.status.isClean {
                EmptyStateView(
                    "No Changes",
                    systemImage: "checkmark.circle",
                    description: "Working tree is clean"
                )
            } else {
                FileStatusList(viewModel: viewModel)
            }
        }
        .alert("Error", isPresented: .init(
            get: { viewModel.error != nil },
            set: { if !$0 { viewModel.error = nil } }
        )) {
            Button("OK") { viewModel.error = nil }
        } message: {
            if let error = viewModel.error {
                Text(error.localizedDescription)
            }
        }
    }
}

#Preview {
    StatusView(
        viewModel: StatusViewModel(
            repository: Repository(rootURL: URL(fileURLWithPath: "/tmp")),
            gitService: GitService()
        )
    )
}
