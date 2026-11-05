import Foundation
import Combine

@MainActor
final class PasswordRecoveryViewModel: ObservableObject {
    enum Stage: Equatable {
        case request
        case confirm
        case complete
    }

    @Published var email: String
    @Published var token = ""
    @Published var password = ""
    @Published var confirmation = ""
    @Published private(set) var stage: Stage = .request
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var statusMessage: String?

    private let requestReset: @MainActor (String) async throws -> Void
    private let confirmReset: @MainActor (String, String) async throws -> Void

    init(
        initialEmail: String,
        requestReset: @escaping @MainActor (String) async throws -> Void,
        confirmReset: @escaping @MainActor (String, String) async throws -> Void
    ) {
        self.email = initialEmail
        self.requestReset = requestReset
        self.confirmReset = confirmReset
    }

    var canSubmitPassword: Bool {
        token.count >= 43 && password.count >= 12 && password == confirmation
    }

    func requestCode() async {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedEmail.isEmpty else {
            errorMessage = "Enter an email address."
            return
        }

        isLoading = true
        errorMessage = nil
        statusMessage = nil
        defer { isLoading = false }

        do {
            try await requestReset(normalizedEmail)
            stage = .confirm
            statusMessage = "If an account uses this address, recovery instructions will arrive shortly."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func confirmPassword() async {
        guard password.count >= 12 else {
            errorMessage = "Password must be at least 12 characters."
            return
        }
        guard password == confirmation else {
            errorMessage = "The passwords do not match."
            return
        }
        guard token.count >= 43 else {
            errorMessage = "Enter the recovery code from the email."
            return
        }

        isLoading = true
        errorMessage = nil
        statusMessage = nil
        defer { isLoading = false }

        do {
            try await confirmReset(
                token.trimmingCharacters(in: .whitespacesAndNewlines),
                password
            )
            token = ""
            password = ""
            confirmation = ""
            stage = .complete
            statusMessage = "Password updated."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func requestAnotherCode() {
        guard !isLoading else { return }
        stage = .request
        token = ""
        password = ""
        confirmation = ""
        errorMessage = nil
        statusMessage = nil
    }
}
