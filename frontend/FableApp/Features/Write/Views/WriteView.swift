import SwiftUI

public struct WriteView: View {
    @EnvironmentObject var store: StoryStore
    @ObservedObject private var auth = AuthManager.shared
    
    @State private var isShowingPublishSheet: Bool = false
    @State private var publishedStory: Story?
    @State private var selectedStoryToRead: Story?
    @State private var isShowingClearAlert: Bool = false
    @State private var formattingRequest: ManuscriptFormattingRequest?
    
    var availableGenres: [String] { store.genres.map(\.name) }

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
                                store.clearWriterDraft()
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
                        Button {
                            Task {
                                guard let story = await store.publishStory() else { return }
                                publishedStory = story
                                isShowingPublishSheet = true
                            }
                        } label: {
                            Group {
                                if store.isPublishingStory {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: "arrow.up")
                                        .font(.system(size: 16, weight: .bold))
                                }
                            }
                            .foregroundColor(.white)
                            .frame(width: 42, height: 42)
                            .background(FableTheme.brandPrimary)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(color: FableTheme.brandPrimary.opacity(0.35), radius: 6, y: 3)
                        }
                        .disabled(store.isPublishingStory)
                        .accessibilityLabel(store.isPublishingStory ? "Publishing story" : "Publish story")
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
                                    
                                    TextField("Genre", text: $store.draftGenre)
                                        .font(.system(size: 13, weight: .medium))
                                        .textInputAutocapitalization(.words)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 7)
                                        .background(FableTheme.surface)
                                        .clipShape(Capsule())

                                    Menu {
                                        ForEach(availableGenres, id: \.self) { genre in
                                            Button(genre) {
                                                store.draftGenre = genre
                                            }
                                        }
                                    } label: {
                                        Image(systemName: "chevron.down")
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundColor(FableTheme.brandPrimary)
                                            .padding(8)
                                            .background(FableTheme.surface)
                                            .clipShape(Circle())
                                    }
                                    Spacer()
                                }

                                Divider()

                                TextField("Chapter title (optional)", text: $store.draftChapter)
                                    .font(.system(size: 13, weight: .medium))
                                    .textInputAutocapitalization(.sentences)
                                    .foregroundColor(FableTheme.textSecondary)
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
                                            formattingRequest = ManuscriptFormattingRequest(style: .bold)
                                        }) {
                                            Text("B")
                                                .font(.system(size: 12, weight: .bold))
                                                .frame(width: 24, height: 24)
                                                .background(FableTheme.surface)
                                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                                .foregroundColor(FableTheme.textPrimary)
                                        }
                                        .accessibilityLabel("Insert bold formatting markers")
                                        
                                        Button(action: {
                                            formattingRequest = ManuscriptFormattingRequest(style: .italic)
                                        }) {
                                            Text("I")
                                                .font(.system(size: 12, weight: .semibold))
                                                .italic()
                                                .frame(width: 24, height: 24)
                                                .background(FableTheme.surface)
                                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                                .foregroundColor(FableTheme.textPrimary)
                                        }
                                        .accessibilityLabel("Insert italic formatting markers")
                                        
                                        Button(action: {
                                            formattingRequest = ManuscriptFormattingRequest(style: .quote)
                                        }) {
                                            Image(systemName: "quote.opening")
                                                .font(.system(size: 10))
                                                .frame(width: 24, height: 24)
                                                .background(FableTheme.surface)
                                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                                .foregroundColor(FableTheme.textPrimary)
                                        }
                                        .accessibilityLabel("Insert a block quote marker")
                                        
                                        Button(action: {
                                            formattingRequest = ManuscriptFormattingRequest(style: .sceneBreak)
                                        }) {
                                            Image(systemName: "divide")
                                                .font(.system(size: 11))
                                                .frame(width: 24, height: 24)
                                                .background(FableTheme.surface)
                                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                                .foregroundColor(FableTheme.textPrimary)
                                        }
                                        .accessibilityLabel("Insert a scene break")
                                    }
                                }
                                
                                ManuscriptEditor(
                                    text: $store.draftManuscript,
                                    formattingRequest: $formattingRequest
                                )
                                .frame(minHeight: 280)
                                .accessibilityIdentifier("manuscriptEditor")
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
                        Image(systemName: "iphone")
                            .font(.system(size: 11))
                            .foregroundColor(FableTheme.brandPrimary)
                        Text("Saved locally")
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
                if let publishedStory {
                    StoryPublishedSheet(
                        story: publishedStory,
                        onReturnToLibrary: {
                            store.selectedTab = .library
                        },
                        onViewStory: {
                            selectedStoryToRead = publishedStory
                        }
                    )
                }
            }
            .alert("Couldn't publish story", isPresented: Binding(
                get: { store.publishErrorMessage != nil },
                set: { if !$0 { store.publishErrorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { store.publishErrorMessage = nil }
            } message: {
                Text(store.publishErrorMessage ?? "")
            }
            .fullScreenCover(item: $selectedStoryToRead) { story in
                ReaderView(story: story)
                    .environmentObject(store)
            }
            .task(id: auth.currentSession?.id) {
                store.restoreWriterDraftForCurrentSession()
            }
        }
    }
}

#Preview {
    WriteView()
        .environmentObject(StoryStore())
}
