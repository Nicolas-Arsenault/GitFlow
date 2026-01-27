import Foundation

/// Represents a Git remote.
struct Remote: Identifiable, Equatable, Hashable {
    /// The remote name (e.g., "origin").
    let name: String

    /// The fetch URL.
    let fetchURL: String

    /// The push URL (may differ from fetch URL).
    let pushURL: String

    var id: String { name }

    /// Creates a Remote.
    init(name: String, fetchURL: String, pushURL: String? = nil) {
        self.name = name
        self.fetchURL = fetchURL
        self.pushURL = pushURL ?? fetchURL
    }

    /// Whether this remote uses SSH.
    var isSSH: Bool {
        fetchURL.hasPrefix("git@") || fetchURL.contains("ssh://")
    }

    /// Whether this remote uses HTTPS.
    var isHTTPS: Bool {
        fetchURL.hasPrefix("https://") || fetchURL.hasPrefix("http://")
    }

    /// Extracts the host from the URL.
    var host: String? {
        if isSSH {
            // git@github.com:user/repo.git
            let pattern = #"git@([^:]+):"#
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: fetchURL, range: NSRange(fetchURL.startIndex..., in: fetchURL)),
               let range = Range(match.range(at: 1), in: fetchURL) {
                return String(fetchURL[range])
            }
        } else if let url = URL(string: fetchURL) {
            return url.host
        }
        return nil
    }
}
