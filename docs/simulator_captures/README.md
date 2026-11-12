# Fable iOS — Complete UI & Endpoint Screenshot Gallery

This directory contains a complete visual capture of every screen, filter state, reader mode, modal sheet, and backend API integration in **Fable iOS** (captured on `iPhone 17 Pro` simulator with `StoryStore.isMangaEnabled = false`, focusing 100% on open-source books, classic fables, and original stories).

## Full Screen Walkthrough Video
- **[`fable_ios_full_walkthrough.mp4`](./fable_ios_full_walkthrough.mp4)** — Continuous screen recording stepping through authentication, library category filters, fable & classic book readers (starting at Chapter 1, Page 1), table of contents, typography/theme drawers, explore filters, live search, genre/author drill-downs, the writer's studio, and shelf/profile/settings screens.

---

## Screenshot Index (29 Captures)

| # | File | Screen / State | Connected Backend API Endpoint(s) |
|---|---|---|---|
| 01 | [`01_welcome_screen.png`](./01_welcome_screen.png) | Welcome Gateway (`BOOKS & FABLES`) | — |
| 02 | [`02_auth_sign_in_sheet.png`](./02_auth_sign_in_sheet.png) | Sign In Modal Sheet | `POST /api/v1/auth/login`, `POST /api/v1/auth/password-reset/request` |
| 03 | [`03_auth_create_account_sheet.png`](./03_auth_create_account_sheet.png) | Create Account Modal Sheet | `POST /api/v1/auth/register` |
| 04 | [`04_library_filter_all.png`](./04_library_filter_all.png) | Library — Filter: `All` (Featured & Latest) | `GET /api/v1/stories`, `GET /api/v1/discovery/feed` |
| 05 | [`05_library_filter_fables.png`](./05_library_filter_fables.png) | Library — Filter: `Fables` (Aesop's Fables) | `GET /api/v1/stories?genre=Fables` |
| 06 | [`06_library_filter_classics.png`](./06_library_filter_classics.png) | Library — Filter: `Classics` (Gutenberg Classics) | `GET /api/v1/public/gutenberg`, `GET /api/v1/stories?genre=Classics` |
| 07 | [`07_library_filter_mystery.png`](./07_library_filter_mystery.png) | Library — Filter: `Mystery` | `GET /api/v1/stories?genre=Mystery` |
| 08 | [`08_library_filter_fiction.png`](./08_library_filter_fiction.png) | Library — Filter: `Fiction` | `GET /api/v1/public/gutenberg?topic=fiction` |
| 09 | [`09_library_filter_gothic.png`](./09_library_filter_gothic.png) | Library — Filter: `Gothic` | `GET /api/v1/stories?genre=Gothic` |
| 10 | [`10_library_filter_romance.png`](./10_library_filter_romance.png) | Library — Filter: `Romance` | `GET /api/v1/stories?genre=Romance` |
| 11 | [`11_library_filter_adventure.png`](./11_library_filter_adventure.png) | Library — Filter: `Adventure` | `GET /api/v1/stories?genre=Adventure` |
| 12 | [`12_reader_fable_chapter_1.png`](./12_reader_fable_chapter_1.png) | Reader — Classic Fable (*The Tortoise and the Hare*, Ch. 1 • Page 1) | `GET /api/v1/stories/{story_id}/chapters` |
| 13 | [`13_reader_classic_book_chapter_1.png`](./13_reader_classic_book_chapter_1.png) | Reader — Classic Book (*Alice in Wonderland*, Ch. 1 • Page 1) | `GET /api/v1/stories/{story_id}/chapters` |
| 14 | [`14_reader_table_of_contents_sheet.png`](./14_reader_table_of_contents_sheet.png) | Reader — Table of Contents Sheet (Chapters I–XII) | `GET /api/v1/stories/{story_id}/chapters` |
| 15 | [`15_reader_display_options_sheet.png`](./15_reader_display_options_sheet.png) | Reader — Typography & Theme Customization Sheet | Local `UserDefaults` + Dynamic Type |
| 16 | [`16_reader_dark_theme_mode.png`](./16_reader_dark_theme_mode.png) | Reader — Midnight Dark Theme Mode | Local `UserDefaults` + Pacing Engine |
| 17 | [`17_explore_discovery_all.png`](./17_explore_discovery_all.png) | Explore — Discovery Catalog (`All`) | `GET /api/v1/discovery/genres`, `GET /api/v1/discovery/authors` |
| 18 | [`18_explore_filter_under_5_mins.png`](./18_explore_filter_under_5_mins.png) | Explore — Filter: `Under 5 mins` | `GET /api/v1/stories` |
| 19 | [`19_explore_filter_community_favorites.png`](./19_explore_filter_community_favorites.png) | Explore — Filter: `Community Favorites` | `GET /api/v1/stories` |
| 20 | [`20_explore_filter_quick_reads.png`](./20_explore_filter_quick_reads.png) | Explore — Filter: `Quick Reads` | `GET /api/v1/stories` |
| 21 | [`21_explore_live_search_results.png`](./21_explore_live_search_results.png) | Explore — Live Search Query (`"Sherlock"`) | `GET /api/v1/stories?search=Sherlock`, `GET /api/v1/public/gutenberg?search=Sherlock` |
| 22 | [`22_explore_genre_detail_view.png`](./22_explore_genre_detail_view.png) | Explore — Genre Detail View | `GET /api/v1/discovery/genres` |
| 23 | [`23_explore_author_detail_sheet.png`](./23_explore_author_detail_sheet.png) | Explore — Author Detail Sheet | `GET /api/v1/discovery/authors`, `GET /api/v1/public/gutenberg` |
| 24 | [`24_write_studio_editor.png`](./24_write_studio_editor.png) | Writer's Studio — Manuscript Editor | `POST /api/v1/stories`, `GET /api/v1/users/me/stories` |
| 25 | [`25_shelf_tab_saved.png`](./25_shelf_tab_saved.png) | My Shelf — `Saved` Tab & Reading Analytics | `GET /api/v1/users/me/shelf`, `GET /api/v1/users/me/reading-stats` |
| 26 | [`26_shelf_tab_finished.png`](./26_shelf_tab_finished.png) | My Shelf — `Finished` Tab | `PUT /api/v1/users/me/shelf` |
| 27 | [`27_shelf_tab_my_drafts.png`](./27_shelf_tab_my_drafts.png) | My Shelf — `My Drafts` Tab | `GET /api/v1/users/me/stories` |
| 28 | [`28_profile_sheet.png`](./28_profile_sheet.png) | User Profile Modal Sheet | `GET /api/v1/users/me`, `PATCH /api/v1/users/me` |
| 29 | [`29_settings_sheet.png`](./29_settings_sheet.png) | Settings & System Diagnostics Sheet | `GET /api/v1/health` |
