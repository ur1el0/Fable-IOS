import Foundation
import SwiftUI
import Combine

/// Discrete lifecycle states for user authentication.
public enum AuthState: Equatable {
    case checkingSession
    case signedOut
    case signedIn(UserSession)

    public static func == (lhs: AuthState, rhs: AuthState) -> Bool {
        switch (lhs, rhs) {
        case (.checkingSession, .checkingSession):
            return true
        case (.signedOut, .signedOut):
            return true
        case (.signedIn(let lUser), .signedIn(let rUser)):
            return lUser.email == rUser.email && lUser.isGuest == rUser.isGuest
        default:
            return false
        }
    }
}

/// Reactive ViewModel governing user authentication, registration,
/// and hardware-backed session persistence via native iOS Keychain.
@MainActor
public final class AuthViewModel: ObservableObject {
    public static let shared = AuthViewModel()

    @Published public var authState: AuthState = .checkingSession
    @Published public var currentUser: UserSession? = nil
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String? = nil

    private let keychain: KeychainStore
    private let apiService: StoryAPIServiceProtocol
    private let sessionKeychainKey = "userSession"

    public init(keychain: KeychainStore = .shared, apiService: StoryAPIServiceProtocol = StoryAPIService()) {
        self.keychain = keychain
        self.apiService = apiService
    }

    /// Verifies existing credentials stored securely in the iOS Keychain.
    public func checkExistingSession() async {
        // Brief simulated check for smooth launch transition
        try? await Task.sleep(nanoseconds: 150_000_000)

        guard let sessionData = keychain.readData(key: sessionKeychainKey) else {
            // Check legacy fallback from UserDefaults if transitioning
            if let legacyData = UserDefaults.standard.data(forKey: "fable_persisted_session_v1"),
               let legacySession = try? JSONDecoder().decode(UserSession.self, from: legacyData) {
                guard legacySession.isGuest || hasServerAccessToken else {
                    UserDefaults.standard.removeObject(forKey: "fable_persisted_session_v1")
                    keychain.deleteData(key: sessionKeychainKey)
                    keychain.deleteAccessToken()
                    self.currentUser = nil
                    self.authState = .signedOut
                    return
                }
                // Migrate immediately to hardware Keychain
                if let encoded = try? JSONEncoder().encode(legacySession) {
                    keychain.saveData(key: sessionKeychainKey, data: encoded)
                }
                UserDefaults.standard.removeObject(forKey: "fable_persisted_session_v1")
                self.currentUser = legacySession
                self.authState = .signedIn(legacySession)
                syncToAuthManager(session: legacySession)
                return
            }

            self.currentUser = nil
            self.authState = .signedOut
            return
        }

        do {
            let session = try JSONDecoder().decode(UserSession.self, from: sessionData)
            guard session.isGuest || hasServerAccessToken else {
                keychain.deleteData(key: sessionKeychainKey)
                keychain.deleteAccessToken()
                self.currentUser = nil
                self.authState = .signedOut
                return
            }
            if session.isGuest {
                keychain.deleteAccessToken()
            }
            self.currentUser = session
            self.authState = .signedIn(session)
            syncToAuthManager(session: session)
        } catch {
            keychain.deleteData(key: sessionKeychainKey)
            keychain.deleteAccessToken()
            self.currentUser = nil
            self.authState = .signedOut
        }
    }

    /// Authenticates user credentials and stores session securely in Keychain.
    public func login(email: String, password: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedEmail.contains("@"), trimmedEmail.contains(".") else {
            errorMessage = "Please enter a valid email address."
            return false
        }
        guard password.count >= 6 else {
            errorMessage = "Password must be at least 6 characters."
            return false
        }

        do {
            let response = try await apiService.login(email: trimmedEmail, password: password)
            let session = makeSession(from: response.user)
            return persistSession(session, accessToken: response.accessToken)
        } catch let error as APIRequestError {
            errorMessage = error.message
            return false
        } catch {
            errorMessage = "Sign in failed. Check your connection."
            return false
        }
    }

    public func register(name: String, handle: String, email: String, password: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = "Full name cannot be blank."
            return false
        }
        guard trimmedEmail.contains("@"), trimmedEmail.contains(".") else {
            errorMessage = "Please enter a valid email address."
            return false
        }
        guard password.count >= 6 else {
            errorMessage = "Password must be at least 6 characters."
            return false
        }

        do {
            let response = try await apiService.register(email: trimmedEmail, password: password, name: trimmedName, handle: handle)
            let session = makeSession(from: response.user)
            return persistSession(session, accessToken: response.accessToken)
        } catch let error as APIRequestError {
            errorMessage = error.message
            return false
        } catch {
            errorMessage = "Account creation failed. Check your connection."
            return false
        }
    }

    public func continueAsGuest() {
        let guest = UserSession.guest()
        _ = persistSession(guest, accessToken: nil)
    }

    /// Clears Keychain credentials and returns state to signedOut.
    public func logout() {
        keychain.deleteData(key: sessionKeychainKey)
        keychain.deleteAccessToken()
        AuthManager.shared.signOut()
        self.currentUser = nil
        self.authState = .signedOut
        self.errorMessage = nil
    }

    // MARK: - Private Helpers

    func adoptSession(_ session: UserSession) {
        currentUser = session
        authState = .signedIn(session)
    }

    func adoptSignedOutState() {
        currentUser = nil
        authState = .signedOut
        errorMessage = nil
    }

    private var hasServerAccessToken: Bool {
        guard let token = keychain.readAccessToken() else { return false }
        return !token.hasPrefix("fable_token_") && !token.hasPrefix("token_")
    }

    private func makeSession(from user: AuthUserDTO) -> UserSession {
        UserSession(
            id: user.id,
            name: user.name,
            handle: user.handle,
            email: user.email,
            bio: user.bio,
            avatarName: user.avatarImageUrl ?? user.avatarImageName,
            joinedDate: user.createdAtUtc
        )
    }

    private func syncToAuthManager(session: UserSession) {
        AuthManager.shared.acceptSession(session)
    }

    @discardableResult
    private func persistSession(_ session: UserSession, accessToken: String?) -> Bool {
        do {
            let data = try JSONEncoder().encode(session)
            guard keychain.saveData(key: sessionKeychainKey, data: data) else {
                errorMessage = "Failed to store the local session securely."
                return false
            }
            if let accessToken {
                guard keychain.saveAccessToken(accessToken) else {
                    keychain.deleteData(key: sessionKeychainKey)
                    errorMessage = "Failed to store the access token securely."
                    return false
                }
            } else {
                keychain.deleteAccessToken()
            }
            currentUser = session
            authState = .signedIn(session)
            errorMessage = nil
            AuthManager.shared.acceptSession(session)
            return true
        } catch {
            errorMessage = "Failed to store the local session securely."
            return false
        }
    }

}
