import SwiftUI

struct ShelfView: View {
    @EnvironmentObject var store: StoryStore
    
    @State private var selectedTab: String = "Saved"
    @State private var selectedStoryToRead: Story?
    @State private var isShowingSettingsSheet: Bool = false
    
    let tabs = ["Saved", "Finished", "My Drafts"]
    
    var activeStories: [Story] {
        store.stories.filter { $0.isSaved }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                FableTheme.warmCream.ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        // Brand Logo Header
                        HStack(spacing: 8) {
                            Image(systemName: "book.pages.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                                .padding(7)
                                .background(FableTheme.terracotta)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            
                            Text("Fable")
                                .font(.system(size: 20, weight: .bold, design: .serif))
                                .foregroundColor(FableTheme.deepCharcoal)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        
                        // Title Row with Stats & Settings
                        HStack {
                            Text("My Shelf")
                                .font(.system(size: 34, weight: .bold, design: .serif))
                                .foregroundColor(FableTheme.deepCharcoal)
                            
                            Spacer()
                            
                            HStack(spacing: 16) {
                                Button(action: {}) {
                                    Image(systemName: "chart.line.uptrend.xyaxis")
                                        .font(.system(size: 18))
                                        .foregroundColor(FableTheme.terracotta)
                                }
                                
                                Button(action: {
                                    isShowingSettingsSheet = true
                                }) {
                                    Image(systemName: "gearshape")
                                        .font(.system(size: 18))
                                        .foregroundColor(FableTheme.deepCharcoal)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        
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
                                        .foregroundColor(selectedTab == tab ? FableTheme.deepCharcoal : FableTheme.subtleSlate)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                        .shadow(color: selectedTab == tab ? Color.black.opacity(0.06) : Color.clear, radius: 4, y: 1)
                                }
                            }
                        }
                        .padding(4)
                        .background(Color.gray.opacity(0.09))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 20)
                        
                        // ACTIVE STORIES Section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("ACTIVE STORIES (\(activeStories.count))")
                                    .font(.system(size: 11, weight: .bold))
                                    .tracking(1.0)
                                    .foregroundColor(FableTheme.subtleSlate)
                                
                                Spacer()
                                
                                Button(action: {}) {
                                    HStack(spacing: 4) {
                                        Text("Filter")
                                            .font(.system(size: 12, weight: .semibold))
                                        Image(systemName: "slider.horizontal.3")
                                            .font(.system(size: 11))
                                    }
                                    .foregroundColor(FableTheme.terracotta)
                                }
                            }
                            
                            // Container Card for Active Stories
                            VStack(spacing: 0) {
                                ForEach(Array(activeStories.enumerated()), id: \.element.id) { index, story in
                                    Button(action: {
                                        selectedStoryToRead = story
                                    }) {
                                        HStack(alignment: .center, spacing: 14) {
                                            VStack(alignment: .leading, spacing: 4) {
                                                HStack(spacing: 4) {
                                                    Circle()
                                                        .fill(FableTheme.terracotta)
                                                        .frame(width: 5, height: 5)
                                                    Text("Reading • \(story.readingTimeMinutes)m left")
                                                        .font(.system(size: 11, weight: .medium))
                                                        .foregroundColor(FableTheme.subtleSlate)
                                                }
                                                
                                                Text(story.title)
                                                    .font(.system(size: 17, weight: .bold, design: .serif))
                                                    .foregroundColor(FableTheme.deepCharcoal)
                                                    .lineLimit(1)
                                                
                                                Text(story.author)
                                                    .font(.system(size: 13))
                                                    .foregroundColor(FableTheme.subtleSlate)
                                            }
                                            
                                            Spacer()
                                            
                                            // Circular Progress Ring with Percentage
                                            ZStack {
                                                Circle()
                                                    .stroke(Color.gray.opacity(0.15), lineWidth: 3)
                                                    .frame(width: 38, height: 38)
                                                
                                                Circle()
                                                    .trim(from: 0, to: CGFloat(story.progressPercent) / 100.0)
                                                    .stroke(FableTheme.terracotta, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                                                    .rotationEffect(.degrees(-90))
                                                    .frame(width: 38, height: 38)
                                                
                                                Text("\(story.progressPercent)%")
                                                    .font(.system(size: 10, weight: .bold))
                                                    .foregroundColor(FableTheme.terracotta)
                                            }
                                            
                                            Button(action: {}) {
                                                Image(systemName: "ellipsis")
                                                    .font(.system(size: 14))
                                                    .foregroundColor(FableTheme.subtleSlate)
                                                    .padding(6)
                                            }
                                        }
                                        .padding(.horizontal, 18)
                                        .padding(.vertical, 16)
                                    }
                                    .buttonStyle(.plain)
                                    
                                    if index < activeStories.count - 1 {
                                        Divider()
                                            .padding(.horizontal, 18)
                                    }
                                }
                            }
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                            .shadow(color: Color.black.opacity(0.04), radius: 8, y: 2)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 4)
                        .padding(.bottom, 90) // spacing for custom tab bar
                    }
                }
            }
            .fullScreenCover(item: $selectedStoryToRead) { story in
                ReaderView(story: story)
                    .environmentObject(store)
            }
            .sheet(isPresented: $isShowingSettingsSheet) {
                SettingsView()
                    .environmentObject(store)
            }
        }
    }
}
