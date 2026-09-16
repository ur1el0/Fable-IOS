# Fable iOS: Authentication & Hardware Security Architecture

**Document Version:** 1.0.0  
**Target Milestone:** Midterm Presentation & Technical Defense  
**Author:** Roosc Zaño (`@zanoroosc`)  

---

## 1. Executive Summary: Enterprise Session Security

Authentication in Fable is engineered according to Apple's Secure Enclave standards and enterprise Model-View-ViewModel (MVVM) state-machine design.

```
                  ┌─────────────────────────────────────┐
                  │       Application Boot Lifecycle    │
                  └──────────────────┬──────────────────┘
                                     │
                                     ▼
                     [ AuthState.checkingSession ]
                                     │
               Query Native Apple Hardware Keychain
                                     │
                ┌────────────────────┴────────────────────┐
                │ Keychain Item Found?                    │
                ▼                                         ▼
              [ YES ]                                   [ NO ]
                │                                         │
                ▼                                         ▼
   [ AuthState.signedIn(Session) ]              [ AuthState.signedOut ]
                │                                         │
                ▼                                         ▼
       Renders Main App                           Renders Welcome Flow
    (Explore / Library / Shelf)                (Welcome / SignIn / SignUp)
```

---

## 2. The Tri-State Authentication State Machine

In `frontend/FableApp/ViewModels/AuthViewModel.swift`, the authentication lifecycle is governed by an explicit ternary state enum:

```swift
public enum AuthState: Equatable {
    case checkingSession              // Splash / checking Keychain on launch
    case signedOut                    // No valid session; show Welcome flow
    case signedIn(UserSession)        // Authenticated; render primary tabs
}
```

### Why a State Machine over Boolean Flags (`isLoggedIn: Bool`):
- **Eliminates Race Conditions:** Boolean flags allow illegal hybrid states (e.g., `isLoggedIn == true` while `currentUser == nil`). An enum with associated values guarantees that the user object **must** exist if the state is `.signedIn`.
- **Prevents UI Flashing:** The `.checkingSession` state displays a graceful, atmospheric splash loader while the Keychain is queried asynchronously on app launch, preventing jarring screen flashes.

---

## 3. The 3 Authentication Surfaces

Fable presents three distinct, card-based authentication views built with elevated container styling (`.fableCard()`):

### 3.1 Welcome Landing Screen (`WelcomeView.swift`)
- **Brand Identity:** Serif typography ("Fable: Ambient Literary Sanctuary"), calming atmospheric palette, and clear value proposition.
- **Flat Navigation:** Clean primary "Sign In" and secondary "Create Account" buttons.
- **Evaluator Fast-Path ("Continue as Guest"):** 
  - Allows professors and evaluators to bypass account creation and immediately test all 10 screens and reading engines with a single tap.
  - Automatically initializes a temporary guest session (`UserSession(name: "Guest Reader", email: "guest@fable.local")`).

### 3.2 Sign In Screen (`SignInView.swift`)
- **Card Container:** Floating card with soft shadow and rounded corners.
- **Validation Guard (`isSubmitDisabled`):**
  - Sign-in button is disabled until the user provides a valid email containing `@` and a non-empty password.
- **Interactive Features:**
  - Password visibility toggle (`Eye` icon switching between `SecureField` and `TextField`).
  - Animated error banners with contextual messaging upon invalid credentials.
  - Built-in "Demo Credentials" shortcut for instant grading evaluation.

### 3.3 Sign Up Screen (`SignUpView.swift`)
- **Field Captures:** Full name, email address, password, and confirm password.
- **Live Password Matching:** Real-time feedback verifying that the confirmation password matches the primary password before submission is unlocked.
- **Automatic Sign-In:** Upon successful registration, the session is generated, stored in the Keychain, and the user is transitioned directly to the Explore tab.

---

## 4. Native Hardware Security: Apple Keychain vs. UserDefaults

A critical security question during capstone defenses is: *"Where do you store user authentication tokens?"*

### 4.1 Why `UserDefaults` is Strictly Prohibited:
Many student applications store authentication tokens or passwords in `UserDefaults`:
```swift
// INSECURE ANTI-PATTERN:
UserDefaults.standard.set(token, forKey: "auth_token")
```
**The Security Flaw:** `UserDefaults` writes data to an unencrypted `.plist` file stored in the app's local sandbox (`/Library/Preferences/bundle.id.plist`). On a jailbroken device, backed-up phone, or via file inspection tools, this file can be extracted in plaintext, exposing user sessions to credential theft.

### 4.2 The Solution: Hardware Keychain (`KeychainStore.swift`)
Fable implements a native wrapper around Apple's C-based **Keychain Services API**:

```swift
public final class KeychainStore {
    public static let shared = KeychainStore()
    private let service = "mseuf.edu.ph.FableApp"
    
    public func set(_ data: Data, forKey key: String) -> Bool {
        // Query dictionary
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        SecItemDelete(query as CFDictionary)
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }
    
    public func get(forKey key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        return status == errSecSuccess ? (result as? Data) : nil
    }
}
```

### 4.3 Key Security Attributes:
- **`kSecClassGenericPassword`:** Categorizes data as high-security credentials.
- **`kSecAttrAccessibleAfterFirstUnlock`:** Enforces hardware-level disk encryption: credentials can only be read when the device has been unlocked by the user's passcode or Face ID, remaining encrypted while the device is locked.
- **Secure Enclave Integration:** Encryption keys are managed by Apple's dedicated hardware security co-processor.

---

## 5. Session Data Contract & Secure Sign-Out

### 5.1 The `UserSession` Contract (`frontend/FableApp/Models/Models.swift`)
```swift
public struct UserSession: Codable, Equatable {
    public let id: UUID
    public let token: String
    public let name: String
    public let email: String
    public let role: String
    public let expiresAt: Date
}
```

### 5.2 Clean Sign-Out Lifecycle
When the user taps "Sign Out" in `SettingsView` or `ProfileView`:
1. `AuthViewModel.signOut()` invokes `KeychainStore.shared.delete(forKey: "fable_user_session")`.
2. Hardware credentials are purged from Keychain storage.
3. The state machine transitions to `.signedOut`.
4. `ContentView` observes the state change and immediately unmounts all reader and library tabs, returning to `WelcomeView`.

---

## 6. Defense Talking Point: "How Secure is Your Auth?"

> *"Security was designed from day one around Apple's zero-trust guidelines. We strictly avoid storing session tokens or passwords in plaintext plist files like UserDefaults. Instead, we use Apple's native Security framework with hardware-backed Keychain Services. Tokens are encrypted on-device with the Secure Enclave under `kSecAttrAccessibleAfterFirstUnlock`, meaning credentials cannot be extracted even if the device filesystem is inspected. For our presentation, we also built a guest-access state machine bypass so evaluators can test all features with zero friction."*
