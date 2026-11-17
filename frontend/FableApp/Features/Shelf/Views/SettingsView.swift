import SwiftUI

public struct SettingsView: View {
    @EnvironmentObject var store: StoryStore
    @Environment(\.dismiss) var dismiss
    @ObservedObject var auth = AuthManager.shared
    
    @State private var imageCacheSizeInBytes: Int64 = 0
    @State private var isClearingImageCache: Bool = false
    @State private var imageCacheMessage: String?
    @State private var navigateToProfile: Bool = false
    @State private var isShowingSignOutAlert: Bool = false
    @State private var isShowingDiagnostics: Bool = false
    @State private var isShowingServerConfig: Bool = false
    @State private var customServerInput: String = StoryAPIService.resolvedBaseURL().absoluteString
    @State private var currentServerURLString: String = StoryAPIService.resolvedBaseURL().absoluteString
    
    public init() {}

    private var versionLabel: String {
        let metadata = Bundle.main.infoDictionary ?? [:]
        let version = metadata["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = metadata["CFBundleVersion"] as? String ?? "Unknown"
        return "Fable for iOS • Version \(version) (Build \(build))"
    }
    
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
                                    FableImageView(name: auth.currentSession?.avatarName, placeholderIcon: "person.crop.circle")
                                        .frame(width: 54, height: 54)
                                        .clipShape(Circle())
                                    
                                    VStack(alignment: .leading, spacing: 3) {
                                        HStack(spacing: 6) {
                                            Text(auth.currentSession?.name ?? "Guest")
                                                .fableFont(size: 17, weight: .bold)
                                                .foregroundColor(FableTheme.textPrimary)
                                            
                                            if auth.isGuestMode {
                                                Text("GUEST")
                                                    .fableFont(size: 9, weight: .bold)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(FableTheme.brandPrimary.opacity(0.12))
                                                    .foregroundColor(FableTheme.brandPrimary)
                                                    .clipShape(Capsule())
                                            }
                                        }
                                        
                                        Text(auth.currentSession?.email ?? "Tap to view profile")
                                            .fableFont(size: 13)
                                            .foregroundColor(FableTheme.textMuted)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .fableFont(size: 14, weight: .semibold)
                                        .foregroundColor(Color.gray.opacity(0.4))
                                }
                                .padding(16)
                                .background(FableTheme.cardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .shadow(color: Color.black.opacity(0.03), radius: 6, y: 2)
                            }
                            .buttonStyle(.plain)
                            
                            // App Appearance Section (System / Light / Dark)
                            VStack(alignment: .leading, spacing: 10) {
                                Text("APPEARANCE")
                                    .fableFont(size: 11, weight: .bold)
                                    .tracking(1.0)
                                    .foregroundColor(FableTheme.textMuted)
                                    .padding(.leading, 8)

                                VStack(spacing: 12) {
                                    HStack(spacing: 14) {
                                        Image(systemName: store.appAppearance.iconName)
                                            .fableFont(size: 16)
                                            .foregroundColor(FableTheme.brandPrimary)
                                            .frame(width: 32, height: 32)
                                            .background(FableTheme.brandPrimary.opacity(0.12))
                                            .clipShape(RoundedRectangle(cornerRadius: 8))

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("App Theme")
                                                .fableFont(size: 15, weight: .medium)
                                                .foregroundColor(FableTheme.textPrimary)
                                            Text("Follow iOS system appearance or force Light / Dark")
                                                .fableFont(size: 11)
                                                .foregroundColor(FableTheme.textMuted)
                                        }

                                        Spacer()
                                    }

                                    Picker("App Theme", selection: $store.appAppearance) {
                                        ForEach(AppAppearance.allCases) { appearance in
                                            Text(appearance.displayName).tag(appearance)
                                        }
                                    }
                                    .pickerStyle(.segmented)
                                    .accessibilityLabel("App Theme")
                                }
                                .padding(16)
                                .background(FableTheme.cardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .shadow(color: Color.black.opacity(0.03), radius: 6, y: 2)
                            }

                            // Reading Preferences Section
                            VStack(alignment: .leading, spacing: 10) {
                                Text("READING PREFERENCES")
                                    .fableFont(size: 11, weight: .bold)
                                    .tracking(1.0)
                                    .foregroundColor(FableTheme.textMuted)
                                    .padding(.leading, 8)
                                
                                VStack(spacing: 0) {
                                    // Reader Font Picker + Segmented Toggle
                                    VStack(alignment: .leading, spacing: 12) {
                                        HStack(spacing: 14) {
                                            Image(systemName: "character.textbox")
                                                .fableFont(size: 16)
                                                .foregroundColor(FableTheme.textPrimary)
                                                .frame(width: 32, height: 32)
                                                .background(FableTheme.surface)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                            
                                            Text("Reader Font")
                                                .fableFont(size: 15, weight: .medium)
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
                                                        .fableFont(size: 14, design: store.readerFont.design)
                                                        .foregroundColor(FableTheme.textMuted)
                                                    Image(systemName: "chevron.up.chevron.down")
                                                        .fableFont(size: 11)
                                                        .foregroundColor(FableTheme.textMuted.opacity(0.6))
                                                }
                                            }
                                        }

                                        HStack(spacing: 4) {
                                            ForEach(ReaderFont.allCases) { font in
                                                Button(action: {
                                                    FableHaptics.selection()
                                                    store.readerFont = font
                                                }) {
                                                    Text(font.rawValue)
                                                        .fableFont(
                                                            size: 13,
                                                            weight: store.readerFont == font ? .semibold : .regular,
                                                            design: font.design,
                                                            respectReaderFont: false
                                                        )
                                                        .frame(maxWidth: .infinity)
                                                        .padding(.vertical, 8)
                                                        .background(store.readerFont == font ? FableTheme.cardBackground : Color.clear)
                                                        .foregroundColor(store.readerFont == font ? FableTheme.textPrimary : FableTheme.textMuted)
                                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                                        .shadow(color: store.readerFont == font ? Color.black.opacity(0.08) : Color.clear, radius: 3, y: 1)
                                                }
                                                .buttonStyle(.plain)
                                            }
                                        }
                                        .padding(4)
                                        .background(FableTheme.surfaceVariant)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    
                                    Divider().padding(.leading, 62)

                                    // Text Size Slider
                                    VStack(alignment: .leading, spacing: 10) {
                                        HStack(spacing: 14) {
                                            Image(systemName: "textformat.size")
                                                .fableFont(size: 16)
                                                .foregroundColor(FableTheme.textPrimary)
                                                .frame(width: 32, height: 32)
                                                .background(FableTheme.surface)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))

                                            Text("Text Size")
                                                .fableFont(size: 15, weight: .medium)
                                                .foregroundColor(FableTheme.textPrimary)

                                            Spacer()

                                            Text("\(Int(store.readerFontSize))%")
                                                .fableFont(size: 13, weight: .semibold)
                                                .monospacedDigit()
                                                .foregroundColor(FableTheme.brandPrimary)
                                        }

                                        HStack(spacing: 12) {
                                            Text("A")
                                                .fableFont(size: 12, weight: .semibold, design: store.readerFont.design)
                                                .foregroundColor(FableTheme.textMuted)

                                            Slider(value: $store.readerFontSize, in: 80...150, step: 5)
                                                .tint(FableTheme.brandPrimary)
                                                .accessibilityLabel("Text Size")

                                            Text("A")
                                                .fableFont(size: 18, weight: .bold, design: store.readerFont.design)
                                                .foregroundColor(FableTheme.textPrimary)
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(FableTheme.surfaceVariant)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)

                                    Divider().padding(.leading, 62)

                                    // Line Spacing Toggle
                                    VStack(alignment: .leading, spacing: 10) {
                                        HStack(spacing: 14) {
                                            Image(systemName: "arrow.up.and.down.text.horizontal")
                                                .fableFont(size: 16)
                                                .foregroundColor(FableTheme.textPrimary)
                                                .frame(width: 32, height: 32)
                                                .background(FableTheme.surface)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))

                                            Text("Line Spacing")
                                                .fableFont(size: 15, weight: .medium)
                                                .foregroundColor(FableTheme.textPrimary)

                                            Spacer()

                                            Text(store.readerLineSpacing.rawValue)
                                                .fableFont(size: 13, weight: .medium)
                                                .foregroundColor(FableTheme.textMuted)
                                        }

                                        Picker("Line Spacing", selection: $store.readerLineSpacing) {
                                            ForEach(ReaderLineSpacing.allCases) { spacing in
                                                Text(spacing.rawValue).tag(spacing)
                                            }
                                        }
                                        .pickerStyle(.segmented)
                                        .accessibilityLabel("Line Spacing")
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)

                                    Divider().padding(.leading, 62)

                                    // Live Reading Typography Preview
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("PREVIEW")
                                            .fableFont(size: 10, weight: .bold)
                                            .tracking(1.0)
                                            .foregroundColor(store.readerTheme.textColor.opacity(0.65))

                                        Text("Stories come alive when typography and contrast match your environment.")
                                            .fableFont(
                                                size: 14,
                                                scale: max(12.0 / 14.0, CGFloat(store.readerFontSize / 100.0)),
                                                design: store.readerFont.design,
                                                relativeTo: .body
                                            )
                                            .lineSpacing(store.readerLineSpacing.points)
                                            .foregroundColor(store.readerTheme.textColor)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    .padding(14)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(store.readerTheme.backgroundColor)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(FableTheme.divider, lineWidth: 0.8)
                                    )
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)

                                    Divider().padding(.leading, 62)
                                    
                                    // Default Theme Picker Menu
                                    HStack(spacing: 14) {
                                        Image(systemName: "paintpalette")
                                            .fableFont(size: 16)
                                            .foregroundColor(FableTheme.textPrimary)
                                            .frame(width: 32, height: 32)
                                            .background(FableTheme.surface)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                        
                                        Text("Reader Theme")
                                            .fableFont(size: 15, weight: .medium)
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
                                                    .overlay(
                                                        Circle()
                                                            .stroke(FableTheme.divider, lineWidth: 0.8)
                                                    )
                                                Text(store.readerTheme.rawValue)
                                                    .fableFont(size: 14)
                                                    .foregroundColor(FableTheme.textMuted)
                                                Image(systemName: "chevron.up.chevron.down")
                                                    .fableFont(size: 11)
                                                    .foregroundColor(FableTheme.textMuted.opacity(0.6))
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    
                                    Divider().padding(.leading, 62)
                                    
                                    // Haptic Feedback Toggle
                                    HStack(spacing: 14) {
                                        Image(systemName: "iphone.radiowaves.left.and.right")
                                            .fableFont(size: 16)
                                            .foregroundColor(FableTheme.textPrimary)
                                            .frame(width: 32, height: 32)
                                            .background(FableTheme.surface)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                        
                                        Text("Haptic Feedback")
                                            .fableFont(size: 15, weight: .medium)
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
                                    .fableFont(size: 11, weight: .bold)
                                    .tracking(1.0)
                                    .foregroundColor(FableTheme.textMuted)
                                    .padding(.leading, 8)
                                
                                VStack(spacing: 0) {
                                    HStack(spacing: 14) {
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text("Downloaded Cover & Panel Images")
                                                .fableFont(size: 15, weight: .medium)
                                                .foregroundColor(FableTheme.textPrimary)
                                            Text(imageCacheMessage ?? ByteCountFormatter.string(fromByteCount: imageCacheSizeInBytes, countStyle: .file))
                                                .fableFont(size: 12)
                                                .foregroundColor(FableTheme.textMuted)
                                        }
                                        
                                        Spacer()
                                        
                                        Button {
                                            Task {
                                                isClearingImageCache = true
                                                defer { isClearingImageCache = false }
                                                do {
                                                    try await DiskImageCache.shared.clearCache()
                                                    imageCacheSizeInBytes = await DiskImageCache.shared.diskUsageInBytes()
                                                    imageCacheMessage = "Image cache cleared"
                                                } catch {
                                                    imageCacheMessage = "Unable to clear image cache"
                                                }
                                            }
                                        } label: {
                                            Text(isClearingImageCache ? "Clearing…" : "Clear")
                                                .fableFont(size: 13, weight: .semibold)
                                                .foregroundColor(FableTheme.textPrimary)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .background(FableTheme.surfaceVariant)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                        }
                                        .disabled(isClearingImageCache)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    
                                    Divider().padding(.leading, 16)
                                    
                                    HStack(spacing: 14) {
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text("Auto-Archive Completed")
                                                .fableFont(size: 15, weight: .medium)
                                                .foregroundColor(FableTheme.textPrimary)
                                            Text("Remove finished books from Saved")
                                                .fableFont(size: 12)
                                                .foregroundColor(FableTheme.textMuted)
                                        }
                                        Spacer()
                                        Toggle("", isOn: $store.autoArchiveCompletedStories)
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
                            
                            // System Diagnostics & Verification Section
                            VStack(alignment: .leading, spacing: 10) {
                                Text("SYSTEM DIAGNOSTICS & VERIFICATION")
                                    .fableFont(size: 11, weight: .bold)
                                    .tracking(1.0)
                                    .foregroundColor(FableTheme.textMuted)
                                    .padding(.leading, 8)
                                
                                VStack(spacing: 0) {
                                    Button(action: {
                                        isShowingDiagnostics = true
                                    }) {
                                        HStack(spacing: 12) {
                                            Image(systemName: "checkmark.shield")
                                                .fableFont(size: 16)
                                                .foregroundColor(FableTheme.brandPrimary)
                                                .frame(width: 32, height: 32)
                                                .background(FableTheme.brandPrimary.opacity(0.12))
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                            
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text("System Diagnostics & Health")
                                                    .fableFont(size: 15, weight: .medium)
                                                    .foregroundColor(FableTheme.textPrimary)
                                                
                                                Text("Verify chapter updates, genres, artists, and analytics")
                                                    .fableFont(size: 11)
                                                    .foregroundColor(FableTheme.textMuted)
                                            }
                                            
                                            Spacer()
                                            
                                            Image(systemName: "chevron.right")
                                                .fableFont(size: 13, weight: .semibold)
                                                .foregroundColor(Color.gray.opacity(0.4))
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                    }

                                    Divider().padding(.leading, 16)

                                    Button(action: {
                                        customServerInput = StoryAPIService.resolvedBaseURL().absoluteString
                                        isShowingServerConfig = true
                                    }) {
                                        HStack(spacing: 12) {
                                            Image(systemName: "server.rack")
                                                .fableFont(size: 16)
                                                .foregroundColor(FableTheme.brandPrimary)
                                                .frame(width: 32, height: 32)
                                                .background(FableTheme.brandPrimary.opacity(0.12))
                                                .clipShape(RoundedRectangle(cornerRadius: 8))

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text("Backend Server URL")
                                                    .fableFont(size: 15, weight: .medium)
                                                    .foregroundColor(FableTheme.textPrimary)

                                                Text(currentServerURLString)
                                                    .fableFont(size: 11, design: .monospaced)
                                                    .foregroundColor(FableTheme.textMuted)
                                                    .lineLimit(1)
                                            }

                                            Spacer()

                                            Image(systemName: "pencil")
                                                .fableFont(size: 13, weight: .semibold)
                                                .foregroundColor(FableTheme.brandPrimary)
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                    }
                                }
                                .background(FableTheme.cardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .shadow(color: Color.black.opacity(0.03), radius: 6, y: 2)
                            }
                            .alert("Backend Server URL", isPresented: $isShowingServerConfig) {
                                TextField("http://192.168.1.50:8001/api/v1", text: $customServerInput)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                Button("Save & Sync") {
                                    let updated = StoryAPIService.setCustomBaseURL(customServerInput)
                                    currentServerURLString = updated.absoluteString
                                    Task { await store.syncWithCloudBackend() }
                                }
                                Button("Use Render Cloud") {
                                    let updated = StoryAPIService.setCustomBaseURL(StoryAPIService.cloudRenderBaseURLString)
                                    currentServerURLString = updated.absoluteString
                                    Task { await store.syncWithCloudBackend() }
                                }
                                Button("Reset to Bundle Default") {
                                    let updated = StoryAPIService.setCustomBaseURL(nil)
                                    currentServerURLString = updated.absoluteString
                                    Task { await store.syncWithCloudBackend() }
                                }
                                Button("Cancel", role: .cancel) {}
                            } message: {
                                Text("Enter your Fedora/Mac LAN URL (e.g. http://192.168.1.50:8001/api/v1), an HTTPS tunnel URL, or choose Render Cloud.")
                            }
                            
                            // Account & Session Section
                            VStack(alignment: .leading, spacing: 10) {
                                Text("ACCOUNT & SESSION")
                                    .fableFont(size: 11, weight: .bold)
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
                                                .fableFont(size: 15)
                                                .frame(width: 24)
                                            
                                            Text(auth.isGuestMode ? "Exit Guest Mode" : "Sign Out of Fable")
                                                .fableFont(size: 15, weight: .medium)
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
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                        auth.signOut()
                                        store.clearUserStateOnSignOut()
                                    }
                                }
                                Button("Cancel", role: .cancel) {}
                            } message: {
                                Text(auth.isGuestMode ? "You will return to the welcome screen." : "Your local reading data and drafts will remain preserved on this device.")
                            }
                            
                            // App Version Info
                            VStack(spacing: 4) {
                                Text(versionLabel)
                                    .fableFont(size: 12, weight: .medium)
                                    .foregroundColor(FableTheme.textMuted)
                                Text("Inspired by high-end independent editorial journals.")
                                    .fableFont(size: 11)
                                    .foregroundColor(FableTheme.textMuted)
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
                    .fableFont(size: 15, weight: .semibold)
                    .foregroundColor(FableTheme.brandPrimary)
                }
            }
            .sheet(isPresented: $navigateToProfile) {
                ProfileView()
                    .environmentObject(store)
                    .preferredColorScheme(store.appAppearance.colorScheme)
            }
            .sheet(isPresented: $isShowingDiagnostics) {
                SystemDiagnosticsSheet()
                    .preferredColorScheme(store.appAppearance.colorScheme)
            }
            .task {
                imageCacheSizeInBytes = await DiskImageCache.shared.diskUsageInBytes()
            }
        }
        .preferredColorScheme(store.appAppearance.colorScheme)
        .onAppear {
            store.appAppearance.applyToWindows()
        }
        .onChange(of: store.appAppearance) { _, newAppearance in
            newAppearance.applyToWindows()
        }
    }
}
