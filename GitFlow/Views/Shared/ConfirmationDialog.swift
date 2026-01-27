import SwiftUI

/// A reusable confirmation dialog for destructive actions.
struct DestructiveConfirmationDialog: ViewModifier {
    let title: String
    let message: String
    let actionLabel: String
    @Binding var isPresented: Bool
    let action: () -> Void

    func body(content: Content) -> some View {
        content
            .confirmationDialog(title, isPresented: $isPresented) {
                Button(actionLabel, role: .destructive) {
                    action()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text(message)
            }
    }
}

extension View {
    /// Presents a confirmation dialog for destructive actions.
    func destructiveConfirmation(
        _ title: String,
        message: String,
        actionLabel: String = "Delete",
        isPresented: Binding<Bool>,
        action: @escaping () -> Void
    ) -> some View {
        modifier(DestructiveConfirmationDialog(
            title: title,
            message: message,
            actionLabel: actionLabel,
            isPresented: isPresented,
            action: action
        ))
    }
}

/// A custom confirmation dialog view.
struct ConfirmationDialogView: View {
    let title: String
    let message: String
    let confirmLabel: String
    let isDestructive: Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void

    init(
        title: String,
        message: String,
        confirmLabel: String = "Continue",
        isDestructive: Bool = false,
        onConfirm: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.title = title
        self.message = message
        self.confirmLabel = confirmLabel
        self.isDestructive = isDestructive
        self.onConfirm = onConfirm
        self.onCancel = onCancel
    }

    var body: some View {
        VStack(spacing: 16) {
            // Icon
            Image(systemName: isDestructive ? "exclamationmark.triangle.fill" : "questionmark.circle.fill")
                .font(.system(size: 36))
                .foregroundStyle(isDestructive ? .red : .blue)

            // Title
            Text(title)
                .font(.headline)

            // Message
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            // Actions
            HStack(spacing: 12) {
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)

                Button(confirmLabel) {
                    onConfirm()
                }
                .buttonStyle(.borderedProminent)
                .tint(isDestructive ? .red : .accentColor)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 300)
        .background(Color(NSColor.windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 20)
    }
}

#Preview {
    ConfirmationDialogView(
        title: "Discard Changes",
        message: "Are you sure you want to discard all changes? This cannot be undone.",
        confirmLabel: "Discard",
        isDestructive: true,
        onConfirm: { },
        onCancel: { }
    )
    .padding()
}
