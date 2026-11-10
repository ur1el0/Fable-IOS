import SwiftUI

public struct WelcomeView: View {
    @ObservedObject var authVM: AuthViewModel = .shared
    @ObservedObject var auth = AuthManager.shared

    @State private var isShowingSignIn: Bool = false
    @State private var isShowingSignUp: Bool = false

    public init() {}

    public var body: some View {
        ZStack {
            FableTheme.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Modern Brand Header
                VStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 24)
                            .fill(FableTheme.surface)
                            .frame(width: 80, height: 80)
                            .overlay(
                                RoundedRectangle(cornerRadius: 24)
                                    .stroke(FableTheme.brandPrimary.opacity(0.2), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.04), radius: 10, y: 4)

                        Image(systemName: "square.stack.3d.up.fill")
                            .fableFont(size: 36)
                            .foregroundColor(FableTheme.brandPrimary)
                    }

                    VStack(spacing: 6) {
                        Text("Fable")
                            .fableFont(size: 42, weight: .black)
                            .foregroundColor(FableTheme.textPrimary)

                        Text(StoryStore.isMangaEnabled ? "STORIES & MANGA" : "BOOKS & FABLES")
                            .fableFont(size: 11, weight: .bold)
                            .tracking(2.0)
                            .foregroundColor(FableTheme.brandPrimary)
                    }

                    Text(StoryStore.isMangaEnabled ? "A modern, distraction-free platform for reading novels, manga, and original stories." : "A modern, distraction-free platform for reading classic books, fables, and original stories.")
                        .fableFont(size: 15, weight: .regular)
                        .foregroundColor(FableTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 36)
                        .padding(.top, 4)
                }

                Spacer()

                // Hero Feature Highlights Card
                VStack(spacing: 10) {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(FableTheme.brandPrimary.opacity(0.12))
                            .frame(width: 32, height: 32)
                            .overlay(
                                Image(systemName: "sparkles")
                                    .fableFont(size: 14, weight: .bold)
                                    .foregroundColor(FableTheme.brandPrimary)
                            )

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Read Anywhere")
                                .fableFont(size: 13, weight: .bold)
                                .foregroundColor(FableTheme.textPrimary)
                            Text(StoryStore.isMangaEnabled ? "Manga & Novels • Offline mode • Adaptive reader" : "Classics & Fables • Offline mode • Adaptive reader")
                                .fableFont(size: 11)
                                .foregroundColor(FableTheme.textMuted)
                        }
                        Spacer()
                    }
                    .padding(14)
                    .background(FableTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(FableTheme.lightBorder, lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.03), radius: 6, y: 2)
                    .padding(.horizontal, 28)
                }

                Spacer()

                // Action Gateway Buttons
                VStack(spacing: 12) {
                    Button(action: {
                        isShowingSignIn = true
                    }) {
                        HStack {
                            Text("Sign In")
                                .fableFont(size: 16, weight: .semibold)
                            Image(systemName: "arrow.right")
                                .fableFont(size: 13, weight: .bold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(FableTheme.brandPrimary)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: FableTheme.brandPrimary.opacity(0.3), radius: 10, y: 4)
                    }

                    Button(action: {
                        isShowingSignUp = true
                    }) {
                        Text("Create Account")
                            .fableFont(size: 15, weight: .semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(FableTheme.surface)
                            .foregroundColor(FableTheme.textPrimary)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(FableTheme.lightBorder, lineWidth: 1)
                            )
                    }

                    Button(action: {
                        withAnimation(.easeInOut) {
                            authVM.continueAsGuest()
                        }
                    }) {
                        Text("Continue as Guest")
                            .fableFont(size: 13, weight: .medium)
                            .foregroundColor(FableTheme.textMuted)
                            .padding(.vertical, 8)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 36)
            }
        }
        .sheet(isPresented: $isShowingSignIn) {
            SignInView(authVM: authVM, onNavigateToRegister: {
                isShowingSignIn = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    isShowingSignUp = true
                }
            })
        }
        .sheet(isPresented: $isShowingSignUp) {
            SignUpView(authVM: authVM, onNavigateToLogin: {
                isShowingSignUp = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    isShowingSignIn = true
                }
            })
        }
    }
}

#Preview {
    WelcomeView()
}
