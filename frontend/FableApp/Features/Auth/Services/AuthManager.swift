import SwiftUI
import Combine

@MainActor
public final class AuthManager: ObservableObject {
    public static let shared = AuthManager()

    private let sessionStorageKey = "fable_persisted_session_v1"

    @Published public private(set) var currentSession: UserSession?
    @Published public private(set) var isAuthenticated: Bool = false
    @Published public private(set) var isGuestMode: Bool = false
    @Published public var authErrorMessage: String?
    @Published public var isLoading: Bool = false

    public init() {
        restoreSession()
    }

    // MARK: - Session Restoration
    private func restoreSession() {
        guard let data = UserDefaults.standard.data(forKey: sessionStorageKey) else {
            return
        }
        do {
            let session = try JSONDecoder().decode(UserSession.self, from: data)
            self.currentSession = session
            self.isAuthenticated = true
            self.isGuestMode = session.isGuest
        } catch {
            UserDefaults.standard.removeObject(forKey: sessionStorageKey)
        }
    }

    private func persistSession(_ session: UserSession) {
        do {
            let data = try JSONEncoder().encode(session)
            UserDefaults.standard.set(data, forKey: sessionStorageKey)
            self.currentSession = session
            self.isAuthenticated = true
            self.isGuestMode = session.isGuest
            self.authErrorMessage = nil
        } catch {
            self.authErrorMessage = "Failed to secure local user session."
        }
    }

    // MARK: - Authentication Actions
    public func signIn(email: String, password: String) async -> Bool {
        self.isLoading = true
        self.authErrorMessage = nil

        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedEmail.contains("@") && trimmedEmail.contains(".") else {
            self.authErrorMessage = "Please enter a valid email address."
            self.isLoading = false
            return false
        }

        guard password.count >= 6 else {
            self.authErrorMessage = "Password must be at least 6 characters."
            self.isLoading = false
            return false
        }

        // Brief delay to simulate authentic verification
        try? await Task.sleep(nanoseconds: 300_000_000)

        // Derive author name from email username if not default
        let authorName = trimmedEmail.lowercased().contains("roosc") ? "Roosc Zaño" : trimmedEmail.components(separatedBy: "@").first?.capitalized ?? "Author"
        let handle = "@\(trimmedEmail.components(separatedBy: "@").first?.lowercased() ?? "author")"

        let session = UserSession(
            name: authorName,
            handle: handle,
            email: trimmedEmail,
            bio: "Writer of quiet lore, archivist of dusk folklore, and collector of vintage horology tales.",
            avatarName: "avatar_roosc",
            isGuest: false
        )

        persistSession(session)
        self.isLoading = false
        return true
    }

    public func signUp(name: String, handle: String, email: String, password: String) async -> Bool {
        self.isLoading = true
        self.authErrorMessage = nil

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedHandle = handle.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty else {
            self.authErrorMessage = "Author name cannot be blank."
            self.isLoading = false
            return false
        }

        guard trimmedEmail.contains("@") && trimmedEmail.contains(".") else {
            self.authErrorMessage = "Please provide a valid email."
            self.isLoading = false
            return false
        }

        guard password.count >= 6 else {
            self.authErrorMessage = "Password must be at least 6 characters."
            self.isLoading = false
            return false
        }

        let formattedHandle = trimmedHandle.hasPrefix("@") ? trimmedHandle : "@\(trimmedHandle)"

        try? await Task.sleep(nanoseconds: 400_000_000)

        let session = UserSession(
            name: trimmedName,
            handle: formattedHandle.isEmpty ? "@author" : formattedHandle,
            email: trimmedEmail,
            bio: "Newly minted scribe on Fable.",
            avatarName: nil,
            isGuest: false
        )

        persistSession(session)
        self.isLoading = false
        return true
    }

    public func continueAsGuest() {
        let guest = UserSession.guestUser
        persistSession(guest)
    }

    public func signOut() {
        UserDefaults.standard.removeObject(forKey: sessionStorageKey)
        self.currentSession = nil
        self.isAuthenticated = false
        self.isGuestMode = false
        self.authErrorMessage = nil
    }
}
