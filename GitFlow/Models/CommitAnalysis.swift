import Foundation

/// Analysis result for a commit, providing high-level understanding of intent and risk.
struct CommitAnalysis {
    /// The type of change this commit represents.
    let commitType: CommitType

    /// Risk level of this commit.
    let riskLevel: RiskLevel

    /// Whether this commit contains breaking changes.
    let isBreaking: Bool

    /// Summary statistics.
    let stats: Stats

    /// Detected patterns in the commit.
    let patterns: [ChangePattern]

    // MARK: - Nested Types

    /// Classification of commit intent.
    enum CommitType: String, CaseIterable {
        case feature = "Feature"
        case bugfix = "Bug Fix"
        case refactor = "Refactor"
        case documentation = "Documentation"
        case test = "Test"
        case chore = "Chore"
        case style = "Style"
        case performance = "Performance"
        case security = "Security"
        case mixed = "Mixed"

        var icon: String {
            switch self {
            case .feature: return "plus.circle.fill"
            case .bugfix: return "ladybug.fill"
            case .refactor: return "arrow.triangle.2.circlepath"
            case .documentation: return "doc.text.fill"
            case .test: return "checkmark.seal.fill"
            case .chore: return "wrench.fill"
            case .style: return "paintbrush.fill"
            case .performance: return "gauge.with.dots.needle.67percent"
            case .security: return "lock.shield.fill"
            case .mixed: return "square.stack.fill"
            }
        }

        var color: String {
            switch self {
            case .feature: return "green"
            case .bugfix: return "red"
            case .refactor: return "blue"
            case .documentation: return "purple"
            case .test: return "orange"
            case .chore: return "gray"
            case .style: return "pink"
            case .performance: return "yellow"
            case .security: return "red"
            case .mixed: return "secondary"
            }
        }
    }

    /// Risk classification for the commit.
    enum RiskLevel: String, CaseIterable, Comparable {
        case none = "None"
        case low = "Low"
        case medium = "Medium"
        case high = "High"

        var icon: String {
            switch self {
            case .none: return "checkmark.circle"
            case .low: return "minus.circle"
            case .medium: return "exclamationmark.circle"
            case .high: return "exclamationmark.triangle.fill"
            }
        }

        var color: String {
            switch self {
            case .none: return "green"
            case .low: return "blue"
            case .medium: return "orange"
            case .high: return "red"
            }
        }

        static func < (lhs: RiskLevel, rhs: RiskLevel) -> Bool {
            let order: [RiskLevel] = [.none, .low, .medium, .high]
            return order.firstIndex(of: lhs)! < order.firstIndex(of: rhs)!
        }
    }

    /// Summary statistics for the commit.
    struct Stats {
        let filesChanged: Int
        let additions: Int
        let deletions: Int
        let renamedFiles: Int
        let generatedFiles: Int
        let testFiles: Int

        /// Net change (additions - deletions).
        var netChange: Int { additions - deletions }

        /// Ratio of test files to total files.
        var testRatio: Double {
            guard filesChanged > 0 else { return 0 }
            return Double(testFiles) / Double(filesChanged)
        }
    }

    /// Patterns detected in the changes.
    enum ChangePattern: Equatable {
        case authenticationChange
        case authorizationChange
        case apiSignatureChange
        case databaseSchemaChange
        case configurationChange
        case dependencyUpdate
        case errorHandlingChange
        case loggingChange
        case testCoverageChange
        case documentationOnly
        case formattingOnly

        var description: String {
            switch self {
            case .authenticationChange: return "Authentication logic modified"
            case .authorizationChange: return "Authorization checks changed"
            case .apiSignatureChange: return "Public API signature change"
            case .databaseSchemaChange: return "Database/persistence changes"
            case .configurationChange: return "Configuration changes"
            case .dependencyUpdate: return "Dependency updates"
            case .errorHandlingChange: return "Error handling modified"
            case .loggingChange: return "Logging changes"
            case .testCoverageChange: return "Test coverage modified"
            case .documentationOnly: return "Documentation only"
            case .formattingOnly: return "Formatting only"
            }
        }

        var riskContribution: RiskLevel {
            switch self {
            case .authenticationChange, .authorizationChange:
                return .high
            case .apiSignatureChange, .databaseSchemaChange:
                return .high
            case .configurationChange, .errorHandlingChange:
                return .medium
            case .dependencyUpdate:
                return .medium
            case .loggingChange, .testCoverageChange:
                return .low
            case .documentationOnly, .formattingOnly:
                return .none
            }
        }
    }
}

// MARK: - Commit Analyzer

/// Analyzes commits to determine type, risk, and patterns.
struct CommitAnalyzer {

    /// Analyzes a set of file diffs to produce a commit analysis.
    /// - Parameters:
    ///   - diffs: The file diffs in the commit.
    ///   - message: The commit message (optional, for type inference).
    /// - Returns: Analysis result for the commit.
    static func analyze(diffs: [FileDiff], message: String? = nil) -> CommitAnalysis {
        let stats = computeStats(diffs: diffs)
        let patterns = detectPatterns(diffs: diffs)
        let commitType = inferCommitType(diffs: diffs, message: message, patterns: patterns)
        let riskLevel = computeRiskLevel(patterns: patterns, stats: stats)
        let isBreaking = detectBreakingChanges(diffs: diffs, patterns: patterns)

        return CommitAnalysis(
            commitType: commitType,
            riskLevel: riskLevel,
            isBreaking: isBreaking,
            stats: stats,
            patterns: patterns
        )
    }

    // MARK: - Private Helpers

    private static func computeStats(diffs: [FileDiff]) -> CommitAnalysis.Stats {
        var additions = 0
        var deletions = 0
        var renamedFiles = 0
        var generatedFiles = 0
        var testFiles = 0

        for diff in diffs {
            additions += diff.additions
            deletions += diff.deletions

            if diff.changeType == .renamed {
                renamedFiles += 1
            }

            if diff.isGeneratedFile {
                generatedFiles += 1
            }

            if isTestFile(path: diff.path) {
                testFiles += 1
            }
        }

        return CommitAnalysis.Stats(
            filesChanged: diffs.count,
            additions: additions,
            deletions: deletions,
            renamedFiles: renamedFiles,
            generatedFiles: generatedFiles,
            testFiles: testFiles
        )
    }

    private static func detectPatterns(diffs: [FileDiff]) -> [CommitAnalysis.ChangePattern] {
        var patterns: Set<CommitAnalysis.ChangePattern> = []

        for diff in diffs {
            let pathLower = diff.path.lowercased()
            let content = diff.hunks.flatMap { $0.lines.map { $0.content } }.joined()
            let contentLower = content.lowercased()

            // Authentication changes
            if pathLower.contains("auth") || pathLower.contains("login") ||
               contentLower.contains("password") || contentLower.contains("token") ||
               contentLower.contains("authenticate") || contentLower.contains("credential") {
                patterns.insert(.authenticationChange)
            }

            // Authorization changes
            if pathLower.contains("permission") || pathLower.contains("role") ||
               contentLower.contains("authorize") || contentLower.contains("acl") ||
               contentLower.contains("access control") {
                patterns.insert(.authorizationChange)
            }

            // Database/schema changes
            if pathLower.contains("migration") || pathLower.contains("schema") ||
               pathLower.contains("model") || pathLower.hasSuffix(".sql") ||
               contentLower.contains("create table") || contentLower.contains("alter table") {
                patterns.insert(.databaseSchemaChange)
            }

            // API changes
            if pathLower.contains("api") || pathLower.contains("endpoint") ||
               pathLower.contains("route") || pathLower.contains("controller") {
                // Check for signature changes (public func changes)
                if contentLower.contains("public func") || contentLower.contains("public var") ||
                   contentLower.contains("@objc") || contentLower.contains("@available") {
                    patterns.insert(.apiSignatureChange)
                }
            }

            // Configuration changes
            if pathLower.hasSuffix(".json") || pathLower.hasSuffix(".yaml") ||
               pathLower.hasSuffix(".yml") || pathLower.hasSuffix(".plist") ||
               pathLower.contains("config") || pathLower.contains("settings") {
                patterns.insert(.configurationChange)
            }

            // Dependency updates
            if pathLower.contains("package") || pathLower.contains("podfile") ||
               pathLower.contains("cartfile") || pathLower.hasSuffix(".resolved") {
                patterns.insert(.dependencyUpdate)
            }

            // Error handling
            if contentLower.contains("catch") || contentLower.contains("throw") ||
               contentLower.contains("error") || contentLower.contains("exception") {
                patterns.insert(.errorHandlingChange)
            }

            // Logging
            if contentLower.contains("print(") || contentLower.contains("nslog") ||
               contentLower.contains("logger") || contentLower.contains("os_log") {
                patterns.insert(.loggingChange)
            }

            // Test changes
            if isTestFile(path: diff.path) {
                patterns.insert(.testCoverageChange)
            }
        }

        // Check for documentation-only or formatting-only
        let nonDocDiffs = diffs.filter { !isDocFile(path: $0.path) }
        if nonDocDiffs.isEmpty && !diffs.isEmpty {
            patterns.insert(.documentationOnly)
        }

        return Array(patterns)
    }

    private static func inferCommitType(
        diffs: [FileDiff],
        message: String?,
        patterns: [CommitAnalysis.ChangePattern]
    ) -> CommitAnalysis.CommitType {
        // Try to infer from conventional commit message
        if let message = message?.lowercased() {
            if message.hasPrefix("feat") || message.contains("add") || message.contains("new") {
                return .feature
            }
            if message.hasPrefix("fix") || message.contains("bug") || message.contains("patch") {
                return .bugfix
            }
            if message.hasPrefix("refactor") || message.contains("refactor") || message.contains("restructure") {
                return .refactor
            }
            if message.hasPrefix("docs") || message.contains("documentation") || message.contains("readme") {
                return .documentation
            }
            if message.hasPrefix("test") || message.contains("test") || message.contains("spec") {
                return .test
            }
            if message.hasPrefix("chore") || message.contains("chore") || message.contains("maintenance") {
                return .chore
            }
            if message.hasPrefix("style") || message.contains("format") || message.contains("lint") {
                return .style
            }
            if message.hasPrefix("perf") || message.contains("performance") || message.contains("optimize") {
                return .performance
            }
            if message.hasPrefix("security") || message.contains("security") || message.contains("vulnerability") {
                return .security
            }
        }

        // Infer from patterns
        if patterns.contains(.documentationOnly) {
            return .documentation
        }
        if patterns.contains(.formattingOnly) {
            return .style
        }
        if patterns.contains(.testCoverageChange) && patterns.count == 1 {
            return .test
        }
        if patterns.contains(.authenticationChange) || patterns.contains(.authorizationChange) {
            return .security
        }
        if patterns.contains(.dependencyUpdate) && patterns.count == 1 {
            return .chore
        }

        // Infer from file changes
        let testFiles = diffs.filter { isTestFile(path: $0.path) }
        if testFiles.count == diffs.count {
            return .test
        }

        let docFiles = diffs.filter { isDocFile(path: $0.path) }
        if docFiles.count == diffs.count {
            return .documentation
        }

        // Check for pure renames (likely refactor)
        let pureRenames = diffs.filter { $0.isPureRename }
        if pureRenames.count > diffs.count / 2 {
            return .refactor
        }

        // Check for mostly additions (likely feature)
        let totalAdditions = diffs.reduce(0) { $0 + $1.additions }
        let totalDeletions = diffs.reduce(0) { $0 + $1.deletions }
        if totalAdditions > totalDeletions * 3 {
            return .feature
        }

        // Multiple different types of changes
        if patterns.count > 3 {
            return .mixed
        }

        // Default to feature for mostly additions, bugfix otherwise
        return totalAdditions > totalDeletions ? .feature : .bugfix
    }

    private static func computeRiskLevel(
        patterns: [CommitAnalysis.ChangePattern],
        stats: CommitAnalysis.Stats
    ) -> CommitAnalysis.RiskLevel {
        // Get highest risk from patterns
        var maxRisk = CommitAnalysis.RiskLevel.none
        for pattern in patterns {
            if pattern.riskContribution > maxRisk {
                maxRisk = pattern.riskContribution
            }
        }

        // Bump risk for large changes
        if stats.filesChanged > 20 && maxRisk < .medium {
            maxRisk = .medium
        }
        if stats.additions + stats.deletions > 1000 && maxRisk < .medium {
            maxRisk = .medium
        }

        // Lower risk if tests are included
        if stats.testRatio > 0.3 && maxRisk > .low {
            // Test coverage reduces perceived risk
            maxRisk = CommitAnalysis.RiskLevel(rawValue: maxRisk.rawValue) ?? maxRisk
        }

        return maxRisk
    }

    private static func detectBreakingChanges(
        diffs: [FileDiff],
        patterns: [CommitAnalysis.ChangePattern]
    ) -> Bool {
        // Breaking if API signatures changed
        if patterns.contains(.apiSignatureChange) {
            return true
        }

        // Breaking if database schema changed
        if patterns.contains(.databaseSchemaChange) {
            return true
        }

        // Check for deleted public APIs in diffs
        for diff in diffs {
            for hunk in diff.hunks {
                for line in hunk.lines where line.type == .deletion {
                    let content = line.content.lowercased()
                    if content.contains("public func") || content.contains("public var") ||
                       content.contains("public class") || content.contains("public struct") ||
                       content.contains("public enum") || content.contains("public protocol") {
                        return true
                    }
                }
            }
        }

        return false
    }

    private static func isTestFile(path: String) -> Bool {
        let pathLower = path.lowercased()
        return pathLower.contains("test") || pathLower.contains("spec") ||
               pathLower.hasSuffix("tests.swift") || pathLower.hasSuffix("test.swift") ||
               pathLower.contains("/tests/") || pathLower.contains("/spec/")
    }

    private static func isDocFile(path: String) -> Bool {
        let pathLower = path.lowercased()
        return pathLower.hasSuffix(".md") || pathLower.hasSuffix(".txt") ||
               pathLower.hasSuffix(".rst") || pathLower.contains("readme") ||
               pathLower.contains("/docs/") || pathLower.contains("documentation")
    }
}
