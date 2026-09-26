import SwiftUI
import Combine

@MainActor
public final class AuthManager: ObservableObject {
    public static let shared = AuthManager()

    private let sessionStorageKey = "fable_persisted_session_v1"
    private let pendingProfileKeyPrefix = "fable_pending_profile_"
    private let apiService: StoryAPIServiceProtocol

    @Published public private(set) var currentSession: UserSession?
    @Published public private(set) var isAuthenticated: Bool = false
    @Published public private(set) var isGuestMode: Bool = false
    @Published public var authErrorMessage: String?
    @Published public var isLoading: Bool = false

    public init(apiService: StoryAPIServiceProtocol = StoryAPIService()) {
        self.apiService = apiService
        restoreSession()
    }

    // MARK: - Session Restoration
    private func restoreSession() {
        if let sessionData = KeychainStore.shared.readData(key: "userSession"),
           let session = try? JSONDecoder().decode(UserSession.self, from: sessionData) {
            restore(session)
            return
        }

        guard let data = UserDefaults.standard.data(forKey: sessionStorageKey) else {
            return
        }
        do {
            let session = try JSONDecoder().decode(UserSession.self, from: data)
            guard session.isGuest || hasServerAccessToken else {
                KeychainStore.shared.deleteData(key: "userSession")
                KeychainStore.shared.deleteAccessToken()
                UserDefaults.standard.removeObject(forKey: sessionStorageKey)
                return
            }
            if let encoded = try? JSONEncoder().encode(session) {
                KeychainStore.shared.saveData(key: "userSession", data: encoded)
            }
            UserDefaults.standard.removeObject(forKey: sessionStorageKey)
            restore(session)
        } catch {
            UserDefaults.standard.removeObject(forKey: sessionStorageKey)
        }
    }

    private var hasServerAccessToken: Bool {
        guard let token = KeychainStore.shared.readAccessToken() else { return false }
        return !token.hasPrefix("fable_token_") && !token.hasPrefix("token_")
    }

    private func restore(_ session: UserSession) {
        guard session.isGuest || hasServerAccessToken else {
            KeychainStore.shared.deleteData(key: "userSession")
            KeychainStore.shared.deleteAccessToken()
            return
        }
        if session.isGuest {
            KeychainStore.shared.deleteAccessToken()
        }
        currentSession = session
        isAuthenticated = true
        isGuestMode = session.isGuest
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

    @discardableResult
    private func persistSession(_ session: UserSession, accessToken: String?) -> Bool {
        do {
            let data = try JSONEncoder().encode(session)
            guard KeychainStore.shared.saveData(key: "userSession", data: data) else {
                authErrorMessage = "Failed to secure local user session."
                return false
            }
            if let accessToken {
                guard KeychainStore.shared.saveAccessToken(accessToken) else {
                    KeychainStore.shared.deleteData(key: "userSession")
                    authErrorMessage = "Failed to secure the access token."
                    return false
                }
            } else if session.isGuest {
                KeychainStore.shared.deleteAccessToken()
            }
            acceptSession(session)
            return true
        } catch {
            authErrorMessage = "Failed to secure local user session."
            return false
        }
    }

    func acceptSession(_ session: UserSession) {
        currentSession = session
        isAuthenticated = true
        isGuestMode = session.isGuest
        authErrorMessage = nil
        AuthViewModel.shared.adoptSession(session)
    }

    public func signIn(email: String, password: String) async -> Bool {
        isLoading = true
        authErrorMessage = nil
        defer { isLoading = false }

        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedEmail.contains("@"), trimmedEmail.contains(".") else {
            authErrorMessage = "Please enter a valid email address."
            return false
        }
        guard password.count >= 6 else {
            authErrorMessage = "Password must be at least 6 characters."
            return false
        }

        do {
            let response = try await apiService.login(email: trimmedEmail, password: password)
            return persistSession(makeSession(from: response.user), accessToken: response.accessToken)
        } catch let error as APIRequestError {
            authErrorMessage = error.message
            return false
        } catch {
            authErrorMessage = "Sign in failed. Check your connection."
            return false
        }
    }

    public func signUp(name: String, handle: String, email: String, password: String) async -> Bool {
        isLoading = true
        authErrorMessage = nil
        defer { isLoading = false }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            authErrorMessage = "Author name cannot be blank."
            return false
        }
        guard trimmedEmail.contains("@"), trimmedEmail.contains(".") else {
            authErrorMessage = "Please provide a valid email."
            return false
        }
        guard password.count >= 6 else {
            authErrorMessage = "Password must be at least 6 characters."
            return false
        }

        do {
            let response = try await apiService.register(email: trimmedEmail, password: password, name: trimmedName, handle: handle)
            let session = makeSession(from: response.user)
            return persistSession(session, accessToken: response.accessToken)
        } catch let error as APIRequestError {
            authErrorMessage = error.message
            return false
        } catch {
            authErrorMessage = "Account creation failed. Check your connection."
            return false
        }
    }

    public func updateProfile(name: String, handle: String, bio: String, avatarName: String? = nil) async -> Bool {
        guard var session = currentSession else { return false }
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else {
            authErrorMessage = "Display name cannot be blank."
            return false
        }
        let cleanHandle = handle.trimmingCharacters(in: .whitespacesAndNewlines)
        session.name = cleanName
        session.handle = cleanHandle.isEmpty || cleanHandle.hasPrefix("@") ? cleanHandle : "@\(cleanHandle)"
        session.bio = bio.trimmingCharacters(in: .whitespacesAndNewlines)
        if let avatarName { session.avatarName = avatarName }
        guard persistSession(session, accessToken: nil) else { return false }
        guard !session.isGuest else { return true }

        let request = ProfileUpdateRequest(name: session.name, handle: session.handle, bio: session.bio)
        let pendingKey = pendingProfileKeyPrefix + session.id.uuidString
        if let data = try? JSONEncoder().encode(request) {
            UserDefaults.standard.set(data, forKey: pendingKey)
        }
        guard let token = KeychainStore.shared.readAccessToken() else {
            authErrorMessage = "Profile saved locally. It will sync after the next sign in."
            return false
        }

        do {
            let user = try await apiService.updateProfile(request, token: token)
            let updatedSession = makeSession(from: user)
            guard persistSession(updatedSession, accessToken: token) else { return false }
            UserDefaults.standard.removeObject(forKey: pendingKey)
            return true
        } catch {
            authErrorMessage = "Profile saved locally and queued to sync when online."
            return false
        }
    }

    public func syncPendingProfile() async {
        guard let session = currentSession, !session.isGuest,
              let token = KeychainStore.shared.readAccessToken() else { return }
        let pendingKey = pendingProfileKeyPrefix + session.id.uuidString
        guard let data = UserDefaults.standard.data(forKey: pendingKey),
              let request = try? JSONDecoder().decode(ProfileUpdateRequest.self, from: data) else { return }

        do {
            let user = try await apiService.updateProfile(request, token: token)
            _ = persistSession(makeSession(from: user), accessToken: token)
            UserDefaults.standard.removeObject(forKey: pendingKey)
        } catch {
            authErrorMessage = "Profile update remains queued while the backend is unavailable."
        }
    }

    public func signOut() {
        if let session = currentSession, !session.isGuest,
           let token = KeychainStore.shared.readAccessToken() {
            Task { try? await apiService.logout(token: token) }
        }
        if let session = currentSession {
            UserDefaults.standard.removeObject(forKey: pendingProfileKeyPrefix + session.id.uuidString)
        }
        KeychainStore.shared.deleteData(key: "userSession")
        KeychainStore.shared.deleteAccessToken()
        UserDefaults.standard.removeObject(forKey: sessionStorageKey)
        self.currentSession = nil
        self.isAuthenticated = false
        self.isGuestMode = false
        self.authErrorMessage = nil
        AuthViewModel.shared.adoptSignedOutState()
    }
}
