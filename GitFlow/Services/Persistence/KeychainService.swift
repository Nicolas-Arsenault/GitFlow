import Foundation
import Security

/// Provides secure storage for sensitive data using the macOS Keychain.
///
/// The Keychain is the recommended way to store secrets on macOS because:
/// - Data is encrypted at rest using the device's secure enclave
/// - Access is controlled by the app's code signing identity
/// - Data persists across app launches and updates
/// - Protected by system-level security (Touch ID, password, etc.)
final class KeychainService {
    // MARK: - Types

    /// Errors that can occur during Keychain operations.
    enum KeychainError: LocalizedError {
        case itemNotFound
        case duplicateItem
        case invalidData
        case unexpectedStatus(OSStatus)

        var errorDescription: String? {
            switch self {
            case .itemNotFound:
                return "Item not found in Keychain"
            case .duplicateItem:
                return "Item already exists in Keychain"
            case .invalidData:
                return "Invalid data format"
            case .unexpectedStatus(let status):
                if let message = SecCopyErrorMessageString(status, nil) {
                    return "Keychain error: \(message)"
                }
                return "Keychain error: \(status)"
            }
        }
    }

    // MARK: - Properties

    /// The service identifier for Keychain items.
    /// Using bundle identifier ensures items are scoped to this app.
    private let service: String

    /// Shared instance for app-wide use.
    static let shared = KeychainService()

    // MARK: - Initialization

    /// Creates a KeychainService with the specified service identifier.
    /// - Parameter service: The service identifier. Defaults to the app's bundle identifier.
    init(service: String = Bundle.main.bundleIdentifier ?? "com.gitflow.app") {
        self.service = service
    }

    // MARK: - Public Methods

    /// Saves a string value securely to the Keychain.
    ///
    /// - Parameters:
    ///   - value: The string value to store.
    ///   - account: The account identifier (key) for the item.
    /// - Throws: `KeychainError` if the operation fails.
    func save(_ value: String, for account: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.invalidData
        }

        // First, try to delete any existing item
        try? delete(for: account)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            // Accessibility: Available after first unlock, not backed up to iCloud
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    /// Retrieves a string value from the Keychain.
    ///
    /// - Parameter account: The account identifier (key) for the item.
    /// - Returns: The stored string value, or `nil` if not found.
    func retrieve(for account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }

        return value
    }

    /// Deletes a value from the Keychain.
    ///
    /// - Parameter account: The account identifier (key) for the item.
    /// - Throws: `KeychainError` if the operation fails (except for item not found).
    func delete(for account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)

        // Ignore "item not found" errors since we're deleting anyway
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    /// Updates an existing value in the Keychain, or creates it if it doesn't exist.
    ///
    /// - Parameters:
    ///   - value: The new string value to store.
    ///   - account: The account identifier (key) for the item.
    /// - Throws: `KeychainError` if the operation fails.
    func update(_ value: String, for account: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.invalidData
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        if status == errSecItemNotFound {
            // Item doesn't exist, create it
            try save(value, for: account)
        } else if status != errSecSuccess {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    /// Checks if a value exists in the Keychain for the given account.
    ///
    /// - Parameter account: The account identifier (key) to check.
    /// - Returns: `true` if a value exists, `false` otherwise.
    func exists(for account: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: false
        ]

        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }
}

// MARK: - Keychain Account Keys

/// Constants for Keychain account identifiers used throughout the app.
enum KeychainAccount {
    /// GitHub personal access token for API authentication.
    static let githubToken = "github_personal_access_token"

    /// GitHub OAuth access token (from OAuth flow).
    static let githubOAuthToken = "github_oauth_token"

    /// GitHub OAuth client secret.
    static let githubClientSecret = "github_client_secret"
}
