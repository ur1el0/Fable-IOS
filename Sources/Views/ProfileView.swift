import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var store: StoryStore
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedTab: String = "Published"
    @State private var selectedStoryToRead: Story?
    
    var body: some View {
        ZStack {
            FableTheme.warmCream.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top Nav Bar
                HStack {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(FableTheme.deepCharcoal)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Avatar with Edit Badge
                        ZStack(alignment: .bottomTrailing) {
                            if let avatar = UIImage(named: "avatar_roosc") {
                                Image(uiImage: avatar)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 96, height: 96)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(Color.white, lineWidth: 3))
                                    .shadow(color: Color.black.opacity(0.08), radius: 6, y: 3)
                            } else {
                                Circle()
                                    .fill(FableTheme.softPeach)
                                    .frame(width: 96, height: 96)
                            }
                            
                            Button(action: {}) {
                                Image(systemName: "pencil")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 26, height: 26)
                                    .background(FableTheme.terracotta)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                            }
                        }
                        
                        // Name & Bio
                        VStack(spacing: 6) {
                            HStack(spacing: 6) {
                                Text("Roosc Zaño")
                                    .font(.system(size: 24, weight: .bold, design: .serif))
                                    .foregroundColor(FableTheme.deepCharcoal)
                                
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(FableTheme.terracotta)
                            }
                            
                            Text("@zanoroosc")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(FableTheme.subtleSlate)
                            
                            Text("Writer of quiet lore, archivist of dusk folklore, and collector of vintage horology tales. Author of 14 published stories.")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(FableTheme.deepCharcoal.opacity(0.85))
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                                .padding(.horizontal, 32)
                                .padding(.top, 4)
                        }
                        
                        // Action Buttons
                        HStack(spacing: 12) {
                            Button(action: {}) {
                                HStack(spacing: 6) {
                                    Image(systemName: "slider.horizontal.2.square")
                                        .font(.system(size: 13))
                                    Text("Edit Profile")
                                        .font(.system(size: 14, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(FableTheme.terracotta)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            
                            Button(action: {}) {
                                HStack(spacing: 6) {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.system(size: 13))
                                    Text("Share Profile")
                                        .font(.system(size: 14, weight: .semibold))
                                }
                                .foregroundColor(FableTheme.deepCharcoal)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.gray.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // Stats Card
                        HStack(spacing: 0) {
                            VStack(spacing: 4) {
                                Text("\(14 + (store.profileStories.count > 3 ? 1 : 0))")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(FableTheme.deepCharcoal)
                                Text("Stories")
                                    .font(.system(size: 12))
                                    .foregroundColor(FableTheme.subtleSlate)
                            }
                            .frame(maxWidth: .infinity)
                            
                            Divider()
                                .frame(height: 28)
                            
                            VStack(spacing: 4) {
                                Text("4.9k")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(FableTheme.deepCharcoal)
                                Text("Reads")
                                    .font(.system(size: 12))
                                    .foregroundColor(FableTheme.subtleSlate)
                            }
                            .frame(maxWidth: .infinity)
                            
                            Divider()
                                .frame(height: 28)
                            
                            VStack(spacing: 4) {
                                Text("890")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(FableTheme.deepCharcoal)
                                Text("Followers")
                                    .font(.system(size: 12))
                                    .foregroundColor(FableTheme.subtleSlate)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .padding(.vertical, 16)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: Color.black.opacity(0.04), radius: 6, y: 2)
                        .padding(.horizontal, 20)
                        
                        // Tabs Picker: Published / Reading Lists
                        HStack(spacing: 0) {
                            Button(action: { selectedTab = "Published" }) {
                                Text("Published")
                                    .font(.system(size: 14, weight: selectedTab == "Published" ? .semibold : .medium))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(selectedTab == "Published" ? Color.white : Color.clear)
                                    .foregroundColor(selectedTab == "Published" ? FableTheme.deepCharcoal : FableTheme.subtleSlate)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .shadow(color: selectedTab == "Published" ? Color.black.opacity(0.06) : Color.clear, radius: 4, y: 1)
                            }
                            
                            Button(action: { selectedTab = "Reading Lists" }) {
                                Text("Reading Lists")
                                    .font(.system(size: 14, weight: selectedTab == "Reading Lists" ? .semibold : .medium))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(selectedTab == "Reading Lists" ? Color.white : Color.clear)
                                    .foregroundColor(selectedTab == "Reading Lists" ? FableTheme.deepCharcoal : FableTheme.subtleSlate)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .shadow(color: selectedTab == "Reading Lists" ? Color.black.opacity(0.06) : Color.clear, radius: 4, y: 1)
                            }
                        }
                        .padding(4)
                        .background(Color.gray.opacity(0.09))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 20)
                        
                        // Published Stories List
                        VStack(spacing: 14) {
                            ForEach(store.profileStories) { story in
                                Button(action: {
                                    selectedStoryToRead = story
                                }) {
                                    HStack(alignment: .top, spacing: 14) {
                                        VStack(alignment: .leading, spacing: 6) {
                                            if let badge = story.badgeText {
                                                Text(badge)
                                                    .font(.system(size: 10, weight: .bold))
                                                    .tracking(0.8)
                                                    .foregroundColor(FableTheme.terracotta)
                                            }
                                            
                                            Text(story.title)
                                                .font(.system(size: 17, weight: .bold, design: .serif))
                                                .foregroundColor(FableTheme.deepCharcoal)
                                            
                                            Text(story.excerpt)
                                                .font(.system(size: 13, weight: .regular, design: .serif))
                                                .foregroundColor(FableTheme.deepCharcoal.opacity(0.75))
                                                .lineLimit(2)
                                            
                                            HStack(spacing: 12) {
                                                HStack(spacing: 3) {
                                                    Image(systemName: "star.fill")
                                                        .font(.system(size: 9))
                                                        .foregroundColor(.yellow)
                                                    Text(String(format: "%.1f", story.rating))
                                                        .font(.system(size: 11, weight: .semibold))
                                                        .foregroundColor(FableTheme.deepCharcoal)
                                                }
                                                
                                                HStack(spacing: 3) {
                                                    Image(systemName: "eye")
                                                        .font(.system(size: 9))
                                                    Text(story.readsCount)
                                                        .font(.system(size: 11))
                                                }
                                                .foregroundColor(FableTheme.subtleSlate)
                                                
                                                Spacer()
                                                
                                                Image(systemName: "chart.line.uptrend.xyaxis")
                                                    .font(.system(size: 11))
                                                    .foregroundColor(FableTheme.subtleSlate)
                                                
                                                Image(systemName: "ellipsis")
                                                    .font(.system(size: 11))
                                                    .foregroundColor(FableTheme.subtleSlate)
                                            }
                                            .padding(.top, 4)
                                        }
                                        
                                        if let cover = story.coverImageName, let img = UIImage(named: cover) {
                                            Image(uiImage: img)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 76, height: 76)
                                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                        }
                                    }
                                    .padding(16)
                                    .background(Color.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                    .shadow(color: Color.black.opacity(0.03), radius: 6, y: 2)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                    }
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .fullScreenCover(item: $selectedStoryToRead) { story in
            ReaderView(story: story)
                .environmentObject(store)
        }
    }
}
