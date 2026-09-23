import SwiftUI

public struct WriteView: View {
    @EnvironmentObject var store: StoryStore
    
    @State private var isShowingPublishSheet: Bool = false
    @State private var publishedStoryToRead: Story?
    @State private var isShowingClearAlert: Bool = false
    @FocusState private var isManuscriptFocused: Bool
    
    let availableGenres = [
        "Manga", "Folklore", "Mythology", "Gothic", "Classic Fiction",
        "Classic Mystery", "Dark Fantasy", "Speculative", "Urban Legend"
    ]
    
    let availableChapters = ["Prologue", "Chapter I", "Chapter II", "Chapter III", "Chapter IV", "Epilogue"]
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                FableTheme.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Top Bar
                    HStack {
                        Button("Clear") {
                            isShowingClearAlert = true
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.red.opacity(0.85))
                        .alert("Discard Draft?", isPresented: $isShowingClearAlert) {
                            Button("Discard", role: .destructive) {
                                store.draftTitle = ""
                                store.draftSynopsis = ""
                                store.draftManuscript = ""
                            }
                            Button("Cancel", role: .cancel) {}
                        } message: {
                            Text("Are you sure you want to clear your title, synopsis, and manuscript?")
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 6) {
                            Image(systemName: "pencil.and.scribble")
                                .font(.system(size: 11))
                            Text("DRAFT MODE")
                                .font(.system(size: 11, weight: .bold))
                                .tracking(1.0)
                        }
                        .foregroundColor(FableTheme.brandPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(FableTheme.surface)
                        .clipShape(Capsule())
                        
                        Spacer()
                        
                        // Publish Button (Terracotta square with arrow up)
                        Button(action: {
                            store.publishStory()
                            isShowingPublishSheet = true
                        }) {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 42, height: 42)
                                .background(FableTheme.brandPrimary)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .shadow(color: FableTheme.brandPrimary.opacity(0.35), radius: 6, y: 3)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 18) {
                            // IDENTITY CARD
                            VStack(alignment: .leading, spacing: 14) {
                                HStack {
                                    Text("IDENTITY")
                                        .font(.system(size: 11, weight: .bold))
                                        .tracking(1.0)
                                        .foregroundColor(FableTheme.textMuted)
                                    
                                    Spacer()
                                    
                                    HStack(spacing: 4) {
                                        Circle()
                                            .fill(FableTheme.brandPrimary)
                                            .frame(width: 6, height: 6)
                                        Text("Manuscript")
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundColor(FableTheme.brandPrimary)
                                    }
                                }
                                
                                HStack(spacing: 12) {
                                    Text("Title")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(FableTheme.textMuted)
                                        .frame(width: 44, alignment: .leading)
                                    
                                    TextField("Story Title", text: $store.draftTitle)
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(FableTheme.textPrimary)
                                }
                                
                                Divider()
                                
                                HStack(spacing: 12) {
                                    Text("Genre")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(FableTheme.textMuted)
                                        .frame(width: 44, alignment: .leading)
                                    
                                    // Interactive Genre Picker Menu
                                    Menu {
                                        ForEach(availableGenres, id: \.self) { genre in
                                            Button(genre) {
                                                store.draftGenre = genre
                                            }
                                        }
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: "book.closed")
                                                .font(.system(size: 11))
                                            Text(store.draftGenre)
                                                .font(.system(size: 12, weight: .semibold))
                                            Image(systemName: "chevron.down")
                                                .font(.system(size: 9))
                                        }
                                        .foregroundColor(FableTheme.brandPrimary)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(FableTheme.surface)
                                        .clipShape(Capsule())
                                    }
                                    
                                    // Interactive Chapter Picker Menu
                                    Menu {
                                        ForEach(availableChapters, id: \.self) { chapter in
                                            Button(chapter) {
                                                store.draftChapter = chapter
                                            }
                                        }
                                    } label: {
                                        HStack(spacing: 4) {
                                            Text(store.draftChapter)
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundColor(FableTheme.textSecondary)
                                            Image(systemName: "chevron.down")
                                                .font(.system(size: 9))
                                                .foregroundColor(FableTheme.textMuted)
                                        }
                                    }
                                    
                                    Spacer()
                                }
                            }
                            .padding(18)
                            .background(FableTheme.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                            .shadow(color: Color.black.opacity(0.03), radius: 6, y: 2)
                            .padding(.horizontal, 20)
                            
                            // SYNOPSIS CARD
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("SYNOPSIS")
                                        .font(.system(size: 11, weight: .bold))
                                        .tracking(1.0)
                                        .foregroundColor(FableTheme.textMuted)
                                    
                                    Spacer()
                                    
                                    Text("Micro-prologue")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(FableTheme.textMuted)
                                }
                                
                                TextEditor(text: $store.draftSynopsis)
                                    .frame(minHeight: 75)
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundColor(FableTheme.textPrimary)
                                    .scrollContentBackground(.hidden)
                                    .lineSpacing(4)
                                
                                HStack {
                                    HStack(spacing: 4) {
                                        Image(systemName: "eye.circle")
                                            .font(.system(size: 11))
                                        Text("Previewable on Shelf")
                                            .font(.system(size: 11))
                                    }
                                    .foregroundColor(FableTheme.textMuted)
                                    
                                    Spacer()
                                    
                                    Text("\(store.draftSynopsis.count) / 200")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(FableTheme.textMuted)
                                }
                            }
                            .padding(18)
                            .background(FableTheme.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                            .shadow(color: Color.black.opacity(0.03), radius: 6, y: 2)
                            .padding(.horizontal, 20)
                            
                            // MANUSCRIPT CARD WITH FORMATTING TOOLBAR (FIGMA.md Frame 4: 1:454)
                            VStack(alignment: .leading, spacing: 14) {
                                HStack {
                                    Text("MANUSCRIPT")
                                        .font(.system(size: 11, weight: .bold))
                                        .tracking(1.0)
                                        .foregroundColor(FableTheme.textMuted)
                                    
                                    Spacer()
                                    
                                    // Formatting Toolbar
                                    HStack(spacing: 8) {
                                        Button(action: {
                                            store.draftManuscript += " **bold text** "
                                        }) {
                                            Text("B")
                                                .font(.system(size: 12, weight: .bold))
                                                .frame(width: 24, height: 24)
                                                .background(FableTheme.surface)
                                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                                .foregroundColor(FableTheme.textPrimary)
                                        }
                                        
                                        Button(action: {
                                            store.draftManuscript += " *italic text* "
                                        }) {
                                            Text("I")
                                                .font(.system(size: 12, weight: .semibold))
                                                .italic()
                                                .frame(width: 24, height: 24)
                                                .background(FableTheme.surface)
                                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                                .foregroundColor(FableTheme.textPrimary)
                                        }
                                        
                                        Button(action: {
                                            store.draftManuscript += "\n> \"A whisper in the dusk...\"\n"
                                        }) {
                                            Image(systemName: "quote.opening")
                                                .font(.system(size: 10))
                                                .frame(width: 24, height: 24)
                                                .background(FableTheme.surface)
                                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                                .foregroundColor(FableTheme.textPrimary)
                                        }
                                        
                                        Button(action: {
                                            store.draftManuscript += "\n\n* * *\n\n"
                                        }) {
                                            Image(systemName: "divide")
                                                .font(.system(size: 11))
                                                .frame(width: 24, height: 24)
                                                .background(FableTheme.surface)
                                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                                .foregroundColor(FableTheme.textPrimary)
                                        }
                                    }
                                }
                                
                                TextEditor(text: $store.draftManuscript)
                                    .frame(minHeight: 280)
                                    .font(.system(size: 16, weight: .regular))
                                    .foregroundColor(FableTheme.textPrimary)
                                    .lineSpacing(6)
                                    .scrollContentBackground(.hidden)
                                    .focused($isManuscriptFocused)
                            }
                            .padding(18)
                            .background(FableTheme.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                            .shadow(color: Color.black.opacity(0.03), radius: 6, y: 2)
                            .padding(.horizontal, 20)
                            
                            // Space for footer pill
                            Spacer().frame(height: 120)
                        }
                    }
                }
                
                // Floating Status Bar at Bottom
                HStack(spacing: 0) {
                    HStack(spacing: 6) {
                        Image(systemName: "text.alignleft")
                            .font(.system(size: 11))
                        Text("\(store.draftWordCount) words")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(FableTheme.brandPrimary)
                    .frame(maxWidth: .infinity)
                    
                    Divider().frame(height: 18)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 11))
                        Text("~\(max(1, store.draftWordCount / 150)) min read")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(FableTheme.textMuted)
                    .frame(maxWidth: .infinity)
                    
                    Divider().frame(height: 18)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "icloud.and.arrow.up")
                            .font(.system(size: 11))
                            .foregroundColor(FableTheme.brandPrimary)
                        Text("Saved")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(FableTheme.textMuted)
                    .frame(maxWidth: .infinity)
                }
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 26)
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.08), radius: 10, y: 4)
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 80) // above custom tab bar
            }
            .sheet(isPresented: $isShowingPublishSheet) {
                StoryPublishedSheet(
                    onReturnToLibrary: {
                        store.selectedTab = .library
                    },
                    onViewStory: {
                        if let first = store.stories.first {
                            publishedStoryToRead = first
                        }
                    }
                )
                .environmentObject(store)
            }
            .fullScreenCover(item: $publishedStoryToRead) { story in
                ReaderView(story: story)
                    .environmentObject(store)
            }
        }
    }
}

#Preview {
    WriteView()
        .environmentObject(StoryStore())
}
