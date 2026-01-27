import SwiftUI

// MARK: - Design System
/// Centralized design system following macOS HIG and the app's UX principles.
/// The goal is to create a calm, trustworthy, and professional interface.

// MARK: - Color Palette

/// Semantic color palette optimized for accessibility and reduced visual anxiety.
/// Uses muted, low-saturation colors that support meaning without creating alarm.
enum DSColors {
    // MARK: Git Semantic Colors (Muted variants)

    /// Safe/addition color - muted green that doesn't overwhelm
    static let addition = Color(nsColor: NSColor(
        calibratedRed: 0.22, green: 0.55, blue: 0.35, alpha: 1.0
    ))

    /// Deletion/removal color - muted red that signals without alarming
    static let deletion = Color(nsColor: NSColor(
        calibratedRed: 0.75, green: 0.32, blue: 0.32, alpha: 1.0
    ))

    /// Warning color - amber that draws attention calmly
    static let warning = Color(nsColor: NSColor(
        calibratedRed: 0.82, green: 0.58, blue: 0.20, alpha: 1.0
    ))

    /// Information color - calm blue
    static let info = Color(nsColor: NSColor(
        calibratedRed: 0.30, green: 0.50, blue: 0.70, alpha: 1.0
    ))

    /// Modification color - muted orange
    static let modification = Color(nsColor: NSColor(
        calibratedRed: 0.75, green: 0.52, blue: 0.28, alpha: 1.0
    ))

    /// Rename color - subtle blue
    static let rename = Color(nsColor: NSColor(
        calibratedRed: 0.40, green: 0.55, blue: 0.75, alpha: 1.0
    ))

    // MARK: Diff Background Colors (Very subtle)

    static let additionBackground = Color(nsColor: NSColor(
        calibratedRed: 0.85, green: 0.95, blue: 0.88, alpha: 1.0
    ))

    static let additionBackgroundDark = Color(nsColor: NSColor(
        calibratedRed: 0.15, green: 0.25, blue: 0.18, alpha: 1.0
    ))

    static let deletionBackground = Color(nsColor: NSColor(
        calibratedRed: 0.98, green: 0.88, blue: 0.88, alpha: 1.0
    ))

    static let deletionBackgroundDark = Color(nsColor: NSColor(
        calibratedRed: 0.28, green: 0.15, blue: 0.15, alpha: 1.0
    ))

    static let hunkHeaderBackground = Color(nsColor: NSColor(
        calibratedRed: 0.92, green: 0.95, blue: 0.98, alpha: 1.0
    ))

    static let hunkHeaderBackgroundDark = Color(nsColor: NSColor(
        calibratedRed: 0.18, green: 0.22, blue: 0.28, alpha: 1.0
    ))

    // MARK: Status Colors (Calmer variants)

    /// Success - used sparingly for positive confirmations
    static let success = Color(nsColor: NSColor(
        calibratedRed: 0.28, green: 0.62, blue: 0.40, alpha: 1.0
    ))

    /// Error - still visible but not alarming
    static let error = Color(nsColor: NSColor(
        calibratedRed: 0.75, green: 0.35, blue: 0.35, alpha: 1.0
    ))

    // MARK: Background Accents

    /// Subtle accent for badges
    static let badgeBackground = Color.accentColor.opacity(0.15)

    /// Warning badge background
    static let warningBadgeBackground = Color(nsColor: NSColor(
        calibratedRed: 0.95, green: 0.88, blue: 0.75, alpha: 1.0
    ))

    // MARK: Adaptive Colors

    /// Returns the appropriate diff addition background for the current color scheme
    static func diffAdditionBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? additionBackgroundDark : additionBackground
    }

    /// Returns the appropriate diff deletion background for the current color scheme
    static func diffDeletionBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? deletionBackgroundDark : deletionBackground
    }

    /// Returns the appropriate hunk header background for the current color scheme
    static func diffHunkBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? hunkHeaderBackgroundDark : hunkHeaderBackground
    }
}

// MARK: - Typography

/// Typography scale following macOS conventions with clear hierarchy.
enum DSTypography {
    // MARK: Section Titles

    /// Large section titles
    static func sectionTitle() -> Font {
        .headline
    }

    /// Subsection titles
    static func subsectionTitle() -> Font {
        .subheadline.weight(.medium)
    }

    // MARK: Content

    /// Primary content (file names, commit messages)
    static func primaryContent() -> Font {
        .body
    }

    /// Secondary content (paths, metadata)
    static func secondaryContent() -> Font {
        .callout
    }

    /// Tertiary content (timestamps, counts)
    static func tertiaryContent() -> Font {
        .caption
    }

    /// Small labels (badges, indicators)
    static func smallLabel() -> Font {
        .caption2
    }

    // MARK: Code

    /// Monospaced font for code/diffs
    static func code(size: CGFloat = 12) -> Font {
        .system(size: size, design: .monospaced)
    }
}

// MARK: - Spacing

/// Consistent spacing scale based on 4pt grid.
enum DSSpacing {
    /// Extra small: 4pt
    static let xs: CGFloat = 4

    /// Small: 8pt
    static let sm: CGFloat = 8

    /// Medium: 12pt
    static let md: CGFloat = 12

    /// Large: 16pt
    static let lg: CGFloat = 16

    /// Extra large: 24pt
    static let xl: CGFloat = 24

    /// Double extra large: 32pt
    static let xxl: CGFloat = 32

    // MARK: Specific Use Cases

    /// Standard horizontal padding for content areas
    static let contentPaddingH: CGFloat = 16

    /// Standard vertical padding for content areas
    static let contentPaddingV: CGFloat = 12

    /// Spacing between list items
    static let listItemSpacing: CGFloat = 2

    /// Spacing between sections
    static let sectionSpacing: CGFloat = 16

    /// Icon-to-text spacing
    static let iconTextSpacing: CGFloat = 8
}

// MARK: - Corner Radius

/// Consistent corner radius values.
enum DSRadius {
    /// Small: 4pt - for badges, small buttons
    static let sm: CGFloat = 4

    /// Medium: 6pt - for cards, list items
    static let md: CGFloat = 6

    /// Large: 8pt - for modals, larger containers
    static let lg: CGFloat = 8

    /// Extra large: 12pt - for sheets, dialogs
    static let xl: CGFloat = 12
}

// MARK: - Shadows

/// Subtle shadow configurations for depth.
enum DSShadow {
    /// Subtle shadow for cards
    static let subtle: (color: Color, radius: CGFloat, y: CGFloat) = (
        Color.black.opacity(0.08), 4, 2
    )

    /// Medium shadow for floating elements
    static let medium: (color: Color, radius: CGFloat, y: CGFloat) = (
        Color.black.opacity(0.12), 8, 4
    )

    /// Strong shadow for modals
    static let strong: (color: Color, radius: CGFloat, y: CGFloat) = (
        Color.black.opacity(0.18), 16, 8
    )
}

// MARK: - View Extensions

extension View {
    /// Applies a subtle card-like background
    func cardStyle() -> some View {
        self
            .padding(DSSpacing.md)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.md))
    }

    /// Applies standard content padding
    func contentPadding() -> some View {
        self.padding(.horizontal, DSSpacing.contentPaddingH)
            .padding(.vertical, DSSpacing.contentPaddingV)
    }

    /// Applies a subtle shadow
    func subtleShadow() -> some View {
        let shadow = DSShadow.subtle
        return self.shadow(color: shadow.color, radius: shadow.radius, y: shadow.y)
    }
}

// MARK: - Accessibility Helpers

extension DSColors {
    /// Provides an accessibility-friendly text color that contrasts with the given background
    static func accessibleText(on backgroundColor: Color) -> Color {
        // For simplicity, use primary text which adapts to light/dark mode
        return .primary
    }

    /// Returns a colorblind-safe indicator symbol for the given change type
    static func accessibilitySymbol(for changeType: FileChangeType) -> String {
        switch changeType {
        case .added: return "plus"
        case .deleted: return "minus"
        case .modified: return "pencil"
        case .renamed: return "arrow.right"
        case .copied: return "doc.on.doc"
        case .unmerged: return "exclamationmark.triangle"
        case .typeChanged: return "arrow.triangle.2.circlepath"
        case .untracked: return "questionmark"
        case .ignored: return "eye.slash"
        }
    }
}

// MARK: - Animation Constants

extension Animation {
    /// Fast interaction response
    static let fastResponse = Animation.easeOut(duration: 0.15)

    /// Standard animation
    static let standard = Animation.easeInOut(duration: 0.25)

    /// Slower, more deliberate animation
    static let deliberate = Animation.easeInOut(duration: 0.35)
}
