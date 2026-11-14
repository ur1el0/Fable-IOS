import SwiftUI

public struct AuthorDetailView: View {
    @EnvironmentObject var store: StoryStore
    @Environment(\.dismiss) var dismiss

    public let writer: Writer

    @State private var authorStories: [Story] = []
    @State private var isLoading: Bool = true
    @State private var selectedStoryToRead: Story?

    public init(writer: Writer) {
        self.writer = writer
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                FableTheme.background.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Author Hero Profile Header
                        VStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(FableTheme.brandPrimary.opacity(0.12))
                                    .frame(width: 96, height: 96)

                                FableImageView(
                                    name: writer.effectiveAvatar,
                                    title: writer.name,
                                    placeholderIcon: "person.circle.fill"
                                )
                                .frame(width: 90, height: 90)
                                .clipShape(Circle())
                                .shadow(color: Color.black.opacity(0.08), radius: 8, y: 3)
                            }

                            VStack(spacing: 4) {
                                Text(writer.name)
                                    .fableFont(size: 24, weight: .bold, design: .serif)
                                    .foregroundColor(FableTheme.textPrimary)

                                HStack(spacing: 8) {
                                    Text("Project Gutenberg")
                                        .fableFont(size: 11, weight: .bold)
                                        .foregroundColor(FableTheme.brandPrimary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(FableTheme.brandPrimary.opacity(0.1))
                                        .clipShape(Capsule())

                                    Text("•")
                                        .foregroundColor(FableTheme.textMuted)

                                    Text(StoryStore.pluralizedCount(max(authorStories.count, writer.storyCount), singular: "Work Available", plural: "Works Available"))
                                        .fableFont(size: 12, weight: .medium)
                                        .foregroundColor(FableTheme.textMuted)
                                }
                            }
                        }
                        .padding(.top, 16)

                        Divider()
                            .padding(.horizontal, 20)

                        // Bibliography Header
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("BIBLIOGRAPHY & WORKS")
                                    .fableFont(size: 11, weight: .bold)
                                    .tracking(1.2)
                                    .foregroundColor(FableTheme.brandPrimary)

                                Text("Available to Read")
                                    .fableFont(size: 18, weight: .bold)
                                    .foregroundColor(FableTheme.textPrimary)
                            }

                            Spacer()

                            if isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Text(StoryStore.pluralizedCount(authorStories.count, singular: "title"))
                                    .fableFont(size: 12, weight: .semibold)
                                    .foregroundColor(FableTheme.textMuted)
                            }
                        }
                        .padding(.horizontal, 20)

                        // Stories Feed
                        if isLoading && authorStories.isEmpty {
                            VStack(spacing: 12) {
                                ProgressView()
                                Text("Discovering works by \(writer.name)...")
                                    .fableFont(size: 13)
                                    .foregroundColor(FableTheme.textMuted)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                        } else if authorStories.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "book.closed")
                                    .fableFont(size: 32)
                                    .foregroundColor(FableTheme.textMuted.opacity(0.6))
                                Text("No titles currently cached for this author.")
                                    .fableFont(size: 14, weight: .semibold)
                                    .foregroundColor(FableTheme.textPrimary)
                                Text(StoryStore.isMangaEnabled ? "Tap below to query Project Gutenberg, Standard Ebooks, and MangaDex." : "Tap below to query Project Gutenberg and Standard Ebooks.")
                                    .fableFont(size: 12)
                                    .foregroundColor(FableTheme.textMuted)
                                    .multilineTextAlignment(.center)

                                Button(action: {
                                    Task {
                                        isLoading = true
                                        authorStories = await store.fetchAuthorStories(for: writer)
                                        isLoading = false
                                    }
                                }) {
                                    Text("Search Online Providers")
                                        .fableFont(size: 13, weight: .semibold)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 10)
                                        .background(FableTheme.brandPrimary)
                                        .clipShape(Capsule())
                                }
                                .padding(.top, 4)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 32)
                            .padding(.horizontal, 24)
                        } else {
                            LazyVStack(spacing: 14) {
                                ForEach(authorStories) { story in
                                    AuthorStoryRowView(story: story) {
                                        selectedStoryToRead = story
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }

                        Spacer().frame(height: 40)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .fableFont(size: 20)
                            .foregroundColor(FableTheme.textMuted.opacity(0.7))
                    }
                }
            }
            .task {
                authorStories = store.stories(for: writer)
                isLoading = true
                let fetched = await store.fetchAuthorStories(for: writer)
                await MainActor.run {
                    self.authorStories = fetched
                    self.isLoading = false
                }
            }
            .fullScreenCover(item: $selectedStoryToRead) { story in
                let currentStory = store.stories.first(where: { $0.id == story.id }) ?? story
                if currentStory.contentFormat == .manga || currentStory.sourceProvider == .mangadex {
                    MangaReaderView(story: currentStory)
                        .environmentObject(store)
                } else {
                    ReaderView(story: currentStory)
                        .environmentObject(store)
                }
            }
        }
    }
}

private struct AuthorStoryRowView: View {
    let story: Story
    let onSelect: () -> Void

    private var formatText: String {
        story.contentFormat == .manga || story.sourceProvider == .mangadex ? "MANGA" : "PROSE"
    }

    private var placeholderIcon: String {
        story.contentFormat == .manga ? "book.pages" : "text.book.closed"
    }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 14) {
                // Cover Art
                FableImageView(
                    name: story.effectiveCoverImage,
                    title: story.title,
                    placeholderIcon: placeholderIcon
                )
                .frame(width: 65, height: 92)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .shadow(color: Color.black.opacity(0.06), radius: 4, y: 2)

                // Story Metadata
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Text(formatText)
                            .fableFont(size: 9, weight: .bold)
                            .foregroundColor(FableTheme.brandPrimary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(FableTheme.brandPrimary.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 4))

                        if !story.genre.rawValue.isEmpty && story.genre != .all && story.genre != .unspecified {
                            Text(story.genre.rawValue.uppercased())
                                .fableFont(size: 9, weight: .semibold)
                                .foregroundColor(FableTheme.textMuted)
                        }
                    }

                    Text(story.title)
                        .fableFont(size: 15, weight: .bold, design: .serif)
                        .foregroundColor(FableTheme.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    if !story.synopsis.isEmpty {
                        Text(story.synopsis)
                            .fableFont(size: 12)
                            .foregroundColor(FableTheme.textMuted)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }

                    HStack(spacing: 8) {
                        if story.contentFormat == .manga {
                            HStack(spacing: 3) {
                                Image(systemName: "square.stack.fill")
                                    .fableFont(size: 10)
                                Text(story.totalChapters > 0
                                     ? StoryStore.pluralizedCount(story.totalChapters, singular: "Chapter")
                                     : "Chapter count loads when opened")
                                    .fableFont(size: 11, weight: .medium)
                            }
                            .foregroundColor(FableTheme.textMuted)
                        } else {
                            HStack(spacing: 3) {
                                Image(systemName: "clock")
                                    .fableFont(size: 10)
                                Text("~\(max(1, story.readingTimeMinutes)) min read")
                                    .fableFont(size: 11, weight: .medium)
                            }
                            .foregroundColor(FableTheme.textMuted)
                        }

                        Spacer()

                        HStack(spacing: 4) {
                            Text("Read")
                                .fableFont(size: 12, weight: .bold)
                            Image(systemName: "arrow.right")
                                .fableFont(size: 10, weight: .bold)
                        }
                        .foregroundColor(FableTheme.brandPrimary)
                    }
                }
            }
            .padding(12)
            .background(FableTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: Color.black.opacity(0.03), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
    }
}
