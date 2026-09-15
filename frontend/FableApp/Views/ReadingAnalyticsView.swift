import SwiftUI

public struct ReadingAnalyticsView: View {
    @EnvironmentObject var store: StoryStore
    @Environment(\.dismiss) var dismiss

    @State private var snapshot: AnalyticsSnapshot?
    @State private var selectedTimeframe: String = "This Week"

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                FableTheme.background
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        // Title & Subtitle
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Reading Analytics")
                                .font(.system(size: 32, weight: .bold, design: .serif))
                                .foregroundColor(FableTheme.textPrimary)

                            Text("Your personal chronicle of literary pacing, hours logged, and collector achievements.")
                                .font(.system(size: 13))
                                .foregroundColor(FableTheme.textMuted)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 12)

                        // 4-Card Hero Grid
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                            statCard(
                                title: "TIME LOGGED",
                                value: formattedReadingTime(minutes: snapshot?.totalMinutesRead ?? store.readingStats.totalMinutesRead),
                                icon: "clock.fill",
                                subtitle: "+14m vs last week"
                            )

                            statCard(
                                title: "STORIES COMPLETED",
                                value: "\(snapshot?.storiesCompletedCount ?? store.readingStats.storiesReadCount)",
                                icon: "book.pages.fill",
                                subtitle: "Folklore & Gothic"
                            )

                            statCard(
                                title: "READING VELOCITY",
                                value: "\(snapshot?.averageWPM ?? 215) WPM",
                                icon: "speedometer",
                                subtitle: "Pacing Engine active"
                            )

                            statCard(
                                title: "READING STREAK",
                                value: "\(snapshot?.currentStreakDays ?? store.readingStats.streakDays) Days",
                                icon: "flame.fill",
                                subtitle: "Next goal: 7 days"
                            )
                        }
                        .padding(.horizontal, 20)

                        // Section 1: Weekly Reading Rhythm Bar Chart
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("WEEKLY READING RHYTHM")
                                        .font(.system(size: 11, weight: .bold))
                                        .tracking(1.2)
                                        .foregroundColor(FableTheme.textMuted)

                                    Text("Minutes Explored Daily")
                                        .font(.system(size: 16, weight: .bold, design: .serif))
                                        .foregroundColor(FableTheme.textPrimary)
                                }

                                Spacer()

                                Text("Goal: 20m/day")
                                    .font(.system(size: 11, weight: .semibold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(FableTheme.surface)
                                    .foregroundColor(FableTheme.brandPrimary)
                                    .clipShape(Capsule())
                            }

                            // Interactive Bar Chart
                            if let activity = snapshot?.weeklyActivity {
                                HStack(alignment: .bottom, spacing: 12) {
                                    ForEach(activity) { day in
                                        VStack(spacing: 6) {
                                            Text("\(day.minutesRead)m")
                                                .font(.system(size: 10, weight: .semibold))
                                                .foregroundColor(day.isToday ? FableTheme.brandPrimary : FableTheme.textMuted)

                                            // Bar Fill
                                            let barHeight = CGFloat(max(16, min(110, day.minutesRead * 3)))
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(day.isToday ? FableTheme.brandPrimary : (day.minutesRead >= 20 ? FableTheme.brandPrimary.opacity(0.4) : Color.gray.opacity(0.18)))
                                                .frame(height: barHeight)

                                            Text(day.dayName)
                                                .font(.system(size: 11, weight: day.isToday ? .bold : .medium))
                                                .foregroundColor(day.isToday ? FableTheme.brandPrimary : FableTheme.textSecondary)
                                        }
                                        .frame(maxWidth: .infinity)
                                    }
                                }
                                .padding(.top, 8)
                                .padding(.bottom, 6)
                            }
                        }
                        .padding(18)
                        .background(FableTheme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: Color.black.opacity(0.03), radius: 8, y: 2)
                        .padding(.horizontal, 20)

                        // Section 2: Genre Literary Palette
                        if let genres = snapshot?.topGenres, !genres.isEmpty {
                            VStack(alignment: .leading, spacing: 14) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("LITERARY PALETTE")
                                        .font(.system(size: 11, weight: .bold))
                                        .tracking(1.2)
                                        .foregroundColor(FableTheme.textMuted)

                                    Text("Genre Affinity Breakdown")
                                        .font(.system(size: 16, weight: .bold, design: .serif))
                                        .foregroundColor(FableTheme.textPrimary)
                                }

                                // Stacked Bar
                                GeometryReader { geo in
                                    HStack(spacing: 2) {
                                        ForEach(genres) { g in
                                            RoundedRectangle(cornerRadius: 3)
                                                .fill(Color(hex: g.colorHex))
                                                .frame(width: max(8, geo.size.width * CGFloat(g.percentage)))
                                        }
                                    }
                                }
                                .frame(height: 10)
                                .clipShape(Capsule())

                                // Detailed Breakdown Rows
                                VStack(spacing: 8) {
                                    ForEach(genres) { g in
                                        HStack {
                                            Circle()
                                                .fill(Color(hex: g.colorHex))
                                                .frame(width: 8, height: 8)

                                            Text(g.genreName)
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundColor(FableTheme.textPrimary)

                                            Spacer()

                                            Text("\(g.storyCount) tales")
                                                .font(.system(size: 12))
                                                .foregroundColor(FableTheme.textMuted)

                                            Text("\(Int(g.percentage * 100))%")
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundColor(FableTheme.brandPrimary)
                                                .frame(width: 36, alignment: .trailing)
                                        }
                                        .padding(.vertical, 2)
                                    }
                                }
                            }
                            .padding(18)
                            .background(FableTheme.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: Color.black.opacity(0.03), radius: 8, y: 2)
                            .padding(.horizontal, 20)
                        }

                        // Section 3: Archivist Hall of Badges
                        if let badges = snapshot?.badges, !badges.isEmpty {
                            VStack(alignment: .leading, spacing: 14) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("COLLECTOR'S CORNER")
                                        .font(.system(size: 11, weight: .bold))
                                        .tracking(1.2)
                                        .foregroundColor(FableTheme.textMuted)

                                    Text("Archivist Literary Badges")
                                        .font(.system(size: 16, weight: .bold, design: .serif))
                                        .foregroundColor(FableTheme.textPrimary)
                                }
                                .padding(.horizontal, 20)

                                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                                    ForEach(badges) { badge in
                                        VStack(alignment: .leading, spacing: 10) {
                                            HStack {
                                                Image(systemName: badge.iconName)
                                                    .font(.system(size: 16, weight: .semibold))
                                                    .foregroundColor(badge.isUnlocked ? FableTheme.brandPrimary : FableTheme.textMuted)
                                                    .frame(width: 34, height: 34)
                                                    .background(badge.isUnlocked ? FableTheme.brandPrimary.opacity(0.12) : Color.gray.opacity(0.08))
                                                    .clipShape(Circle())

                                                Spacer()

                                                if badge.isUnlocked {
                                                    Text("UNLOCKED")
                                                        .font(.system(size: 8, weight: .bold))
                                                        .tracking(0.8)
                                                        .padding(.horizontal, 6)
                                                        .padding(.vertical, 2)
                                                        .background(FableTheme.brandPrimary.opacity(0.15))
                                                        .foregroundColor(FableTheme.brandPrimary)
                                                        .clipShape(Capsule())
                                                } else {
                                                    Text("\(Int(badge.progressFraction * 100))%")
                                                        .font(.system(size: 9, weight: .semibold))
                                                        .foregroundColor(FableTheme.textMuted)
                                                }
                                            }

                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(badge.title)
                                                    .font(.system(size: 13, weight: .bold, design: .serif))
                                                    .foregroundColor(badge.isUnlocked ? FableTheme.textPrimary : FableTheme.textMuted)

                                                Text(badge.subtitle)
                                                    .font(.system(size: 11))
                                                    .foregroundColor(FableTheme.textMuted)
                                                    .lineLimit(2)
                                            }
                                        }
                                        .padding(14)
                                        .background(FableTheme.cardBackground)
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14)
                                                .stroke(badge.isUnlocked ? FableTheme.brandPrimary.opacity(0.3) : FableTheme.lightBorder, lineWidth: 1)
                                        )
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }

                        // Social Sharing Card
                        VStack(spacing: 8) {
                            Text("Chronicle Summary")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(FableTheme.textMuted)

                            ShareLink(
                                item: "I've logged \(snapshot?.totalMinutesRead ?? store.readingStats.totalMinutesRead) minutes reading curated folklore on Fable! Active streak: \(snapshot?.currentStreakDays ?? store.readingStats.streakDays) days."
                            ) {
                                HStack(spacing: 8) {
                                    Image(systemName: "square.and.arrow.up")
                                    Text("Share Reading Chronicle")
                                        .font(.system(size: 14, weight: .semibold))
                                }
                                .foregroundColor(FableTheme.brandPrimary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(FableTheme.cardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(FableTheme.brandPrimary.opacity(0.3), lineWidth: 1)
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 36)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(FableTheme.textPrimary)
                            .padding(6)
                            .background(Color.white)
                            .clipShape(Circle())
                    }
                }
            }
            .onAppear {
                loadAnalytics()
            }
        }
    }

    private func loadAnalytics() {
        let loaded = PersistenceService.shared.fetchFullAnalyticsSnapshot(
            stories: store.stories,
            pinnedQuotesCount: store.pinnedQuotes.count,
            authoredCount: store.profileStories.count,
            averageWPM: 215
        )
        self.snapshot = loaded
    }

    @ViewBuilder
    private func statCard(title: String, value: String, icon: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.0)
                    .foregroundColor(FableTheme.textMuted)
                Spacer()
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(FableTheme.brandPrimary)
            }

            Text(value)
                .font(.system(size: 22, weight: .bold, design: .serif))
                .foregroundColor(FableTheme.textPrimary)

            Text(subtitle)
                .font(.system(size: 11))
                .foregroundColor(FableTheme.textMuted)
        }
        .padding(14)
        .background(FableTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: Color.black.opacity(0.02), radius: 6, y: 2)
    }

    private func formattedReadingTime(minutes: Int) -> String {
        if minutes >= 60 {
            return "\(minutes / 60)h \(minutes % 60)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// Hex color parser extension
private extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 159, 60, 22)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
