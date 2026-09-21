import SwiftUI

public struct SignUpView: View {
    @ObservedObject var authVM: AuthViewModel
    var onNavigateToLogin: (() -> Void)?
    @Environment(\.dismiss) var dismiss

    @State private var name: String = ""
    @State private var handle: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var isPasswordVisible: Bool = false
    @State private var validationError: String? = nil

    public init(authVM: AuthViewModel = .shared, onNavigateToLogin: (() -> Void)? = nil) {
        self.authVM = authVM
        self.onNavigateToLogin = onNavigateToLogin
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                FableTheme.background
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        // Header
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Create Account")
                                .font(.system(size: 32, weight: .bold, design: .serif))
                                .foregroundColor(FableTheme.textPrimary)

                            Text("Sign up to start reading and writing.")
                                .font(.system(size: 14))
                                .foregroundColor(FableTheme.textMuted)
                                .lineSpacing(3)
                        }
                        .padding(.top, 16)

                        // Error Banner (Validation or Backend error)
                        if let error = validationError ?? authVM.errorMessage {
                            HStack(spacing: 10) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundColor(.red)
                                Text(error)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.red)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.red.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }

                        // Form Card
                        VStack(spacing: 16) {
                            // Full Name Field
                            VStack(alignment: .leading, spacing: 6) {
                                Text("FULL NAME")
                                    .font(.system(size: 11, weight: .bold))
                                    .tracking(1.0)
                                    .foregroundColor(FableTheme.textMuted)

                                HStack {
                                    Image(systemName: "person")
                                        .foregroundColor(FableTheme.textMuted)
                                        .frame(width: 20)

                                    TextField("Enter your full name", text: $name)
                                        .font(.system(size: 15))
                                }
                                .padding(14)
                                .background(FableTheme.surface.opacity(0.4))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(FableTheme.lightBorder, lineWidth: 1)
                                )
                            }

                            // Username Handle
                            VStack(alignment: .leading, spacing: 6) {
                                Text("USERNAME")
                                    .font(.system(size: 11, weight: .bold))
                                    .tracking(1.0)
                                    .foregroundColor(FableTheme.textMuted)

                                HStack {
                                    Image(systemName: "at")
                                        .foregroundColor(FableTheme.textMuted)
                                        .frame(width: 20)

                                    TextField("Choose a username", text: $handle)
                                        .autocorrectionDisabled(true)
                                        .textInputAutocapitalization(.never)
                                        .font(.system(size: 15))
                                }
                                .padding(14)
                                .background(FableTheme.surface.opacity(0.4))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(FableTheme.lightBorder, lineWidth: 1)
                                )
                            }

                            // Email Field
                            VStack(alignment: .leading, spacing: 6) {
                                Text("EMAIL")
                                    .font(.system(size: 11, weight: .bold))
                                    .tracking(1.0)
                                    .foregroundColor(FableTheme.textMuted)

                                HStack {
                                    Image(systemName: "envelope")
                                        .foregroundColor(FableTheme.textMuted)
                                        .frame(width: 20)

                                    TextField("Enter your email", text: $email)
                                        .keyboardType(.emailAddress)
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled(true)
                                        .font(.system(size: 15))
                                }
                                .padding(14)
                                .background(FableTheme.surface.opacity(0.4))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(FableTheme.lightBorder, lineWidth: 1)
                                )
                            }

                            // Password Field
                            VStack(alignment: .leading, spacing: 6) {
                                Text("PASSWORD")
                                    .font(.system(size: 11, weight: .bold))
                                    .tracking(1.0)
                                    .foregroundColor(FableTheme.textMuted)

                                HStack {
                                    Image(systemName: "lock")
                                        .foregroundColor(FableTheme.textMuted)
                                        .frame(width: 20)

                                    if isPasswordVisible {
                                        TextField("Enter a password (min. 6 characters)", text: $password)
                                            .font(.system(size: 15))
                                    } else {
                                        SecureField("Enter a password (min. 6 characters)", text: $password)
                                            .font(.system(size: 15))
                                    }

                                    Button(action: {
                                        isPasswordVisible.toggle()
                                    }) {
                                        Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                                            .foregroundColor(FableTheme.textMuted)
                                    }
                                }
                                .padding(14)
                                .background(FableTheme.surface.opacity(0.4))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(FableTheme.lightBorder, lineWidth: 1)
                                )
                            }

                            // Confirm Password Field
                            VStack(alignment: .leading, spacing: 6) {
                                Text("CONFIRM PASSWORD")
                                    .font(.system(size: 11, weight: .bold))
                                    .tracking(1.0)
                                    .foregroundColor(FableTheme.textMuted)

                                HStack {
                                    Image(systemName: "lock.shield")
                                        .foregroundColor(FableTheme.textMuted)
                                        .frame(width: 20)

                                    SecureField("Re-enter password", text: $confirmPassword)
                                        .font(.system(size: 15))
                                }
                                .padding(14)
                                .background(FableTheme.surface.opacity(0.4))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(FableTheme.lightBorder, lineWidth: 1)
                                )
                            }

                            // Policy Disclaimer
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "checkmark.shield")
                                    .font(.system(size: 14))
                                    .foregroundColor(FableTheme.brandPrimary)
                                    .padding(.top, 2)

                                Text("By creating an account, you agree to our Terms of Service and Privacy Policy.")
                                    .font(.system(size: 11))
                                    .foregroundColor(FableTheme.textMuted)
                                    .lineSpacing(2)
                            }
                            .padding(12)
                            .background(FableTheme.surface.opacity(0.3))
                            .clipShape(RoundedRectangle(cornerRadius: 10))

                            // Submit Button
                            Button(action: {
                                validateAndSubmit()
                            }) {
                                HStack(spacing: 8) {
                                    if authVM.isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    } else {
                                        Text("Create Account")
                                            .font(.system(size: 16, weight: .semibold))
                                        Image(systemName: "arrow.right")
                                            .font(.system(size: 13, weight: .bold))
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 15)
                                .background(isSubmitDisabled ? FableTheme.brandPrimary.opacity(0.5) : FableTheme.brandPrimary)
                                .foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .shadow(color: FableTheme.brandPrimary.opacity(0.25), radius: 8, y: 3)
                            }
                            .disabled(isSubmitDisabled || authVM.isLoading)
                        }
                        .padding(18)
                        .fableCard()

                        // Navigation switch to Sign In
                        if let onNavigateToLogin {
                            Button(action: onNavigateToLogin) {
                                HStack(spacing: 4) {
                                    Text("Already have an account?")
                                        .foregroundColor(FableTheme.textSecondary)
                                    Text("Sign In")
                                        .fontWeight(.bold)
                                        .foregroundColor(FableTheme.brandPrimary)
                                }
                                .font(.system(size: 14))
                                .frame(maxWidth: .infinity)
                                .padding(.top, 4)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(FableTheme.textPrimary)
                            .padding(6)
                            .background(Color.white)
                            .clipShape(Circle())
                    }
                }
            }
        }
    }

    private var isSubmitDisabled: Bool {
        name.trimmingCharacters(in: .whitespaces).isEmpty ||
        email.trimmingCharacters(in: .whitespaces).isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty
    }

    private func validateAndSubmit() {
        validationError = nil

        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else {
            validationError = "Please enter your name."
            return
        }

        let trimmedEmail = email.trimmingCharacters(in: .whitespaces)
        guard trimmedEmail.contains("@") && trimmedEmail.contains(".") else {
            validationError = "Please enter a valid email address."
            return
        }

        guard password.count >= 6 else {
            validationError = "Password must be at least 6 characters."
            return
        }

        guard password == confirmPassword else {
            validationError = "Passwords do not match."
            return
        }

        Task {
            let success = await authVM.register(name: trimmedName, handle: handle, email: trimmedEmail, password: password)
            if success {
                dismiss()
            }
        }
    }
}
