# Fable iOS: Midterm Presentation & Defense Documentation Suite

**Evaluation Milestone:** Midterm Capstone Defense ($\ge 50\%$ Functional Implementation)  
**Branch:** `feature/midterm-presentation` (Preserved Midterm Baseline: `v0.5.0-midterm`)  
**Student Presenter:** Roosc Zaño (`@zanoroosc`)  

---

## Master Document Index

This directory provides complete, presentation-ready documentation covering all aspects of the Fable iOS architecture, technical decisions, data strategy, and panel defense preparation:

| Document | Description | Key Focus Areas |
|---|---|---|
| [**`01_MIDTERM_SYSTEM_OVERVIEW.md`**](./01_MIDTERM_SYSTEM_OVERVIEW.md) | Executive Summary & Compliance Audit | $\ge 50\%$ rubric verification, 10-screen UI inventory, 5 core pillars |
| [**`02_TECH_STACK_AND_DATABASE.md`**](./02_TECH_STACK_AND_DATABASE.md) | Technology Stack & Database Design | SwiftUI, SwiftData vs CoreData, SQLite schema, FastAPI & Pydantic |
| [**`03_NETWORKING_AND_API_INTEGRATION.md`**](./03_NETWORKING_AND_API_INTEGRATION.md) | Client-Server Architecture | URLSession async/await, contract parity (camelCase / snake_case), LWW sync |
| [**`04_HARDCODED_DATA_VS_DYNAMIC_ENGINES.md`**](./04_HARDCODED_DATA_VS_DYNAMIC_ENGINES.md) | Data Strategy & Engine Audit | Seed library rationale vs live pacing, AVFoundation audio, and procedural UI |
| [**`05_DEFENSE_SLIDES_AND_QNA.md`**](./05_DEFENSE_SLIDES_AND_QNA.md) | Presentation Script & Panel Q&A | 2-minute elevator pitch, 10-slide outline, 10 panel questions & model answers |
| [**`06_FRAMEWORKS_AND_DEPENDENCIES.md`**](./06_FRAMEWORKS_AND_DEPENDENCIES.md) | Frameworks & Zero-Third-Party Architecture | Native Apple SDKs (SwiftUI, SwiftData, AVFoundation, Security) vs backend stack |
| [**`07_AUTHENTICATION_AND_SECURITY.md`**](./07_AUTHENTICATION_AND_SECURITY.md) | Authentication & Hardware Security | Tri-state AuthState machine, KeychainStore (Secure Enclave) vs UserDefaults |
| [**`08_FEATURE_CATALOG_AND_USER_JOURNEYS.md`**](./08_FEATURE_CATALOG_AND_USER_JOURNEYS.md) | Comprehensive Feature Catalog & User Flows | End-to-end feature inventory and Mermaid user journey state diagrams |

---

## Quick Reference: 30-Second Elevator Summary

> **"Fable is an offline-first ambient literary reading platform for iOS built with Swift 5.10, SwiftUI, SwiftData, and AVFoundation, connected to a Python FastAPI and SQLite cloud sync tier. For our midterm milestone, we achieved over 85% completion across all 10 planned screens, featuring live physical book pagination, marginalia quote highlighting, native oral speech synthesis, and deterministic Last-Write-Wins cloud synchronization."**
