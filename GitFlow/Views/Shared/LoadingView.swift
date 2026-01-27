import SwiftUI

// MARK: - Loading View

/// A generic loading view with customizable message.
struct LoadingView: View {
    let message: String

    init(_ message: String = "Loading...") {
        self.message = message
    }

    var body: some View {
        VStack(spacing: DSSpacing.lg) {
            ProgressView()
                .scaleEffect(1.2)

            Text(message)
                .font(DSTypography.secondaryContent())
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Loading Overlay

/// An overlay that shows a loading indicator with optional message.
/// Uses material background for better visual integration.
struct LoadingOverlay: View {
    let isLoading: Bool
    let message: String

    init(isLoading: Bool, message: String = "Loading...") {
        self.isLoading = isLoading
        self.message = message
    }

    var body: some View {
        if isLoading {
            ZStack {
                Color.black.opacity(0.15)
                    .ignoresSafeArea()

                VStack(spacing: DSSpacing.md) {
                    ProgressView()
                    Text(message)
                        .font(DSTypography.tertiaryContent())
                        .foregroundStyle(.secondary)
                }
                .padding(DSSpacing.xl)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: DSRadius.xl))
            }
        }
    }
}

// MARK: - Loading Modifier

/// View modifier for adding a loading overlay.
struct LoadingModifier: ViewModifier {
    let isLoading: Bool
    let message: String

    func body(content: Content) -> some View {
        content
            .overlay {
                LoadingOverlay(isLoading: isLoading, message: message)
            }
            .disabled(isLoading)
    }
}

extension View {
    /// Adds a loading overlay to the view.
    func loading(_ isLoading: Bool, message: String = "Loading...") -> some View {
        modifier(LoadingModifier(isLoading: isLoading, message: message))
    }
}

// MARK: - Empty State View

/// A view displayed when there's no content to show.
/// Follows UX principle: Empty states teach users what to do next.
/// Custom replacement for ContentUnavailableView (macOS 14+) to support macOS 13.
struct EmptyStateView: View {
    let title: String
    let systemImage: String
    let description: String?
    let actionLabel: String?
    let action: (() -> Void)?

    /// Creates an empty state view with optional action button.
    /// - Parameters:
    ///   - title: The main title explaining what's empty
    ///   - systemImage: SF Symbol name for the icon
    ///   - description: Optional helpful description suggesting next steps
    ///   - actionLabel: Optional label for action button
    ///   - action: Optional action to perform when button is tapped
    init(
        _ title: String,
        systemImage: String,
        description: String? = nil,
        actionLabel: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.systemImage = systemImage
        self.description = description
        self.actionLabel = actionLabel
        self.action = action
    }

    /// Convenience initializer for Text-based description
    init(_ title: String, systemImage: String, description: Text?) {
        self.title = title
        self.systemImage = systemImage
        self.description = description.map { String("\($0)") }
        self.actionLabel = nil
        self.action = nil
    }

    var body: some View {
        VStack(spacing: DSSpacing.lg) {
            // Icon - muted to avoid looking like an error
            Image(systemName: systemImage)
                .font(.system(size: 44))
                .foregroundStyle(.tertiary)

            // Title
            Text(title)
                .font(DSTypography.sectionTitle())
                .foregroundStyle(.secondary)

            // Description
            if let description {
                Text(description)
                    .font(DSTypography.secondaryContent())
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DSSpacing.xl)
            }

            // Action button
            if let actionLabel, let action {
                Button(actionLabel) {
                    action()
                }
                .buttonStyle(.bordered)
                .padding(.top, DSSpacing.sm)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(DSSpacing.xl)
    }
}

// MARK: - Skeleton Loading View

/// A skeleton placeholder for content that is loading.
/// Creates a subtle pulsing animation to indicate activity.
struct SkeletonView: View {
    let width: CGFloat?
    let height: CGFloat

    @State private var opacity: Double = 0.3

    init(width: CGFloat? = nil, height: CGFloat = 16) {
        self.width = width
        self.height = height
    }

    var body: some View {
        RoundedRectangle(cornerRadius: DSRadius.sm)
            .fill(Color.secondary.opacity(opacity))
            .frame(width: width, height: height)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 0.8)
                    .repeatForever(autoreverses: true)
                ) {
                    opacity = 0.15
                }
            }
    }
}

/// A skeleton placeholder for a list row.
struct SkeletonRow: View {
    var body: some View {
        HStack(spacing: DSSpacing.md) {
            SkeletonView(width: 20, height: 20)
            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                SkeletonView(width: 120, height: 14)
                SkeletonView(width: 80, height: 10)
            }
            Spacer()
        }
        .padding(.vertical, DSSpacing.xs)
    }
}

/// A skeleton placeholder for diff content.
struct SkeletonDiff: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                SkeletonView(width: 200, height: 14)
                Spacer()
            }
            .padding(DSSpacing.md)
            .background(Color.secondary.opacity(0.05))

            // Lines
            ForEach(0..<8, id: \.self) { index in
                HStack(spacing: DSSpacing.sm) {
                    SkeletonView(width: 40, height: 12)
                    SkeletonView(width: CGFloat.random(in: 100...300), height: 12)
                    Spacer()
                }
                .padding(.horizontal, DSSpacing.md)
                .padding(.vertical, DSSpacing.xs)
            }
        }
        .background(Color(NSColor.textBackgroundColor))
    }
}

// MARK: - Previews

#Preview("Loading View") {
    LoadingView("Loading repository...")
        .frame(width: 300, height: 200)
}

#Preview("Empty State - Basic") {
    EmptyStateView(
        "No Changes",
        systemImage: "checkmark.circle",
        description: "Your working tree is clean"
    )
    .frame(width: 400, height: 300)
}

#Preview("Empty State - With Action") {
    EmptyStateView(
        "No Commits Yet",
        systemImage: "clock",
        description: "Create your first commit to start tracking changes",
        actionLabel: "Stage All Files"
    ) {
        print("Action tapped")
    }
    .frame(width: 400, height: 300)
}

#Preview("Skeleton Loading") {
    VStack {
        ForEach(0..<5, id: \.self) { _ in
            SkeletonRow()
        }
    }
    .padding()
    .frame(width: 300)
}

#Preview("Skeleton Diff") {
    SkeletonDiff()
        .frame(width: 500, height: 300)
}
