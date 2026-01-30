import Foundation

/// Represents the semantic equivalence analysis of a code change
struct SemanticEquivalence: Equatable {
    /// The type of semantic equivalence
    let equivalenceType: EquivalenceType

    /// Confidence level in the equivalence detection
    let confidence: Confidence

    /// Description of what was detected
    let description: String

    /// The old code snippet
    let oldCode: String?

    /// The new code snippet
    let newCode: String?

    /// Type of semantic equivalence
    enum EquivalenceType: String, Equatable {
        case methodExtraction = "Method Extraction"
        case methodInlining = "Method Inlining"
        case variableRename = "Variable Rename"
        case reordering = "Statement Reordering"
        case formattingOnly = "Formatting Only"
        case commentOnly = "Comment Only"
        case importReorganization = "Import Reorganization"
        case typeAliasChange = "Type Alias Change"
        case unknown = "Unknown"

        var icon: String {
            switch self {
            case .methodExtraction: return "arrow.up.right.square"
            case .methodInlining: return "arrow.down.left.square"
            case .variableRename: return "character.cursor.ibeam"
            case .reordering: return "arrow.up.arrow.down"
            case .formattingOnly: return "textformat"
            case .commentOnly: return "text.bubble"
            case .importReorganization: return "arrow.triangle.2.circlepath"
            case .typeAliasChange: return "t.square"
            case .unknown: return "questionmark.circle"
            }
        }

        var color: String {
            switch self {
            case .methodExtraction, .methodInlining: return "blue"
            case .variableRename: return "purple"
            case .reordering: return "orange"
            case .formattingOnly, .commentOnly: return "gray"
            case .importReorganization: return "teal"
            case .typeAliasChange: return "green"
            case .unknown: return "secondary"
            }
        }

        /// Whether this type of change preserves behavior
        var preservesBehavior: Bool {
            switch self {
            case .formattingOnly, .commentOnly, .importReorganization, .reordering:
                return true
            case .methodExtraction, .methodInlining, .variableRename, .typeAliasChange:
                return true // Generally true but needs verification
            case .unknown:
                return false
            }
        }
    }

    /// Confidence level
    enum Confidence: String, Equatable, Comparable {
        case high = "High"
        case medium = "Medium"
        case low = "Low"
        case unknown = "Unknown"

        static func < (lhs: Confidence, rhs: Confidence) -> Bool {
            let order: [Confidence] = [.unknown, .low, .medium, .high]
            return order.firstIndex(of: lhs)! < order.firstIndex(of: rhs)!
        }

        var color: String {
            switch self {
            case .high: return "green"
            case .medium: return "yellow"
            case .low: return "orange"
            case .unknown: return "gray"
            }
        }
    }

    /// Label to display for this equivalence
    var label: String {
        if equivalenceType.preservesBehavior && confidence >= .medium {
            return "\(equivalenceType.rawValue) — NO BEHAVIOR CHANGE"
        } else if equivalenceType.preservesBehavior {
            return "\(equivalenceType.rawValue) — LIKELY NO BEHAVIOR CHANGE"
        } else {
            return "\(equivalenceType.rawValue) — BEHAVIOR MAY CHANGE"
        }
    }
}

/// Detects semantic equivalence in code changes
class SemanticEquivalenceDetector {

    /// Analyzes diffs to detect semantic equivalences
    func detect(in diffs: [FileDiff]) -> [SemanticEquivalence] {
        var equivalences: [SemanticEquivalence] = []

        for diff in diffs {
            equivalences.append(contentsOf: analyzeFileDiff(diff))
        }

        return equivalences
    }

    /// Analyzes a single file diff
    private func analyzeFileDiff(_ diff: FileDiff) -> [SemanticEquivalence] {
        var equivalences: [SemanticEquivalence] = []

        // Check for formatting-only changes
        if let formattingEquiv = detectFormattingOnly(diff) {
            equivalences.append(formattingEquiv)
        }

        // Check for comment-only changes
        if let commentEquiv = detectCommentOnly(diff) {
            equivalences.append(commentEquiv)
        }

        // Check for import reorganization
        if let importEquiv = detectImportReorganization(diff) {
            equivalences.append(importEquiv)
        }

        // Check for variable renames
        equivalences.append(contentsOf: detectVariableRenames(diff))

        // Check for method extraction
        if let extractionEquiv = detectMethodExtraction(diff) {
            equivalences.append(extractionEquiv)
        }

        // Check for method inlining
        if let inliningEquiv = detectMethodInlining(diff) {
            equivalences.append(inliningEquiv)
        }

        // Check for statement reordering
        if let reorderEquiv = detectReordering(diff) {
            equivalences.append(reorderEquiv)
        }

        return equivalences
    }

    // MARK: - Detection Methods

    private func detectFormattingOnly(_ diff: FileDiff) -> SemanticEquivalence? {
        // Collect all additions and deletions
        var deletedLines: [String] = []
        var addedLines: [String] = []

        for hunk in diff.hunks {
            for line in hunk.lines {
                switch line.type {
                case .deletion:
                    deletedLines.append(normalizeWhitespace(line.content))
                case .addition:
                    addedLines.append(normalizeWhitespace(line.content))
                default:
                    break
                }
            }
        }

        // If normalized content is the same, it's formatting only
        let deletedNormalized = Set(deletedLines.filter { !$0.isEmpty })
        let addedNormalized = Set(addedLines.filter { !$0.isEmpty })

        if deletedNormalized == addedNormalized && !deletedNormalized.isEmpty {
            return SemanticEquivalence(
                equivalenceType: .formattingOnly,
                confidence: .high,
                description: "Only whitespace/formatting changes detected",
                oldCode: nil,
                newCode: nil
            )
        }

        return nil
    }

    private func detectCommentOnly(_ diff: FileDiff) -> SemanticEquivalence? {
        var hasNonCommentChange = false
        var hasCommentChange = false

        for hunk in diff.hunks {
            for line in hunk.lines {
                guard line.type == .deletion || line.type == .addition else { continue }

                let trimmed = line.content.trimmingCharacters(in: .whitespaces)
                if isCommentLine(trimmed) {
                    hasCommentChange = true
                } else if !trimmed.isEmpty {
                    hasNonCommentChange = true
                }
            }
        }

        if hasCommentChange && !hasNonCommentChange {
            return SemanticEquivalence(
                equivalenceType: .commentOnly,
                confidence: .high,
                description: "Only comment changes detected",
                oldCode: nil,
                newCode: nil
            )
        }

        return nil
    }

    private func detectImportReorganization(_ diff: FileDiff) -> SemanticEquivalence? {
        var deletedImports: Set<String> = []
        var addedImports: Set<String> = []
        var hasNonImportChange = false

        for hunk in diff.hunks {
            for line in hunk.lines {
                let trimmed = line.content.trimmingCharacters(in: .whitespaces)

                if isImportLine(trimmed) {
                    let normalized = normalizeImport(trimmed)
                    if line.type == .deletion {
                        deletedImports.insert(normalized)
                    } else if line.type == .addition {
                        addedImports.insert(normalized)
                    }
                } else if !trimmed.isEmpty && (line.type == .deletion || line.type == .addition) {
                    hasNonImportChange = true
                }
            }
        }

        if !hasNonImportChange && deletedImports == addedImports && !deletedImports.isEmpty {
            return SemanticEquivalence(
                equivalenceType: .importReorganization,
                confidence: .high,
                description: "Import statements reordered",
                oldCode: nil,
                newCode: nil
            )
        }

        return nil
    }

    private func detectVariableRenames(_ diff: FileDiff) -> [SemanticEquivalence] {
        var equivalences: [SemanticEquivalence] = []

        for hunk in diff.hunks {
            // Look for paired deletions/additions
            var i = 0
            while i < hunk.lines.count {
                let line = hunk.lines[i]
                if line.type == .deletion {
                    // Find matching addition
                    var j = i + 1
                    while j < hunk.lines.count && hunk.lines[j].type == .deletion {
                        j += 1
                    }
                    if j < hunk.lines.count && hunk.lines[j].type == .addition {
                        // Check if this could be a rename
                        if let rename = detectRenameInPair(deleted: line.content, added: hunk.lines[j].content) {
                            equivalences.append(rename)
                        }
                    }
                }
                i += 1
            }
        }

        return equivalences
    }

    private func detectRenameInPair(deleted: String, added: String) -> SemanticEquivalence? {
        // Tokenize both lines
        let deletedTokens = tokenize(deleted)
        let addedTokens = tokenize(added)

        // Find single-word difference
        if deletedTokens.count == addedTokens.count {
            var differences: [(old: String, new: String)] = []
            for (oldToken, newToken) in zip(deletedTokens, addedTokens) {
                if oldToken != newToken {
                    differences.append((oldToken, newToken))
                }
            }

            // If only one identifier changed, it's likely a rename
            if differences.count == 1 {
                let (oldName, newName) = differences[0]
                if isIdentifier(oldName) && isIdentifier(newName) {
                    return SemanticEquivalence(
                        equivalenceType: .variableRename,
                        confidence: .medium,
                        description: "'\(oldName)' renamed to '\(newName)'",
                        oldCode: deleted,
                        newCode: added
                    )
                }
            }
        }

        return nil
    }

    private func detectMethodExtraction(_ diff: FileDiff) -> SemanticEquivalence? {
        // Look for patterns where:
        // 1. A block of code is deleted
        // 2. A new function is added
        // 3. A call to the new function is added where the code was

        var hasNewFunction = false
        var hasDeletedBlock = false
        var newFunctionName: String?

        for hunk in diff.hunks {
            for line in hunk.lines {
                if line.type == .addition && line.content.contains("func ") {
                    hasNewFunction = true
                    newFunctionName = extractFunctionName(from: line.content)
                }
                if line.type == .deletion && !line.content.trimmingCharacters(in: .whitespaces).isEmpty {
                    hasDeletedBlock = true
                }
            }
        }

        if hasNewFunction && hasDeletedBlock, let funcName = newFunctionName {
            // Check if the new function is called
            for hunk in diff.hunks {
                for line in hunk.lines where line.type == .addition {
                    if line.content.contains("\(funcName)(") {
                        return SemanticEquivalence(
                            equivalenceType: .methodExtraction,
                            confidence: .medium,
                            description: "Code extracted to new function '\(funcName)'",
                            oldCode: nil,
                            newCode: nil
                        )
                    }
                }
            }
        }

        return nil
    }

    private func detectMethodInlining(_ diff: FileDiff) -> SemanticEquivalence? {
        // Look for patterns where:
        // 1. A function is deleted
        // 2. Code is added where the function was called

        var hasDeletedFunction = false
        var deletedFunctionName: String?

        for hunk in diff.hunks {
            for line in hunk.lines {
                if line.type == .deletion && line.content.contains("func ") {
                    hasDeletedFunction = true
                    deletedFunctionName = extractFunctionName(from: line.content)
                }
            }
        }

        if hasDeletedFunction, let funcName = deletedFunctionName {
            // Check if calls to this function were removed
            for hunk in diff.hunks {
                for line in hunk.lines where line.type == .deletion {
                    if line.content.contains("\(funcName)(") {
                        return SemanticEquivalence(
                            equivalenceType: .methodInlining,
                            confidence: .low,
                            description: "Function '\(funcName)' may have been inlined",
                            oldCode: nil,
                            newCode: nil
                        )
                    }
                }
            }
        }

        return nil
    }

    private func detectReordering(_ diff: FileDiff) -> SemanticEquivalence? {
        var deletedStatements: [String] = []
        var addedStatements: [String] = []

        for hunk in diff.hunks {
            for line in hunk.lines {
                let normalized = normalizeWhitespace(line.content)
                if !normalized.isEmpty && !isCommentLine(normalized) {
                    if line.type == .deletion {
                        deletedStatements.append(normalized)
                    } else if line.type == .addition {
                        addedStatements.append(normalized)
                    }
                }
            }
        }

        // Check if it's just reordering (same statements, different order)
        if Set(deletedStatements) == Set(addedStatements) &&
           deletedStatements != addedStatements &&
           deletedStatements.count > 1 {
            return SemanticEquivalence(
                equivalenceType: .reordering,
                confidence: .medium,
                description: "Statements appear to be reordered",
                oldCode: nil,
                newCode: nil
            )
        }

        return nil
    }

    // MARK: - Helpers

    private func normalizeWhitespace(_ str: String) -> String {
        str.components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private func isCommentLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed.hasPrefix("//") || trimmed.hasPrefix("/*") ||
               trimmed.hasPrefix("*") || trimmed.hasPrefix("///") ||
               trimmed.hasPrefix("#")
    }

    private func isImportLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed.hasPrefix("import ") || trimmed.hasPrefix("@import ") ||
               trimmed.hasPrefix("#import ") || trimmed.hasPrefix("#include ") ||
               trimmed.hasPrefix("from ") || trimmed.hasPrefix("require(") ||
               trimmed.hasPrefix("using ")
    }

    private func normalizeImport(_ line: String) -> String {
        normalizeWhitespace(line)
    }

    private func tokenize(_ str: String) -> [String] {
        var tokens: [String] = []
        var current = ""

        for char in str {
            if char.isLetter || char.isNumber || char == "_" {
                current.append(char)
            } else {
                if !current.isEmpty {
                    tokens.append(current)
                    current = ""
                }
                if !char.isWhitespace {
                    tokens.append(String(char))
                }
            }
        }

        if !current.isEmpty {
            tokens.append(current)
        }

        return tokens
    }

    private func isIdentifier(_ str: String) -> Bool {
        guard let first = str.first else { return false }
        return (first.isLetter || first == "_") &&
               str.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" }
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
}
