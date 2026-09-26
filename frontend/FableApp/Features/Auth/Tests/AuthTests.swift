import Foundation

@MainActor
public struct AuthTests {
    public static func runAllTests() async -> (passed: Int, total: Int, failures: [String]) {
        var passed = 0
        var total = 0
        var failures: [String] = []

        func assert(_ condition: Bool, _ testName: String) {
            total += 1
            if condition {
                passed += 1
            } else {
                failures.append(testName)
            }
        }

        let auth = AuthManager()
        auth.signOut()

        // Test 1: Invalid email format rejection
        let invalidEmailResult = await auth.signIn(email: "not-an-email", password: "password123")
        assert(!invalidEmailResult && auth.authErrorMessage == "Please enter a valid email address.", "Reject Invalid Email")

        // Test 2: Password length enforcement (>= 6)
        let shortPasswordResult = await auth.signIn(email: "test@fable.app", password: "123")
        assert(!shortPasswordResult && auth.authErrorMessage == "Password must be at least 6 characters.", "Enforce Minimum Password Length")

        // Test 3: Guest session generation
        auth.continueAsGuest()
        assert(auth.isAuthenticated && auth.isGuestMode && auth.currentSession?.name == "Guest", "Guest Session Generation")

        // Test 4: Sign-out state cleanup
        auth.signOut()
        assert(!auth.isAuthenticated && auth.currentSession == nil, "Sign Out State Cleanup")

        return (passed, total, failures)
    }
}
