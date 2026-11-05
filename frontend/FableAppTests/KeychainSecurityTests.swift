import XCTest
import Security
@testable import FableApp

final class KeychainSecurityTests: XCTestCase {
    func testNewTokenAndSessionItemsUseDeviceOnlyAccessibility() {
        let service = "mseuf.edu.ph.fable.auth"
        let tokenAccount = "accessToken"
        let sessionAccount = "userSession"
        let store = KeychainStore.shared

        store.deleteAccessToken()
        store.deleteData(key: sessionAccount)
        defer {
            store.deleteAccessToken()
            store.deleteData(key: sessionAccount)
        }

        XCTAssertTrue(store.saveAccessToken("test-token-for-keychain-storage"))
        XCTAssertTrue(store.saveData(key: sessionAccount, data: Data("test-session".utf8)))
        XCTAssertEqual(
            keychainAccessibility(service: service, account: tokenAccount),
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly as String
        )
        XCTAssertEqual(
            keychainAccessibility(service: service, account: sessionAccount),
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly as String
        )
    }

    func testExistingTokenAndSessionItemsMigrateToDeviceOnlyAccessibility() {
        let service = "mseuf.edu.ph.fable.auth"
        let tokenAccount = "accessToken"
        let sessionAccount = "userSession"
        let store = KeychainStore.shared
        let legacyToken = "test-token-for-keychain-migration"
        let legacySession = Data("test-session-for-keychain-migration".utf8)

        store.deleteAccessToken()
        store.deleteData(key: sessionAccount)
        defer {
            store.deleteAccessToken()
            store.deleteData(key: sessionAccount)
        }

        let tokenQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: tokenAccount,
            kSecValueData as String: Data(legacyToken.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        XCTAssertEqual(SecItemAdd(tokenQuery as CFDictionary, nil), errSecSuccess)

        let sessionQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: sessionAccount,
            kSecValueData as String: legacySession,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        XCTAssertEqual(SecItemAdd(sessionQuery as CFDictionary, nil), errSecSuccess)

        XCTAssertEqual(store.readAccessToken(), legacyToken)
        XCTAssertEqual(store.readData(key: sessionAccount), legacySession)
        XCTAssertEqual(
            keychainAccessibility(service: service, account: tokenAccount),
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly as String
        )
        XCTAssertEqual(
            keychainAccessibility(service: service, account: sessionAccount),
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly as String
        )
    }

    private func keychainAccessibility(service: String, account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let attributes = result as? [String: Any] else {
            return nil
        }
        return attributes[kSecAttrAccessible as String] as? String
    }
}
