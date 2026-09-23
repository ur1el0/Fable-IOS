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
        let result = AppHealthTests.runAllTests()
        self.passed = result.passed
        self.total = result.total
        self.failures = result.failures
        self.reports = result.reports
    }
}
