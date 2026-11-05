import Foundation

@MainActor
public struct PasswordRecoveryTests {
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

        let resetCode = String(repeating: "a", count: 43)
        var requestedEmails: [String] = []
        var submittedCredentials: [(String, String)] = []
        let viewModel = PasswordRecoveryViewModel(
            initialEmail: " reader@example.com ",
            requestReset: { email in requestedEmails.append(email) },
            confirmReset: { token, password in submittedCredentials.append((token, password)) }
        )

        await viewModel.requestCode()
        assert(requestedEmails == ["reader@example.com"], "Trim email before requesting recovery")
        assert(viewModel.stage == .confirm, "Move to code confirmation after accepted request")
        assert(
            viewModel.statusMessage == "If an account uses this address, recovery instructions will arrive shortly.",
            "Keep account existence private in the recovery status"
        )

        viewModel.token = " \(resetCode) "
        viewModel.password = "short"
        viewModel.confirmation = "short"
        await viewModel.confirmPassword()
        assert(viewModel.errorMessage == "Password must be at least 12 characters.", "Reject short passwords")
        assert(submittedCredentials.isEmpty, "Do not submit a short password")

        viewModel.password = "ReplacementPassword123!"
        viewModel.confirmation = "DifferentPassword456!"
        await viewModel.confirmPassword()
        assert(viewModel.errorMessage == "The passwords do not match.", "Reject mismatched passwords")
        assert(submittedCredentials.isEmpty, "Do not submit mismatched password values")

        viewModel.confirmation = viewModel.password
        await viewModel.confirmPassword()
        assert(
            submittedCredentials.count == 1
                && submittedCredentials[0].0 == resetCode
                && submittedCredentials[0].1 == "ReplacementPassword123!",
            "Submit recovery code and matching password"
        )
        assert(viewModel.stage == .complete, "Show completion state after successful reset")
        assert(
            viewModel.token.isEmpty && viewModel.password.isEmpty && viewModel.confirmation.isEmpty,
            "Clear recovery code and password after successful reset"
        )
        viewModel.requestAnotherCode()
        assert(viewModel.stage == .request, "Return to the email step when requesting another code")

        let failedRequest = PasswordRecoveryViewModel(
            initialEmail: "reader@example.com",
            requestReset: { _ in throw APIRequestError(message: "Recovery unavailable") },
            confirmReset: { _, _ in }
        )
        await failedRequest.requestCode()
        assert(failedRequest.stage == .request, "Stay on request form when recovery request fails")
        assert(failedRequest.errorMessage == "Recovery unavailable", "Show a request failure message")

        return (passed, total, failures)
    }
}
