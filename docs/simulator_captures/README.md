# Fable iOS — UI & Endpoint Screenshot Gallery

This directory contains visual captures of the reachable screens, filter states, reader modes, modal sheets, and live backend API integrations in **Fable iOS**, recorded on an `iPhone 17 Pro` simulator (`iOS 26.5`) running `feat/plans-01-04-remediation` (`5c37d20`) via `AUTO_UI_TOUR=1` with `StoryStore.isMangaEnabled = false` against the local FastAPI backend (`http://127.0.0.1:8001/api/v1`) serving live **Standard Ebooks** and **Project Gutenberg** catalogs.

## Full Screen Walkthrough Video & Endpoint Verification
- **[`fable_ios_full_walkthrough.mp4`](./fable_ios_full_walkthrough.mp4)** — Screen recording stepping through welcome/authentication sheets, live library feed, classic prose reader (*Pride and Prejudice*), table of contents, display options, dark theme mode, explore filters, live search, genre and author sheets, writer's studio, and shelf/profile/settings views (`46.4s`, `588x1280` H.264 MP4, `26M`).
- **[`ENDPOINT_VERIFICATION.md`](./ENDPOINT_VERIFICATION.md)** — Live HTTP verification sweep across `33` endpoint calls covering health, community stories, genres, top authors, updates, Standard Ebooks catalog & chapters, Project Gutenberg catalog & chapters, MangaDex proxy routes, OpenAPI schema, auth lifecycle, story CRUD, shelf sync, and reading sessions/stats (`200`/`201`/`204`).

---

## Screenshot Index (25 Captures)

| # | File | Screen / State | Connected Backend API Endpoint(s) |
|---|---|---|---|
| 01 | [`01_welcome_screen.png`](./01_welcome_screen.png) | Welcome Gateway (`BOOKS & FABLES`) | — |
| 02 | [`02_auth_sign_in_sheet.png`](./02_auth_sign_in_sheet.png) | Sign In Modal Sheet | `POST /api/v1/auth/login`, `POST /api/v1/auth/password-reset/request` |
| 03 | [`03_auth_create_account_sheet.png`](./03_auth_create_account_sheet.png) | Create Account Modal Sheet | `POST /api/v1/auth/register` |
| 04 | [`04_library_filter_all.png`](./04_library_filter_all.png) | Library — Filter: `All` (*Pride and Prejudice*, *Dracula*, 24 titles) | `GET /api/v1/stories`, `GET /api/v1/public/standard-ebooks?topic=fiction`, `GET /api/v1/public/gutenberg?topic=fiction`, `GET /api/v1/updates` |
| 07 | [`07_library_filter_mystery.png`](./07_library_filter_mystery.png) | Library — Filter: `Mystery` (*The Adventures of Sherlock Holmes*, 1 title) | `GET /api/v1/public/standard-ebooks?topic=fiction`, `GET /api/v1/public/gutenberg?topic=fiction` |
| 08 | [`08_library_filter_fiction.png`](./08_library_filter_fiction.png) | Library — Filter: `Fiction` (*Pride and Prejudice*, *The Count of Monte Cristo*, 8 titles) | `GET /api/v1/public/standard-ebooks?topic=fiction`, `GET /api/v1/public/gutenberg?topic=fiction` |
| 12 | [`12_reader_fable_chapter_1.png`](./12_reader_fable_chapter_1.png) | Reader — Opening Title (*Pride and Prejudice*, Sepia, Ch. 1 • Page 1/6) | `GET /api/v1/public/standard-ebooks/chapters?book_id=jane-austen/pride-and-prejudice` |
| 13 | [`13_reader_classic_book_chapter_1.png`](./13_reader_classic_book_chapter_1.png) | Reader — Classic Book (*Pride and Prejudice*, Sepia, Ch. 1 • Page 1/6) | `GET /api/v1/public/standard-ebooks/chapters?book_id=jane-austen/pride-and-prejudice` |
| 14 | [`14_reader_table_of_contents_sheet.png`](./14_reader_table_of_contents_sheet.png) | Reader — Multi-Chapter Table of Contents Sheet (`I`–`V`+) | `GET /api/v1/public/standard-ebooks/chapters?book_id=jane-austen/pride-and-prejudice` |
| 15 | [`15_reader_display_options_sheet.png`](./15_reader_display_options_sheet.png) | Reader — Display Options (Typography & Theme) Sheet | Local `UserDefaults` + Dynamic Type |
| 16 | [`16_reader_dark_theme_mode.png`](./16_reader_dark_theme_mode.png) | Reader — Midnight Dark Theme Mode | Local `UserDefaults` + Pacing Engine |
| 17 | [`17_explore_discovery_all.png`](./17_explore_discovery_all.png) | Explore — Discovery Catalog (`All`, 14 derived categories) | `GET /api/v1/genres`, `GET /api/v1/authors/top` |
| 18 | [`18_explore_filter_under_5_mins.png`](./18_explore_filter_under_5_mins.png) | Explore — Filter: `Under 5 mins` | `GET /api/v1/stories`, `GET /api/v1/public/standard-ebooks`, `GET /api/v1/public/gutenberg` |
| 19 | [`19_explore_filter_community_favorites.png`](./19_explore_filter_community_favorites.png) | Explore — Filter: `Community Favorites` | `GET /api/v1/stories`, `GET /api/v1/public/standard-ebooks`, `GET /api/v1/public/gutenberg` |
| 20 | [`20_explore_filter_quick_reads.png`](./20_explore_filter_quick_reads.png) | Explore — Filter: `Quick Reads` | `GET /api/v1/stories`, `GET /api/v1/public/standard-ebooks`, `GET /api/v1/public/gutenberg` |
| 21 | [`21_explore_live_search_results.png`](./21_explore_live_search_results.png) | Explore — Live Search Query (`"Sherlock"`, 9 Standard Ebooks results) | `GET /api/v1/stories?search=Sherlock`, `GET /api/v1/public/standard-ebooks?search=Sherlock`, `GET /api/v1/public/gutenberg?search=Sherlock` |
| 22 | [`22_explore_genre_detail_view.png`](./22_explore_genre_detail_view.png) | Explore — Genre Detail View | `GET /api/v1/genres`, `GET /api/v1/public/standard-ebooks`, `GET /api/v1/public/gutenberg` |
| 23 | [`23_explore_author_detail_sheet.png`](./23_explore_author_detail_sheet.png) | Explore — Author Detail Sheet (`Various` live search loading state) | `GET /api/v1/authors/top`, `GET /api/v1/public/standard-ebooks?search=Various`, `GET /api/v1/public/gutenberg?search=Various` |
| 24 | [`24_write_studio_editor.png`](./24_write_studio_editor.png) | Writer's Studio — Manuscript Editor (*The Clockwork Nightingale*) | `POST /api/v1/stories`, `GET /api/v1/auth/me/stories` |
| 25 | [`25_shelf_tab_saved.png`](./25_shelf_tab_saved.png) | My Shelf — `Saved` Tab & Reading Journal Stats (*Pride and Prejudice*) | `GET /api/v1/shelf`, `GET /api/v1/auth/me/stats` |
| 26 | [`26_shelf_tab_finished.png`](./26_shelf_tab_finished.png) | My Shelf — `Finished` Tab (*Dracula*) | `POST /api/v1/shelf/sync` |
| 27 | [`27_shelf_tab_my_drafts.png`](./27_shelf_tab_my_drafts.png) | My Shelf — `My Drafts` Tab | `GET /api/v1/auth/me/stories` |
| 28 | [`28_profile_sheet.png`](./28_profile_sheet.png) | Guest Author Profile Modal Sheet | `GET /api/v1/auth/me`, `PATCH /api/v1/auth/me`, `DELETE /api/v1/auth/me` |
| 29 | [`29_settings_sheet.png`](./29_settings_sheet.png) | Settings & System Diagnostics Sheet | `GET /api/v1/health` |
| 30 | [`30_api_openapi_docs.png`](./30_api_openapi_docs.png) | FastAPI Swagger / OpenAPI Docs (`http://127.0.0.1:8001/docs`) | `GET /docs`, `GET /openapi.json` |

> **Note:** Library category filter captures `05` (`Fables`), `06` (`Classics`), `09` (`Gothic`), `10` (`Romance`), and `11` (`Adventure`) are skipped by `AUTO_UI_TOUR` when those exact category tags are not derived from the current live Standard Ebooks + Gutenberg fiction snapshot, while `07` (`Mystery`) and `08` (`Fiction`) are newly captured alongside Standard Ebooks titles.
