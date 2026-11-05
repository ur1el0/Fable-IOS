import SwiftUI
import UIKit

struct PasswordRecoveryView: View {
    @ObservedObject private var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var email: String
    @State private var token = ""
    @State private var password = ""
    @State private var confirmation = ""
    @State private var stage: Stage = .request
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var statusMessage: String?

    private enum Stage {
        case request
        case confirm
        case complete
    }

    init(authViewModel: AuthViewModel, initialEmail: String) {
        self.authViewModel = authViewModel
        _email = State(initialValue: initialEmail)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                FableTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text(title)
                            .font(.largeTitle.weight(.bold))
                            .foregroundStyle(FableTheme.textPrimary)

                        Text(description)
                            .font(.body)
                            .foregroundStyle(FableTheme.textSecondary)

                        if let statusMessage {
                            Text(statusMessage)
                                .font(.body)
                                .foregroundStyle(FableTheme.brandSecondary)
                        }

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.body)
                                .foregroundStyle(.red)
                                .accessibilityLabel("Error: \(errorMessage)")
                        }

                        switch stage {
                        case .request:
                            requestForm
                        case .confirm:
                            confirmationForm
                        case .complete:
                            Button("Return to sign in") {
                                dismiss()
                            }
                            .buttonStyle(.borderedProminent)
                            .frame(maxWidth: .infinity, minHeight: 48)
                        }
                    }
                    .padding(24)
                    .frame(maxWidth: 560, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .navigationTitle("Password recovery")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .frame(minWidth: 44, minHeight: 44)
                }
            }
            .onChange(of: statusMessage) { _, message in
                guard let message else { return }
                UIAccessibility.post(notification: .announcement, argument: message)
            }
            .onChange(of: errorMessage) { _, message in
                guard let message else { return }
                UIAccessibility.post(notification: .announcement, argument: message)
            }
        }
    }

    private var requestForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            TextField("Email address", text: $email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("Email address")

            Button {
                Task { await sendRecoveryCode() }
            } label: {
                buttonLabel("Send recovery code")
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity, minHeight: 48)
            .accessibilityLabel(isLoading ? "Sending recovery code" : "Send recovery code")
            .disabled(isLoading || email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private var confirmationForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            TextField("Recovery code", text: $token)
                .textContentType(.oneTimeCode)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("One-time recovery code")

            SecureField("New password", text: $password)
                .textContentType(.newPassword)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("New password, at least 12 characters")

            SecureField("Confirm new password", text: $confirmation)
                .textContentType(.newPassword)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("Confirm new password")

            Button {
                Task { await confirmRecovery() }
            } label: {
                buttonLabel("Update password")
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity, minHeight: 48)
            .accessibilityLabel(isLoading ? "Updating password" : "Update password")
            .disabled(isLoading || !canSubmitPassword)

            Button("Send another code") {
                stage = .request
                statusMessage = nil
                errorMessage = nil
                token = ""
            }
            .frame(maxWidth: .infinity, minHeight: 44)
        }
    }

    private var title: String {
        switch stage {
        case .request: "Reset your password"
        case .confirm: "Choose a new password"
        case .complete: "Password updated"
        }
    }

    private var description: String {
        switch stage {
        case .request:
            "Enter your account email. If it belongs to a Fable account, we’ll send a one-time recovery code."
        case .confirm:
            "Paste the code from the email and choose a password with at least 12 characters. The code expires in 15 minutes."
        case .complete:
            "Your password has been changed. Sign in with the new password. Other active sessions have been signed out."
        }
    }

    private var canSubmitPassword: Bool {
        token.count >= 43 && password.count >= 12 && password == confirmation
    }

    @ViewBuilder
    private func buttonLabel(_ title: String) -> some View {
        if isLoading {
            ProgressView().frame(minHeight: 24)
        } else {
            Text(title).frame(minHeight: 24)
        }
    }

    @MainActor
    private func sendRecoveryCode() async {
        isLoading = true
        errorMessage = nil
        statusMessage = nil
        defer { isLoading = false }

        do {
            try await authViewModel.requestPasswordReset(email: email)
            stage = .confirm
            statusMessage = "If an account uses this address, recovery instructions will arrive shortly."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func confirmRecovery() async {
        guard password == confirmation else {
            errorMessage = "The passwords do not match."
            return
        }
        guard password.count >= 12 else {
            errorMessage = "Password must be at least 12 characters."
            return
        }

        isLoading = true
        errorMessage = nil
        statusMessage = nil
        defer { isLoading = false }

        do {
            try await authViewModel.confirmPasswordReset(token: token, newPassword: password)
            token = ""
            password = ""
            confirmation = ""
            stage = .complete
            statusMessage = "Password updated."
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
