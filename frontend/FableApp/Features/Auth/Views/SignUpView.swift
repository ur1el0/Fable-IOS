import SwiftUI

public struct SignUpView: View {
    @ObservedObject var auth = AuthManager.shared
    @Environment(\.dismiss) var dismiss

    @State private var name: String = ""
    @State private var handle: String = ""
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
                    VStack(alignment: .leading, spacing: 22) {
                        // Header
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Create Account")
                                .font(.system(size: 32, weight: .bold, design: .serif))
                                .foregroundColor(FableTheme.textPrimary)

                            Text("Join a fellowship of storytellers and archivist readers. Publish original folklore or curate your personal literary shelf.")
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

                        // Form Fields
                        VStack(spacing: 16) {
                            // Pen Name Field
                            VStack(alignment: .leading, spacing: 6) {
                                Text("PEN NAME / FULL NAME")
                                    .font(.system(size: 11, weight: .bold))
                                    .tracking(1.0)
                                    .foregroundColor(FableTheme.textMuted)

                                HStack {
                                    Image(systemName: "person")
                                        .foregroundColor(FableTheme.textMuted)
                                        .frame(width: 20)

                                    TextField("e.g. Roosc Zaño", text: $name)
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

                            // Author Handle
                            VStack(alignment: .leading, spacing: 6) {
                                Text("AUTHOR HANDLE")
                                    .font(.system(size: 11, weight: .bold))
                                    .tracking(1.0)
                                    .foregroundColor(FableTheme.textMuted)

                                HStack {
                                    Image(systemName: "at")
                                        .foregroundColor(FableTheme.textMuted)
                                        .frame(width: 20)

                                    TextField("e.g. @zanoroosc", text: $handle)
                                        .autocorrectionDisabled(true)
                                        .textInputAutocapitalization(.never)
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
                                Text("PASSWORD (MINIMUM 6 CHARACTERS)")
                                    .font(.system(size: 11, weight: .bold))
                                    .tracking(1.0)
                                    .foregroundColor(FableTheme.textMuted)

                                HStack {
                                    Image(systemName: "lock")
                                        .foregroundColor(FableTheme.textMuted)
                                        .frame(width: 20)

                                    if isPasswordVisible {
                                        TextField("Create password", text: $password)
                                            .font(.system(size: 15))
                                    } else {
                                        SecureField("Create password", text: $password)
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

                        // Literary Ethics Disclaimer
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "checkmark.shield")
                                .font(.system(size: 14))
                                .foregroundColor(FableTheme.brandPrimary)
                                .padding(.top, 2)

                            Text("By registering, you commit to publishing original writings, respect historical public domain lore, and preserve respectful literary discourse.")
                                .font(.system(size: 11))
                                .foregroundColor(FableTheme.textMuted)
                                .lineSpacing(2)
                        }
                        .padding(12)
                        .background(FableTheme.surface.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                        // Submit Button
                        Button(action: {
                            Task {
                                let success = await auth.signUp(name: name, handle: handle, email: email, password: password)
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
                                    Text("Complete Author Registration")
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
                    }
                    .padding(.horizontal, 24)
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
}
