import SwiftUI

/// View displaying change impact analysis results.
struct ChangeImpactView: View {
    let impact: ChangeImpactAnalysis

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: "waveform.path.ecg")
                    .foregroundStyle(publicApiColor)
                Text("Impact Analysis")
                    .font(.caption.bold())

                Spacer()

                // Public API badge
                if impact.publicApiChanged {
                    PublicApiBadge()
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(publicApiColor.opacity(0.05))

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                // Breaking changes
                if !impact.breakingChanges.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Breaking Changes")
                            .font(.caption.bold())
                            .foregroundStyle(.red)

                        ForEach(impact.breakingChanges) { change in
                            HStack(spacing: 6) {
                                Image(systemName: severityIcon(for: change.severity))
                                    .font(.caption)
                                    .foregroundStyle(severityColor(for: change.severity))
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(change.description)
                                        .font(.caption)
                                    Text(change.entity)
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                    }
                }

                // Affected callers
                if !impact.affectedCallers.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Potentially Affected (\(impact.affectedFiles))")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)

                        ForEach(impact.affectedCallers.prefix(5), id: \.self) { caller in
                            HStack(spacing: 6) {
                                Image(systemName: "function")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(caller)
                                    .font(.caption)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        }

                        if impact.affectedCallers.count > 5 {
                            Text("... and \(impact.affectedCallers.count - 5) more")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }

                // Dependency impact
                if impact.dependencyImpact.affectsDownstream || !impact.dependencyImpact.affectedPackages.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Dependency Impact")
                            .font(.caption.bold())
                            .foregroundStyle(.orange)

                        if impact.dependencyImpact.affectsDownstream {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                                Text("May affect downstream consumers")
                                    .font(.caption)
                            }
                        }

                        ForEach(impact.dependencyImpact.affectedPackages, id: \.self) { pkg in
                            HStack(spacing: 6) {
                                Image(systemName: "shippingbox")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(pkg)
                                    .font(.caption)
                            }
                        }
                    }
                }

                // Test coverage
                VStack(alignment: .leading, spacing: 4) {
                    Text("Test Coverage")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        // Coverage indicator
                        TestCoverageIndicator(coverage: impact.testCoverage)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(impact.testCoverage.rawValue)
                                .font(.caption)
                            if impact.testCoverage == .missing {
                                Text("Consider adding tests for these changes")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
            }
            .padding(12)
        }
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var publicApiColor: Color {
        impact.publicApiChanged ? .orange : .green
    }

    private func severityIcon(for severity: ChangeImpactAnalysis.BreakingChange.Severity) -> String {
        switch severity {
        case .minor: return "exclamationmark.circle"
        case .major: return "exclamationmark.triangle.fill"
        case .critical: return "xmark.octagon.fill"
        }
    }

    private func severityColor(for severity: ChangeImpactAnalysis.BreakingChange.Severity) -> Color {
        switch severity {
        case .minor: return .yellow
        case .major: return .orange
        case .critical: return .red
        }
    }
}

/// Badge showing public API change.
struct PublicApiBadge: View {
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 9, weight: .bold))
            Text("PUBLIC API")
                .font(.system(size: 9, weight: .bold))
        }
        .foregroundStyle(.orange)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Color.orange.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

/// Visual indicator for test coverage level.
struct TestCoverageIndicator: View {
    let coverage: ChangeImpactAnalysis.TestCoverage

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(index < filledBars ? color : Color.secondary.opacity(0.2))
                    .frame(width: 8, height: 12)
            }
        }
    }

    private var filledBars: Int {
        switch coverage {
        case .covered: return 3
        case .partial: return 2
        case .missing: return 0
        case .unknown: return 1
        }
    }

    private var color: Color {
        switch coverage {
        case .covered: return .green
        case .partial: return .orange
        case .missing: return .red
        case .unknown: return .gray
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        ChangeImpactView(impact: ChangeImpactAnalysis(
            affectedFiles: 6,
            affectedCallers: ["login()", "logout()", "refreshToken()"],
            publicApiChanged: true,
            testCoverage: .partial,
            dependencyImpact: ChangeImpactAnalysis.DependencyImpact(
                dependentFiles: [],
                affectedPackages: ["Package.swift"],
                affectsDownstream: true
            ),
            breakingChanges: [
                ChangeImpactAnalysis.BreakingChange(
                    description: "Method signature changed",
                    severity: .major,
                    entity: "authenticate(user:password:)"
                )
            ]
        ))

        ChangeImpactView(impact: ChangeImpactAnalysis(
            affectedFiles: 0,
            affectedCallers: [],
            publicApiChanged: false,
            testCoverage: .covered,
            dependencyImpact: ChangeImpactAnalysis.DependencyImpact(
                dependentFiles: [],
                affectedPackages: [],
                affectsDownstream: false
            ),
            breakingChanges: []
        ))
    }
    .padding()
    .frame(width: 400)
}
