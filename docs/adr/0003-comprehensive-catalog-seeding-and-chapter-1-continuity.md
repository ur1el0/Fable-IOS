# ADR 0003: Unified multi-chapter catalog seeding and Chapter 1 continuity guarantee

- **Status:** Accepted
- **Date:** 2026-11-10

## Context

Previously, catalog items fetched dynamically from live external providers (such as Gutendex or MangaDex) could either fail when campus/lab Wi-Fi was restricted, return single-blob texts without chapter navigation, or return only late-volume chapters (such as Chapter 109+) when upstream feeds sorted descending or lacked early chapters. Users opening a book or fable expected every title in the catalog to open reliably at **Chapter 1** with a navigable Table of Contents (`chapters: [StoryChapterDTO]`).

## Decision

1. Maintain a canonical, version-controlled seed catalog in `data/curated_catalog.json` generated and verified via `scripts/seed_comprehensive_catalog.py`.
2. Automatically upsert all curated catalog entries and their structured `chapters_json` arrays during SQLite initialization (`init_db()` in `backend/core/database.py`).
3. Enforce a strict **Chapter 1 Continuity Invariant**:
   - Every seeded and ingested story must contain a non-empty `chapters` array sorted in ascending order (`chapterNumber: 1, 2, ...`) where the first chapter is guaranteed to be `chapterNumber == 1`.
   - `ReaderView.swift` and `MangaReaderView.swift` sort chapters ascending by `chapterNumber` and default unread stories to Chapter 1 (`index == 0`).

## Consequences

- **Positive:** Deterministic offline-first and local-backend behavior across Mac lab machines and laptops—every book, fable, folklore tale, and classic novel opens immediately at Chapter 1 with multi-chapter Table of Contents support.
- **Positive:** Enforced by automated tests in `backend/tests/test_api_v1.py` (`100/100 passed`).
- **Trade-off:** `data/curated_catalog.json` adds ~2 MB of structured JSON text to the repository, which is well within Git comfort limits and eliminates cold-boot dependency on external APIs.
