import SwiftUI
import Combine

@MainActor
public final class StoryStore: ObservableObject {
    @Published var stories: [Story] = []
    @Published var selectedCategory: String = "All"
    @Published var activeReaderStory: Story?
    @Published var isShowingDisplayOptions: Bool = false
    @Published var isShowingSettings: Bool = false
    @Published var isShowingProfile: Bool = false
    @Published var isShowingGenreDetail: Bool = false
    @Published var selectedGenre: GenreCategory?
    @Published var isStoryPublished: Bool = false
    @Published var selectedTab: FableTab = .library
    
    // Reader Preferences (Persisted across launches)
    @Published var readerFont: ReaderFont = .serif {
        didSet { UserDefaults.standard.set(readerFont.rawValue, forKey: "fable_pref_reader_font") }
    }
    @Published var readerFontSize: Double = 100.0 {
        didSet { UserDefaults.standard.set(readerFontSize, forKey: "fable_pref_reader_font_size") }
    }
    @Published var readerTheme: ReaderTheme = .sepia {
        didSet { UserDefaults.standard.set(readerTheme.rawValue, forKey: "fable_pref_reader_theme") }
    }
    @Published var readerLineSpacing: ReaderLineSpacing = .normal {
        didSet { UserDefaults.standard.set(readerLineSpacing.rawValue, forKey: "fable_pref_reader_line_spacing") }
    }
    @Published var hapticFeedback: Bool = true {
        didSet { UserDefaults.standard.set(hapticFeedback, forKey: "fable_pref_reader_haptics") }
    }
    @Published var isPaginatedMode: Bool = false {
        didSet { UserDefaults.standard.set(isPaginatedMode, forKey: "fable_pref_reader_paginated") }
    }
    
    // Marginalia & Quotes (Plan 02)
    @Published var activeStoryAnnotations: [Annotation] = []
    @Published var pinnedQuotes: [Annotation] = []
    
    // Living Reading Stats (Plan 03 & Mobile Hardening)
    @Published var readingStats: PersistenceService.ReadingStatsSummary = PersistenceService.ReadingStatsSummary(storiesReadCount: 12, totalMinutesRead: 48, streakDays: 3)
    
    // Writing Draft
    @Published var draftTitle: String = "The Metamorphosis"
    @Published var draftGenre: String = "Classic Fiction"
    @Published var draftChapter: String = "Chapter I"
    @Published var draftSynopsis: String = "Gregor Samsa wakes one morning to discover he has transformed into a monstrous insect, forcing his family to confront their dependency and disgust."
    @Published var draftManuscript: String = """
One morning, when Gregor Samsa woke from troubled dreams, he found himself transformed in his bed into a horrible vermin. He lay on his armour-like back, and if he lifted his head a little he could see his brown belly, slightly domed and divided by arches into stiff sections. The bedding was hardly able to cover it and seemed ready to slide off any moment. His many legs, pitifully thin compared with the size of the rest of him, waved about helplessly as he looked.

"What's happened to me?" he thought. It wasn't a dream. His room, a proper human room although a little too small, lay peacefully between its four familiar walls. A collection of textile samples lay spread out on the table — Samsa was a travelling salesman — and above it there hung a picture that he had recently cut out of an illustrated magazine and housed in a nice, gilded frame.
"""
    
    // Genres
    @Published var genres: [GenreCategory] = [
        GenreCategory(
            name: "Folklore",
            storyCount: 340,
            readersCount: "18.4k",
            description: "Traditional tales passed down through generations, reimagined by contemporary scribes—from fireside Slavic forest myths to maritime legends whispered across coastal tides.",
            imageName: "genre_folklore"
        ),
        GenreCategory(
            name: "Mythology",
            storyCount: 218,
            readersCount: "12.1k",
            description: "Epic sagas of deities, ancient heroes, and cosmic origins spanning classical traditions to obscure forgotten pantheons.",
            imageName: "genre_mythology"
        ),
        GenreCategory(
            name: "Gothic",
            storyCount: 185,
            readersCount: "9.8k",
            description: "Atmospheric hauntings, crumbling estates, and romantic dread exploring the psychological depths of human melancholy.",
            imageName: "genre_gothic"
        ),
        GenreCategory(
            name: "Classic Mystery",
            storyCount: 185,
            readersCount: "14.2k",
            description: "Whodunits, deductive puzzles, and atmospheric investigations through gaslit cobblestones and locked rooms.",
            imageName: "genre_mystery"
        )
    ]
    
    // Trending Writers
    @Published var writers: [Writer] = [
        Writer(name: "R.F. Kuang", avatarImageName: "author_kuang", storyCount: 14, rating: 4.9),
        Writer(name: "Rebecca Yarros", avatarImageName: "author_yarros", storyCount: 9, rating: 4.8),
        Writer(name: "T.J. Klune", avatarImageName: "author_klune", storyCount: 16, rating: 4.9),
        Writer(name: "Silvia Moreno", avatarImageName: "author_kuang", storyCount: 14, rating: 4.8)
    ]
    
    // User Profile Stories
    @Published var profileStories: [Story] = []
    
    init() {
        loadReaderPreferences()
        setupInitialStories()
        syncWithPersistence()
    }
    
    private func loadReaderPreferences() {
        if let fontRaw = UserDefaults.standard.string(forKey: "fable_pref_reader_font"),
           let font = ReaderFont(rawValue: fontRaw) {
            self.readerFont = font
        }
        let storedSize = UserDefaults.standard.double(forKey: "fable_pref_reader_font_size")
        if storedSize >= 80.0 && storedSize <= 150.0 {
            self.readerFontSize = storedSize
        }
        if let themeRaw = UserDefaults.standard.string(forKey: "fable_pref_reader_theme"),
           let theme = ReaderTheme(rawValue: themeRaw) {
            self.readerTheme = theme
        }
        if let spacingRaw = UserDefaults.standard.string(forKey: "fable_pref_reader_line_spacing"),
           let spacing = ReaderLineSpacing(rawValue: spacingRaw) {
            self.readerLineSpacing = spacing
        }
        if UserDefaults.standard.object(forKey: "fable_pref_reader_haptics") != nil {
            self.hapticFeedback = UserDefaults.standard.bool(forKey: "fable_pref_reader_haptics")
        }
        if UserDefaults.standard.object(forKey: "fable_pref_reader_paginated") != nil {
            self.isPaginatedMode = UserDefaults.standard.bool(forKey: "fable_pref_reader_paginated")
        }
    }
    
    private func setupInitialStories() {
        let draculaParagraphs = [
            "Before the sun had set, we reached the Bistritz pass. The grey of the evening had begun to fall, and the shadows of the mountains seemed to close in around us with every mile. The horses began to strain against the harness as the road turned sharply upward into the deep pine forests of Transylvania.",
            "\"The castle is on the very edge of a terrible precipice,\" the driver whispered, crossing himself as the wolves began their low, distant howling down in the valley below. \"A stone falling from the window would fall a thousand feet without touching anything.\"",
            "The wind grew colder, piercing through my woollen mantle with icy teeth. Far above, perched jaggedly upon a fang of rock, the black battlements rose against a sky bruised with indigo and blood orange.",
            "I could hear the wolves getting closer. Their choruses echoed through the gorge like a choir of starved spirits. And then, at the crest of the winding road, a tall figure in a heavy cape stepped into the lantern light..."
        ]
        
        let dracula = Story(
            title: "Dracula",
            author: "Bram Stoker",
            genre: "Gothic",
            excerpt: "The castle is on the very edge of a terrible precipice. A stone falling from the window would fall a thousand feet without touching anything.",
            paragraphs: draculaParagraphs,
            coverImageName: "cover_dracula",
            heroImageName: "hero_castle",
            readingTimeMinutes: 4,
            totalPages: 5,
            currentPage: 2,
            progressPercent: 35,
            rating: 4.95,
            isTaleOfTheDay: true,
            isSaved: true
        )
        
        let sleepyHollow = Story(
            title: "The Legend of Sleepy Hollow",
            author: "Washington Irving",
            genre: "Folklore",
            excerpt: "A drowsy, dreamy influence seems to hang over the land, and to pervade the very atmosphere.",
            paragraphs: [
                "A drowsy, dreamy influence seems to hang over the land, and to pervade the very atmosphere. Some say that the place was bewitched by a High German doctor, during the early days of the settlement; others, that an old Indian chief, the prophet or wizard of his tribe, held his powwows there before the country was discovered by Master Hendrick Hudson.",
                "Certain it is, the place still continues under the sway of some bewitching power, that holds a spell over the minds of the good people, causing them to walk in a continual reverie. They are given to all kinds of marvelous beliefs, are subject to trances and visions, and frequently see strange sights, and hear music and voices in the air."
            ],
            coverImageName: "thumb_sleepy",
            heroImageName: "cover_sleepy_featured",
            readingTimeMinutes: 4,
            totalPages: 24,
            currentPage: 14,
            progressPercent: 60,
            rating: 4.95,
            isSaved: true,
            isCuratorSpotlight: true
        )
        
        let metamorphosis = Story(
            title: "The Metamorphosis",
            author: "Franz Kafka",
            genre: "Classic Fiction",
            excerpt: "“One morning, when Gregor Samsa woke from troubled dreams, he found himself transformed in his bed into a monstrous vermin.”",
            paragraphs: [
                "One morning, when Gregor Samsa woke from troubled dreams, he found himself transformed in his bed into a monstrous vermin.",
                "He lay on his armour-like back, and if he lifted his head a little he could see his brown belly, slightly domed and divided by arches into stiff sections."
            ],
            coverImageName: "thumb_metamorphosis",
            readingTimeMinutes: 5,
            totalPages: 8,
            currentPage: 6,
            progressPercent: 80,
            isRecentSubmission: true,
            isSaved: true
        )
        
        let tellTale = Story(
            title: "The Tell-Tale Heart",
            author: "Edgar Allan Poe",
            genre: "Gothic",
            excerpt: "\"True! — nervous — very, very dreadfully nervous I had been and am; but why will you say that I am mad?\"",
            paragraphs: [
                "True! — nervous — very, very dreadfully nervous I had been and am; but why will you say that I am mad? The disease had sharpened my senses — not destroyed — not dulled them.",
                "Above all was the sense of hearing acute. I heard all things in the heaven and in the earth. I heard many things in hell. How, then, am I mad? Hearken! and observe how healthily — how calmly I can tell you the whole story."
            ],
            coverImageName: "thumb_tell_tale",
            readingTimeMinutes: 3,
            totalPages: 4,
            currentPage: 1,
            progressPercent: 15,
            isRecentSubmission: true,
            isSaved: true
        )
        
        let mariaMakiling = Story(
            title: "The Legend of Maria Makiling",
            author: "Jose Rizal",
            genre: "Folklore",
            excerpt: "\"She was a fantastic creature, half nymph, half sylph, born under the moonbeams in the mystery of ancient woods...\"",
            paragraphs: [
                "She was a fantastic creature, half nymph, half sylph, born under the moonbeams in the mystery of ancient woods...",
                "Her voice was like the murmur of crystal water over white pebbles, and her step was as light as the dewdrop falling upon a leaf at dawn."
            ],
            coverImageName: "thumb_maria_makiling",
            readingTimeMinutes: 4,
            totalPages: 6,
            currentPage: 1,
            progressPercent: 0,
            isRecentSubmission: true,
            isSaved: true
        )
        
        // Genre Detail stories (Folklore)
        let ripVanWinkle = Story(
            title: "Rip Van Winkle",
            author: "Washington Irving",
            genre: "American Tale",
            excerpt: "\"Whoever has made a voyage up the Hudson must remember the Kaatskill mountains, rising in lordly height above the rolling river.\"",
            coverImageName: "thumb_rip_van_winkle",
            readingTimeMinutes: 4,
            rating: 4.9,
            savesCount: "1.2k saves",
            badgeText: "AMERICAN TALE"
        )
        
        let monkeysPaw = Story(
            title: "The Monkey's Paw",
            author: "W.W. Jacobs",
            genre: "Gothic Fable",
            excerpt: "\"Without, the night was cold and wet, but in the small parlour the blinds were drawn and the fire burned brightly before the hearth.\"",
            coverImageName: "thumb_monkeys_paw",
            readingTimeMinutes: 5,
            rating: 4.8,
            savesCount: "890 saves",
            badgeText: "GOTHIC FABLE"
        )
        
        let fisherman = Story(
            title: "The Fisherman and His Wife",
            author: "Brothers Grimm",
            genre: "Grimm's Fairy Tale",
            excerpt: "\"There once was a fisherman and his wife who lived together in a little cottage close by the sea, until one day a magic flounder spoke.\"",
            coverImageName: "thumb_fisherman",
            readingTimeMinutes: 4,
            rating: 4.8,
            savesCount: "670 saves",
            badgeText: "GRIMM'S FAIRY TALE"
        )
        
        let sandman = Story(
            title: "The Sandman",
            author: "E.T.A. Hoffmann",
            genre: "Dark Romanticism",
            excerpt: "\"Nathaniel sat across from the silent Olimpia, whose crystal-clear eyes rested upon him with strange and motionless intensity.\"",
            coverImageName: "thumb_sandman",
            readingTimeMinutes: 2,
            rating: 4.7,
            savesCount: "410 saves",
            badgeText: "DARK ROMANTICISM"
        )
        
        self.stories = [dracula, sleepyHollow, metamorphosis, tellTale, mariaMakiling, ripVanWinkle, monkeysPaw, fisherman, sandman]
        
        // Profile Stories (Roosc Zaño)
        self.profileStories = [
            Story(
                title: "The Clockmaker of Prague",
                author: "Roosc Zaño",
                genre: "Folklore",
                excerpt: "In the shadowed alleys behind the Astronomical Clock, Master Hanuš polished cogs that measured not minutes, but heartbeats.",
                coverImageName: "thumb_clockmaker",
                readingTimeMinutes: 4,
                rating: 4.9,
                readsCount: "1.2k reads",
                badgeText: "FOLKLORE • 4 min read"
            ),
            Story(
                title: "The Whispering Pines",
                author: "Roosc Zaño",
                genre: "Nature Myth",
                excerpt: "The woods speak in root-taps and resin-fall. If you lean your ear to the moss before dusk, you may hear the oldest branch sigh.",
                coverImageName: "thumb_pines",
                readingTimeMinutes: 2,
                rating: 4.8,
                readsCount: "840 reads",
                badgeText: "NATURE MYTH • 2 min read"
            ),
            Story(
                title: "The Starlit Loom",
                author: "Roosc Zaño",
                genre: "Fable",
                excerpt: "Woven from silver comet strands, the cloak was meant for travelers crossing the edge of dreams into the waking sky.",
                coverImageName: "thumb_loom",
                readingTimeMinutes: 3,
                rating: 5.0,
                readsCount: "620 reads",
                badgeText: "FABLE • Completed"
            )
        ]
    }
    
    var draftWordCount: Int {
        draftManuscript.split { $0.isWhitespace || $0.isNewline }.count
    }
    
    func resetDisplayOptions() {
        readerFont = .serif
        readerFontSize = 100.0
        readerTheme = .sepia
        readerLineSpacing = .normal
    }
    
    func publishStory() {
        let newStory = Story(
            title: draftTitle,
            author: "Roosc Zaño",
            genre: draftGenre,
            excerpt: draftSynopsis,
            paragraphs: [draftManuscript],
            coverImageName: "thumb_metamorphosis",
            readingTimeMinutes: max(1, draftWordCount / 150),
            totalPages: 1,
            currentPage: 1,
            progressPercent: 0,
            rating: 5.0,
            isRecentSubmission: true
        )
        stories.insert(newStory, at: 0)
        profileStories.insert(newStory, at: 0)
        isStoryPublished = true
        
        // Persist to SwiftData SQLite
        PersistenceService.shared.saveStory(newStory)
    }
    
    private func syncWithPersistence() {
        // Seed default stories if SQLite is empty
        PersistenceService.shared.seedInitialDataIfNeeded(seedStories: self.stories)
        
        // Hydrate and reconcile from SQLite
        let persisted = PersistenceService.shared.fetchAllStories()
        if !persisted.isEmpty {
            for entity in persisted {
                if let idx = stories.firstIndex(where: { $0.id == entity.id }) {
                    stories[idx].isBookmarked = entity.isBookmarked
                    stories[idx].isCompleted = entity.isCompleted
                    stories[idx].progressPercent = Int(entity.readingProgress * 100.0)
                    stories[idx].currentPage = max(1, entity.currentPage)
                    stories[idx].totalPages = max(1, entity.totalPages)
                } else {
                    let userStory = Story(
                        id: entity.id,
                        title: entity.title,
                        author: entity.author,
                        genre: entity.genreRaw,
                        excerpt: entity.synopsis,
                        paragraphs: [entity.content],
                        coverImageName: "thumb_metamorphosis",
                        readingTimeMinutes: entity.readTimeMinutes,
                        totalPages: max(1, entity.totalPages),
                        currentPage: max(1, entity.currentPage),
                        progressPercent: Int(entity.readingProgress * 100.0),
                        rating: 5.0,
                        isRecentSubmission: true,
                        isSaved: entity.isBookmarked,
                        isFinished: entity.isCompleted
                    )
                    stories.insert(userStory, at: 0)
                    profileStories.insert(userStory, at: 0)
                }
            }
        }
        
        reloadPinnedQuotes()
        reloadReadingStats()
    }
    
    func reloadReadingStats() {
        self.readingStats = PersistenceService.shared.fetchReadingStats()
    }
    
    func reloadPinnedQuotes() {
        let loaded = PersistenceService.shared.fetchAllPinnedAnnotations()
        if loaded.isEmpty {
            let defaultQuote = Annotation(
                storyId: UUID(uuidString: "11111111-1111-1111-1111-111111111111") ?? UUID(),
                storyTitle: "De Oratore",
                storyAuthor: "Marcus Tullius Cicero",
                utf16StartOffset: 0,
                utf16EndOffset: 51,
                selectedText: "A room without books is like a body without a soul.",
                note: "Foundational literary ethos",
                color: .terracotta,
                isPinnedToJournal: true
            )
            self.pinnedQuotes = [defaultQuote]
        } else {
            self.pinnedQuotes = loaded
        }
    }
    
    // MARK: - Actions
    func toggleBookmark(for story: Story) {
        if let idx = stories.firstIndex(where: { $0.id == story.id }) {
            stories[idx].isBookmarked.toggle()
        }
        if let idx = profileStories.firstIndex(where: { $0.id == story.id }) {
            profileStories[idx].isBookmarked.toggle()
        }
        _ = PersistenceService.shared.toggleBookmark(storyId: story.id)
    }
    
    func updateProgress(for storyId: UUID, page: Int, totalPages: Int) {
        if let idx = stories.firstIndex(where: { $0.id == storyId }) {
            stories[idx].currentPage = page
            stories[idx].totalPages = totalPages
            let pct = min(100, max(0, Int((Double(page) / Double(max(1, totalPages))) * 100)))
            stories[idx].progressPercent = pct
            if pct >= 100 {
                stories[idx].isCompleted = true
            }
            PersistenceService.shared.updateProgress(
                storyId: storyId,
                progressPercent: pct,
                isCompleted: pct >= 100,
                page: page,
                totalPages: totalPages
            )
            reloadReadingStats()
        }
    }
    
    func logReadingSession(for story: Story, seconds: Int) {
        PersistenceService.shared.logReadingSession(
            storyId: story.id,
            storyTitle: story.title,
            seconds: seconds,
            isCompleted: story.isCompleted
        )
        reloadReadingStats()
    }
    
    func markAsFinished(storyId: UUID) {
        if let idx = stories.firstIndex(where: { $0.id == storyId }) {
            stories[idx].isCompleted = true
            stories[idx].progressPercent = 100
            let pages = stories[idx].totalPages
            PersistenceService.shared.updateProgress(
                storyId: storyId,
                progressPercent: 100,
                isCompleted: true,
                page: pages,
                totalPages: pages
            )
            reloadReadingStats()
        }
    }
    
    func removeFromShelf(storyId: UUID) {
        if let idx = stories.firstIndex(where: { $0.id == storyId }) {
            stories[idx].isBookmarked = false
            _ = PersistenceService.shared.toggleBookmark(storyId: storyId)
        }
    }
    
    // MARK: - Marginalia & Annotations (Plan 02)
    func loadAnnotations(for storyId: UUID) {
        self.activeStoryAnnotations = PersistenceService.shared.fetchAnnotations(for: storyId)
    }
    
    func addAnnotation(
        story: Story,
        text: String,
        startOffset: Int,
        endOffset: Int,
        color: HighlightColor,
        note: String? = nil,
        pinToJournal: Bool = false
    ) {
        let annotation = Annotation(
            storyId: story.id,
            storyTitle: story.title,
            storyAuthor: story.author,
            utf16StartOffset: startOffset,
            utf16EndOffset: endOffset,
            selectedText: text,
            note: note,
            color: color,
            isPinnedToJournal: pinToJournal
        )
        activeStoryAnnotations.append(annotation)
        PersistenceService.shared.saveAnnotation(annotation)
        if pinToJournal {
            reloadPinnedQuotes()
        }
    }
    
    func deleteAnnotation(id: UUID, storyId: UUID) {
        activeStoryAnnotations.removeAll(where: { $0.id == id })
        PersistenceService.shared.deleteAnnotation(id: id)
        reloadPinnedQuotes()
    }
    
    func togglePinQuote(for annotation: Annotation) {
        var updated = annotation
        updated.isPinnedToJournal.toggle()
        PersistenceService.shared.saveAnnotation(updated)
        if let idx = activeStoryAnnotations.firstIndex(where: { $0.id == annotation.id }) {
            activeStoryAnnotations[idx] = updated
        }
        reloadPinnedQuotes()
    }
}
