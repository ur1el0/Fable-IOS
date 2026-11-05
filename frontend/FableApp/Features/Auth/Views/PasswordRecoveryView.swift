import SwiftUI
import UIKit

struct PasswordRecoveryView: View {
    @StateObject private var viewModel: PasswordRecoveryViewModel
    @Environment(\.dismiss) private var dismiss

    init(authViewModel: AuthViewModel, initialEmail: String) {
        _viewModel = StateObject(
            wrappedValue: PasswordRecoveryViewModel(
                initialEmail: initialEmail,
                requestReset: { email in
                    try await authViewModel.requestPasswordReset(email: email)
                },
                confirmReset: { token, password in
                    try await authViewModel.confirmPasswordReset(token: token, newPassword: password)
                }
            )
        )
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

                        if let statusMessage = viewModel.statusMessage {
                            Text(statusMessage)
                                .font(.body)
                                .foregroundStyle(FableTheme.brandSecondary)
                        }

                        if let errorMessage = viewModel.errorMessage {
                            Text(errorMessage)
                                .font(.body)
                                .foregroundStyle(.red)
                                .accessibilityLabel("Error: \(errorMessage)")
                        }

                        switch viewModel.stage {
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
            .onChange(of: viewModel.statusMessage) { _, message in
                guard let message else { return }
                UIAccessibility.post(notification: .announcement, argument: message)
            }
            .onChange(of: viewModel.errorMessage) { _, message in
                guard let message else { return }
                UIAccessibility.post(notification: .announcement, argument: message)
            }
        }
    }

    private var requestForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            TextField("Email address", text: $viewModel.email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("Email address")

            Button {
                Task { await viewModel.requestCode() }
            } label: {
                buttonLabel("Send recovery code")
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity, minHeight: 48)
            .accessibilityLabel(viewModel.isLoading ? "Sending recovery code" : "Send recovery code")
            .disabled(viewModel.isLoading || viewModel.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private var confirmationForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            TextField("Recovery code", text: $viewModel.token)
                .textContentType(.oneTimeCode)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("One-time recovery code")

            SecureField("New password", text: $viewModel.password)
                .textContentType(.newPassword)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("New password, at least 12 characters")

            SecureField("Confirm new password", text: $viewModel.confirmation)
                .textContentType(.newPassword)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("Confirm new password")

            Button {
                Task { await viewModel.confirmPassword() }
            } label: {
                buttonLabel("Update password")
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity, minHeight: 48)
            .accessibilityLabel(viewModel.isLoading ? "Updating password" : "Update password")
            .disabled(viewModel.isLoading || !viewModel.canSubmitPassword)

            Button("Send another code") {
                viewModel.requestAnotherCode()
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .disabled(viewModel.isLoading)
        }
    }

    private var title: String {
        switch viewModel.stage {
        case .request: "Reset your password"
        case .confirm: "Choose a new password"
        case .complete: "Password updated"
        }
    }

    private var description: String {
        switch viewModel.stage {
        case .request:
            "Enter your account email. If it belongs to a Fable account, we’ll send a one-time recovery code."
        case .confirm:
            "Paste the code from the email and choose a password with at least 12 characters. The code expires in 15 minutes."
        case .complete:
            "Your password has been changed. Sign in with the new password. Other active sessions have been signed out."
        }
    }

    @ViewBuilder
    private func buttonLabel(_ title: String) -> some View {
        if viewModel.isLoading {
            ProgressView().frame(minHeight: 24)
        } else {
            Text(title).frame(minHeight: 24)
        }
    }
}
