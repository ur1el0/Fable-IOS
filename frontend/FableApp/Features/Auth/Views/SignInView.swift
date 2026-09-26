import SwiftUI

public struct SignInView: View {
    @ObservedObject var authVM: AuthViewModel
    var onNavigateToRegister: (() -> Void)?
    @Environment(\.dismiss) var dismiss

    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isPasswordVisible: Bool = false

    public init(authVM: AuthViewModel = .shared, onNavigateToRegister: (() -> Void)? = nil) {
        self.authVM = authVM
        self.onNavigateToRegister = onNavigateToRegister
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
                            Text("Sign In")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(FableTheme.textPrimary)

                            Text("Enter your credentials to continue.")
                                .font(.system(size: 14))
                                .foregroundColor(FableTheme.textMuted)
                                .lineSpacing(3)
                        }
                        .padding(.top, 16)

                        // Error Banner
                        if let error = authVM.errorMessage {
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
                                        TextField("Enter your password", text: $password)
                                            .font(.system(size: 15))
                                    } else {
                                        SecureField("Enter your password", text: $password)
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

                            // Submit Button
                            Button(action: {
                                Task {
                                    let success = await authVM.login(email: email, password: password)
                                    if success {
                                        dismiss()
                                    }
                                }
                            }) {
                                HStack(spacing: 8) {
                                    if authVM.isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    } else {
                                        Text("Sign In")
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

                        // Navigation switch to Register
                        if let onNavigateToRegister {
                            Button(action: onNavigateToRegister) {
                                HStack(spacing: 4) {
                                    Text("Don't have an account?")
                                        .foregroundColor(FableTheme.textSecondary)
                                    Text("Create Account")
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
        email.trimmingCharacters(in: .whitespaces).isEmpty || password.isEmpty
    }
}

#Preview {
    SignInView()
}
