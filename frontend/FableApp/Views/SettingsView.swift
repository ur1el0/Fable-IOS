import SwiftUI

public struct SettingsView: View {
    @EnvironmentObject var store: StoryStore
    @Environment(\.dismiss) var dismiss
    @ObservedObject var auth = AuthManager.shared
    
    @State private var autoArchiveStories: Bool = false
    @State private var cacheCleared: Bool = false
    @State private var navigateToProfile: Bool = false
    @State private var isShowingSignOutAlert: Bool = false
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ZStack {
                FableTheme.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 20) {
                            // User Profile Card (tappable to view Profile)
                            Button(action: {
                                navigateToProfile = true
                            }) {
                                HStack(spacing: 14) {
                                    FableImageView(name: auth.currentSession?.avatarName ?? "avatar_roosc", placeholderIcon: "person.crop.circle")
                                        .frame(width: 54, height: 54)
                                        .clipShape(Circle())
                                    
                                    VStack(alignment: .leading, spacing: 3) {
                                        HStack(spacing: 6) {
                                            Text(auth.currentSession?.name ?? "Guest Reader")
                                                .font(.system(size: 17, weight: .bold))
                                                .foregroundColor(FableTheme.textPrimary)
                                            
                                            if auth.isGuestMode {
                                                Text("GUEST")
                                                    .font(.system(size: 9, weight: .bold))
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(FableTheme.brandPrimary.opacity(0.12))
                                                    .foregroundColor(FableTheme.brandPrimary)
                                                    .clipShape(Capsule())
                                            }
                                        }
                                        
                                        Text(auth.currentSession?.email ?? "Tap to view profile")
                                            .font(.system(size: 13))
                                            .foregroundColor(FableTheme.textMuted)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(Color.gray.opacity(0.4))
                                }
                                .padding(16)
                                .background(FableTheme.cardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .shadow(color: Color.black.opacity(0.03), radius: 6, y: 2)
                            }
                            .buttonStyle(.plain)
                            
                            // Reading Preferences Section
                            VStack(alignment: .leading, spacing: 10) {
                                Text("READING PREFERENCES")
                                    .font(.system(size: 11, weight: .bold))
                                    .tracking(1.0)
                                    .foregroundColor(FableTheme.textMuted)
                                    .padding(.leading, 8)
                                
                                VStack(spacing: 0) {
                                    // Default Reader Font Picker Menu
                                    HStack(spacing: 14) {
                                        Image(systemName: "character.textbox")
                                            .font(.system(size: 16))
                                            .foregroundColor(FableTheme.textPrimary)
                                            .frame(width: 32, height: 32)
                                            .background(FableTheme.surface)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                        
                                        Text("Reader Font")
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundColor(FableTheme.textPrimary)
                                        
                                        Spacer()
                                        
                                        Menu {
                                            ForEach(ReaderFont.allCases) { font in
                                                Button(action: {
                                                    store.readerFont = font
                                                }) {
                                                    Text(font.displayName)
                                                }
                                            }
                                        } label: {
                                            HStack(spacing: 4) {
                                                Text(store.readerFont.displayName)
                                                    .font(.system(size: 14))
                                                    .foregroundColor(FableTheme.textMuted)
                                                Image(systemName: "chevron.up.chevron.down")
                                                    .font(.system(size: 11))
                                                    .foregroundColor(Color.gray.opacity(0.4))
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    
                                    Divider().padding(.leading, 62)
                                    
                                    // Default Theme Picker Menu
                                    HStack(spacing: 14) {
                                        Image(systemName: "paintpalette")
                                            .font(.system(size: 16))
                                            .foregroundColor(FableTheme.textPrimary)
                                            .frame(width: 32, height: 32)
                                            .background(FableTheme.surface)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                        
                                        Text("Theme Mode")
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundColor(FableTheme.textPrimary)
                                        
                                        Spacer()
                                        
                                        Menu {
                                            ForEach(ReaderTheme.allCases) { theme in
                                                Button(action: {
                                                    store.readerTheme = theme
                                                }) {
                                                    Text(theme.rawValue)
                                                }
                                            }
                                        } label: {
                                            HStack(spacing: 6) {
                                                Circle()
                                                    .fill(store.readerTheme.swatchColor)
                                                    .frame(width: 14, height: 14)
                                                Text(store.readerTheme.rawValue)
                                                    .font(.system(size: 14))
                                                    .foregroundColor(FableTheme.textMuted)
                                                Image(systemName: "chevron.up.chevron.down")
                                                    .font(.system(size: 11))
                                                    .foregroundColor(Color.gray.opacity(0.4))
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    
                                    Divider().padding(.leading, 62)
                                    
                                    // Haptic Feedback Toggle
                                    HStack(spacing: 14) {
                                        Image(systemName: "iphone.radiowaves.left.and.right")
                                            .font(.system(size: 16))
                                            .foregroundColor(FableTheme.textPrimary)
                                            .frame(width: 32, height: 32)
                                            .background(FableTheme.surface)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                        
                                        Text("Haptic Feedback")
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundColor(FableTheme.textPrimary)
                                        
                                        Spacer()
                                        
                                        Toggle("", isOn: $store.hapticFeedback)
                                            .tint(FableTheme.brandPrimary)
                                            .labelsHidden()
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                }
                                .background(FableTheme.cardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .shadow(color: Color.black.opacity(0.03), radius: 6, y: 2)
                            }
                            
                            // Storage & Cache Section
                            VStack(alignment: .leading, spacing: 10) {
                                Text("STORAGE & CACHE")
                                    .font(.system(size: 11, weight: .bold))
                                    .tracking(1.0)
                                    .foregroundColor(FableTheme.textMuted)
                                    .padding(.leading, 8)
                                
                                VStack(spacing: 0) {
                                    HStack(spacing: 14) {
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text("Offline Library Cache")
                                                .font(.system(size: 15, weight: .medium))
                                                .foregroundColor(FableTheme.textPrimary)
                                            Text(cacheCleared ? "Cache clean (0 MB)" : "9 Stories Cached (24 MB)")
                                                .font(.system(size: 12))
                                                .foregroundColor(FableTheme.textMuted)
                                        }
                                        
                                        Spacer()
                                        
                                        Button(action: {
                                            withAnimation {
                                                cacheCleared = true
                                            }
                                        }) {
                                            Text(cacheCleared ? "Cleaned" : "Clear Cache")
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundColor(cacheCleared ? .green : FableTheme.textPrimary)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .background(FableTheme.surfaceVariant)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    
                                    Divider().padding(.leading, 16)
                                    
                                    HStack(spacing: 14) {
                                        Text("Auto-Archive Completed")
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundColor(FableTheme.textPrimary)
                                        Spacer()
                                        Toggle("", isOn: $autoArchiveStories)
                                            .tint(FableTheme.brandPrimary)
                                            .labelsHidden()
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                }
                                .background(FableTheme.cardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .shadow(color: Color.black.opacity(0.03), radius: 6, y: 2)
                            }
                            
                            // Account & Session Section
                            VStack(alignment: .leading, spacing: 10) {
                                Text("ACCOUNT & SESSION")
                                    .font(.system(size: 11, weight: .bold))
                                    .tracking(1.0)
                                    .foregroundColor(FableTheme.textMuted)
                                    .padding(.leading, 8)
                                
                                VStack(spacing: 0) {
                                    Button(action: {
                                        isShowingSignOutAlert = true
                                    }) {
                                        HStack(spacing: 12) {
                                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                                .foregroundColor(.red.opacity(0.85))
                                                .font(.system(size: 15))
                                                .frame(width: 24)
                                            
                                            Text(auth.isGuestMode ? "Exit Guest Mode" : "Sign Out of Fable")
                                                .font(.system(size: 15, weight: .medium))
                                                .foregroundColor(.red.opacity(0.9))
                                            
                                            Spacer()
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 14)
                                    }
                                }
                                .background(FableTheme.cardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .shadow(color: Color.black.opacity(0.03), radius: 6, y: 2)
                            }
                            .alert(auth.isGuestMode ? "Exit Guest Mode?" : "Sign Out?", isPresented: $isShowingSignOutAlert) {
                                Button(auth.isGuestMode ? "Exit" : "Sign Out", role: .destructive) {
                                    dismiss()
                                    auth.signOut()
                                }
                                Button("Cancel", role: .cancel) {}
                            } message: {
                                Text(auth.isGuestMode ? "You will return to the welcome screen." : "Your local reading data and drafts will remain preserved on this device.")
                            }
                            
                            // App Version Info
                            VStack(spacing: 4) {
                                Text("Fable for iOS • Version 1.0.0 (Build 77)")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(FableTheme.textMuted)
                                Text("Inspired by high-end independent editorial journals.")
                                    .font(.system(size: 11))
                                    .foregroundColor(FableTheme.textMuted.opacity(0.7))
                            }
                            .padding(.top, 8)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(FableTheme.brandPrimary)
                }
            }
            .sheet(isPresented: $navigateToProfile) {
                ProfileView()
                    .environmentObject(store)
            }
        }
    }
}
