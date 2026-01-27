import SwiftUI
import CryptoKit

/// A small avatar view for displaying user identity in commit history.
/// Uses Gravatar when available, with an initials-based fallback.
struct AvatarView: View {
    let name: String
    let email: String
    let size: CGFloat

    @State private var gravatarImage: NSImage?
    @State private var imageLoadFailed = false

    init(name: String, email: String, size: CGFloat = 24) {
        self.name = name
        self.email = email
        self.size = size
    }

    var body: some View {
        Group {
            if let image = gravatarImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                InitialsAvatarView(name: name, email: email, size: size)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .task(id: email) {
            await loadGravatar()
        }
    }

    private func loadGravatar() async {
        guard !imageLoadFailed else { return }

        let gravatarURL = Self.gravatarURL(for: email, size: Int(size * 2))

        do {
            let (data, response) = try await URLSession.shared.data(from: gravatarURL)

            // Check if we got a valid image response (not a 404 default)
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200,
               let image = NSImage(data: data) {
                await MainActor.run {
                    self.gravatarImage = image
                }
            } else {
                await MainActor.run {
                    self.imageLoadFailed = true
                }
            }
        } catch {
            await MainActor.run {
                self.imageLoadFailed = true
            }
        }
    }

    /// Generates a Gravatar URL for the given email address.
    /// - Parameters:
    ///   - email: The email address to hash
    ///   - size: The desired image size in pixels
    /// - Returns: The Gravatar URL with d=404 to detect missing avatars
    static func gravatarURL(for email: String, size: Int) -> URL {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let hash = Insecure.MD5.hash(data: Data(trimmedEmail.utf8))
            .map { String(format: "%02x", $0) }
            .joined()

        return URL(string: "https://www.gravatar.com/avatar/\(hash)?s=\(size)&d=404")!
    }
}

/// Fallback avatar showing initials with a color derived from the name/email.
struct InitialsAvatarView: View {
    let name: String
    let email: String
    let size: CGFloat

    var body: some View {
        ZStack {
            avatarColor

            Text(initials)
                .font(.system(size: size * 0.4, weight: .medium, design: .rounded))
                .foregroundStyle(.white)
        }
    }

    /// Extracts initials from the name (up to 2 characters).
    private var initials: String {
        let components = name.split(separator: " ")
        if components.count >= 2 {
            let first = components[0].prefix(1)
            let last = components[components.count - 1].prefix(1)
            return "\(first)\(last)".uppercased()
        } else if let first = components.first?.prefix(2) {
            return String(first).uppercased()
        }
        return "?"
    }

    /// Generates a consistent color based on the email hash.
    private var avatarColor: Color {
        let hash = abs(email.hashValue)

        // Use a set of pleasant, muted colors that work well in both light and dark mode
        let colors: [Color] = [
            Color(hue: 0.0, saturation: 0.5, brightness: 0.6),   // Muted red
            Color(hue: 0.08, saturation: 0.5, brightness: 0.6),  // Muted orange
            Color(hue: 0.12, saturation: 0.5, brightness: 0.6),  // Muted amber
            Color(hue: 0.3, saturation: 0.45, brightness: 0.55), // Muted green
            Color(hue: 0.45, saturation: 0.45, brightness: 0.55),// Muted teal
            Color(hue: 0.55, saturation: 0.45, brightness: 0.6), // Muted cyan
            Color(hue: 0.6, saturation: 0.5, brightness: 0.6),   // Muted blue
            Color(hue: 0.7, saturation: 0.45, brightness: 0.6),  // Muted indigo
            Color(hue: 0.8, saturation: 0.4, brightness: 0.6),   // Muted purple
            Color(hue: 0.9, saturation: 0.4, brightness: 0.6),   // Muted pink
        ]

        return colors[hash % colors.count]
    }
}

#Preview("Gravatar") {
    HStack(spacing: 16) {
        AvatarView(name: "John Doe", email: "john@example.com", size: 24)
        AvatarView(name: "John Doe", email: "john@example.com", size: 32)
        AvatarView(name: "John Doe", email: "john@example.com", size: 48)
    }
    .padding()
}

#Preview("Initials Fallback") {
    HStack(spacing: 16) {
        InitialsAvatarView(name: "John Doe", email: "john@example.com", size: 24)
        InitialsAvatarView(name: "Jane Smith", email: "jane@example.com", size: 32)
        InitialsAvatarView(name: "Alice", email: "alice@example.com", size: 48)
        InitialsAvatarView(name: "Bob Builder", email: "bob@builder.com", size: 32)
    }
    .padding()
}
