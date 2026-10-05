# Project Instructions

## Project

Fable is a native iOS reading and writing app with a FastAPI backend. Keep the client usable with its locally persisted state when the backend is unavailable.

## Tech Stack

- iOS 17+ app built with SwiftUI; Xcode project: `frontend/FableApp.xcodeproj`.
- Swift language mode is 5.0 in the project build settings.
- Local client persistence uses SwiftData. HTTP requests use URLSession.
- Backend uses Python 3.11, FastAPI, Pydantic v2, and SQLite.
- API dependencies and supported minimum versions are listed in `backend/requirements.txt`.

## Architecture

- `FableApp.swift` installs the SwiftData model container; `ContentView.swift` coordinates authentication state and app tabs.
- Feature views live under `frontend/FableApp/Features/`. Keep views focused on presentation and route state changes or network work through the existing store, manager, or service.
- `StoryStore` coordinates catalog, reading, shelf, and local persistence state. `AuthManager` coordinates sessions; `KeychainStore` stores credentials.
- Keep API transport behind `StoryAPIServiceProtocol`; its implementation is `StoryAPIService`.
- Backend requests flow from `backend/api/v1/endpoints/` through Pydantic schemas and `backend/services/` to SQLite via `backend/core/database.py`.
- Keep Swift Codable models and Pydantic DTO aliases aligned with the camelCase JSON API contract.
- SQLite tables are initialized and compatibly extended in `backend/core/database.py`. Preserve existing data when changing schema.

## Project Structure

- `frontend/FableApp/App/` — app lifecycle and root navigation
- `frontend/FableApp/Core/` — shared theme, components, cache, and security
- `frontend/FableApp/Features/` — Auth, Library, Reader, Shelf, and Write
- `backend/api/v1/` — versioned API router and endpoints
- `backend/models/`, `backend/schemas/`, `backend/services/` — backend data and application layers
- `docs/` — architecture, plans, runbooks, and project documentation

## Code Style

- Follow the existing feature-based organization and local naming patterns.
- Swift types and files use PascalCase; Python modules and functions use `snake_case`.
- Use async/await for asynchronous client and provider I/O.
- Validate backend input through Pydantic request models. Derive ownership and other server-controlled values from the authenticated session.
- Keep account-scoped reads and writes filtered by the authenticated user in backend services.
- Do not place credentials or real secrets in source, fixtures, or documentation.

## Verification and Common Tasks

- Backend tests: `pytest backend/test_main.py -v`
- Start the backend from `backend/`: `uvicorn main:app --reload --host 127.0.0.1 --port 8000`
- Open the iOS project on macOS: `open frontend/FableApp.xcodeproj`; select the `FableApp` scheme and an iOS 17+ simulator in Xcode.
- GitHub Actions currently runs the backend test suite and builds the Docker image. The Swift `Features/*/Tests` files are in-app diagnostic helpers, not an Xcode XCTest target.

## Documentation Notes

Some older documentation describes strict MVC or lists a `Package.swift`; the current app root uses `StoryStore` and the repository has no Swift package manifest. Confirm implementation details in source before relying on older architecture diagrams or file inventories.

## Git

- Use a feature branch; do not push commits directly to `main`.
- Recent commit subjects use concise conventional prefixes such as `feat:`, `fix:`, and `docs:`.
- Keep commits focused and list the exact changed file paths when reporting them.
