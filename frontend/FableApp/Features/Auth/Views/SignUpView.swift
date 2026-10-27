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

    private enum Field: Hashable {
        case name
        case handle
        case email
        case password
        case confirmPassword
    }
    @FocusState private var focusedField: Field?

    @MainActor
    public init(authVM: AuthViewModel? = nil, onNavigateToLogin: (() -> Void)? = nil) {
        self.authVM = authVM ?? .shared
        self.onNavigateToLogin = onNavigateToLogin
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                FableTheme.background
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        // Brand Logo & Title
                        HStack(spacing: 8) {
                            Image(systemName: "square.stack.3d.up.fill")
                                .font(.system(size: 13))
                                .foregroundColor(.white)
                                .padding(7)
                                .background(FableTheme.brandPrimary)
                                .clipShape(RoundedRectangle(cornerRadius: 8))

                            Text("Fable")
                                .font(.system(size: 18, weight: .black))
                                .foregroundColor(FableTheme.textPrimary)
                        }
                        .padding(.top, 16)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Create Account")
                                .font(.system(size: 30, weight: .bold, design: .serif))
                                .foregroundColor(FableTheme.textPrimary)

                            Text("Sign up to start reading, syncing shelves, and publishing tales.")
                                .font(.system(size: 14))
                                .foregroundColor(FableTheme.textSecondary)
                                .lineSpacing(3)
                        }

                        // Error Banner (Validation or Backend error)
                        if let error = validationError ?? authVM.errorMessage {
                            HStack(spacing: 10) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundColor(.red)
                                Text(error)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.red)
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.red.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.red.opacity(0.2), lineWidth: 0.8)
                            )
                        }

                        // Form Card
                        VStack(spacing: 16) {
                            // Full Name Field
                            VStack(alignment: .leading, spacing: 6) {
                                Text("FULL NAME")
                                    .font(.system(size: 11, weight: .bold))
                                    .tracking(1.0)
                                    .foregroundColor(focusedField == .name ? FableTheme.brandPrimary : FableTheme.textMuted)

                                HStack(spacing: 12) {
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(focusedField == .name ? FableTheme.brandPrimary : FableTheme.textMuted)
                                        .frame(width: 20)

                                    TextField("Enter your full name", text: $name)
                                        .textContentType(.name)
                                        .focused($focusedField, equals: .name)
                                        .font(.system(size: 15))
                                        .submitLabel(.next)
                                        .onSubmit { focusedField = .handle }
                                }
                                .padding(14)
                                .background(FableTheme.surface.opacity(0.45))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(focusedField == .name ? FableTheme.brandPrimary : FableTheme.divider.opacity(0.8), lineWidth: focusedField == .name ? 1.5 : 1)
                                )
                            }

                            // Username Handle
                            VStack(alignment: .leading, spacing: 6) {
                                Text("USERNAME")
                                    .font(.system(size: 11, weight: .bold))
                                    .tracking(1.0)
                                    .foregroundColor(focusedField == .handle ? FableTheme.brandPrimary : FableTheme.textMuted)

                                HStack(spacing: 12) {
                                    Image(systemName: "at")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(focusedField == .handle ? FableTheme.brandPrimary : FableTheme.textMuted)
                                        .frame(width: 20)

                                    TextField("Choose a username", text: $handle)
                                        .autocorrectionDisabled(true)
                                        .textInputAutocapitalization(.never)
                                        .textContentType(.username)
                                        .focused($focusedField, equals: .handle)
                                        .font(.system(size: 15))
                                        .submitLabel(.next)
                                        .onSubmit { focusedField = .email }
                                }
                                .padding(14)
                                .background(FableTheme.surface.opacity(0.45))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(focusedField == .handle ? FableTheme.brandPrimary : FableTheme.divider.opacity(0.8), lineWidth: focusedField == .handle ? 1.5 : 1)
                                )
                            }

                            // Email Field
                            VStack(alignment: .leading, spacing: 6) {
                                Text("EMAIL")
                                    .font(.system(size: 11, weight: .bold))
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
                                        .font(.system(size: 15))
                                        .submitLabel(.next)
                                        .onSubmit { focusedField = .password }
                                }
                                .padding(14)
                                .background(FableTheme.surface.opacity(0.45))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(focusedField == .email ? FableTheme.brandPrimary : FableTheme.divider.opacity(0.8), lineWidth: focusedField == .email ? 1.5 : 1)
                                )
                            }

                            // Password Field
                            VStack(alignment: .leading, spacing: 6) {
                                Text("PASSWORD")
                                    .font(.system(size: 11, weight: .bold))
                                    .tracking(1.0)
                                    .foregroundColor(focusedField == .password ? FableTheme.brandPrimary : FableTheme.textMuted)

                                HStack(spacing: 12) {
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(focusedField == .password ? FableTheme.brandPrimary : FableTheme.textMuted)
                                        .frame(width: 20)

                                    if isPasswordVisible {
                                        TextField("Min. 12 characters", text: $password)
                                            .textContentType(.newPassword)
                                            .focused($focusedField, equals: .password)
                                            .font(.system(size: 15))
                                            .submitLabel(.next)
                                            .onSubmit { focusedField = .confirmPassword }
                                    } else {
                                        SecureField("Min. 12 characters", text: $password)
                                            .textContentType(.newPassword)
                                            .focused($focusedField, equals: .password)
                                            .font(.system(size: 15))
                                            .submitLabel(.next)
                                            .onSubmit { focusedField = .confirmPassword }
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

                            // Confirm Password Field
                            VStack(alignment: .leading, spacing: 6) {
                                Text("CONFIRM PASSWORD")
                                    .font(.system(size: 11, weight: .bold))
                                    .tracking(1.0)
                                    .foregroundColor(focusedField == .confirmPassword ? FableTheme.brandPrimary : FableTheme.textMuted)

                                HStack(spacing: 12) {
                                    Image(systemName: "lock.shield.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(focusedField == .confirmPassword ? FableTheme.brandPrimary : FableTheme.textMuted)
                                        .frame(width: 20)

                                    SecureField("Re-enter password", text: $confirmPassword)
                                        .textContentType(.newPassword)
                                        .focused($focusedField, equals: .confirmPassword)
                                        .font(.system(size: 15))
                                        .submitLabel(.go)
                                        .onSubmit {
                                            if !isSubmitDisabled {
                                                validateAndSubmit()
                                            }
                                        }
                                }
                                .padding(14)
                                .background(FableTheme.surface.opacity(0.45))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(focusedField == .confirmPassword ? FableTheme.brandPrimary : FableTheme.divider.opacity(0.8), lineWidth: focusedField == .confirmPassword ? 1.5 : 1)
                                )
                            }

                            // Policy Disclaimer
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "checkmark.shield.fill")
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
                            Button(action: validateAndSubmit) {
                                HStack(spacing: 8) {
                                    if authVM.isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    } else {
                                        Text("Create Account")
                                            .font(.system(size: 16, weight: .bold))
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
                        .padding(20)
                        .background(FableTheme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(FableTheme.divider.opacity(0.8), lineWidth: 0.8)
                        )
                        .shadow(color: Color.black.opacity(0.02), radius: 3, x: 0, y: 1)
                        .shadow(color: Color.black.opacity(0.05), radius: 12, x: 0, y: 5)

                        // Navigation switch to Sign In
                        if let onNavigateToLogin {
                            Button {
                                FableHaptics.light()
                                onNavigateToLogin()
                            } label: {
                                HStack(spacing: 4) {
                                    Text("Already have an account?")
                                        .foregroundColor(FableTheme.textSecondary)
                                    Text("Sign In")
                                        .fontWeight(.bold)
                                        .foregroundColor(FableTheme.brandPrimary)
                                }
                                .font(.system(size: 14))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
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

    private var isSubmitDisabled: Bool {
        name.trimmingCharacters(in: .whitespaces).isEmpty ||
        email.trimmingCharacters(in: .whitespaces).isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty
    }

    private func validateAndSubmit() {
        FableHaptics.medium()
        validationError = nil
        focusedField = nil

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

        guard password.count >= 12 else {
            validationError = "Password must be at least 12 characters."
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

#Preview {
    SignUpView()
}
