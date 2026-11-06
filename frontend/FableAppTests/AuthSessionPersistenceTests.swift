import XCTest
@testable import FableApp

final class AuthSessionPersistenceTests: XCTestCase {
    @MainActor
    func testAuthenticatedSessionRequiresAccessToken() {
        let defaultsKey = "fable_persisted_session_v1"
        UserDefaults.standard.removeObject(forKey: defaultsKey)
        defer { UserDefaults.standard.removeObject(forKey: defaultsKey) }
        let keychain = InMemoryKeychainStore()
        let auth = AuthManager(keychainStore: keychain)

        let persisted = auth.persistSession(makeUserSession(), accessToken: nil)

        XCTAssertFalse(persisted)
        XCTAssertFalse(auth.isAuthenticated)
        XCTAssertNil(auth.currentSession)
        XCTAssertNil(keychain.readData(key: "userSession"))
        XCTAssertNil(keychain.readAccessToken())
        XCTAssertNil(UserDefaults.standard.data(forKey: defaultsKey))
    }

    @MainActor
    func testAuthenticatedSessionFailsClosedWhenAccessTokenCannotBeStored() {
        UserDefaults.standard.removeObject(forKey: "fable_persisted_session_v1")
        let keychain = InMemoryKeychainStore()
        keychain.failAccessTokenSave = true
        let auth = AuthManager(keychainStore: keychain)

        let persisted = auth.persistSession(makeUserSession(), accessToken: "server-token")

        XCTAssertFalse(persisted)
        XCTAssertFalse(auth.isAuthenticated)
        XCTAssertNil(auth.currentSession)
        XCTAssertNil(keychain.readData(key: "userSession"))
        XCTAssertNil(keychain.readAccessToken())
        XCTAssertEqual(auth.authErrorMessage, "Failed to secure the local user session.")
    }

    @MainActor
    func testAuthenticatedSessionFailsClosedWhenSessionCannotBeStored() {
        UserDefaults.standard.removeObject(forKey: "fable_persisted_session_v1")
        let keychain = InMemoryKeychainStore()
        keychain.failSessionSave = true
        let auth = AuthManager(keychainStore: keychain)

        let persisted = auth.persistSession(makeUserSession(), accessToken: "server-token")

        XCTAssertFalse(persisted)
        XCTAssertFalse(auth.isAuthenticated)
        XCTAssertNil(auth.currentSession)
        XCTAssertNil(keychain.readData(key: "userSession"))
        XCTAssertNil(keychain.readAccessToken())
    }

    @MainActor
    func testAuthViewModelRejectsAuthenticatedSessionWithoutToken() {
        UserDefaults.standard.removeObject(forKey: "fable_persisted_session_v1")
        let keychain = InMemoryKeychainStore()
        let auth = AuthViewModel(keychainStore: keychain)

        let persisted = auth.persistSession(makeUserSession(), accessToken: nil)

        XCTAssertFalse(persisted)
        XCTAssertNil(auth.currentUser)
        XCTAssertEqual(auth.authState, .signedOut)
        XCTAssertNil(keychain.readData(key: "userSession"))
        XCTAssertNil(keychain.readAccessToken())
    }

    private func makeUserSession() -> UserSession {
        UserSession(name: "Test Reader", handle: "@reader", email: "reader@example.test")
    }
}

private final class InMemoryKeychainStore: KeychainStoring {
    private var data: [String: Data] = [:]
    private var accessToken: String?
    var failSessionSave = false
    var failAccessTokenSave = false

    func saveAccessToken(_ token: String) -> Bool {
        guard !failAccessTokenSave else { return false }
        accessToken = token
        return true
    }

    func readAccessToken() -> String? {
        accessToken
    }

    func deleteAccessToken() -> Bool {
        accessToken = nil
        return true
    }

    func saveData(key: String, data value: Data) -> Bool {
        guard !failSessionSave else { return false }
        data[key] = value
        return true
    }

    func readData(key: String) -> Data? {
        data[key]
    }

    func deleteData(key: String) -> Bool {
        data.removeValue(forKey: key)
        return true
    }
}
