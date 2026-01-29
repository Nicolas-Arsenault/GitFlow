import SwiftUI
import AppKit

/// Manager for tab-based window management with multiple repositories.
@MainActor
class TabWindowManager: ObservableObject {
    static let shared = TabWindowManager()

    @Published var tabs: [WindowTab] = []
    @Published var activeTabId: UUID?

    private var windowToTabMapping: [NSWindow: UUID] = [:]

    private init() {}

    // MARK: - Tab Management

    var activeTab: WindowTab? {
        tabs.first { $0.id == activeTabId }
    }

    func createTab(for repository: Repository) -> WindowTab {
        // Check if tab already exists
        if let existingTab = tabs.first(where: { $0.repositoryPath == repository.path }) {
            activateTab(existingTab.id)
            return existingTab
        }

        let tab = WindowTab(repository: repository)
        tabs.append(tab)
        activateTab(tab.id)
        return tab
    }

    func closeTab(_ tabId: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == tabId }) else { return }

        let wasActive = activeTabId == tabId
        tabs.remove(at: index)

        // If we closed the active tab, activate another one
        if wasActive && !tabs.isEmpty {
            let newIndex = min(index, tabs.count - 1)
            activateTab(tabs[newIndex].id)
        } else if tabs.isEmpty {
            activeTabId = nil
        }
    }

    func closeOtherTabs(_ tabId: UUID) {
        tabs.removeAll { $0.id != tabId }
        activeTabId = tabId
    }

    func closeAllTabs() {
        tabs.removeAll()
        activeTabId = nil
    }

    func activateTab(_ tabId: UUID) {
        guard tabs.contains(where: { $0.id == tabId }) else { return }
        activeTabId = tabId
    }

    func moveTab(from source: Int, to destination: Int) {
        guard source < tabs.count, destination <= tabs.count else { return }
        let tab = tabs.remove(at: source)
        let adjustedDestination = destination > source ? destination - 1 : destination
        tabs.insert(tab, at: min(adjustedDestination, tabs.count))
    }

    // MARK: - Window Integration

    func createNewWindow(for repository: Repository? = nil) {
        let windowController = NSWindowController()
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1200, height: 800),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.title = repository?.name ?? "GitFlow"
        window.center()

        // Create content view
        let contentView = TabAwareContentView()
        window.contentView = NSHostingView(rootView: contentView)

        windowController.window = window
        windowController.showWindow(nil)

        // Create tab for repository if provided
        if let repo = repository {
            _ = createTab(for: repo)
        }
    }

    func openInNewTab(_ repository: Repository) {
        _ = createTab(for: repository)
    }

    // MARK: - Tab State

    func saveTabState() {
        let tabData = tabs.map { TabData(path: $0.repositoryPath, name: $0.name) }
        if let data = try? JSONEncoder().encode(tabData) {
            UserDefaults.standard.set(data, forKey: "savedTabs")
        }
        if let activeId = activeTabId {
            UserDefaults.standard.set(activeId.uuidString, forKey: "activeTabId")
        }
    }

    func restoreTabState() {
        guard let data = UserDefaults.standard.data(forKey: "savedTabs"),
              let tabData = try? JSONDecoder().decode([TabData].self, from: data) else {
            return
        }

        for tab in tabData {
            let url = URL(fileURLWithPath: tab.path)
            if FileManager.default.fileExists(atPath: tab.path) {
                let repo = Repository(rootURL: url)
                _ = createTab(for: repo)
            }
        }

        // Restore active tab
        if let activeIdString = UserDefaults.standard.string(forKey: "activeTabId"),
           let activeId = UUID(uuidString: activeIdString),
           tabs.contains(where: { $0.id == activeId }) {
            activeTabId = activeId
        } else if let firstTab = tabs.first {
            activeTabId = firstTab.id
        }
    }
}

// MARK: - Repository Tab Model

struct WindowTab: Identifiable, Equatable {
    let id: UUID
    let repositoryPath: String
    let name: String
    var hasChanges: Bool = false
    var currentBranch: String = ""

    init(repository: Repository) {
        self.id = UUID()
        self.repositoryPath = repository.path
        self.name = repository.name
    }

    static func == (lhs: WindowTab, rhs: WindowTab) -> Bool {
        lhs.id == rhs.id
    }
}

struct TabData: Codable {
    let path: String
    let name: String
}

// MARK: - Tab Bar View

struct TabBarView: View {
    @ObservedObject var manager: TabWindowManager
    @State private var draggedTab: WindowTab?

    var body: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 1) {
                    ForEach(manager.tabs) { tab in
                        TabItemView(
                            tab: tab,
                            isActive: tab.id == manager.activeTabId,
                            onActivate: { manager.activateTab(tab.id) },
                            onClose: { manager.closeTab(tab.id) }
                        )
                        .onDrag {
                            draggedTab = tab
                            return NSItemProvider(object: tab.id.uuidString as NSString)
                        }
                        .onDrop(of: [.text], delegate: TabDropDelegate(
                            tab: tab,
                            manager: manager,
                            draggedTab: $draggedTab
                        ))
                    }
                }
                .padding(.horizontal, 4)
            }

            Spacer()

            // New tab button
            Button(action: { openNewTab() }) {
                Image(systemName: "plus")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            .help("New tab")
            .padding(.horizontal, 8)
        }
        .frame(height: 28)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private func openNewTab() {
        // Would show repository picker
        NotificationCenter.default.post(name: .showOpenPanel, object: nil)
    }
}

// MARK: - Tab Item View

struct TabItemView: View {
    let tab: WindowTab
    let isActive: Bool
    let onActivate: () -> Void
    let onClose: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 6) {
            // Status indicator
            if tab.hasChanges {
                Circle()
                    .fill(Color.orange)
                    .frame(width: 6, height: 6)
            }

            // Repository name
            Text(tab.name)
                .font(.caption)
                .lineLimit(1)

            // Branch name
            if !tab.currentBranch.isEmpty {
                Text(tab.currentBranch)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            // Close button
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .medium))
            }
            .buttonStyle(.borderless)
            .help("Close tab")
            .opacity(isHovering || isActive ? 1 : 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isActive ? Color.accentColor.opacity(0.2) : (isHovering ? Color.secondary.opacity(0.1) : Color.clear))
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
        }
        .onTapGesture {
            onActivate()
        }
        .contextMenu {
            Button("Close Tab") {
                onClose()
            }

            Button("Close Other Tabs") {
                TabWindowManager.shared.closeOtherTabs(tab.id)
            }
            .disabled(TabWindowManager.shared.tabs.count <= 1)

            Divider()

            Button("Open in New Window") {
                // Would open repository in new window
            }

            Divider()

            Button("Copy Path") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(tab.repositoryPath, forType: .string)
            }

            Button("Reveal in Finder") {
                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: tab.repositoryPath)
            }
        }
    }
}

// MARK: - Tab Drop Delegate

struct TabDropDelegate: DropDelegate {
    let tab: WindowTab
    let manager: TabWindowManager
    @Binding var draggedTab: WindowTab?

    func performDrop(info: DropInfo) -> Bool {
        draggedTab = nil
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let draggedTab = draggedTab,
              draggedTab.id != tab.id,
              let fromIndex = manager.tabs.firstIndex(where: { $0.id == draggedTab.id }),
              let toIndex = manager.tabs.firstIndex(where: { $0.id == tab.id }) else {
            return
        }

        withAnimation(.easeInOut(duration: 0.2)) {
            manager.moveTab(from: fromIndex, to: toIndex)
        }
    }
}

// MARK: - Tab-Aware Content View

struct TabAwareContentView: View {
    @StateObject private var tabManager = TabWindowManager.shared

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar (only show if multiple tabs)
            if tabManager.tabs.count > 1 {
                TabBarView(manager: tabManager)
                Divider()
            }

            // Content area
            if let activeTab = tabManager.activeTab {
                // Would show actual repository content
                VStack {
                    Text("Repository: \(activeTab.name)")
                        .font(.title)
                    Text("Path: \(activeTab.repositoryPath)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Welcome/empty state
                VStack(spacing: 16) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)

                    Text("Open a Repository")
                        .font(.headline)

                    Text("Open a repository to get started, or drag a folder here.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Button("Open Repository...") {
                        NotificationCenter.default.post(name: .showOpenPanel, object: nil)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

// MARK: - Settings

struct TabSettings: Codable {
    var enableTabs: Bool = true
    var openNewReposInTab: Bool = true
    var showTabsWhenSingle: Bool = false
    var maxTabs: Int = 20
    var restoreTabsOnLaunch: Bool = true

    private static let key = "tabSettings"

    static func load() -> TabSettings {
        guard let data = UserDefaults.standard.data(forKey: key),
              let settings = try? JSONDecoder().decode(TabSettings.self, from: data) else {
            return TabSettings()
        }
        return settings
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: TabSettings.key)
        }
    }
}

#Preview("Tab Bar") {
    let manager = TabWindowManager.shared
    let _ = manager.createTab(for: Repository(rootURL: URL(fileURLWithPath: "/tmp/repo1")))
    let _ = manager.createTab(for: Repository(rootURL: URL(fileURLWithPath: "/tmp/repo2")))
    let _ = manager.createTab(for: Repository(rootURL: URL(fileURLWithPath: "/tmp/repo3")))

    return TabBarView(manager: manager)
        .frame(width: 600)
}

#Preview("Content View") {
    TabAwareContentView()
        .frame(width: 800, height: 600)
}
