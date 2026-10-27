import SwiftUI

public struct ProfileView: View {
    @EnvironmentObject var store: StoryStore
    @Environment(\.dismiss) var dismiss
    @ObservedObject var auth = AuthManager.shared
    
    @State private var selectedTab: String = "Published"
    @State private var selectedStoryToRead: Story?
    @State private var isShowingEditProfile: Bool = false
    @State private var isShowingSignOutAlert: Bool = false
    @State private var isShowingAuthSheet: Bool = false
    
    @State private var userName: String = ""
    @State private var userHandle: String = ""
    @State private var userBio: String = ""
    @State private var userAvatar: String? = nil
    
    let tabs = ["Published", "Saved", "Reading Stats"]
    
    public init() {}

    private var shareableProfileDetails: String {
        [userName, userHandle, userBio]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                FableTheme.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Top Navigation Bar
                    HStack {
                        Button(action: {
                            dismiss()
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(FableTheme.textPrimary)
                                .frame(width: 36, height: 36)
                                .background(FableTheme.surface)
                                .clipShape(Circle())
                        }
                        
                        Spacer()
                        
                        Text("Author Profile")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(FableTheme.textPrimary)
                        
                        Spacer()
                        
                        ShareLink(item: shareableProfileDetails, subject: Text("Fable author profile")) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(FableTheme.textPrimary)
                                .frame(width: 36, height: 36)
                                .background(FableTheme.surface)
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 20) {
                            // Avatar & Status Badge
                            VStack(spacing: 12) {
                                ProfileAvatarView(avatarName: userAvatar ?? auth.currentSession?.avatarName, name: userName, size: 96)
                                    .overlay(Circle().stroke(Color.white, lineWidth: 3))
                                    .shadow(color: Color.black.opacity(0.08), radius: 8, y: 4)
                                    .padding(.top, 8)
                                
                                // Name, Handle & Membership Badge
                                VStack(spacing: 4) {
                                    HStack(spacing: 8) {
                                        Text(userName.isEmpty ? "Author" : userName)
                                            .font(.system(size: 26, weight: .bold, design: .serif))
                                            .foregroundColor(FableTheme.textPrimary)
                                        
                                        if auth.isGuestMode {
                                            Text("GUEST")
                                                .font(.system(size: 9, weight: .heavy))
                                                .padding(.horizontal, 7)
                                                .padding(.vertical, 3)
                                                .background(FableTheme.brandPrimary.opacity(0.12))
                                                .foregroundColor(FableTheme.brandPrimary)
                                                .clipShape(Capsule())
                                        } else {
                                            Image(systemName: "checkmark.seal.fill")
                                                .font(.system(size: 14))
                                                .foregroundColor(FableTheme.brandPrimary)
                                        }
                                    }
                                    
                                    if !userHandle.isEmpty {
                                        Text(userHandle)
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(FableTheme.textMuted)
                                    }
                                    
                                    if !userBio.isEmpty {
                                        Text(userBio)
                                            .font(.system(size: 14, weight: .regular))
                                            .foregroundColor(FableTheme.textPrimary.opacity(0.85))
                                            .multilineTextAlignment(.center)
                                            .lineSpacing(4)
                                            .padding(.horizontal, 28)
                                            .padding(.top, 4)
                                    }
                                }
                            }
                            
                            // Profile Action Buttons
                            HStack(spacing: 12) {
                                Button(action: {
                                    isShowingEditProfile = true
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "pencil")
                                            .font(.system(size: 13, weight: .semibold))
                                        Text("Edit Profile")
                                            .font(.system(size: 14, weight: .semibold))
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(FableTheme.brandPrimary)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .shadow(color: FableTheme.brandPrimary.opacity(0.25), radius: 6, y: 2)
                                }
                                
                                ShareLink(item: shareableProfileDetails, subject: Text("Fable profile")) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "square.and.arrow.up")
                                            .font(.system(size: 13, weight: .semibold))
                                        Text("Share Profile")
                                            .font(.system(size: 14, weight: .semibold))
                                    }
                                    .foregroundColor(FableTheme.textPrimary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(FableTheme.surfaceVariant)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                            }
                            .padding(.horizontal, 24)
                            
                            // Guest Upgrade Callout Banner
                            if auth.isGuestMode {
                                HStack(spacing: 14) {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 20))
                                        .foregroundColor(FableTheme.brandPrimary)
                                        .frame(width: 40, height: 40)
                                        .background(FableTheme.brandPrimary.opacity(0.12))
                                        .clipShape(Circle())
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Claim Your Account")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(FableTheme.textPrimary)
                                        Text("Sync reading across devices and publish tales.")
                                            .font(.system(size: 12))
                                            .foregroundColor(FableTheme.textMuted)
                                    }
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        isShowingAuthSheet = true
                                    }) {
                                        Text("Sign In")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 8)
                                            .background(FableTheme.brandPrimary)
                                            .clipShape(Capsule())
                                    }
                                }
                                .padding(16)
                                .background(FableTheme.cardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .shadow(color: Color.black.opacity(0.03), radius: 6, y: 2)
                                .padding(.horizontal, 20)
                            }
                            
                            // Segmented Tabs
                            HStack(spacing: 0) {
                                ForEach(tabs, id: \.self) { tab in
                                    Button(action: {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                            selectedTab = tab
                                        }
                                    }) {
                                        Text(tab)
                                            .font(.system(size: 14, weight: selectedTab == tab ? .semibold : .medium))
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 10)
                                            .background(selectedTab == tab ? Color.white : Color.clear)
                                            .foregroundColor(selectedTab == tab ? FableTheme.textPrimary : FableTheme.textMuted)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                            .shadow(color: selectedTab == tab ? Color.black.opacity(0.06) : Color.clear, radius: 4, y: 1)
                                    }
                                }
                            }
                            .padding(4)
                            .background(FableTheme.surfaceVariant)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal, 20)
                            .padding(.top, 4)
                            
                            // Tab Content
                            if selectedTab == "Published" {
                                if store.profileStories.isEmpty {
                                    VStack(spacing: 12) {
                                        Image(systemName: "pencil.and.outline")
                                            .font(.system(size: 32))
                                            .foregroundColor(FableTheme.textMuted.opacity(0.5))
                                        
                                        Text("No published stories")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(FableTheme.textPrimary)
                                        
                                        Text("When you publish a story from the Write tab, it will appear here for readers.")
                                            .font(.system(size: 13))
                                            .foregroundColor(FableTheme.textMuted)
                                            .multilineTextAlignment(.center)
                                            .padding(.horizontal, 32)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 40)
                                } else {
                                    VStack(spacing: 12) {
                                        ForEach(store.profileStories) { story in
                                            Button(action: {
                                                selectedStoryToRead = story
                                            }) {
                                                HStack(spacing: 14) {
                                                    FableImageView(name: story.effectiveCoverImage, placeholderIcon: "book")
                                                        .frame(width: 54, height: 68)
                                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                                        .shadow(color: Color.black.opacity(0.06), radius: 3, y: 1)
                                                    
                                                    VStack(alignment: .leading, spacing: 4) {
                                                        Text(story.title)
                                                            .font(.system(size: 15, weight: .bold, design: .serif))
                                                            .foregroundColor(FableTheme.textPrimary)
                                                        
                                                        Text("\(story.genre.rawValue) • \(story.readingTimeMinutes)m read")
                                                            .font(.system(size: 12))
                                                            .foregroundColor(FableTheme.textMuted)
                                                        
                                                        HStack(spacing: 8) {
                                                            if let rating = story.rating {
                                                                Text("★ \(rating, specifier: "%.1f")")
                                                                    .font(.system(size: 11, weight: .semibold))
                                                                    .foregroundColor(.orange)
                                                            }
                                                            Text("• \(story.readsCount) reads")
                                                                .font(.system(size: 11))
                                                                .foregroundColor(FableTheme.textMuted)
                                                        }
                                                    }
                                                    
                                                    Spacer()
                                                    
                                                    Image(systemName: "chevron.right")
                                                        .font(.system(size: 12))
                                                        .foregroundColor(FableTheme.textMuted)
                                                }
                                                .padding(14)
                                                .background(FableTheme.cardBackground)
                                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                                .shadow(color: Color.black.opacity(0.03), radius: 6, y: 2)
                                                .padding(.horizontal, 20)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                            } else if selectedTab == "Saved" {
                                let saved = store.stories.filter { $0.isBookmarked }
                                if saved.isEmpty {
                                    VStack(spacing: 12) {
                                        Image(systemName: "bookmark")
                                            .font(.system(size: 32))
                                            .foregroundColor(FableTheme.textMuted.opacity(0.5))
                                        
                                        Text("No saved stories")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(FableTheme.textPrimary)
                                        
                                        Text("Bookmark stories in the library to easily revisit them later.")
                                            .font(.system(size: 13))
                                            .foregroundColor(FableTheme.textMuted)
                                            .multilineTextAlignment(.center)
                                            .padding(.horizontal, 32)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 40)
                                } else {
                                    VStack(spacing: 12) {
                                        ForEach(saved) { story in
                                            Button(action: {
                                                selectedStoryToRead = story
                                            }) {
                                                HStack(spacing: 14) {
                                                    FableImageView(name: story.effectiveCoverImage, placeholderIcon: "bookmark.fill")
                                                        .frame(width: 54, height: 68)
                                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                                        .shadow(color: Color.black.opacity(0.06), radius: 3, y: 1)
                                                    
                                                    VStack(alignment: .leading, spacing: 4) {
                                                        Text(story.title)
                                                            .font(.system(size: 15, weight: .bold, design: .serif))
                                                            .foregroundColor(FableTheme.textPrimary)
                                                        Text(story.author)
                                                            .font(.system(size: 12))
                                                            .foregroundColor(FableTheme.textMuted)
                                                    }
                                                    
                                                    Spacer()
                                                    
                                                    Image(systemName: "bookmark.fill")
                                                        .foregroundColor(FableTheme.brandPrimary)
                                                }
                                                .padding(14)
                                                .background(FableTheme.cardBackground)
                                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                                .shadow(color: Color.black.opacity(0.03), radius: 6, y: 2)
                                                .padding(.horizontal, 20)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                            } else {
                                // Reading Stats Tab
                                VStack(alignment: .leading, spacing: 14) {
                                    HStack(spacing: 16) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Total Reading")
                                                .font(.system(size: 12, weight: .medium))
                                                .foregroundColor(FableTheme.textMuted)
                                            let hours = Double(store.readingStats.totalMinutesRead) / 60.0
                                            Text(String(format: "%.1f hrs", hours))
                                                .font(.system(size: 24, weight: .bold))
                                                .monospacedDigit()
                                                .foregroundColor(FableTheme.brandPrimary)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(16)
                                        .background(FableTheme.cardBackground)
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                        .shadow(color: Color.black.opacity(0.03), radius: 6, y: 2)
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Stories Finished")
                                                .font(.system(size: 12, weight: .medium))
                                                .foregroundColor(FableTheme.textMuted)
                                            Text("\(store.readingStats.storiesReadCount)")
                                                .font(.system(size: 24, weight: .bold))
                                                .monospacedDigit()
                                                .foregroundColor(FableTheme.brandPrimary)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(16)
                                        .background(FableTheme.cardBackground)
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                        .shadow(color: Color.black.opacity(0.03), radius: 6, y: 2)
                                    }
                                    .padding(.horizontal, 20)
                                }
                            }
                            
                            // Account & Session Section (First-Class Sign Out)
                            VStack(alignment: .leading, spacing: 10) {
                                Text("ACCOUNT & SESSION")
                                    .font(.system(size: 11, weight: .bold))
                                    .tracking(1.0)
                                    .foregroundColor(FableTheme.textMuted)
                                    .padding(.leading, 4)
                                
                                VStack(spacing: 0) {
                                    HStack(spacing: 14) {
                                        Image(systemName: auth.isGuestMode ? "person.crop.circle.badge.questionmark" : "checkmark.shield.fill")
                                            .font(.system(size: 16))
                                            .foregroundColor(auth.isGuestMode ? .orange : FableTheme.brandPrimary)
                                            .frame(width: 32, height: 32)
                                            .background((auth.isGuestMode ? Color.orange : FableTheme.brandPrimary).opacity(0.12))
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(auth.isGuestMode ? "Guest Profile" : "Authenticated Member")
                                                .font(.system(size: 15, weight: .medium))
                                                .foregroundColor(FableTheme.textPrimary)
                                            
                                            Text(auth.isGuestMode ? "Local session preserved on device" : (auth.currentSession?.email ?? "Cloud Synced"))
                                                .font(.system(size: 12))
                                                .foregroundColor(FableTheme.textMuted)
                                        }
                                        
                                        Spacer()
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    
                                    Divider().padding(.leading, 62)
                                    
                                    // Sign Out / Exit Guest Mode Button
                                    Button(action: {
                                        isShowingSignOutAlert = true
                                    }) {
                                        HStack(spacing: 12) {
                                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                                .foregroundColor(.red.opacity(0.9))
                                                .font(.system(size: 15))
                                                .frame(width: 32, height: 32)
                                            
                                            Text(auth.isGuestMode ? "Exit Guest Mode" : "Sign Out of Fable")
                                                .font(.system(size: 15, weight: .medium))
                                                .foregroundColor(.red.opacity(0.95))
                                            
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
                            .padding(.horizontal, 20)
                            .padding(.top, 10)
                            
                            Spacer().frame(height: 40)
                        }
                    }
                }
            }
            .fullScreenCover(item: $selectedStoryToRead) { story in
                ReaderView(story: story)
                    .environmentObject(store)
            }
            .sheet(isPresented: $isShowingEditProfile) {
                EditProfileSheet(
                    currentName: userName,
                    currentHandle: userHandle,
                    currentBio: userBio,
                    currentAvatar: userAvatar ?? auth.currentSession?.avatarName
                ) { newName, newHandle, newBio, newAvatar in
                    self.userName = newName
                    self.userHandle = newHandle
                    self.userBio = newBio
                    self.userAvatar = newAvatar
                }
            }
            .sheet(isPresented: $isShowingAuthSheet) {
                NavigationStack {
                    SignInView()
                }
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
                Text(auth.isGuestMode ? "You will return to the welcome screen." : "Your local reading data and drafts will remain safely preserved.")
            }
            .task(id: auth.currentSession?.id) {
                await store.loadMyPublishedStories()
            }
            .onAppear {
                store.reloadReadingStats()
                if let session = auth.currentSession {
                    self.userName = session.name
                    self.userHandle = session.handle
                    self.userBio = session.bio
                    self.userAvatar = session.avatarName
                }
            }
        }
    }
}

// MARK: - Profile Avatar Subview
public struct ProfileAvatarView: View {
    public let avatarName: String?
    public let name: String
    public let size: CGFloat
    
    public init(avatarName: String?, name: String, size: CGFloat) {
        self.avatarName = avatarName
        self.name = name
        self.size = size
    }
    
    public var body: some View {
        if let avatarName, !avatarName.isEmpty {
            if avatarName.starts(with: "http") {
                FableImageView(name: avatarName, placeholderIcon: "person.crop.circle.fill")
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                // SF Symbol Preset
                let symbol = avatarName.starts(with: "sf:") ? String(avatarName.dropFirst(3)) : avatarName
                ZStack {
                    LinearGradient(
                        colors: [FableTheme.brandPrimary, FableTheme.brandPrimary.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Image(systemName: symbol)
                        .font(.system(size: size * 0.44, weight: .semibold))
                        .foregroundColor(.white)
                }
                .frame(width: size, height: size)
                .clipShape(Circle())
            }
        } else {
            FableImageView(name: nil, title: name, placeholderIcon: "person.crop.circle.fill")
                .frame(width: size, height: size)
                .clipShape(Circle())
        }
    }
}

// MARK: - Isolated Edit Profile Sheet
struct EditProfileSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var auth = AuthManager.shared
    
    @State private var draftName: String
    @State private var draftHandle: String
    @State private var draftBio: String
    @State private var selectedAvatar: String
    @State private var isSaving: Bool = false
    @State private var errorMessage: String?
    
    let onSaved: (String, String, String, String) -> Void
    
    let avatarPresets: [String] = [
        "person.crop.circle.fill",
        "sparkles",
        "book.closed.fill",
        "pencil.and.outline",
        "wand.and.stars",
        "flame.fill",
        "moon.stars.fill",
        "feather"
    ]
    
    init(currentName: String, currentHandle: String, currentBio: String, currentAvatar: String?, onSaved: @escaping (String, String, String, String) -> Void) {
        _draftName = State(initialValue: currentName)
        let rawHandle = currentHandle.hasPrefix("@") ? String(currentHandle.dropFirst()) : currentHandle
        _draftHandle = State(initialValue: rawHandle)
        _draftBio = State(initialValue: currentBio)
        _selectedAvatar = State(initialValue: currentAvatar ?? "person.crop.circle.fill")
        self.onSaved = onSaved
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Avatar Picker Section
                Section("Author Glyph") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 14) {
                            ForEach(avatarPresets, id: \.self) { symbol in
                                Button(action: {
                                    FableHaptics.selection()
                                    selectedAvatar = symbol
                                }) {
                                    ZStack {
                                        Circle()
                                            .fill(selectedAvatar == symbol ? FableTheme.brandPrimary : FableTheme.surfaceVariant)
                                            .frame(width: 48, height: 48)
                                        
                                        Image(systemName: symbol)
                                            .font(.system(size: 20))
                                            .foregroundColor(selectedAvatar == symbol ? .white : FableTheme.textPrimary)
                                    }
                                    .overlay(
                                        Circle()
                                            .stroke(selectedAvatar == symbol ? FableTheme.brandPrimary : Color.clear, lineWidth: 2)
                                            .padding(-2)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                Section("Author Details") {
                    TextField("Full Name or Pen Name", text: $draftName)
                        .autocorrectionDisabled()
                    
                    HStack(spacing: 2) {
                        Text("@")
                            .foregroundColor(FableTheme.textMuted)
                        TextField("handle", text: $draftHandle)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                    }
                }
                
                Section("Biography") {
                    TextField("Tell readers about your stories...", text: $draftBio, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.system(size: 13))
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(FableTheme.textMuted)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isSaving ? "Saving…" : "Save") {
                        saveProfile()
                    }
                    .disabled(isSaving || draftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(FableTheme.brandPrimary)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
    
    private func saveProfile() {
        isSaving = true
        errorMessage = nil
        Task {
            let cleanHandle = draftHandle.trimmingCharacters(in: .whitespacesAndNewlines)
            let formattedHandle = cleanHandle.isEmpty ? "" : (cleanHandle.hasPrefix("@") ? cleanHandle : "@\(cleanHandle)")
            
            let success = await auth.updateProfile(
                name: draftName,
                handle: formattedHandle,
                bio: draftBio,
                avatarName: selectedAvatar
            )
            isSaving = false
            if success {
                FableHaptics.success()
                onSaved(draftName, formattedHandle, draftBio, selectedAvatar)
                dismiss()
            } else {
                errorMessage = auth.authErrorMessage ?? "Unable to update profile. Please check connection."
            }
        }
    }
}
