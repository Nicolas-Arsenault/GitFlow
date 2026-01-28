import Foundation

/// A command that can be executed from the command palette.
struct PaletteCommand: Identifiable, Equatable {
    let id = UUID()

    /// The display name of the command.
    let name: String

    /// A description of what the command does.
    let description: String?

    /// The category of the command.
    let category: CommandCategory

    /// Keyboard shortcut, if any.
    let shortcut: String?

    /// Icon name for the command.
    let iconName: String

    /// The action to perform.
    let action: () -> Void

    init(
        name: String,
        description: String? = nil,
        category: CommandCategory,
        shortcut: String? = nil,
        iconName: String = "command",
        action: @escaping () -> Void
    ) {
        self.name = name
        self.description = description
        self.category = category
        self.shortcut = shortcut
        self.iconName = iconName
        self.action = action
    }

    static func == (lhs: PaletteCommand, rhs: PaletteCommand) -> Bool {
        lhs.id == rhs.id
    }
}

/// Category of commands in the palette.
enum CommandCategory: String, CaseIterable, Identifiable {
    case git = "Git"
    case branch = "Branch"
    case commit = "Commit"
    case file = "File"
    case view = "View"
    case navigation = "Navigation"
    case repository = "Repository"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .git: return "chevron.left.forwardslash.chevron.right"
        case .branch: return "arrow.triangle.branch"
        case .commit: return "checkmark.circle"
        case .file: return "doc"
        case .view: return "eye"
        case .navigation: return "arrow.right.circle"
        case .repository: return "folder"
        }
    }
}

/// A recent action that was performed.
struct RecentAction: Identifiable, Codable {
    let id: UUID
    let name: String
    let category: String
    let timestamp: Date

    init(name: String, category: String) {
        self.id = UUID()
        self.name = name
        self.category = category
        self.timestamp = Date()
    }
}

/// A search result from global search.
struct GlobalSearchResult: Identifiable {
    let id = UUID()

    /// The type of result.
    let type: SearchResultType

    /// The display title.
    let title: String

    /// Secondary information.
    let subtitle: String?

    /// The path or reference.
    let path: String?

    /// Match highlights (ranges).
    let highlights: [Range<String.Index>]

    /// Action to perform when selected.
    let action: () -> Void

    init(
        type: SearchResultType,
        title: String,
        subtitle: String? = nil,
        path: String? = nil,
        highlights: [Range<String.Index>] = [],
        action: @escaping () -> Void
    ) {
        self.type = type
        self.title = title
        self.subtitle = subtitle
        self.path = path
        self.highlights = highlights
        self.action = action
    }
}

/// Type of search result.
enum SearchResultType: String, CaseIterable {
    case file = "File"
    case commit = "Commit"
    case branch = "Branch"
    case tag = "Tag"
    case stash = "Stash"
    case command = "Command"

    var iconName: String {
        switch self {
        case .file: return "doc"
        case .commit: return "checkmark.circle"
        case .branch: return "arrow.triangle.branch"
        case .tag: return "tag"
        case .stash: return "tray.and.arrow.down"
        case .command: return "command"
        }
    }

    var color: String {
        switch self {
        case .file: return "blue"
        case .commit: return "green"
        case .branch: return "purple"
        case .tag: return "orange"
        case .stash: return "cyan"
        case .command: return "gray"
        }
    }
}

/// Quick action for the quick actions menu.
struct QuickAction: Identifiable {
    let id = UUID()
    let name: String
    let iconName: String
    let shortcut: String?
    let action: () -> Void
}
