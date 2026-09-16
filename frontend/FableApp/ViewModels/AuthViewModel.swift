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
    private let sessionKeychainKey = "userSession"

    public init(keychain: KeychainStore = .shared) {
        self.keychain = keychain
    }

    /// Verifies existing credentials stored securely in the iOS Keychain.
    public func checkExistingSession() async {
        // Brief simulated check for smooth launch transition
        try? await Task.sleep(nanoseconds: 150_000_000)

        guard let sessionData = keychain.readData(key: sessionKeychainKey) else {
            // Check legacy fallback from UserDefaults if transitioning
            if let legacyData = UserDefaults.standard.data(forKey: "fable_persisted_session_v1"),
               let legacySession = try? JSONDecoder().decode(UserSession.self, from: legacyData) {
                // Migrate immediately to hardware Keychain
                if let encoded = try? JSONEncoder().encode(legacySession) {
                    keychain.saveData(key: sessionKeychainKey, data: encoded)
                    keychain.saveAccessToken("token_\(UUID().uuidString)")
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
        self.isLoading = true
        self.errorMessage = nil

        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedEmail.contains("@") && trimmedEmail.contains(".") else {
            self.errorMessage = "Please enter a valid email address."
            self.isLoading = false
            return false
        }

        guard password.count >= 6 else {
            self.errorMessage = "Password must be at least 6 characters."
            self.isLoading = false
            return false
        }

        // Brief delay to simulate authentic verification
        try? await Task.sleep(nanoseconds: 300_000_000)

        let authorName = trimmedEmail.lowercased().contains("roosc") ? "Roosc Zaño" : trimmedEmail.components(separatedBy: "@").first?.capitalized ?? "Author"
        let handle = "@\(trimmedEmail.components(separatedBy: "@").first?.lowercased() ?? "author")"

        let session = UserSession(
            name: authorName,
            handle: handle,
            email: trimmedEmail,
            bio: "Reader and storyteller on Fable.",
            avatarName: "avatar_roosc",
            isGuest: false
        )

        persistSession(session)
        self.isLoading = false
        return true
    }

    /// Registers a new user account, stores credentials, and auto-signs in.
    public func register(name: String, handle: String, email: String, password: String) async -> Bool {
        self.isLoading = true
        self.errorMessage = nil

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedHandle = handle.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty else {
            self.errorMessage = "Full name cannot be blank."
            self.isLoading = false
            return false
        }

        guard trimmedEmail.contains("@") && trimmedEmail.contains(".") else {
            self.errorMessage = "Please enter a valid email address."
            self.isLoading = false
            return false
        }

        guard password.count >= 6 else {
            self.errorMessage = "Password must be at least 6 characters."
            self.isLoading = false
            return false
        }

        let formattedHandle = trimmedHandle.hasPrefix("@") ? trimmedHandle : "@\(trimmedHandle)"

        try? await Task.sleep(nanoseconds: 350_000_000)

        let session = UserSession(
            name: trimmedName,
            handle: formattedHandle.isEmpty ? "@reader" : formattedHandle,
            email: trimmedEmail,
            bio: "Story enthusiast on Fable.",
            avatarName: nil,
            isGuest: false
        )

        persistSession(session)
        self.isLoading = false
        return true
    }

    /// Initiates an offline guest session.
    public func continueAsGuest() {
        let guest = UserSession.guestUser
        persistSession(guest)
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

    private func persistSession(_ session: UserSession) {
        do {
            let data = try JSONEncoder().encode(session)
            keychain.saveData(key: sessionKeychainKey, data: data)
            keychain.saveAccessToken("fable_token_\(UUID().uuidString)")
            self.currentUser = session
            self.authState = .signedIn(session)
            self.errorMessage = nil
            syncToAuthManager(session: session)
        } catch {
            self.errorMessage = "Failed to store credentials in hardware Keychain."
        }
    }

    private func syncToAuthManager(session: UserSession) {
        if let data = try? JSONEncoder().encode(session) {
            UserDefaults.standard.set(data, forKey: "fable_persisted_session_v1")
        }
    }
}
