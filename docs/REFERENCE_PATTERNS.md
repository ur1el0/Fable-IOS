# Reference Architecture Patterns & System Design Guidelines

**Document Version:** 1.0.0  
**Source Baseline:** [`reference/Provision`](../reference/Provision)  
**Target Repository:** Fable iOS (`FableApp`)  
**Audience:** AI Subagents, Core Engineers, and System Architects  
**Purpose:** Serves as the authoritative architectural blueprint for directory structure, authentication state machines, native hardware security, and user interaction logic across the Fable iOS codebase.

---

## 1. Executive Summary & Architectural Heritage

The reference project [`reference/Provision/frontend/frontend`](../reference/Provision/frontend/frontend) establishes a clean, enterprise-grade iOS application architecture adhering strictly to **Model-View-ViewModel (MVVM)**, Apple Human Interface Guidelines (HIG), and iOS Security framework best practices.

To achieve enterprise uniformity, maintainability, and data security, all AI agents and contributors must adhere to the patterns documented herein when authoring or refactoring features for **Fable**.

```text
reference/Provision/frontend/frontend/ (Gold Standard Architecture)
├── Core/
│   ├── APIClient.swift        # HTTP networking pipeline & bearer token injection
│   ├── KeychainStore.swift    # Hardware-backed Secure Enclave credential storage
│   └── Theme.swift            # Design tokens, semantic colors, card view modifiers
├── Models/
│   ├── User.swift             # Identity, session, and domain data contracts
│   └── ...                    # Domain entities
├── ViewModels/
│   ├── AuthViewModel.swift    # Reactive AuthState machine & session lifecycle
│   └── ...                    # Domain-specific state controllers
├── Views/
│   ├── LoginView.swift        # Card-based container, standard inputs, error banners
│   ├── RegisterView.swift     # Registration card, password confirmation, validation
│   └── ...                    # Modular SwiftUI presentation surfaces
├── ContentView.swift          # Root state-driven router
└── frontendApp.swift          # Application lifecycle entry point
```

---

## 2. Standardized Directory & Namespace Topology

All iOS code residing in `frontend/FableApp/` must conform to this structured layout:

### 2.1 Directory Responsibilities
* **`Core/`**: Low-level foundational services, cryptographic storage, network pipelines, and design system styling tokens:
  * [`KeychainStore.swift`](file:///Users/maclab/Documents/roosc/Fable-IOS/frontend/FableApp/Core/KeychainStore.swift) — Apple `Security` framework wrapper for secure tokens.
  * [`Theme.swift`](file:///Users/maclab/Documents/roosc/Fable-IOS/frontend/FableApp/Theme.swift) — Color palettes, typography definitions, and card view modifiers (`.fableCard()`).
  * Networking pipelines & API gateways.
* **`Models/`**: Pure data structs, Codable transfer objects (DTOs), and value types. No UI dependencies.
* **`ViewModels/`**: Reactive `ObservableObject` classes managing domain logic, validation state, asynchronous API interactions, and user mutation lifecycles.
* **`Views/`**: Declarative SwiftUI presentation components. Views must delegate business operations and mutations to ViewModels or Services rather than executing inline network calls.

> [!IMPORTANT]
> **Xcode Synchronized Groups:** `FableApp.xcodeproj` utilizes `PBXFileSystemSynchronizedRootGroup` anchored to `FableApp`. Any files or directories created inside `frontend/FableApp/` are automatically recognized by the Xcode build system without manual edits to `project.pbxproj`.

---

## 3. Native Hardware Security Architecture (`KeychainStore`)

### 3.1 Deprecation of Plaintext Session Storage
Serializing authentication tokens or user credentials into `UserDefaults` is strictly prohibited. `UserDefaults` stores unencrypted plist data in application sandboxes that can be extracted on jailbroken or compromised devices.

### 3.2 Secure Enclave & Keychain Implementation Pattern
Session persistence must be managed via Apple's native **`Security` framework** using the generic password class (`kSecClassGenericPassword`):

```swift
import Foundation
import Security

public final class KeychainStore {
    public static let shared = KeychainStore()
    
    private let service = "mseuf.edu.ph.fable.auth"
    private let tokenAccount = "accessToken"
    
    private init() {}
    
    @discardableResult
    public func saveAccessToken(_ token: String) -> Bool {
        guard let data = token.data(using: .utf8) else { return false }
        deleteAccessToken()
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: tokenAccount,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }
    
    public func readAccessToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: tokenAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &dataTypeRef) == errSecSuccess,
              let data = dataTypeRef as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
    
    @discardableResult
    public func deleteAccessToken() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: tokenAccount
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
```

---

## 4. Authentication State Machine (`AuthState` & `AuthViewModel`)

### 4.1 Discrete Three-State Lifecycle
Authentication must not rely on ambiguous combinations of booleans. It must be modeled as a strict, exhaustive state enum:

```swift
public enum AuthState: Equatable {
    case checkingSession
    case signedOut
    case signedIn(UserSession)
}
```

### 4.2 Standard ViewModel Contract
The `AuthViewModel` must expose these reactive properties and asynchronous operations:

```swift
@MainActor
public class AuthViewModel: ObservableObject {
    @Published public var authState: AuthState = .checkingSession
    @Published public var currentUser: UserSession? = nil
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String? = nil
    
    // 1. Launch Session Restoration
    public func checkExistingSession() async
    
    // 2. Credential Verification
    public func login(email: String, password: String) async -> Bool
    
    // 3. User Registration
    public func register(name: String, email: String, password: String) async -> Bool
    
    // 4. Session Teardown
    public func logout() async
    
    // 5. Offline Guest Mode Access
    public func continueAsGuest()
}
```

---

## 5. UI Architecture, Form Validation & Error Patterns

### 5.1 Card-Based Layout Paradigm
Auth inputs must be enclosed in rounded, elevated card containers with semantic borders, avoiding unbounded full-screen input sprawling:

```swift
// Card View Modifier Pattern
struct FableCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(FableTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(FableTheme.lightBorder, lineWidth: 1))
            .shadow(color: Color.black.opacity(0.04), radius: 8, y: 3)
    }
}

extension View {
    public func fableCard() -> some View {
        modifier(FableCardModifier())
    }
}
```

### 5.2 Input Validation & Button Affordance
* **Submit Button Guarding:** Form submit buttons must compute an `isSubmitDisabled` state (verifying non-empty, trimmed fields) and disable the action when invalid.
* **Confirm Password Checking:** Registration forms must enforce password confirmation parity before dispatching network requests.
* **Loading States:** Submit buttons must swap label text with a progress spinner (`ProgressView()`) when `authVM.isLoading == true`.

### 5.3 Standardized Alert Banners
Error feedback must never be presented as intrusive UIAlert popups when avoidable. Render inline alert banners at the top of the form card:

```swift
if let err = validationError ?? authVM.errorMessage {
    HStack(spacing: 10) {
        Image(systemName: "exclamationmark.circle.fill")
            .foregroundColor(.red)
        Text(err)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.red)
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.red.opacity(0.08))
    .clipShape(RoundedRectangle(cornerRadius: 10))
}
```

### 5.4 Flat In-Place Navigation (No Stacked Sheets)
Rather than launching multi-layered modal sheets over a landing page, present a clean, toggleable view structure where the user can smoothly switch between `LoginView` and `RegisterView` using an inline navigation button (`Don't have an account? Create Account` / `Already have an account? Sign In`).

---

## 6. Root Routing Architecture (`ContentView`)

The application's root view must bind directly to the `AuthState` state machine:

```swift
public struct ContentView: View {
    @StateObject private var authVM = AuthViewModel()
    @State private var showingRegister: Bool = false
    
    public var body: some View {
        Group {
            switch authVM.authState {
            case .checkingSession:
                splashLoadingView
            case .signedOut:
                if showingRegister {
                    RegisterView(authVM: authVM, onNavigateToLogin: { showingRegister = false })
                } else {
                    LoginView(authVM: authVM, onNavigateToRegister: { showingRegister = true })
                }
            case .signedIn:
                mainAppTabView
                    .onAppear { showingRegister = false }
            }
        }
        .task {
            await authVM.checkExistingSession()
        }
        .onChange(of: authVM.authState) { _, _ in
            showingRegister = false
        }
    }
}
```

---

## 7. Directives for AI Subagents & Future Implementations

When authoring changes or adding features:
1. **Never Commit Plaintext Secrets or Tokens:** Verify all authentication tokens route through `KeychainStore`.
2. **Preserve Synchronized Root Groups:** Place new Swift files under the logical folders (`Core/`, `Models/`, `ViewModels/`, `Views/`). Do not alter `project.pbxproj` manually.
3. **Strict Build Verification:** Always verify compilation via `xcodebuild -scheme FableApp -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO` before declaring tasks complete.
4. **Maintain Conventional Commits:** Every modification must produce minimal, atomic commits (`feat:`, `fix:`, `refactor:`, `docs:`) accompanied by an updated entry in [`docs/FINAL_MILESTONE_PROGRESS.md`](FINAL_MILESTONE_PROGRESS.md).
