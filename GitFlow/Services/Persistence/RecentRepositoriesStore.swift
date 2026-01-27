import Foundation

/// Stores and retrieves the list of recently opened repositories.
final class RecentRepositoriesStore {
    /// The UserDefaults key for recent repositories.
    private let key = "com.gitflow.recentRepositories"

    /// The UserDefaults instance.
    private let defaults: UserDefaults

    /// Maximum number of recent repositories to store.
    private let maxCount = 10

    /// Creates a RecentRepositoriesStore.
    /// - Parameter defaults: The UserDefaults instance to use. Defaults to standard.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Saves the list of recent repositories.
    /// - Parameter repositories: The URLs of recently opened repositories.
    func save(_ repositories: [URL]) {
        let paths = repositories.prefix(maxCount).map(\.path)
        defaults.set(paths, forKey: key)
    }

    /// Loads the list of recent repositories.
    /// - Returns: The URLs of recently opened repositories.
    func load() -> [URL] {
        guard let paths = defaults.stringArray(forKey: key) else {
            return []
        }

        return paths.compactMap { path in
            let url = URL(fileURLWithPath: path)
            // Only return if the directory still exists
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory),
                  isDirectory.boolValue else {
                return nil
            }
            return url
        }
    }

    /// Adds a repository to the recent list.
    /// - Parameter url: The URL of the repository to add.
    func add(_ url: URL) {
        var repositories = load()

        // Remove if already exists (to move to front)
        repositories.removeAll { $0 == url }

        // Add to front
        repositories.insert(url, at: 0)

        // Trim to max count
        if repositories.count > maxCount {
            repositories = Array(repositories.prefix(maxCount))
        }

        save(repositories)
    }

    /// Removes a repository from the recent list.
    /// - Parameter url: The URL of the repository to remove.
    func remove(_ url: URL) {
        var repositories = load()
        repositories.removeAll { $0 == url }
        save(repositories)
    }

    /// Clears all recent repositories.
    func clear() {
        defaults.removeObject(forKey: key)
    }
}
