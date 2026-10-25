import SwiftUI

public struct SystemDiagnosticsSheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var passed: Int = 0
    @State private var total: Int = 0
    @State private var failures: [String] = []
    @State private var reports: [AppHealthTests.TestReport] = []
    @State private var isRunning: Bool = false

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                FableTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Header Status Banner
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill((failures.isEmpty ? Color.green : Color.red).opacity(0.12))
                                    .frame(width: 64, height: 64)

                                Image(systemName: failures.isEmpty ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                                    .font(.system(size: 30))
                                    .foregroundColor(failures.isEmpty ? .green : .red)
                            }

                            Text(failures.isEmpty ? "All Systems Operational" : "Verification Failures Detected")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(FableTheme.textPrimary)

                            Text("\(passed) of \(total) Internal Health Contracts Passing")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(FableTheme.textMuted)

                            Button(action: {
                                runDiagnostics()
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.clockwise")
                                    Text("Re-Run Verification")
                                }
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(FableTheme.brandPrimary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(FableTheme.brandPrimary.opacity(0.10))
                                .clipShape(Capsule())
                            }
                            .padding(.top, 4)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                        .background(FableTheme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .shadow(color: Color.black.opacity(0.03), radius: 8, y: 2)

                        // Detailed Test List
                        VStack(alignment: .leading, spacing: 12) {
                            Text("HEALTH CONTRACTS")
                                .font(.system(size: 11, weight: .bold))
                                .tracking(1.0)
                                .foregroundColor(FableTheme.textMuted)
                                .padding(.leading, 8)

                            VStack(spacing: 12) {
                                ForEach(reports) { report in
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack(alignment: .top, spacing: 12) {
                                            Image(systemName: report.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                                                .font(.system(size: 18))
                                                .foregroundColor(report.passed ? .green : .red)
                                                .padding(.top, 2)

                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(report.name)
                                                    .font(.system(size: 15, weight: .bold))
                                                    .foregroundColor(FableTheme.textPrimary)

                                                Text(report.description)
                                                    .font(.system(size: 12))
                                                    .foregroundColor(FableTheme.textMuted)
                                                    .lineLimit(2)
                                            }

                                            Spacer()

                                            Text(report.passed ? "PASS" : "FAIL")
                                                .font(.system(size: 10, weight: .heavy))
                                                .foregroundColor(report.passed ? .green : .red)
                                                .padding(.horizontal, 7)
                                                .padding(.vertical, 3)
                                                .background((report.passed ? Color.green : Color.red).opacity(0.12))
                                                .clipShape(Capsule())
                                        }

                                        // Diagnostics Details Box
                                        Text(report.details)
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundColor(FableTheme.textSecondary)
                                            .padding(10)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .background(FableTheme.surface)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                    .padding(14)
                                    .background(FableTheme.cardBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                    .shadow(color: Color.black.opacity(0.02), radius: 4, y: 1)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("System Diagnostics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(FableTheme.brandPrimary)
                }
            }
            .onAppear {
                runDiagnostics()
            }
        }
    }

    private func runDiagnostics() {
        Task { @MainActor in
            var allReports: [AppHealthTests.TestReport] = []
            var allFailures: [String] = []
            var passedCount = 0
            var totalCount = 0

            // 1. App Health Subsystem Contracts
            let healthResult = AppHealthTests.runAllTests()
            allReports.append(contentsOf: healthResult.reports)
            allFailures.append(contentsOf: healthResult.failures)
            passedCount += healthResult.passed
            totalCount += healthResult.total

            // 2. Reader Engine & Pacing Invariants
            let readerResult = ReaderTests.runAllTests()
            passedCount += readerResult.passed
            totalCount += readerResult.total
            allFailures.append(contentsOf: readerResult.failures)
            allReports.append(AppHealthTests.TestReport(
                name: "Reader Engine & Pacing Invariants",
                description: "Validates WPM velocity clamping (100-600), Unicode tokenization, dynamic font scaling, and page chunking",
                passed: readerResult.failures.isEmpty,
                details: "\(readerResult.passed)/\(readerResult.total) pacing and pagination assertions passed."
            ))

            // 3. Manuscript Composer & Formatting
            let writeResult = WriteTests.runAllTests()
            passedCount += writeResult.passed
            totalCount += writeResult.total
            allFailures.append(contentsOf: writeResult.failures)
            allReports.append(AppHealthTests.TestReport(
                name: "Writer Word Tokenizer & Pacing Estimator",
                description: "Validates whitespace/newline split tokenization and reading duration estimation",
                passed: writeResult.failures.isEmpty,
                details: "\(writeResult.passed)/\(writeResult.total) manuscript composer assertions passed."
            ))

            // 4. Shelf Multi-Tenant Contract & Statistics
            let shelfResult = ShelfTests.runAllTests()
            passedCount += shelfResult.passed
            totalCount += shelfResult.total
            allFailures.append(contentsOf: shelfResult.failures)
            allReports.append(AppHealthTests.TestReport(
                name: "Shelf Analytics & Multi-Tenant Sync Contract",
                description: "Validates reading stats summary, hours formatting, and ShelfSyncItem serialization",
                passed: shelfResult.failures.isEmpty,
                details: "\(shelfResult.passed)/\(shelfResult.total) shelf domain assertions passed."
            ))

            // 5. Authentication & Session Security
            let authResult = await AuthTests.runAllTests()
            passedCount += authResult.passed
            totalCount += authResult.total
            allFailures.append(contentsOf: authResult.failures)
            allReports.append(AppHealthTests.TestReport(
                name: "Authentication & Session Security",
                description: "Validates email format rejection, minimum password length, guest session, and signout cleanup",
                passed: authResult.failures.isEmpty,
                details: "\(authResult.passed)/\(authResult.total) authentication assertions passed."
            ))

            self.passed = passedCount
            self.total = totalCount
            self.failures = allFailures
            self.reports = allReports
        }
    }
}
