import Foundation

/// Represents the impact analysis of a code change
struct ChangeImpactAnalysis: Equatable {
    /// Number of files potentially affected by this change
    let affectedFiles: Int

    /// Names of potentially affected callers/usages
    let affectedCallers: [String]

    /// Whether this change affects public API
    let publicApiChanged: Bool

    /// Test coverage status
    let testCoverage: TestCoverage

    /// Dependency impact (files that depend on changed files)
    let dependencyImpact: DependencyImpact

    /// Breaking change details
    let breakingChanges: [BreakingChange]

    /// Test coverage status
    enum TestCoverage: String, Equatable {
        case covered = "Covered"
        case partial = "Partial"
        case missing = "Missing"
        case unknown = "Unknown"

        var icon: String {
            switch self {
            case .covered: return "checkmark.shield.fill"
            case .partial: return "exclamationmark.shield.fill"
            case .missing: return "xmark.shield.fill"
            case .unknown: return "questionmark.diamond.fill"
            }
        }

        var color: String {
            switch self {
            case .covered: return "green"
            case .partial: return "yellow"
            case .missing: return "red"
            case .unknown: return "gray"
            }
        }
    }

    /// Dependency impact information
    struct DependencyImpact: Equatable {
        /// Files that import/depend on the changed file
        let dependentFiles: [String]

        /// External packages affected
        let affectedPackages: [String]

        /// Whether this could affect downstream consumers
        let affectsDownstream: Bool
    }

    /// Breaking change information
    struct BreakingChange: Identifiable, Equatable {
        let id = UUID()
        let description: String
        let severity: Severity
        let entity: String

        enum Severity: String, Equatable {
            case minor = "Minor"
            case major = "Major"
            case critical = "Critical"

            var color: String {
                switch self {
                case .minor: return "yellow"
                case .major: return "orange"
                case .critical: return "red"
                }
            }
        }

        static func == (lhs: BreakingChange, rhs: BreakingChange) -> Bool {
            lhs.description == rhs.description && lhs.severity == rhs.severity && lhs.entity == rhs.entity
        }
    }
}

/// Analyzes the impact of code changes
class ChangeImpactAnalyzer {

    /// Analyzes the impact of changes in a diff
    /// - Parameters:
    ///   - diffs: The file diffs to analyze
    ///   - structuralChanges: Structural changes detected (if available)
    ///   - repositoryFiles: List of all files in the repository (for dependency analysis)
    /// - Returns: Impact analysis result
    func analyze(
        diffs: [FileDiff],
        structuralChanges: [StructuralChange] = [],
        repositoryFiles: [String] = []
    ) -> ChangeImpactAnalysis {
        // Detect public API changes
        let publicApiChanged = detectPublicApiChanges(diffs: diffs, structuralChanges: structuralChanges)

        // Find affected callers
        let affectedCallers = findAffectedCallers(
            diffs: diffs,
            structuralChanges: structuralChanges,
            repositoryFiles: repositoryFiles
        )

        // Analyze test coverage
        let testCoverage = analyzeTestCoverage(diffs: diffs)

        // Analyze dependency impact
        let dependencyImpact = analyzeDependencyImpact(
            diffs: diffs,
            repositoryFiles: repositoryFiles
        )

        // Detect breaking changes
        let breakingChanges = detectBreakingChanges(
            diffs: diffs,
            structuralChanges: structuralChanges
        )

        return ChangeImpactAnalysis(
            affectedFiles: affectedCallers.count,
            affectedCallers: affectedCallers,
            publicApiChanged: publicApiChanged,
            testCoverage: testCoverage,
            dependencyImpact: dependencyImpact,
            breakingChanges: breakingChanges
        )
    }

    // MARK: - Private Helpers

    private func detectPublicApiChanges(diffs: [FileDiff], structuralChanges: [StructuralChange]) -> Bool {
        // Check structural changes for public visibility changes
        for change in structuralChanges {
            if change.entity.visibility == .public || change.entity.visibility == .open {
                if change.changeType == .removed ||
                   change.changeType == .signatureChanged ||
                   change.changeType == .visibilityChanged {
                    return true
                }
            }
        }

        // Check diffs for public declarations
        for diff in diffs {
            for hunk in diff.hunks {
                for line in hunk.lines where line.type == .deletion {
                    let content = line.content.lowercased()
                    if content.contains("public ") || content.contains("open ") {
                        if content.contains("func ") || content.contains("var ") ||
                           content.contains("let ") || content.contains("class ") ||
                           content.contains("struct ") || content.contains("protocol ") {
                            return true
                        }
                    }
                }
            }
        }

        return false
    }

    private func findAffectedCallers(
        diffs: [FileDiff],
        structuralChanges: [StructuralChange],
        repositoryFiles: [String]
    ) -> [String] {
        var affectedNames: Set<String> = []

        // Collect names of changed entities
        for change in structuralChanges {
            if change.changeType == .removed ||
               change.changeType == .renamed ||
               change.changeType == .signatureChanged {
                affectedNames.insert(change.entity.name)
                if let old = change.oldEntity {
                    affectedNames.insert(old.name)
                }
            }
        }

        // Also check for deleted function/class names from diffs
        for diff in diffs {
            for hunk in diff.hunks {
                for line in hunk.lines where line.type == .deletion {
                    // Extract function names from deleted lines
                    let content = line.content
                    if let funcName = extractFunctionName(from: content) {
                        affectedNames.insert(funcName)
                    }
                    if let className = extractClassName(from: content) {
                        affectedNames.insert(className)
                    }
                }
            }
        }

        // In a real implementation, we would search the repository for usages
        // For now, we return the affected entity names
        return Array(affectedNames)
    }

    private func analyzeTestCoverage(diffs: [FileDiff]) -> ChangeImpactAnalysis.TestCoverage {
        var hasSourceChanges = false
        var hasTestChanges = false

        for diff in diffs {
            let path = diff.path.lowercased()
            if path.contains("test") || path.contains("spec") {
                hasTestChanges = true
            } else if path.hasSuffix(".swift") || path.hasSuffix(".m") ||
                      path.hasSuffix(".java") || path.hasSuffix(".kt") ||
                      path.hasSuffix(".ts") || path.hasSuffix(".js") {
                hasSourceChanges = true
            }
        }

        if hasSourceChanges && hasTestChanges {
            return .covered
        } else if hasSourceChanges && !hasTestChanges {
            return .missing
        } else if !hasSourceChanges && hasTestChanges {
            return .covered
        } else {
            return .unknown
        }
    }

    private func analyzeDependencyImpact(
        diffs: [FileDiff],
        repositoryFiles: [String]
    ) -> ChangeImpactAnalysis.DependencyImpact {
        let changedFileNames = diffs.map { ($0.path as NSString).lastPathComponent }

        // Find files that might import the changed files
        // In a real implementation, this would parse imports
        var dependentFiles: [String] = []
        var affectedPackages: [String] = []

        for diff in diffs {
            let path = diff.path

            // Check for package manifest changes
            if path.contains("Package.swift") || path.contains("Podfile") ||
               path.contains("package.json") || path.contains("build.gradle") {
                affectedPackages.append(path)
            }
        }

        return ChangeImpactAnalysis.DependencyImpact(
            dependentFiles: dependentFiles,
            affectedPackages: affectedPackages,
            affectsDownstream: !affectedPackages.isEmpty
        )
    }

    private func detectBreakingChanges(
        diffs: [FileDiff],
        structuralChanges: [StructuralChange]
    ) -> [ChangeImpactAnalysis.BreakingChange] {
        var breakingChanges: [ChangeImpactAnalysis.BreakingChange] = []

        for change in structuralChanges {
            // Removed public entities are breaking
            if change.changeType == .removed &&
               (change.entity.visibility == .public || change.entity.visibility == .open) {
                breakingChanges.append(ChangeImpactAnalysis.BreakingChange(
                    description: "Public \(change.entity.kind.rawValue) '\(change.entity.name)' was removed",
                    severity: .major,
                    entity: change.entity.name
                ))
            }

            // Public signature changes are breaking
            if change.changeType == .signatureChanged &&
               (change.entity.visibility == .public || change.entity.visibility == .open) {
                breakingChanges.append(ChangeImpactAnalysis.BreakingChange(
                    description: "Public \(change.entity.kind.rawValue) '\(change.entity.name)' signature changed",
                    severity: .major,
                    entity: change.entity.name
                ))
            }

            // Visibility reductions are breaking
            if change.changeType == .visibilityChanged,
               let oldEntity = change.oldEntity,
               change.entity.visibility < oldEntity.visibility {
                breakingChanges.append(ChangeImpactAnalysis.BreakingChange(
                    description: "'\(change.entity.name)' visibility reduced from \(oldEntity.visibility.rawValue) to \(change.entity.visibility.rawValue)",
                    severity: .major,
                    entity: change.entity.name
                ))
            }
        }

        return breakingChanges
    }

    private func extractFunctionName(from line: String) -> String? {
        let pattern = "func\\s+(\\w+)"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              let range = Range(match.range(at: 1), in: line) else {
            return nil
        }
        return String(line[range])
    }

    private func extractClassName(from line: String) -> String? {
        let pattern = "(?:class|struct|enum|protocol)\\s+(\\w+)"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              let range = Range(match.range(at: 1), in: line) else {
            return nil
        }
        return String(line[range])
    }
}
