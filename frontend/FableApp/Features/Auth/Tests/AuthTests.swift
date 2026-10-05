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
        let authViewModel = AuthViewModel.shared

        // Test 1: Invalid email format rejection
        let invalidEmailResult = await auth.signIn(email: "not-an-email", password: "password123")
        assert(!invalidEmailResult && auth.authErrorMessage == "Please enter a valid email address.", "Reject Invalid Email")

        // Test 2: Password length enforcement (>= 6)
        let shortPasswordResult = await auth.signIn(email: "test@fable.app", password: "123")
        assert(!shortPasswordResult && auth.authErrorMessage == "Password must be at least 6 characters.", "Enforce Minimum Password Length")

        // Test 3: Guest session generation
        authViewModel.continueAsGuest()
        assert(
            AuthManager.shared.isAuthenticated
                && AuthManager.shared.isGuestMode
                && authViewModel.currentUser?.name == "Guest",
            "Guest Session Generation"
        )

        // Test 4: Sign-out state cleanup
        authViewModel.logout()
        assert(
            !AuthManager.shared.isAuthenticated
                && authViewModel.currentUser == nil,
            "Sign Out State Cleanup"
        )
        auth.signOut()

        return (passed, total, failures)
    }
}
