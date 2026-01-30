import SwiftUI

/// Summary view showing commit analysis with type, risk, and patterns.
struct CommitSummaryView: View {
    let analysis: CommitAnalysis
    let commit: Commit?

    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Compact summary bar
            summaryBar

            // Expandable details
            if isExpanded {
                Divider()
                expandedDetails
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Summary Bar

    private var summaryBar: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: 12) {
                // Commit type badge
                commitTypeBadge

                Divider()
                    .frame(height: 20)

                // Risk level
                riskBadge

                if analysis.isBreaking {
                    breakingBadge
                }

                Divider()
                    .frame(height: 20)

                // Stats
                statsView

                Spacer()

                // Expand/collapse indicator
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var commitTypeBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: analysis.commitType.icon)
                .font(.caption)
            Text(analysis.commitType.rawValue)
                .font(.caption.bold())
        }
        .foregroundStyle(colorForType(analysis.commitType))
    }

    private var riskBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: analysis.riskLevel.icon)
                .font(.caption)
            Text(analysis.riskLevel.rawValue)
                .font(.caption)
        }
        .foregroundStyle(colorForRisk(analysis.riskLevel))
    }

    private var breakingBadge: some View {
        HStack(spacing: 2) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption2)
            Text("Breaking")
                .font(.caption2.bold())
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.red)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private var statsView: some View {
        HStack(spacing: 12) {
            // Files changed
            HStack(spacing: 4) {
                Image(systemName: "doc")
                    .font(.caption2)
                Text("\(analysis.stats.filesChanged)")
                    .font(.caption)
            }
            .foregroundStyle(.secondary)

            // Additions/deletions
            HStack(spacing: 6) {
                Text("+\(analysis.stats.additions)")
                    .font(.caption.monospaced())
                    .foregroundStyle(.green)
                Text("-\(analysis.stats.deletions)")
                    .font(.caption.monospaced())
                    .foregroundStyle(.red)
            }

            // Renames indicator
            if analysis.stats.renamedFiles > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "arrow.right")
                        .font(.caption2)
                    Text("\(analysis.stats.renamedFiles)")
                        .font(.caption)
                }
                .foregroundStyle(.blue)
                .help("\(analysis.stats.renamedFiles) renamed files")
            }

            // Test coverage indicator
            if analysis.stats.testFiles > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "checkmark.seal")
                        .font(.caption2)
                    Text("\(analysis.stats.testFiles)")
                        .font(.caption)
                }
                .foregroundStyle(.orange)
                .help("\(analysis.stats.testFiles) test files")
            }
        }
    }

    // MARK: - Expanded Details

    private var expandedDetails: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Patterns section
            if !analysis.patterns.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Detected Patterns")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)

                    FlowLayout(spacing: 6) {
                        ForEach(analysis.patterns, id: \.self) { pattern in
                            patternBadge(pattern)
                        }
                    }
                }
            }

            // Detailed stats
            detailedStats

            // Risk explanation
            if analysis.riskLevel != .none {
                riskExplanation
            }
        }
        .padding(12)
    }

    private func patternBadge(_ pattern: CommitAnalysis.ChangePattern) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(colorForRisk(pattern.riskContribution))
                .frame(width: 6, height: 6)
            Text(pattern.description)
                .font(.caption)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private var detailedStats: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Change Summary")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 4) {
                GridRow {
                    Text("Files changed:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(analysis.stats.filesChanged)")
                        .font(.caption.monospaced())
                }

                GridRow {
                    Text("Lines added:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("+\(analysis.stats.additions)")
                        .font(.caption.monospaced())
                        .foregroundStyle(.green)
                }

                GridRow {
                    Text("Lines removed:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("-\(analysis.stats.deletions)")
                        .font(.caption.monospaced())
                        .foregroundStyle(.red)
                }

                GridRow {
                    Text("Net change:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(analysis.stats.netChange >= 0 ? "+\(analysis.stats.netChange)" : "\(analysis.stats.netChange)")
                        .font(.caption.monospaced())
                        .foregroundStyle(analysis.stats.netChange >= 0 ? .green : .red)
                }

                if analysis.stats.generatedFiles > 0 {
                    GridRow {
                        Text("Generated files:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(analysis.stats.generatedFiles)")
                            .font(.caption.monospaced())
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }

    private var riskExplanation: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Risk Factors")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            let riskPatterns = analysis.patterns.filter { $0.riskContribution >= .medium }
            if !riskPatterns.isEmpty {
                ForEach(riskPatterns, id: \.self) { pattern in
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.circle")
                            .font(.caption)
                            .foregroundStyle(colorForRisk(pattern.riskContribution))
                        Text(pattern.description)
                            .font(.caption)
                    }
                }
            }

            if analysis.stats.filesChanged > 20 {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Text("Large changeset (\(analysis.stats.filesChanged) files)")
                        .font(.caption)
                }
            }
        }
    }

    // MARK: - Helpers

    private func colorForType(_ type: CommitAnalysis.CommitType) -> Color {
        switch type {
        case .feature: return .green
        case .bugfix: return .red
        case .refactor: return .blue
        case .documentation: return .purple
        case .test: return .orange
        case .chore: return .gray
        case .style: return .pink
        case .performance: return .yellow
        case .security: return .red
        case .mixed: return .secondary
        }
    }

    private func colorForRisk(_ risk: CommitAnalysis.RiskLevel) -> Color {
        switch risk {
        case .none: return .green
        case .low: return .blue
        case .medium: return .orange
        case .high: return .red
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        CommitSummaryView(
            analysis: CommitAnalysis(
                commitType: .feature,
                riskLevel: .low,
                isBreaking: false,
                stats: CommitAnalysis.Stats(
                    filesChanged: 5,
                    additions: 234,
                    deletions: 45,
                    renamedFiles: 1,
                    generatedFiles: 0,
                    testFiles: 2
                ),
                patterns: [.configurationChange, .testCoverageChange]
            ),
            commit: nil
        )

        CommitSummaryView(
            analysis: CommitAnalysis(
                commitType: .security,
                riskLevel: .high,
                isBreaking: true,
                stats: CommitAnalysis.Stats(
                    filesChanged: 12,
                    additions: 567,
                    deletions: 234,
                    renamedFiles: 0,
                    generatedFiles: 1,
                    testFiles: 3
                ),
                patterns: [.authenticationChange, .apiSignatureChange, .testCoverageChange]
            ),
            commit: nil
        )
    }
    .padding()
    .frame(width: 500)
}
