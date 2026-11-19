# Fable iOS: Final Capstone Defense & Presentation Guide

**Target Milestone:** Final Capstone Presentation & Technical Defense  
**Presenter:** Roosc Zaño (`@zanoroosc`)  
**Synced Baseline:** `main` (`f3f5b87`, PRs #44–#48)

---

## 1. 5-Minute Live Demo Flow ("The Hero Path")

1. **Opening Pitch (30s):** Present Fable as an offline-first, contract-first iOS reading and community publishing platform for open-source classics (Standard Ebooks & Project Gutenberg), fables, and original writing.
2. **Welcome & Runtime Server Switcher (`WelcomeView`):** Show Sign In, Create Account, Guest Mode, and the **`Server: … • Change`** pill for switching between a local laptop, an HTTPS tunnel, or Render Cloud without rebuilding.
3. **Zero-Baseline Shelf & Federated Library (`ShelfView` → `LibraryView`):** Show that new accounts start with authentic empty states, while Library federates Standard Ebooks, Project Gutenberg, and Fable Originals with `Live Cloud` / `Offline Cache` status and category filters.
4. **On-Demand Reading & Offline Download (`ReaderView`):** Open a multi-chapter classic (e.g., *Pride and Prejudice*), open the Table of Contents, and show **In-Book Search** plus **One-Tap Offline Download**.
5. **Typography, Highlights, Export & Audio:** Adjust **Display Options (`Aa`)** (font, Dynamic Type size, line spacing, 6 themes, brightness slider), long-press a passage to highlight/export (**Markdown** & **Quote Card**), and play **`AVSpeechSynthesizer`** narration with the regional voice picker.
6. **Community Publishing (`WriteView`):** Draft a short story with live word counting and read-time estimation, publish it, and open `StoryPublishedSheet`.
7. **Diagnostics & Session Isolation (`SettingsView` → `SystemDiagnosticsSheet`):** Run built-in health contracts and Sign Out to prove account/shelf isolation.

---

## 2. Tech Stack Summary

- **iOS Client:** Swift 5.10 / Swift 6 Concurrency (`@MainActor`, `async/await`), **SwiftUI** (iOS 17.0+), Modular **MVVM+S** vertical slices (`App/`, `Core/`, `Features/{Auth,Library,Reader,Shelf,Write}`), **Combine**, **SwiftData**, **`AVFoundation`** (`AVSpeechSynthesizer`), Apple **`Security`** (`KeychainStore`), `URLSession` + `DiskImageCache` (256 MiB cap), **XCTest**.
- **Backend API:** Python 3.9+, **FastAPI**, **Pydantic v2** (`serialization_alias` camelCase/snake_case parity), **Uvicorn**, **HTTPX** (Standard Ebooks & Gutendex/Project Gutenberg), **Pytest**.
- **Security & Auth:** Salted **PBKDF2-HMAC-SHA256** password hashing, **SHA-256** hashed 30-day bearer tokens, password recovery flow, rate-limiting middleware, sanitized error handlers.
- **Database & Hosting:** **SQLite 3** (local) + **PostgreSQL via Neon** (hosted), **Render** (`render.yaml`), **Docker**, **Cloudflare Tunnel** (`cloudflared`), **GitHub Actions CI**.

---

## 3. Setup & Wireless iPhone Usage

- **Mac / Fedora Linux Backend (one command):** `./scripts/start_wireless_server.sh` (creates `.venv`, starts Uvicorn on `0.0.0.0:8001` with `FABLE_ENV=development`, and opens a `trycloudflare.com` HTTPS tunnel).
- **Windows Backend:** Run `uvicorn main:app --host 0.0.0.0 --port 8001` from `backend/` with `FABLE_ENV=development` alongside `cloudflared tunnel --no-autoupdate --url http://127.0.0.1:8001` (or use Render Cloud).
- **iOS Client (Xcode on Mac):** `open frontend/FableApp.xcodeproj` → scheme `FableApp` → iPhone Simulator (iOS 17.0+) or physical iPhone → `Cmd+R`.
- **Switch Server on iPhone (no Mac needed):** Tap **`Server: … • Change`** on `WelcomeView` or **Shelf ➔ Settings ➔ Backend Server URL** and enter your HTTPS tunnel URL, LAN IP (`http://<ip>:8001/api/v1`), or tap **Use Render Cloud** (`https://fable-api-cbo8.onrender.com/api/v1`).

---

## 4. Midterm (50%) vs. Final State Comparison

| Area | Midterm Baseline (50% Milestone) | Final State (`main`) |
|---|---|---|
| **Catalog & Content** | Demo/bundled catalog and local art | Live federated **Standard Ebooks** + **Project Gutenberg** + **Fable Originals**, on-demand chapter hydration, **UUIDv5** edition disambiguation, zero-baseline accounts |
| **Auth & Security** | Basic local profile/session | **PBKDF2-HMAC-SHA256** hashing, **SHA-256** 30-day Keychain bearer sessions, password recovery, account/device shelf isolation, rate limits |
| **Database & Hosting** | Local SQLite only | Dual **SQLite + Neon PostgreSQL**, **Render Cloud** (`render.yaml`), Docker/OCI, encrypted backup scripts |
| **Architecture & UI** | Flat `Views/`/`ViewModels/`, parchment-only | Feature-driven vertical slices (**MVVM+S**), Electric Indigo UI, runtime **Backend Server URL switcher**, Manga feature-flagged off (`isMangaEnabled = false`) |
| **Reader Capabilities** | Single-text reader + basic display/TTS | Multi-chapter TOC, **in-book search**, **one-tap offline download**, **long-press marginalia**, **Markdown & Quote Card export**, brightness slider, dynamic chapter audio + voice picker |
| **Testing & CI** | Manual UI verification | **Pytest** backend suite + **XCTest** iOS suite + **GitHub Actions CI** + in-app `SystemDiagnosticsSheet` |
