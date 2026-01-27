import Foundation
import SwiftUI

/// Stores and retrieves application settings.
final class SettingsStore: ObservableObject {
    // MARK: - Keys

    private enum Keys {
        static let diffViewMode = "com.gitflow.diffViewMode"
        static let showLineNumbers = "com.gitflow.showLineNumbers"
        static let wrapLines = "com.gitflow.wrapLines"
        static let showRemoteBranches = "com.gitflow.showRemoteBranches"
        static let fontSize = "com.gitflow.fontSize"
        static let gitPath = "com.gitflow.gitPath"
    }

    // MARK: - Properties

    private let defaults: UserDefaults

    /// The diff view mode (unified or split).
    @Published var diffViewMode: DiffViewModel.ViewMode {
        didSet {
            defaults.set(diffViewMode.rawValue, forKey: Keys.diffViewMode)
        }
    }

    /// Whether to show line numbers in diffs.
    @Published var showLineNumbers: Bool {
        didSet {
            defaults.set(showLineNumbers, forKey: Keys.showLineNumbers)
        }
    }

    /// Whether to wrap long lines in diffs.
    @Published var wrapLines: Bool {
        didSet {
            defaults.set(wrapLines, forKey: Keys.wrapLines)
        }
    }

    /// Whether to show remote branches by default.
    @Published var showRemoteBranches: Bool {
        didSet {
            defaults.set(showRemoteBranches, forKey: Keys.showRemoteBranches)
        }
    }

    /// The font size for code display.
    @Published var fontSize: Double {
        didSet {
            defaults.set(fontSize, forKey: Keys.fontSize)
        }
    }

    /// Custom path to the Git executable.
    @Published var gitPath: String {
        didSet {
            defaults.set(gitPath, forKey: Keys.gitPath)
        }
    }

    // MARK: - Initialization

    /// Creates a SettingsStore.
    /// - Parameter defaults: The UserDefaults instance to use. Defaults to standard.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        // Load settings from defaults
        self.diffViewMode = defaults.string(forKey: Keys.diffViewMode)
            .flatMap { DiffViewModel.ViewMode(rawValue: $0) } ?? .unified

        self.showLineNumbers = defaults.object(forKey: Keys.showLineNumbers) as? Bool ?? true
        self.wrapLines = defaults.object(forKey: Keys.wrapLines) as? Bool ?? false
        self.showRemoteBranches = defaults.object(forKey: Keys.showRemoteBranches) as? Bool ?? true
        self.fontSize = defaults.object(forKey: Keys.fontSize) as? Double ?? 12.0
        self.gitPath = defaults.string(forKey: Keys.gitPath) ?? "/usr/bin/git"
    }

    // MARK: - Methods

    /// Resets all settings to their defaults.
    func resetToDefaults() {
        diffViewMode = .unified
        showLineNumbers = true
        wrapLines = false
        showRemoteBranches = true
        fontSize = 12.0
        gitPath = "/usr/bin/git"
    }
}
