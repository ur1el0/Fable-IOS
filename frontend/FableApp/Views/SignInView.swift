import SwiftUI

public struct SignInView: View {
    @ObservedObject var auth = AuthManager.shared
    @Environment(\.dismiss) var dismiss

    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isPasswordVisible: Bool = false

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                FableTheme.background
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        // Header
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Sign In")
                                .font(.system(size: 32, weight: .bold, design: .serif))
                                .foregroundColor(FableTheme.textPrimary)

                            Text("Enter your pen credentials to access your personal shelf, bookmarked folklore, and authored manuscripts.")
                                .font(.system(size: 14))
                                .foregroundColor(FableTheme.textMuted)
                                .lineSpacing(3)
                        }
                        .padding(.top, 16)

                        // Error Banner
                        if let error = auth.authErrorMessage {
                            HStack(spacing: 10) {
                                Image(systemName: "exclamationmark.triangle.fill")
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

                        // Input Fields
                        VStack(spacing: 16) {
                            // Email Field
                            VStack(alignment: .leading, spacing: 6) {
                                Text("EMAIL ADDRESS")
                                    .font(.system(size: 11, weight: .bold))
                                    .tracking(1.0)
                                    .foregroundColor(FableTheme.textMuted)

                                HStack {
                                    Image(systemName: "envelope")
                                        .foregroundColor(FableTheme.textMuted)
                                        .frame(width: 20)

                                    TextField("scribe@fable.app", text: $email)
                                        .keyboardType(.emailAddress)
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled(true)
                                        .font(.system(size: 15))
                                }
                                .padding(14)
                                .background(FableTheme.cardBackground)
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
                                        TextField("Enter password", text: $password)
                                            .font(.system(size: 15))
                                    } else {
                                        SecureField("Enter password", text: $password)
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
                                .background(FableTheme.cardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(FableTheme.lightBorder, lineWidth: 1)
                                )
                            }
                        }

                        // Submit Button
                        Button(action: {
                            Task {
                                let success = await auth.signIn(email: email, password: password)
                                if success {
                                    dismiss()
                                }
                            }
                        }) {
                            HStack(spacing: 8) {
                                if auth.isLoading {
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
                            .padding(.vertical, 16)
                            .background(FableTheme.brandPrimary)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .shadow(color: FableTheme.brandPrimary.opacity(0.25), radius: 8, y: 3)
                        }
                        .disabled(auth.isLoading)

                        // Demo Credentials Quick-Fill (Lab Convenience)
                        Button(action: {
                            self.email = "roosc-zano@fable.app"
                            self.password = "prague1890"
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 12))
                                Text("Fill Demo Author Credentials")
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .foregroundColor(FableTheme.brandPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(FableTheme.brandPrimary.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                    .padding(.horizontal, 24)
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
}
