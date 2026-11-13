# Live Backend Endpoint Verification Report

Recorded against local FastAPI server (`http://127.0.0.1:8001`) on `feat/plans-01-04-remediation`.

| Method | Endpoint | HTTP | Latency (ms) | Response Summary |
|---|---|---:|---:|---|
| `GET` | `/api/v1/health` | `200` | 8.8 | object(status, database, timestamp_utc) |
| `GET` | `/api/v1/stories` | `200` | 2.5 | 0 items |
| `GET` | `/api/v1/genres` | `200` | 2.0 | 0 items |
| `GET` | `/api/v1/authors/top` | `200` | 301.7 | 6 items (first='Various') |
| `GET` | `/api/v1/updates` | `200` | 7.3 | object(taleOfTheDay, curatorSpotlight, recentSubmissions, totalStories, timestampUtc) |
| `GET` | `/api/v1/public/standard-ebooks?topic=fiction` | `200` | 2.3 | 12 items (first='Pride and Prejudice') |
| `GET` | `/api/v1/public/standard-ebooks?search=Sherlock` | `200` | 1.5 | 9 items (first='The Casebook of Sherlock Holmes') |
| `GET` | `/api/v1/public/standard-ebooks/chapters?book_id=jane-austen/pride-and-prejudice` | `200` | 4.3 | 61 items (first='I') |
| `GET` | `/api/v1/public/gutenberg?topic=fiction` | `200` | 4019.1 | 12 items (first="Alice's Adventures in Wonderland") |
| `GET` | `/api/v1/public/gutenberg?search=Sherlock` | `200` | 3484.2 | 12 items (first='Sherlock Holmes: De Agra-Schat') |
| `GET` | `/api/v1/public/gutenberg/11` | `200` | 1727.3 | object(id, title, author, genre, chapter, synopsis) |
| `GET` | `/api/v1/public/gutenberg/11/chapters` | `200` | 7.4 | 12 items (first='CHAPTER I.') |
| `GET` | `/api/v1/public/manga?search=one` | `200` | 4.6 | 20 items (first='Tennis no Oujisama - Onecoin Reserve (Doujinshi)') |
| `GET` | `/openapi.json` | `200` | 4.0 | object(openapi, info, paths, components) |
| `GET` | `/api/v1/public/manga/595e3a7a-c762-4f87-90ee-a7dc0dabef91` | `200` | 444.6 | object(id, title, author, genre, chapter, synopsis) |
| `GET` | `/api/v1/public/manga/595e3a7a-c762-4f87-90ee-a7dc0dabef91/chapters` | `200` | 1047.7 | 1 items (first='Oneshot') |
| `POST` | `/api/v1/auth/register` | `201` | 187.0 | object(accessToken, tokenType, user) |
| `POST` | `/api/v1/auth/login` | `200` | 151.9 | object(accessToken, tokenType, user) |
| `GET` | `/api/v1/auth/me` | `200` | 3.4 | object(id, email, name, handle, bio, avatarImageName) |
| `PATCH` | `/api/v1/auth/me` | `200` | 7.9 | object(id, email, name, handle, bio, avatarImageName) |
| `POST` | `/api/v1/stories` | `201` | 18.6 | object(id, title, author, genre, chapter, synopsis) |
| `GET` | `/api/v1/stories/fd1ba13b-1ca4-4c96-aae8-bb8176c5920e` | `200` | 4.3 | object(id, title, author, genre, chapter, synopsis) |
| `GET` | `/api/v1/stories/fd1ba13b-1ca4-4c96-aae8-bb8176c5920e/chapters` | `200` | 2.4 | 1 items (first='Chapter I: Smoke') |
| `GET` | `/api/v1/stories/fd1ba13b-1ca4-4c96-aae8-bb8176c5920e/chapters/1` | `200` | 2.4 | object(id, storyId, chapterNumber, title, content, wordCount) |
| `PATCH` | `/api/v1/stories/fd1ba13b-1ca4-4c96-aae8-bb8176c5920e` | `200` | 8.3 | object(id, title, author, genre, chapter, synopsis) |
| `GET` | `/api/v1/auth/me/stories` | `200` | 4.3 | 1 items (first='Ephemeral Verification Tale') |
| `GET` | `/api/v1/shelf?deviceId=aaaedf9f-8ab4-4cdf-9b11-ac0edce3d81e` | `200` | 2.9 | 0 items |
| `POST` | `/api/v1/shelf/sync` | `200` | 8.4 | object(status, reconciledItems, serverTimeUtc) |
| `POST` | `/api/v1/auth/me/reading-sessions` | `204` | 8.1 | text(0 chars) |
| `GET` | `/api/v1/auth/me/stats` | `200` | 4.0 | object(storiesReadCount, totalMinutesRead, streakDays) |
| `DELETE` | `/api/v1/stories/fd1ba13b-1ca4-4c96-aae8-bb8176c5920e` | `204` | 7.3 | text(0 chars) |
| `POST` | `/api/v1/auth/logout` | `204` | 7.3 | text(0 chars) |
| `DELETE` | `/api/v1/auth/me` | `204` | 9.9 | ephemeral user cleaned up |
