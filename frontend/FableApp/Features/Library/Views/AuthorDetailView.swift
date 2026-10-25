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

    private var authorBio: String {
        let name = writer.name.lowercased()
        if name.contains("shelley") {
            return "Pioneering novelist of Gothic horror and science fiction, renowned for Frankenstein and The Last Man."
        } else if name.contains("doyle") {
            return "Master of Victorian detective fiction, creator of Sherlock Holmes and Dr. John Watson."
        } else if name.contains("stoker") {
            return "Iconic author of Gothic literature, defining vampire folklore with his 1897 masterpiece Dracula."
        } else if name.contains("austen") {
            return "Celebrated literary realist and social satirist, author of Pride and Prejudice, Emma, and Sense and Sensibility."
        } else if name.contains("poe") {
            return "Father of the modern detective story and psychological horror, famed for The Raven and Tales of the Grotesque."
        } else if name.contains("fujimoto") {
            return "Acclaimed Japanese manga creator known for dark fantasy, cinematic pacing, Chainsaw Man, and Look Back."
        }
        return "Featured creator in the Fable reading catalog with works available across prose literature and graphic manga."
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
                                HStack(spacing: 6) {
                                    Text(writer.name)
                                        .font(.system(size: 24, weight: .bold, design: .serif))
                                        .foregroundColor(FableTheme.textPrimary)

                                    Image(systemName: "checkmark.seal.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(FableTheme.brandPrimary)
                                }

                                HStack(spacing: 8) {
                                    Text("Catalog Creator")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(FableTheme.brandPrimary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(FableTheme.brandPrimary.opacity(0.1))
                                        .clipShape(Capsule())

                                    Text("•")
                                        .foregroundColor(FableTheme.textMuted)

                                    Text("\(max(authorStories.count, writer.storyCount)) Works Available")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(FableTheme.textMuted)
                                }
                            }

                            Text(authorBio)
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(FableTheme.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                                .lineSpacing(3)
                        }
                        .padding(.top, 16)

                        Divider()
                            .padding(.horizontal, 20)

                        // Bibliography Header
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("BIBLIOGRAPHY & WORKS")
                                    .font(.system(size: 11, weight: .bold))
                                    .tracking(1.2)
                                    .foregroundColor(FableTheme.brandPrimary)

                                Text("Available to Read")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(FableTheme.textPrimary)
                            }

                            Spacer()

                            if isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Text("\(authorStories.count) titles")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(FableTheme.textMuted)
                            }
                        }
                        .padding(.horizontal, 20)

                        // Stories Feed
                        if isLoading && authorStories.isEmpty {
                            VStack(spacing: 12) {
                                ProgressView()
                                Text("Discovering works by \(writer.name)...")
                                    .font(.system(size: 13))
                                    .foregroundColor(FableTheme.textMuted)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                        } else if authorStories.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "book.closed")
                                    .font(.system(size: 32))
                                    .foregroundColor(FableTheme.textMuted.opacity(0.6))
                                Text("No titles currently cached for this author.")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(FableTheme.textPrimary)
                                Text("Tap below to query Project Gutenberg and MangaDex.")
                                    .font(.system(size: 12))
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
                                        .font(.system(size: 13, weight: .semibold))
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
                            .font(.system(size: 20))
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
                if story.contentFormat == .manga || story.sourceProvider == .mangadex {
                    MangaReaderView(story: story)
                        .environmentObject(store)
                } else {
                    ReaderView(story: story)
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
                    name: story.coverImageUrl,
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
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(FableTheme.brandPrimary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(FableTheme.brandPrimary.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 4))

                        if !story.genre.rawValue.isEmpty && story.genre != .all && story.genre != .unspecified {
                            Text(story.genre.rawValue.uppercased())
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(FableTheme.textMuted)
                        }
                    }

                    Text(story.title)
                        .font(.system(size: 15, weight: .bold, design: .serif))
                        .foregroundColor(FableTheme.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    if !story.synopsis.isEmpty {
                        Text(story.synopsis)
                            .font(.system(size: 12))
                            .foregroundColor(FableTheme.textMuted)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }

                    HStack(spacing: 8) {
                        if story.contentFormat == .manga {
                            HStack(spacing: 3) {
                                Image(systemName: "square.stack.fill")
                                    .font(.system(size: 10))
                                Text("\(max(1, story.totalChapters)) Chapters")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundColor(FableTheme.textMuted)
                        } else {
                            HStack(spacing: 3) {
                                Image(systemName: "clock")
                                    .font(.system(size: 10))
                                Text("~\(max(1, story.readingTimeMinutes)) min read")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundColor(FableTheme.textMuted)
                        }

                        Spacer()

                        HStack(spacing: 4) {
                            Text("Read")
                                .font(.system(size: 12, weight: .bold))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 10, weight: .bold))
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
