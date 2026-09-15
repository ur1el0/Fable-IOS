# Feature Plan 06: Automated Unit & Integration Testing Suite (XCTest)

**Document Version:** 1.0.0  
**Architectural Scope:** Quality Assurance, Test-Driven Development (TDD), Regression Prevention  
**Target Framework:** Apple XCTest Framework (iOS 17.0+, Swift 5.9+)  
**Engineering Discipline:** Enterprise Software Quality & Verification Architecture  

---

## 1. Executive Summary & Verification Tenets

### 1.1 The Necessity of Automated Verification
As Fable expands across persistence layers, pacing engines, and authentication controllers, manual verification alone cannot guarantee system integrity. Regressions in reading time calculations, session state restoration, or database transactional boundaries could compromise user trust.

### 1.2 Architectural Invariants
1. **Zero Flakiness:** All tests execute deterministically in-memory without depending on network availability or external filesystems.
2. **Sub-Second Execution:** The complete test suite must execute in $<3.0\text{ seconds}$ on macOS hardware.
3. **Isolated Memory Containers:** Database tests execute against an in-memory `ModelContainer` (`isStoredInMemoryOnly: true`), ensuring zero side effects on the device's persistent SQLite database.
4. **Boundary & Negative Testing:** Tests explicitly assert both expected success paths and negative edge cases (invalid email formats, short passwords, out-of-bounds reading velocity).

---

## 2. Test Suite Architecture & Coverage Matrix

```
┌─────────────────────────────────────────────────────────────┐
│                      FableAppTests Target                   │
└─────────────────────────────────────────────────────────────┘
                               │
       ┌───────────────────────┼───────────────────────┐
       ▼                       ▼                       ▼
┌──────────────┐       ┌──────────────┐       ┌──────────────┐
│  AuthManager │       │ PacingEngine │       │ Persistence  │
│    Tests     │       │    Tests     │       │Service Tests │
└──────────────┘       └──────────────┘       └──────────────┘
```

| Test Class | Target Component | Core Verification Objectives |
|---|---|---|
| **`AuthManagerTests`** | [`AuthManager`](file:///Users/maclab/Documents/roosc/Fable-iOS/frontend/FableApp/Controllers/AuthManager.swift#L5) | Email format validation, password length ($\ge 6$), guest mode session generation, sign-out cache clearance. |
| **`PacingEngineTests`** | [`PacingEngine`](file:///Users/maclab/Documents/roosc/Fable-iOS/frontend/FableApp/Controllers/PacingEngine.swift#L5) | Rolling word rate estimation, velocity clamping ($100 \le \text{WPM} \le 600$), remaining minutes computation. |
| **`PersistenceServiceTests`** | [`PersistenceService`](file:///Users/maclab/Documents/roosc/Fable-iOS/frontend/FableApp/Services/PersistenceService.swift#L10) | SwiftData in-memory transactional insert, query filtering, cascade deletion of annotations, reading log rollups. |
| **`StoryStoreTests`** | [`StoryStore`](file:///Users/maclab/Documents/roosc/Fable-iOS/frontend/FableApp/StoryStore.swift#L10) | Bookmark toggling, category filtering, reading progress calculation, living streak calculations. |

---

## 3. Concrete Test Case Specifications

### 3.1 AuthManager Unit Tests (`AuthManagerTests.swift`)

```swift
import XCTest
@testable import FableApp

@MainActor
final class AuthManagerTests: XCTestCase {
    var authManager: AuthManager!
    
    override func setUp() {
        super.setUp()
        authManager = AuthManager()
        authManager.signOut() // Start clean
    }
    
    func testSignIn_RejectsInvalidEmail() async {
        let success = await authManager.signIn(email: "notanemail", password: "password123")
        XCTAssertFalse(success)
        XCTAssertEqual(authManager.authErrorMessage, "Please enter a valid email address.")
        XCTAssertFalse(authManager.isAuthenticated)
    }
    
    func testSignIn_RejectsShortPassword() async {
        let success = await authManager.signIn(email: "valid@fable.app", password: "123")
        XCTAssertFalse(success)
        XCTAssertEqual(authManager.authErrorMessage, "Password must be at least 6 characters.")
        XCTAssertFalse(authManager.isAuthenticated)
    }
    
    func testContinueAsGuest_CreatesGuestSession() {
        authManager.continueAsGuest()
        XCTAssertTrue(authManager.isAuthenticated)
        XCTAssertTrue(authManager.isGuestMode)
        XCTAssertEqual(authManager.currentSession?.name, "Guest Reader")
    }
}
```

### 3.2 PacingEngine Unit Tests (`PacingEngineTests.swift`)

```swift
import XCTest
@testable import FableApp

final class PacingEngineTests: XCTestCase {
    var engine: PacingEngine!
    
    override func setUp() {
        super.setUp()
        engine = PacingEngine()
    }
    
    func testEstimatedMinutes_ComputesReasonablePace() {
        // At baseline 200 WPM, a 1,000-word chapter should take 5 minutes
        let minutes = engine.estimatedMinutesRemaining(remainingWords: 1000)
        XCTAssertEqual(minutes, 5)
    }
    
    func testRollingVelocity_ClampsExtremeOutliers() {
        // Extreme fast reading should clamp at max 600 WPM
        engine.recordReadingPace(wordsRead: 1000, elapsedSeconds: 10)
        XCTAssertLessThanOrEqual(engine.currentWPM, 600)
        
        // Extreme slow reading should clamp at minimum 100 WPM
        engine.recordReadingPace(wordsRead: 5, elapsedSeconds: 300)
        XCTAssertGreaterThanOrEqual(engine.currentWPM, 100)
    }
}
```

---

## 4. Execution & CI Integration

The test suite is executed directly via `xcodebuild`:

```bash
xcodebuild test \
  -project frontend/FableApp.xcodeproj \
  -scheme FableApp \
  -destination 'generic/platform=iOS Simulator'
```
