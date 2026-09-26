import SwiftUI

public struct ProfileView: View {
    @EnvironmentObject var store: StoryStore
    @Environment(\.dismiss) var dismiss
    @ObservedObject var auth = AuthManager.shared
    
    @State private var selectedTab: String = "Published"
    @State private var selectedStoryToRead: Story?
    @State private var isShowingEditProfile: Bool = false
    
    @State private var userName: String = ""
    @State private var userHandle: String = ""
    @State private var userBio: String = ""
    
    let tabs = ["Published", "Saved", "Reading Stats"]
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ZStack {
                FableTheme.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Top Nav Bar
                    HStack {
                        Button(action: {
                            dismiss()
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(FableTheme.textPrimary)
                                .padding(8)
                                .background(Color.white)
                                .clipShape(Circle())
                        }
                        
                        Spacer()
                        
                        Text("Profile")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(FableTheme.textPrimary)
                        
                        Spacer()
                        
                        // Native Share Profile
                        ShareLink(item: "Check out \(userName)'s profile on Fable.") {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 15))
                                .foregroundColor(FableTheme.textPrimary)
                                .padding(8)
                                .background(Color.white)
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 20) {
                            // Avatar with Edit Badge
                            ZStack(alignment: .bottomTrailing) {
                                FableImageView(name: auth.currentSession?.avatarName, placeholderIcon: "person.crop.circle.fill")
                                    .frame(width: 96, height: 96)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(Color.white, lineWidth: 3))
                                    .shadow(color: Color.black.opacity(0.08), radius: 6, y: 3)
                                
                                Button(action: {
                                    isShowingEditProfile = true
                                }) {
                                    Image(systemName: "pencil")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(width: 26, height: 26)
                                        .background(FableTheme.brandPrimary)
                                        .clipShape(Circle())
                                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                                }
                            }
                            .padding(.top, 8)
                            
                            // Name & Bio
                            VStack(spacing: 6) {
                                HStack(spacing: 6) {
                                    Text(userName)
                                        .font(.system(size: 24, weight: .black))
                                        .foregroundColor(FableTheme.textPrimary)
                                    
                                }
                                
                                Text(userHandle)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(FableTheme.textMuted)
                                
                                Text(userBio)
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundColor(FableTheme.textPrimary.opacity(0.85))
                                    .multilineTextAlignment(.center)
                                    .lineSpacing(4)
                                    .padding(.horizontal, 32)
                                    .padding(.top, 4)
                            }
                            
                            // Action Buttons
                            HStack(spacing: 12) {
                                Button(action: {
                                    isShowingEditProfile = true
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "slider.horizontal.2.square")
                                            .font(.system(size: 13))
                                        Text("Edit Profile")
                                            .font(.system(size: 14, weight: .semibold))
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(FableTheme.brandPrimary)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                
                                ShareLink(item: "Check out \(userName)'s profile on Fable.") {
                                    HStack(spacing: 6) {
                                        Image(systemName: "square.and.arrow.up")
                                            .font(.system(size: 13))
                                        Text("Share")
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
                            
                            // Segmented Picker
                            HStack(spacing: 0) {
                                ForEach(tabs, id: \.self) { tab in
                                    Button(action: {
                                        withAnimation {
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
                            .padding(.top, 6)
                            
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
                                        
                                        Text("When you publish a story, it will appear here for everyone to read.")
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
                                                
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text(story.title)
                                                        .font(.system(size: 15, weight: .bold))
                                                        .foregroundColor(FableTheme.textPrimary)
                                                    
                                                    Text("\(story.genre.rawValue) • \(story.readingTimeMinutes)m read")
                                                        .font(.system(size: 12))
                                                        .foregroundColor(FableTheme.textMuted)
                                                    
                                                    HStack(spacing: 8) {
                                                        Text("★ 4.9")
                                                            .font(.system(size: 11, weight: .semibold))
                                                            .foregroundColor(.orange)
                                                        Text("• 1.2k reads")
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
                                        
                                        Text("Bookmark stories to easily find them later.")
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
                                                
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text(story.title)
                                                        .font(.system(size: 15, weight: .bold))
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
                                                .font(.system(size: 12))
                                                .foregroundColor(FableTheme.textMuted)
                                            let hours = Double(store.readingStats.totalMinutesRead) / 60.0
                                            Text(String(format: "%.1f hrs", hours))
                                                .font(.system(size: 22, weight: .black))
                                                .foregroundColor(FableTheme.brandPrimary)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(16)
                                        .background(FableTheme.cardBackground)
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Stories Finished")
                                                .font(.system(size: 12))
                                                .foregroundColor(FableTheme.textMuted)
                                            Text("\(store.readingStats.storiesReadCount)")
                                                .font(.system(size: 22, weight: .black))
                                                .foregroundColor(FableTheme.brandPrimary)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(16)
                                        .background(FableTheme.cardBackground)
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                    }
                                    .padding(.horizontal, 20)
                                }
                            }
                            
                            Spacer().frame(height: 30)
                        }
                    }
                }
            }
            .fullScreenCover(item: $selectedStoryToRead) { story in
                ReaderView(story: story)
                    .environmentObject(store)
            }
            .sheet(isPresented: $isShowingEditProfile) {
                NavigationStack {
                    Form {
                        Section("Display Name") {
                            TextField("Name", text: $userName)
                        }
                        Section("Handle") {
                            TextField("Handle", text: $userHandle)
                        }
                        Section("Biography") {
                            TextField("Bio", text: $userBio, axis: .vertical)
                                .lineLimit(3...6)
                        }
                    }
                    .navigationTitle("Edit Profile")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Save") {
                                auth.updateProfile(
                                    name: userName,
                                    handle: userHandle,
                                    bio: userBio
                                )
                                isShowingEditProfile = false
                            }
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(FableTheme.brandPrimary)
                        }
                    }
                }
                .presentationDetents([.medium])
            }
            .onAppear {
                store.reloadReadingStats()
                if let session = auth.currentSession {
                    self.userName = session.name
                    self.userHandle = session.handle
                    self.userBio = session.bio
                }
            }
        }
    }
}
