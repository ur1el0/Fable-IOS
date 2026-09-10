import SwiftUI

struct WriteView: View {
    @EnvironmentObject var store: StoryStore
    
    @State private var isShowingPublishSheet: Bool = false
    @State private var publishedStoryToRead: Story?
    @FocusState private var isManuscriptFocused: Bool
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                FableTheme.warmCream.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Top Bar
                    HStack {
                        Button("Clear") {
                            withAnimation {
                                store.draftTitle = ""
                                store.draftSynopsis = ""
                                store.draftManuscript = ""
                            }
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.red.opacity(0.85))
                        
                        Spacer()
                        
                        HStack(spacing: 6) {
                            Image(systemName: "feather")
                                .font(.system(size: 11))
                            Text("DRAFT MODE")
                                .font(.system(size: 11, weight: .bold))
                                .tracking(1.0)
                        }
                        .foregroundColor(FableTheme.terracotta)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(FableTheme.softPeach)
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
                                .background(FableTheme.terracotta)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .shadow(color: FableTheme.terracotta.opacity(0.35), radius: 6, y: 3)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 20) {
                            // IDENTITY CARD
                            VStack(alignment: .leading, spacing: 14) {
                                HStack {
                                    Text("IDENTITY")
                                        .font(.system(size: 11, weight: .bold))
                                        .tracking(1.0)
                                        .foregroundColor(FableTheme.subtleSlate)
                                    
                                    Spacer()
                                    
                                    HStack(spacing: 4) {
                                        Circle()
                                            .fill(FableTheme.terracotta)
                                            .frame(width: 5, height: 5)
                                        Text("Manuscript")
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundColor(FableTheme.terracotta)
                                    }
                                }
                                
                                HStack(spacing: 12) {
                                    Text("Title")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(FableTheme.subtleSlate)
                                        .frame(width: 44, alignment: .leading)
                                    
                                    TextField("Story Title", text: $store.draftTitle)
                                        .font(.system(size: 20, weight: .bold, design: .serif))
                                        .foregroundColor(FableTheme.deepCharcoal)
                                }
                                
                                Divider()
                                
                                HStack(spacing: 12) {
                                    Text("Genre")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(FableTheme.subtleSlate)
                                        .frame(width: 44, alignment: .leading)
                                    
                                    HStack(spacing: 6) {
                                        Image(systemName: "book.closed")
                                            .font(.system(size: 11))
                                        Text(store.draftGenre)
                                            .font(.system(size: 12, weight: .semibold))
                                    }
                                    .foregroundColor(FableTheme.terracotta)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(FableTheme.softPeach)
                                    .clipShape(Capsule())
                                    
                                    Text(store.draftChapter)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(FableTheme.subtleSlate)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(Color.gray.opacity(0.4))
                                }
                            }
                            .padding(18)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                            .shadow(color: Color.black.opacity(0.03), radius: 6, y: 2)
                            .padding(.horizontal, 20)
                            
                            // SYNOPSIS CARD
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("SYNOPSIS")
                                        .font(.system(size: 11, weight: .bold))
                                        .tracking(1.0)
                                        .foregroundColor(FableTheme.subtleSlate)
                                    
                                    Spacer()
                                    
                                    Text("Micro-prologue")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(FableTheme.subtleSlate)
                                }
                                
                                TextEditor(text: $store.draftSynopsis)
                                    .frame(minHeight: 75)
                                    .font(.system(size: 14, weight: .regular, design: .serif))
                                    .foregroundColor(FableTheme.deepCharcoal)
                                    .scrollContentBackground(.hidden)
                                    .lineSpacing(4)
                                
                                HStack {
                                    HStack(spacing: 4) {
                                        Image(systemName: "eye.circle")
                                            .font(.system(size: 11))
                                        Text("Card preview previewable on Shelf")
                                            .font(.system(size: 11))
                                    }
                                    .foregroundColor(FableTheme.subtleSlate)
                                    
                                    Spacer()
                                    
                                    Text("\(store.draftSynopsis.count) / 200")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(FableTheme.subtleSlate)
                                }
                            }
                            .padding(18)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                            .shadow(color: Color.black.opacity(0.03), radius: 6, y: 2)
                            .padding(.horizontal, 20)
                            
                            // MANUSCRIPT CARD
                            VStack(alignment: .leading, spacing: 14) {
                                HStack {
                                    Text("MANUSCRIPT")
                                        .font(.system(size: 11, weight: .bold))
                                        .tracking(1.0)
                                        .foregroundColor(FableTheme.subtleSlate)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "book.pages")
                                        .font(.system(size: 13))
                                        .foregroundColor(FableTheme.terracotta)
                                }
                                
                                TextEditor(text: $store.draftManuscript)
                                    .frame(minHeight: 320)
                                    .font(.system(size: 16, weight: .regular, design: .serif))
                                    .foregroundColor(FableTheme.deepCharcoal)
                                    .lineSpacing(6)
                                    .scrollContentBackground(.hidden)
                                    .focused($isManuscriptFocused)
                                
                                // Pagination dots
                                HStack(spacing: 6) {
                                    Circle().fill(FableTheme.terracotta).frame(width: 5, height: 5)
                                    Circle().fill(Color.gray.opacity(0.3)).frame(width: 5, height: 5)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 4)
                            }
                            .padding(18)
                            .background(Color.white)
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
                        Text("\(store.draftWordCount) / 500 words")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(FableTheme.terracotta)
                    .frame(maxWidth: .infinity)
                    
                    Divider().frame(height: 18)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 11))
                        Text("~\(max(1, store.draftWordCount / 150)) min fable")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(FableTheme.subtleSlate)
                    .frame(maxWidth: .infinity)
                    
                    Divider().frame(height: 18)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "icloud.and.arrow.up")
                            .font(.system(size: 11))
                            .foregroundColor(FableTheme.terracotta)
                        Text("Saved 2m ago")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(FableTheme.subtleSlate)
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
                        // Switch or return
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
