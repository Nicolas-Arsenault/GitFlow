import SwiftUI

/// A reusable header component for stack-based navigation that provides
/// a back button with title and optional subtitle.
///
/// - Usage: Place at the top of detail views that need back navigation
/// - The Escape key is bound to the back action via `.keyboardShortcut`
struct StackNavigationHeader: View {
    let title: String
    var subtitle: String? = nil
    let onBack: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onBack) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.escape, modifiers: [])

            Divider()
                .frame(height: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .lineLimit(1)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

#Preview {
    VStack(spacing: 0) {
        StackNavigationHeader(
            title: "MyFile.swift",
            subtitle: "Sources/App/MyFile.swift",
            onBack: {}
        )
        Divider()
        Spacer()
    }
    .frame(width: 400, height: 300)
}
