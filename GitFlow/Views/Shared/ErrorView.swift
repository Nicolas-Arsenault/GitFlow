import SwiftUI

// MARK: - Error View

/// A view for displaying errors with a calm, helpful tone.
/// Follows UX principle: Errors explain what happened and what to do next.
struct ErrorView: View {
    let error: Error
    let retryAction: (() -> Void)?

    init(_ error: Error, retryAction: (() -> Void)? = nil) {
        self.error = error
        self.retryAction = retryAction
    }

    var body: some View {
        VStack(spacing: DSSpacing.lg) {
            // Icon - using a calmer warning style instead of alarming red
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 44))
                .foregroundStyle(DSColors.warning)

            // Title - calm and informative
            Text("Something went wrong")
                .font(DSTypography.sectionTitle())

            // Message structured as: what happened + helpful context
            VStack(spacing: DSSpacing.sm) {
                Text(userFriendlyMessage)
                    .font(DSTypography.secondaryContent())
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                if let suggestion = recoverySuggestion {
                    Text(suggestion)
                        .font(DSTypography.tertiaryContent())
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, DSSpacing.xl)

            // Actions
            if let retryAction {
                Button("Try Again") {
                    retryAction()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(DSSpacing.xl)
    }

    /// Converts technical errors into user-friendly messages
    private var userFriendlyMessage: String {
        if let gitError = error as? GitError {
            return gitError.userFriendlyDescription
        }
        return error.localizedDescription
    }

    /// Provides helpful suggestions for recovery
    private var recoverySuggestion: String? {
        if let gitError = error as? GitError {
            return gitError.recoverySuggestion
        }
        return nil
    }
}

// MARK: - Error Banner

/// An inline error banner for non-blocking error display.
/// Uses calmer colors and helpful tone.
struct ErrorBanner: View {
    let message: String
    let suggestion: String?
    let dismissAction: () -> Void

    init(message: String, suggestion: String? = nil, dismissAction: @escaping () -> Void) {
        self.message = message
        self.suggestion = suggestion
        self.dismissAction = dismissAction
    }

    var body: some View {
        HStack(alignment: .top, spacing: DSSpacing.sm) {
            Image(systemName: "exclamationmark.circle")
                .foregroundStyle(DSColors.warning)
                .font(.system(size: 16))

            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                Text(message)
                    .font(DSTypography.secondaryContent())

                if let suggestion {
                    Text(suggestion)
                        .font(DSTypography.tertiaryContent())
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button(action: dismissAction) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Dismiss")
        }
        .padding(DSSpacing.md)
        .background(DSColors.warningBadgeBackground)
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.md))
    }
}

// MARK: - Improved Error Alert Modifier

/// View modifier for showing error alerts with helpful messaging.
struct ErrorAlertModifier: ViewModifier {
    @Binding var error: GitError?

    func body(content: Content) -> some View {
        content
            .alert(
                "Something went wrong",
                isPresented: .init(
                    get: { error != nil },
                    set: { if !$0 { error = nil } }
                )
            ) {
                Button("Dismiss") { error = nil }

                if error?.recoverySuggestion != nil {
                    Button("Learn More") {
                        // Could open help or documentation
                        error = nil
                    }
                }
            } message: {
                if let error {
                    VStack {
                        Text(error.userFriendlyDescription)
                        if let suggestion = error.recoverySuggestion {
                            Text(suggestion)
                                .font(.caption)
                        }
                    }
                }
            }
    }
}

extension View {
    /// Presents an error alert when the error binding is non-nil.
    func errorAlert(_ error: Binding<GitError?>) -> some View {
        modifier(ErrorAlertModifier(error: error))
    }
}

// MARK: - GitError Extensions

extension GitError {
    /// User-friendly description that avoids technical jargon
    var userFriendlyDescription: String {
        switch self {
        case .notARepository:
            return "This folder doesn't appear to be a Git repository."
        case .gitNotFound:
            return "Git isn't installed or couldn't be found on your system."
        case .commandFailed:
            return "The Git operation couldn't be completed."
        case .parseError:
            return "Received unexpected data from Git."
        case .branchNotFound(let name):
            return "The branch '\(name)' doesn't exist."
        case .commitNotFound(let hash):
            return "The commit '\(hash.prefix(7))' couldn't be found."
        case .uncommittedChanges:
            return "You have uncommitted changes that would be affected."
        case .mergeConflict(let files):
            return "There are merge conflicts in \(files.count) file\(files.count == 1 ? "" : "s")."
        case .cancelled:
            return "The operation was cancelled."
        case .unknown(let message):
            return message
        }
    }

    /// Helpful suggestion for how to resolve the error
    var recoverySuggestion: String? {
        switch self {
        case .notARepository:
            return "Try opening a different folder or initialize a new repository."
        case .gitNotFound:
            return "Install Git from git-scm.com or via Homebrew."
        case .commandFailed:
            return "Check your Git configuration and try again."
        case .parseError:
            return "Try refreshing or restarting the application."
        case .branchNotFound:
            return "Check the branch name or fetch from remote."
        case .commitNotFound:
            return "The commit may have been removed or rebased away."
        case .uncommittedChanges:
            return "Commit or stash your changes before proceeding."
        case .mergeConflict:
            return "Open each conflicted file and resolve the conflicts manually."
        case .cancelled:
            return nil
        case .unknown:
            return nil
        }
    }
}

// MARK: - Previews

#Preview("Error View") {
    ErrorView(GitError.notARepository(path: "/tmp/not-a-repo")) {
        print("Retry tapped")
    }
    .frame(width: 400, height: 300)
}

#Preview("Error Banner") {
    VStack {
        ErrorBanner(
            message: "Couldn't stage the file",
            suggestion: "Check if the file still exists"
        ) { }
        .padding()

        Spacer()
    }
    .frame(width: 400, height: 200)
}
