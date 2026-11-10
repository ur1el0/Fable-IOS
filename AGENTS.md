# Fable iOS — Agent Entrypoint (`AGENTS.md`)

Welcome! If you are an AI coding agent resuming work on this repository on the developer's laptop, **read these two files immediately before making any edits**:

1. **[`docs/AGENT_HANDOFF_CONTEXT.md`](./docs/AGENT_HANDOFF_CONTEXT.md)** — Full session context, recent commit history (`0c9dfc1` through `c5d9631`), architectural invariants (including why `StoryStore.isMangaEnabled = false`), exact file/line references, and compiler/runtime gotchas.
2. **[`docs/plans/06_SECURITY_VULNERABILITIES_AND_ARCHITECTURE_REMEDIATION.md`](./docs/plans/06_SECURITY_VULNERABILITIES_AND_ARCHITECTURE_REMEDIATION.md)** — The 4-Phase Security & Architecture Hardening Plan ready for execution (`SEC-01`–`SEC-04`, `PERF-01`–`PERF-03`, `DOM-01`–`DOM-02`, `IOS-01`–`IOS-02`).

## Additional Reference Docs
- **[`docs/DATA_SOURCES_AND_API_STRATEGY.md`](./docs/DATA_SOURCES_AND_API_STRATEGY.md)** — Catalog seeding architecture, Chapter 1 continuity invariant, and upstream manga licensing/chapter-gap notes.
- **[`docs/adr/0002-ios-open-source-literature-focus-and-manga-feature-flag.md`](./docs/adr/0002-ios-open-source-literature-focus-and-manga-feature-flag.md)** — ADR 0002: Why Manga is feature-flagged off on iOS (`StoryStore.isMangaEnabled = false`).
- **[`docs/adr/0003-comprehensive-catalog-seeding-and-chapter-1-continuity.md`](./docs/adr/0003-comprehensive-catalog-seeding-and-chapter-1-continuity.md)** — ADR 0003: Canonical multi-chapter catalog seeding (`data/curated_catalog.json`) and Chapter 1 guarantee.
- **[`docs/simulator_captures/README.md`](./docs/simulator_captures/README.md)** — 29 full-screen iOS Simulator screenshots across every view/modal/filter and a full walkthrough video (`fable_ios_full_walkthrough.mp4`).
