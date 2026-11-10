# ADR 0002: Feature-flagging Manga on iOS to focus on open-source books and fables

- **Status:** Accepted
- **Date:** 2026-11-10

## Context

Fable originally ingested both public-domain prose literature (via Project Gutenberg / Gutendex and Standard Ebooks) and community-translated manga chapters (via the MangaDex public API). During end-to-end verification on iOS Simulator, two structural problems with third-party manga aggregation became clear:

1. **Incomplete & Non-Contiguous Upstream Chapter Coverage:** Because MangaDex hosts fan-translated scanlations and removes chapters upon official English publisher licensing or DMCA notices, major series have severe chapter gaps (for example, *Mushoku Tensei: Jobless Reincarnation* lacks English Chapters 79–108 on MangaDex, and *One Piece* lacks Chapters 1–1162). Even after seeding Chapters 1–5 locally, no legal free upstream API provides complete chapter-1-to-latest English runs for commercial manga.
2. **Intellectual Property & App Store Review Compliance:** Distributing unlicensed manga scanlations violates copyright law and **Apple App Store Review Guideline 5.2 (Intellectual Property)**, exposing the iOS application to rejection or takedown.

## Decision

1. Introduce a compile-time/runtime feature flag `StoryStore.isMangaEnabled = false` in `frontend/FableApp/Features/Library/ViewModels/StoryStore.swift`.
2. Filter out `.manga` items across all iOS user-facing discovery, search, genre, author, and shelf views (`LibraryView`, `ExploreView`, `GenreDetailView`, `AuthorDetailView`, `ShelfView`, and `WelcomeView`), focusing the iOS experience 100% on public-domain books, classic fables, folklore, and user-authored manuscripts.
3. Replace manga creators in `FEATURED_CATALOG_AUTHORS` (`backend/services/story_service.py`) with public-domain literary authors (`Lewis Carroll`, `Aesop`).
4. Retain the underlying `ContentFormat.manga` enum, `MangaReaderView.swift`, and `/api/v1/public/manga` backend endpoints in a dormant, tested state so existing backend (`100/100`) and iOS (`22/22`) contract tests continue to pass without destructive schema churn.

## Consequences

- **Positive:** Fable iOS is 100% copyright-clean and compliant with Apple App Store Guideline 5.2; every visible title in the iOS app has complete, legal, contiguous chapters starting at Chapter 1.
- **Positive:** Zero regressions in existing unit/integration tests, and the graphic reader engine (`MangaReaderView`) can be repurposed in the future for public-domain comic strips or author-illustrated manuscripts by toggling `StoryStore.isMangaEnabled`.
- **Trade-off:** Manga filter chips and series cards are hidden from the iOS UI by default.
