import Foundation
import SwiftUI

/// Application-wide constants.
enum Constants {
    /// Application information.
    enum App {
        static let name = "GitFlow"
        static let bundleIdentifier = "com.gitflow.GitFlow"
        static let version = "1.0.0"
    }

    /// Git-related constants.
    enum Git {
        /// Default path to Git executable.
        static let defaultPath = "/usr/bin/git"

        /// Maximum commit message subject length (soft limit).
        static let subjectSoftLimit = 50

        /// Maximum commit message subject length (hard limit).
        static let subjectHardLimit = 72

        /// Default number of commits to load in history.
        static let defaultHistoryLimit = 100

        /// Default context lines for diffs.
        static let defaultContextLines = 3
    }

    /// UI-related constants.
    enum UI {
        /// Default window dimensions.
        enum Window {
            static let minWidth: CGFloat = 900
            static let minHeight: CGFloat = 600
            static let defaultWidth: CGFloat = 1200
            static let defaultHeight: CGFloat = 800
        }

        /// Sidebar dimensions.
        enum Sidebar {
            static let minWidth: CGFloat = 180
            static let idealWidth: CGFloat = 200
            static let maxWidth: CGFloat = 250
        }

        /// Font sizes.
        enum FontSize {
            static let diffCode: CGFloat = 12
            static let minimum: CGFloat = 10
            static let maximum: CGFloat = 18
        }

        /// Animation durations.
        enum Animation {
            static let fast: Double = 0.15
            static let normal: Double = 0.25
            static let slow: Double = 0.4
        }
    }

    /// Keyboard shortcuts.
    enum Shortcuts {
        static let refresh = "r"
        static let commit = "return"
        static let stageAll = "a"
        static let unstageAll = "u"
    }
}

/// Colors used throughout the application.
/// Uses the design system colors for consistency and accessibility.
enum AppColors {
    // Change type colors (muted for reduced visual anxiety)
    static let addition = DSColors.addition
    static let deletion = DSColors.deletion
    static let modification = DSColors.modification
    static let rename = DSColors.rename
    static let untracked = Color.secondary

    // Diff background colors (subtle, adaptive to color scheme)
    static let additionBackground = DSColors.additionBackground
    static let deletionBackground = DSColors.deletionBackground
    static let hunkHeaderBackground = DSColors.hunkHeaderBackground

    // Status colors (calmer variants)
    static let success = DSColors.success
    static let warning = DSColors.warning
    static let error = DSColors.error
    static let info = DSColors.info
}
