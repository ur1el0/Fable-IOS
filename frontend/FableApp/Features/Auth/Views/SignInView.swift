import SwiftUI
import UIKit

public struct SignInView: View {
    @ObservedObject var authVM: AuthViewModel
    var onNavigateToRegister: (() -> Void)?
    @Environment(\.dismiss) var dismiss

    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isPasswordVisible: Bool = false

    private enum Field: Hashable {
        case email
        case password
    }
    @FocusState private var focusedField: Field?

    @MainActor
    public init(authVM: AuthViewModel? = nil, onNavigateToRegister: (() -> Void)? = nil) {
        self.authVM = authVM ?? .shared
        self.onNavigateToRegister = onNavigateToRegister
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                FableTheme.background
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        headerSection
                        errorBanner
                        formCard
                        navigationFooter
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: displayedError) { _, error in
                guard let error else { return }
                UIAccessibility.post(notification: .announcement, argument: error)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(FableTheme.textPrimary)
                            .padding(8)
                            .background(Color.white)
                            .clipShape(Circle())
                            .shadow(color: Color.black.opacity(0.05), radius: 3, y: 1)
                    }
                    .accessibilityLabel("Close")
                }
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 8) {
                Image(systemName: "square.stack.3d.up.fill")
                    .font(.system(size: 13))
                    .foregroundColor(.white)
                    .padding(7)
                    .background(FableTheme.brandPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Text("Fable")
                    .font(.headline.weight(.black))
                    .foregroundColor(FableTheme.textPrimary)
            }
            .padding(.top, 16)

            VStack(alignment: .leading, spacing: 6) {
                Text("Welcome Back")
                    .font(.system(.largeTitle, design: .serif).weight(.bold))
                    .foregroundColor(FableTheme.textPrimary)

                Text("Sign in to synchronize your reading progress, bookmarks, and drafts.")
                    .font(.subheadline)
                    .foregroundColor(FableTheme.textSecondary)
                    .lineSpacing(3)
            }
        }
    }

    @ViewBuilder
    private var errorBanner: some View {
        if let error = authVM.errorMessage {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(.red)
                Text(error)
                    .font(.callout.weight(.medium))
                    .foregroundColor(.red)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Error: \(error)")
            .accessibilityAddTraits(.isStaticText)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.red.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.red.opacity(0.2), lineWidth: 0.8)
            )
        }
    }

    @ViewBuilder
    private var formCard: some View {
        VStack(spacing: 18) {
            emailField
            passwordField
            submitButton
        }
        .padding(20)
        .background(FableTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(FableTheme.divider.opacity(0.8), lineWidth: 0.8)
        )
        .shadow(color: Color.black.opacity(0.02), radius: 3, x: 0, y: 1)
        .shadow(color: Color.black.opacity(0.05), radius: 12, x: 0, y: 5)
    }

    @ViewBuilder
    private var emailField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("EMAIL")
                .font(.caption.weight(.bold))
                .tracking(1.0)
                .foregroundColor(focusedField == .email ? FableTheme.brandPrimary : FableTheme.textMuted)

            HStack(spacing: 12) {
                Image(systemName: "envelope.fill")
                    .font(.system(size: 14))
                    .foregroundColor(focusedField == .email ? FableTheme.brandPrimary : FableTheme.textMuted)
                    .frame(width: 20)

                TextField("Enter your email", text: $email)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .focused($focusedField, equals: .email)
                    .font(.body)
                    .submitLabel(.next)
                    .onSubmit {
                        focusedField = .password
                    }
            }
            .padding(14)
            .background(FableTheme.surface.opacity(0.45))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(focusedField == .email ? FableTheme.brandPrimary : FableTheme.divider.opacity(0.8), lineWidth: focusedField == .email ? 1.5 : 1)
            )
        }
    }

    @ViewBuilder
    private var passwordField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("PASSWORD")
                .font(.caption.weight(.bold))
                .tracking(1.0)
                .foregroundColor(focusedField == .password ? FableTheme.brandPrimary : FableTheme.textMuted)

            HStack(spacing: 12) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 14))
                    .foregroundColor(focusedField == .password ? FableTheme.brandPrimary : FableTheme.textMuted)
                    .frame(width: 20)

                if isPasswordVisible {
                    TextField("Enter your password", text: $password)
                        .textContentType(.password)
                        .focused($focusedField, equals: .password)
                        .font(.body)
                        .submitLabel(.go)
                        .onSubmit {
                            if !isSubmitDisabled {
                                submitSignIn()
                            }
                        }
                } else {
                    SecureField("Enter your password", text: $password)
                        .textContentType(.password)
                        .focused($focusedField, equals: .password)
                        .font(.body)
                        .submitLabel(.go)
                        .onSubmit {
                            if !isSubmitDisabled {
                                submitSignIn()
                            }
                        }
                }

                Button {
                    FableHaptics.light()
                    isPasswordVisible.toggle()
                } label: {
                    Image(systemName: isPasswordVisible ? "eye.slash.fill" : "eye.fill")
                        .font(.system(size: 14))
                        .foregroundColor(FableTheme.textMuted)
                        .frame(width: 40, height: 40)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(isPasswordVisible ? "Hide password" : "Show password")
            }
            .padding(.leading, 14)
            .padding(.trailing, 4)
            .padding(.vertical, 4)
            .background(FableTheme.surface.opacity(0.45))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(focusedField == .password ? FableTheme.brandPrimary : FableTheme.divider.opacity(0.8), lineWidth: focusedField == .password ? 1.5 : 1)
            )
        }
    }

    @ViewBuilder
    private var submitButton: some View {
        Button(action: submitSignIn) {
            HStack(spacing: 8) {
                if authVM.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text("Sign In")
                        .font(.headline.weight(.bold))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .bold))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                LinearGradient(
                    colors: isSubmitDisabled ? [FableTheme.brandPrimary.opacity(0.4), FableTheme.brandPrimary.opacity(0.4)] : [FableTheme.brandPrimary, FableTheme.brandAccent],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: isSubmitDisabled ? Color.clear : FableTheme.brandPrimary.opacity(0.25), radius: 8, y: 3)
        }
        .disabled(isSubmitDisabled || authVM.isLoading)
    }

    @ViewBuilder
    private var navigationFooter: some View {
        if let onNavigateToRegister {
            Button {
                FableHaptics.light()
                onNavigateToRegister()
            } label: {
                HStack(spacing: 4) {
                    Text("Don't have an account?")
                        .foregroundColor(FableTheme.textSecondary)
                    Text("Create Account")
                        .fontWeight(.bold)
                        .foregroundColor(FableTheme.brandPrimary)
                }
                .font(.footnote)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
        }
    }

    private var isSubmitDisabled: Bool {
        email.trimmingCharacters(in: .whitespaces).isEmpty || password.isEmpty
    }

    private var displayedError: String? {
        authVM.errorMessage
    }

    private func submitSignIn() {
        FableHaptics.medium()
        focusedField = nil
        Task {
            let success = await authVM.login(email: email, password: password)
            if success {
                dismiss()
            }
        }
    }
}

#Preview {
    SignInView()
}
