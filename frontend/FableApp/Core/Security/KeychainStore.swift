import Foundation
import Security

/// Native iOS Keychain Store
/// Manages hardware-backed, encrypted credential and session storage
/// via Apple's Security framework (SecItemAdd, SecItemCopyMatching, SecItemDelete).
public final class KeychainStore {
    public static let shared = KeychainStore()

    private let service = "mseuf.edu.ph.fable.auth"
    private let tokenAccount = "accessToken"
    private let sessionAccount = "userSession"

    private init() {}

    // MARK: - Access Token Storage

    /// Saves the authentication token securely into the iOS Keychain.
    /// Replaces any existing token to maintain a single source of truth.
    @discardableResult
    public func saveAccessToken(_ token: String) -> Bool {
        guard let data = token.data(using: .utf8) else { return false }
        deleteAccessToken()

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: tokenAccount,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    /// Reads the stored authentication token from the iOS Keychain.
    /// Returns nil if no token is saved or an error occurs.
    public func readAccessToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: tokenAccount,
            kSecReturnData as String: true,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let attributes = result as? [String: Any],
              let data = attributes[kSecValueData as String] as? Data,
              migrateToDeviceOnlyAccessibility(
                account: tokenAccount,
                currentAccessibility: attributes[kSecAttrAccessible as String]
              ) else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    /// Removes the authentication token from the iOS Keychain.
    @discardableResult
    public func deleteAccessToken() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: tokenAccount
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    // MARK: - Generic Payload / Session Storage

    /// Saves arbitrary data into the iOS Keychain under the specified account key.
    @discardableResult
    public func saveData(key: String, data: Data) -> Bool {
        deleteData(key: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    /// Reads arbitrary data from the iOS Keychain for the specified account key.
    public func readData(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let attributes = result as? [String: Any],
              let data = attributes[kSecValueData as String] as? Data,
              migrateToDeviceOnlyAccessibility(
                account: key,
                currentAccessibility: attributes[kSecAttrAccessible as String]
              ) else {
            return nil
        }

        return data
    }

    /// Deletes arbitrary data from the iOS Keychain for the specified account key.
    @discardableResult
    public func deleteData(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    private func migrateToDeviceOnlyAccessibility(account: String, currentAccessibility: Any?) -> Bool {
        let requiredAccessibility = kSecAttrAccessibleWhenUnlockedThisDeviceOnly as String
        guard (currentAccessibility as? String) != requiredAccessibility else { return true }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let attributes: [String: Any] = [
            // App API requests run while unlocked; device-only items do not migrate through backups.
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        return SecItemUpdate(query as CFDictionary, attributes as CFDictionary) == errSecSuccess
    }
}
