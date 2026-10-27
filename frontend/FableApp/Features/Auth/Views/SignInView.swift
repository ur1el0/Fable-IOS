import SwiftUI

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
                            Text("Welcome Back")
                                .font(.system(size: 30, weight: .bold, design: .serif))
                                .foregroundColor(FableTheme.textPrimary)

                            Text("Sign in to synchronize your reading progress, bookmarks, and drafts.")
                                .font(.system(size: 14))
                                .foregroundColor(FableTheme.textSecondary)
                                .lineSpacing(3)
                        }

                        // Error Banner
                        if let error = authVM.errorMessage {
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
                        VStack(spacing: 18) {
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
                                        TextField("Enter your password", text: $password)
                                            .textContentType(.password)
                                            .focused($focusedField, equals: .password)
                                            .font(.system(size: 15))
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
                                            .font(.system(size: 15))
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

                            // Submit Button
                            Button(action: submitSignIn) {
                                HStack(spacing: 8) {
                                    if authVM.isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    } else {
                                        Text("Sign In")
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

                        // Navigation switch to Register
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
        email.trimmingCharacters(in: .whitespaces).isEmpty || password.isEmpty
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
