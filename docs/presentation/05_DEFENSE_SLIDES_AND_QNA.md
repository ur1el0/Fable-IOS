# Fable iOS: Presentation Slide Deck, Elevator Pitch & Panel Q&A

**Document Version:** 1.0.0  
**Target Milestone:** Midterm Presentation & Technical Defense  
**Presenter:** Roosc Zaño (`@zanoroosc`)  

---

## 1. The 2-Minute Elevator Pitch (Verbatim Script)

> *"Good morning, esteemed panel and professors. My name is Roosc Zaño, and today I am presenting **Fable**, an offline-first ambient literary reading and community publishing platform for iOS.*
> 
> *In today's digital landscape, reading applications have become noisy, cloud-dependent social feeds that interrupt deep focus. Furthermore, classical literature and regional folklore—which were originally born as oral storytelling traditions—have lost their spoken accompaniment.*
> 
> *Fable solves this by combining three core architectural innovations:*
> *First, an **offline-first local persistence architecture** powered by SwiftData and SQLite, giving readers 100% feature parity even on airplane mode or unstable campus Wi-Fi.*
> *Second, an **ambient reader engine** with dynamic book pagination, marginalia quote highlighting, and an **AVFoundation oral speech synthesizer** that reads aloud with live paragraph synchronization.*
> *Third, a **contract-first cloud synchronization tier** built with Python FastAPI and SQLite, using a Last-Write-Wins conflict resolution algorithm to reconcile reading progress across multiple devices.*
> 
> *For our midterm milestone, the rubric required at least 50% interface and functional implementation. I am proud to report that Fable has achieved **over 85% completion**: all 10 planned screens are fully interactive, the 5 core technical pillars are operational, and the app runs with zero external friction in Xcode. Let us proceed with the live demonstration."*

---

## 2. 10-Slide Presentation Outline

### Slide 1: Title & Introduction
- **Header:** FABLE: Ambient Literary Reading & Community Publishing Platform
- **Sub-bullets:**
  - Capstone Midterm Technical Defense ($\ge 50\%$ Evaluation)
  - Student Presenter: Roosc Zaño
  - Tech Focus: Swift 5.10, SwiftUI, SwiftData, AVFoundation, FastAPI, SQLite3

### Slide 2: The Problem Space
- **Three Friction Points:**
  1. *Connectivity Fragility:* Reading apps that freeze without internet.
  2. *Digital Noise:* Commercial reading apps overloaded with ads and social bloat.
  3. *Lost Oral Heritage:* Traditional folklore disconnected from spoken narration.

### Slide 3: The Architectural Solution
- High-level topology diagram showing the iOS Client (SwiftUI + SwiftData) communicating asynchronously with the FastAPI Cloud Sync tier.
- Emphasize the **Dual-Track Data Strategy**: Guaranteed in-memory resilience for testing, backed by live algorithmic engines.

### Slide 4: Midterm Scope Compliance (10 of 10 Screens)
- Visual breakdown of the complete 10-screen interface:
  - *Onboarding:* Welcome, Sign In, Sign Up.
  - *Discovery:* Explore Feed (Tale of the Day, Spotlight), Library Catalog, Genre Detail.
  - *Deep Reading:* Ambient Reader, Display Options Sheet.
  - *Scholarship & Creation:* Personal Shelf (Quote Deck), Story Composer (`WriteView`), Profile & Settings.

### Slide 5: Pillar 1 & 2 — Local Persistence & Marginalia
- **SwiftData + SQLite:** Moving beyond volatile state into ACID-compliant local database transactions.
- **Marginalia Engine:** Selecting text ranges, applying amber/terracotta highlights, and pinning quotes to the personal shelf journal.

### Slide 6: Pillar 3 & 4 — Pacing Engine & Oral Audio Synthesizer
- **Pacing Engine:** Algorithm that chunks raw text into physical book pages and calculates live Words-Per-Minute (WPM).
- **Audio Synthesizer:** Native `AVSpeechSynthesizer` delegate synchronizing spoken utterances with real-time text highlighting.

### Slide 7: Tech Stack & Database Schema
- **Why SwiftData over CoreData/Realm:** Macro-based `@Model`, zero binary overhead, native concurrency.
- **Why FastAPI + SQLite:** Asynchronous REST execution, auto-generated OpenAPI contracts, zero-configuration embedded storage.
- Relational schema: `stories` $\leftrightarrow$ `chapters` $\leftrightarrow$ `shelf_items`.

### Slide 8: Contract-First API & Last-Write-Wins (LWW) Sync
- **Contract Parity:** How Pydantic's `serialization_alias` bridges Python `snake_case` with Swift `camelCase`.
- **LWW Synchronization:** Deterministic edge-to-cloud conflict resolution using ISO 8601 UTC timestamps.

### Slide 9: Live Demonstration Runbook
- Step 1: Launch app $\rightarrow$ Welcome screen $\rightarrow$ Guest access.
- Step 2: Explore feed $\rightarrow$ Browse *Dracula* $\rightarrow$ Open Ambient Reader.
- Step 3: Switch theme to Noir $\rightarrow$ Adjust font size $\rightarrow$ Observe dynamic pagination.
- Step 4: Highlight quote $\rightarrow$ Tap "Save to Shelf".
- Step 5: Start Oral Audio Narration $\rightarrow$ Observe synchronized paragraph highlight.
- Step 6: Navigate to Shelf $\rightarrow$ Verify saved quote deck and reading analytics.

### Slide 10: Conclusion & Final Milestone Roadmap
- Midterm status: Exceeded 50% target (~85% complete).
- Final Milestone objectives: Live Project Gutenberg ingestion, multi-device cloud deployment, and advanced reading analytics.

---

## 3. Anticipated Panel Questions & High-Scoring Technical Answers

### Q1: "Why did you choose SwiftData instead of CoreData or Realm?"
> **Answer:** *"CoreData relies on legacy Objective-C runtime conventions and XML `.xcdatamodeld` mapping files, which are prone to merge conflicts and lack compile-time type safety. Realm, while capable, introduces a heavyweight third-party binary dependency. SwiftData is Apple's native, modern framework introduced in iOS 17. It uses the `@Model` macro for pure Swift declarations, integrates seamlessly with Swift concurrency, and compiles to an optimized on-device SQLite database with zero external binary bloat."*

### Q2: "What happens if the user loses internet connection while reading?"
> **Answer:** *"Fable was engineered specifically with an offline-first architecture. All story texts, reader preferences, annotations, and reading session logs are persisted locally in SwiftData and SQLite. The reader engine, pagination algorithm, and AVFoundation audio synthesizer require zero internet connectivity. When a connection is re-established, the app's synchronization service reconciles local progress with the cloud in the background."*

### Q3: "How does your cloud sync handle conflicts if two devices update reading progress simultaneously?"
> **Answer:** *"We implement a deterministic Last-Write-Wins (LWW) conflict resolution algorithm. Every shelf update payload includes an ISO 8601 UTC timestamp (`updated_at_utc`). The FastAPI backend compares the incoming client timestamp against the stored server timestamp. If the client's timestamp is newer, the database is updated; if the server record is newer, the client is instructed to update its local state with the authoritative server record. This guarantees eventual consistency without requiring complex distributed consensus overhead."*

### Q4: "Is your text-to-speech narration using an external cloud API like ElevenLabs or OpenAI?"
> **Answer:** *"No. We intentionally utilized Apple's native `AVFoundation` framework (`AVSpeechSynthesizer`). Cloud voice APIs introduce subscription costs, rate limits, and network latency that would break the offline reading experience. By utilizing `AVSpeechSynthesizer` on-device, narration operates with zero latency, zero cloud costs, and complete privacy, even on airplane mode."*

### Q5: "How do you handle differences between Python's `snake_case` and Swift's `camelCase` conventions?"
> **Answer:** *"We enforce strict contract parity using Pydantic v2. In our backend schemas, fields are annotated with `serialization_alias` (for example, `read_time_minutes` serializes to `readTimeMinutes`). When FastAPI produces JSON, it outputs camelCase keys that perfectly match Swift's `Codable` structs, eliminating contract mismatches without violating Python's PEP 8 naming standards."*

### Q6: "Why did you create procedural book covers instead of downloading image files?"
> **Answer:** *"In academic lab evaluations across different iOS Simulators, bundled bitmap assets (`.png`, `.jpg`) frequently fail to load due to case-sensitivity mismatches or missing asset catalog links. Our procedural visual engine generates atmospheric vector covers using SwiftUI linear gradients, borders, and typography stamped with the story's genre. This ensures 100% visual reliability with zero risk of broken image boxes."*

### Q7: "How is user session and authentication handled securely on iOS?"
> **Answer:** *"Authentication tokens and user credentials are stored using Apple's native `Security` framework in the iOS hardware-backed Keychain (`KeychainStore.swift`). We strictly prohibited storing tokens in `UserDefaults` because `UserDefaults` stores unencrypted plaintext plist files on disk that can be compromised on jailbroken devices. Keychain encrypts items using the device's Secure Enclave."*

### Q8: "How does your pagination algorithm chunk manuscripts into pages?"
> **Answer:** *"Our `PacingEngine` measures the manuscript text by identifying natural paragraph breaks and sentence boundaries. It targets a comfortable reading density of approximately 180 to 220 words per page. Whenever the user alters font size, line spacing, or window geometry, the engine dynamically recalculates the page splits and updates the total page count in real time."*

### Q9: "What was completed for the midterm vs. what remains for the final milestone?"
> **Answer:** *"For the midterm, we prioritized complete UI implementation (10 of 10 screens), local SwiftData persistence, reader pagination, oral audio narration, marginalia quote highlights, and the initial sync protocol—achieving ~85% total scope. For the final milestone, we are deploying live Project Gutenberg literature ingestion, expanding multi-chapter folio navigation, and connecting bidirectional cloud sync to a remote hosted server."*

### Q10: "How do you avoid overgrown 'God files' in SwiftUI?"
> **Answer:** *"We enforce strict MVVM separation of concerns. SwiftUI views are purely declarative presentation surfaces (`UI = f(state)`). All business logic, state mutations, and API requests are delegated to specialized ViewModels (`AuthViewModel`, `StoryStore`) and domain services (`StoryAPIService`, `PersistenceService`, `PacingEngine`). UI components are modularized into reusable sub-views like `FableImageView` and `DisplayOptionsSheet`."*
