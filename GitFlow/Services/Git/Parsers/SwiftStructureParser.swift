import Foundation
import SwiftSyntax
import SwiftParser

/// Represents a code structure entity (class, struct, function, etc.)
struct CodeEntity: Identifiable, Equatable, Hashable {
    let id: String
    let name: String
    let kind: Kind
    let visibility: Visibility
    let signature: String
    let lineRange: Range<Int>
    let children: [CodeEntity]

    /// The kind of code entity
    enum Kind: String, Equatable, Hashable {
        case `class` = "class"
        case `struct` = "struct"
        case `enum` = "enum"
        case `protocol` = "protocol"
        case `extension` = "extension"
        case function = "func"
        case method = "method"
        case property = "var"
        case constant = "let"
        case initializer = "init"
        case `subscript` = "subscript"
        case `typealias` = "typealias"
        case associatedType = "associatedtype"
        case `case` = "case"

        var icon: String {
            switch self {
            case .class: return "c.square"
            case .struct: return "s.square"
            case .enum: return "e.square"
            case .protocol: return "p.square"
            case .extension: return "curlybraces.square"
            case .function, .method: return "f.square"
            case .property, .constant: return "v.square"
            case .initializer: return "hammer"
            case .subscript: return "square.stack"
            case .typealias, .associatedType: return "t.square"
            case .case: return "list.bullet"
            }
        }

        var color: String {
            switch self {
            case .class, .struct: return "purple"
            case .enum: return "orange"
            case .protocol: return "blue"
            case .extension: return "gray"
            case .function, .method: return "green"
            case .property, .constant: return "teal"
            case .initializer: return "yellow"
            default: return "secondary"
            }
        }
    }

    /// Visibility/access level
    enum Visibility: String, Equatable, Hashable, Comparable {
        case `private` = "private"
        case `fileprivate` = "fileprivate"
        case `internal` = "internal"
        case `public` = "public"
        case `open` = "open"
        case unknown = ""

        static func < (lhs: Visibility, rhs: Visibility) -> Bool {
            let order: [Visibility] = [.private, .fileprivate, .internal, .public, .open]
            let lhsIndex = order.firstIndex(of: lhs) ?? 2
            let rhsIndex = order.firstIndex(of: rhs) ?? 2
            return lhsIndex < rhsIndex
        }
    }

    /// Creates a unique ID from entity properties
    static func makeId(kind: Kind, name: String, signature: String) -> String {
        "\(kind.rawValue):\(name):\(signature.hashValue)"
    }
}

/// Represents a structural change between two versions of code
struct StructuralChange: Identifiable, Equatable {
    let id = UUID()
    let changeType: ChangeType
    let entity: CodeEntity
    let oldEntity: CodeEntity?
    let description: String

    enum ChangeType: String, Equatable {
        case added = "Added"
        case removed = "Removed"
        case modified = "Modified"
        case renamed = "Renamed"
        case moved = "Moved"
        case visibilityChanged = "Visibility Changed"
        case signatureChanged = "Signature Changed"
    }

    var icon: String {
        switch changeType {
        case .added: return "plus.circle.fill"
        case .removed: return "minus.circle.fill"
        case .modified: return "pencil.circle.fill"
        case .renamed: return "arrow.right.circle.fill"
        case .moved: return "arrow.up.arrow.down.circle.fill"
        case .visibilityChanged: return "eye.circle.fill"
        case .signatureChanged: return "signature"
        }
    }

    var color: String {
        switch changeType {
        case .added: return "green"
        case .removed: return "red"
        case .modified: return "orange"
        case .renamed: return "blue"
        case .moved: return "purple"
        case .visibilityChanged: return "yellow"
        case .signatureChanged: return "orange"
        }
    }
}

// MARK: - SwiftSyntax-based Parser

/// Builder class for constructing CodeEntity instances with children
/// Used during AST traversal to accumulate child entities before finalizing the parent
private class EntityBuilder {
    let kind: CodeEntity.Kind
    let name: String
    let visibility: CodeEntity.Visibility
    let signature: String
    let startLine: Int
    var endLine: Int
    var children: [CodeEntity] = []

    init(kind: CodeEntity.Kind, name: String, visibility: CodeEntity.Visibility, signature: String, startLine: Int, endLine: Int) {
        self.kind = kind
        self.name = name
        self.visibility = visibility
        self.signature = signature
        self.startLine = startLine
        self.endLine = endLine
    }

    func addChild(_ entity: CodeEntity) {
        children.append(entity)
    }

    func build() -> CodeEntity {
        CodeEntity(
            id: CodeEntity.makeId(kind: kind, name: name, signature: signature),
            name: name,
            kind: kind,
            visibility: visibility,
            signature: signature,
            lineRange: startLine..<endLine,
            children: children
        )
    }
}

/// SyntaxVisitor that traverses Swift AST and extracts code structure entities.
///
/// This visitor uses a stack-based approach to handle nested declarations:
/// - When entering a type declaration (class, struct, etc.), an EntityBuilder is pushed onto the stack
/// - Child declarations are added to the current builder on the stack
/// - When exiting a type declaration, the builder is popped and finalized
/// - Leaf declarations (functions, properties) are added directly without using the stack
private class SwiftSyntaxStructureVisitor: SyntaxVisitor {
    private let sourceLocationConverter: SourceLocationConverter

    /// Stack of entity builders for handling nested types
    private var entityStack: [EntityBuilder] = []

    /// Root-level entities (not nested inside any type)
    private(set) var rootEntities: [CodeEntity] = []

    init(sourceLocationConverter: SourceLocationConverter) {
        self.sourceLocationConverter = sourceLocationConverter
        super.init(viewMode: .sourceAccurate)
    }

    // MARK: - Helper Methods

    /// Extracts the visibility/access level from declaration modifiers
    private func extractVisibility(from modifiers: DeclModifierListSyntax) -> CodeEntity.Visibility {
        for modifier in modifiers {
            switch modifier.name.tokenKind {
            case .keyword(.private):
                // Check for private(set) which is still private visibility
                return .private
            case .keyword(.fileprivate):
                return .fileprivate
            case .keyword(.internal):
                return .internal
            case .keyword(.public):
                return .public
            case .keyword(.open):
                return .open
            default:
                continue
            }
        }
        return .internal // Swift default
    }

    /// Extracts line range from a syntax node
    /// Returns 0-based line indices with exclusive upper bound to match existing behavior
    private func extractLineRange(from node: some SyntaxProtocol) -> (start: Int, end: Int) {
        let startLocation = sourceLocationConverter.location(for: node.positionAfterSkippingLeadingTrivia)
        let endLocation = sourceLocationConverter.location(for: node.endPositionBeforeTrailingTrivia)

        // Convert to 0-based indices (SourceLocation uses 1-based lines)
        let startLine = startLocation.line - 1
        let endLine = endLocation.line // Exclusive upper bound

        return (startLine, endLine)
    }

    /// Pushes an entity builder onto the stack for types with children
    private func pushEntity(_ builder: EntityBuilder) {
        entityStack.append(builder)
    }

    /// Pops and finalizes an entity, adding it to its parent or root entities
    private func popEntity() {
        guard let completed = entityStack.popLast() else { return }
        let entity = completed.build()

        if let parent = entityStack.last {
            parent.addChild(entity)
        } else {
            rootEntities.append(entity)
        }
    }

    /// Adds a leaf entity (no children) to the current parent or root
    private func addEntity(_ entity: CodeEntity) {
        if let parent = entityStack.last {
            parent.addChild(entity)
        } else {
            rootEntities.append(entity)
        }
    }

    /// Determines if the current context is inside a type (making functions into methods)
    private var isInsideType: Bool {
        !entityStack.isEmpty
    }

    // MARK: - Type Declarations

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        let lineRange = extractLineRange(from: node)
        let visibility = extractVisibility(from: node.modifiers)
        let signature = buildTypeSignature(keyword: "class", name: node.name.text, inheritanceClause: node.inheritanceClause, genericParameterClause: node.genericParameterClause, genericWhereClause: node.genericWhereClause)

        let builder = EntityBuilder(
            kind: .class,
            name: node.name.text,
            visibility: visibility,
            signature: signature,
            startLine: lineRange.start,
            endLine: lineRange.end
        )
        pushEntity(builder)
        return .visitChildren
    }

    override func visitPost(_ node: ClassDeclSyntax) {
        popEntity()
    }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        let lineRange = extractLineRange(from: node)
        let visibility = extractVisibility(from: node.modifiers)
        let signature = buildTypeSignature(keyword: "struct", name: node.name.text, inheritanceClause: node.inheritanceClause, genericParameterClause: node.genericParameterClause, genericWhereClause: node.genericWhereClause)

        let builder = EntityBuilder(
            kind: .struct,
            name: node.name.text,
            visibility: visibility,
            signature: signature,
            startLine: lineRange.start,
            endLine: lineRange.end
        )
        pushEntity(builder)
        return .visitChildren
    }

    override func visitPost(_ node: StructDeclSyntax) {
        popEntity()
    }

    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        let lineRange = extractLineRange(from: node)
        let visibility = extractVisibility(from: node.modifiers)
        let signature = buildTypeSignature(keyword: "enum", name: node.name.text, inheritanceClause: node.inheritanceClause, genericParameterClause: node.genericParameterClause, genericWhereClause: node.genericWhereClause)

        let builder = EntityBuilder(
            kind: .enum,
            name: node.name.text,
            visibility: visibility,
            signature: signature,
            startLine: lineRange.start,
            endLine: lineRange.end
        )
        pushEntity(builder)
        return .visitChildren
    }

    override func visitPost(_ node: EnumDeclSyntax) {
        popEntity()
    }

    override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
        let lineRange = extractLineRange(from: node)
        let visibility = extractVisibility(from: node.modifiers)

        var signature = "protocol \(node.name.text)"
        if let inheritance = node.inheritanceClause {
            signature += inheritance.trimmedDescription
        }

        let builder = EntityBuilder(
            kind: .protocol,
            name: node.name.text,
            visibility: visibility,
            signature: signature,
            startLine: lineRange.start,
            endLine: lineRange.end
        )
        pushEntity(builder)
        return .visitChildren
    }

    override func visitPost(_ node: ProtocolDeclSyntax) {
        popEntity()
    }

    override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        let lineRange = extractLineRange(from: node)
        let visibility = extractVisibility(from: node.modifiers)
        let extendedType = node.extendedType.trimmedDescription

        var signature = "extension \(extendedType)"
        if let inheritance = node.inheritanceClause {
            signature += inheritance.trimmedDescription
        }
        if let whereClause = node.genericWhereClause {
            signature += " " + whereClause.trimmedDescription
        }

        let builder = EntityBuilder(
            kind: .extension,
            name: extendedType,
            visibility: visibility,
            signature: signature,
            startLine: lineRange.start,
            endLine: lineRange.end
        )
        pushEntity(builder)
        return .visitChildren
    }

    override func visitPost(_ node: ExtensionDeclSyntax) {
        popEntity()
    }

    // MARK: - Function Declarations

    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        let lineRange = extractLineRange(from: node)
        let visibility = extractVisibility(from: node.modifiers)
        let kind: CodeEntity.Kind = isInsideType ? .method : .function

        let signature = buildFunctionSignature(node)

        let entity = CodeEntity(
            id: CodeEntity.makeId(kind: kind, name: node.name.text, signature: signature),
            name: node.name.text,
            kind: kind,
            visibility: visibility,
            signature: signature,
            lineRange: lineRange.start..<lineRange.end,
            children: []
        )
        addEntity(entity)
        return .skipChildren // Don't visit function body
    }

    override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
        let lineRange = extractLineRange(from: node)
        let visibility = extractVisibility(from: node.modifiers)

        let signature = buildInitializerSignature(node)

        let entity = CodeEntity(
            id: CodeEntity.makeId(kind: .initializer, name: "init", signature: signature),
            name: "init",
            kind: .initializer,
            visibility: visibility,
            signature: signature,
            lineRange: lineRange.start..<lineRange.end,
            children: []
        )
        addEntity(entity)
        return .skipChildren
    }

    // MARK: - Property Declarations

    override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        let lineRange = extractLineRange(from: node)
        let visibility = extractVisibility(from: node.modifiers)
        let isLet = node.bindingSpecifier.tokenKind == .keyword(.let)
        let kind: CodeEntity.Kind = isLet ? .constant : .property

        // Handle each binding (e.g., `var a, b: Int` has two bindings)
        for binding in node.bindings {
            guard let identifier = binding.pattern.as(IdentifierPatternSyntax.self) else {
                continue
            }

            let name = identifier.identifier.text
            let signature = buildPropertySignature(node, binding: binding, name: name)

            let entity = CodeEntity(
                id: CodeEntity.makeId(kind: kind, name: name, signature: signature),
                name: name,
                kind: kind,
                visibility: visibility,
                signature: signature,
                lineRange: lineRange.start..<lineRange.end,
                children: []
            )
            addEntity(entity)
        }
        return .skipChildren
    }

    // MARK: - Enum Cases

    override func visit(_ node: EnumCaseDeclSyntax) -> SyntaxVisitorContinueKind {
        let lineRange = extractLineRange(from: node)

        // Each case declaration can have multiple elements (e.g., `case a, b, c`)
        for element in node.elements {
            let name = element.name.text
            let signature = buildEnumCaseSignature(element)

            let entity = CodeEntity(
                id: CodeEntity.makeId(kind: .case, name: name, signature: signature),
                name: name,
                kind: .case,
                visibility: .internal, // Enum cases inherit enum's visibility
                signature: signature,
                lineRange: lineRange.start..<lineRange.end,
                children: []
            )
            addEntity(entity)
        }
        return .skipChildren
    }

    // MARK: - Type Aliases and Associated Types

    override func visit(_ node: TypeAliasDeclSyntax) -> SyntaxVisitorContinueKind {
        let lineRange = extractLineRange(from: node)
        let visibility = extractVisibility(from: node.modifiers)

        let signature = "typealias \(node.name.text) = \(node.initializer.value.trimmedDescription)"

        let entity = CodeEntity(
            id: CodeEntity.makeId(kind: .typealias, name: node.name.text, signature: signature),
            name: node.name.text,
            kind: .typealias,
            visibility: visibility,
            signature: signature,
            lineRange: lineRange.start..<lineRange.end,
            children: []
        )
        addEntity(entity)
        return .skipChildren
    }

    override func visit(_ node: AssociatedTypeDeclSyntax) -> SyntaxVisitorContinueKind {
        let lineRange = extractLineRange(from: node)

        var signature = "associatedtype \(node.name.text)"
        if let inheritance = node.inheritanceClause {
            signature += inheritance.trimmedDescription
        }
        if let initializer = node.initializer {
            signature += " = \(initializer.value.trimmedDescription)"
        }

        let entity = CodeEntity(
            id: CodeEntity.makeId(kind: .associatedType, name: node.name.text, signature: signature),
            name: node.name.text,
            kind: .associatedType,
            visibility: .internal, // Associated types are always internal to protocol
            signature: signature,
            lineRange: lineRange.start..<lineRange.end,
            children: []
        )
        addEntity(entity)
        return .skipChildren
    }

    // MARK: - Subscript Declarations

    override func visit(_ node: SubscriptDeclSyntax) -> SyntaxVisitorContinueKind {
        let lineRange = extractLineRange(from: node)
        let visibility = extractVisibility(from: node.modifiers)

        let signature = buildSubscriptSignature(node)

        let entity = CodeEntity(
            id: CodeEntity.makeId(kind: .subscript, name: "subscript", signature: signature),
            name: "subscript",
            kind: .subscript,
            visibility: visibility,
            signature: signature,
            lineRange: lineRange.start..<lineRange.end,
            children: []
        )
        addEntity(entity)
        return .skipChildren
    }

    // MARK: - Signature Builders

    /// Builds a signature for type declarations (class, struct, enum)
    private func buildTypeSignature(
        keyword: String,
        name: String,
        inheritanceClause: InheritanceClauseSyntax?,
        genericParameterClause: GenericParameterClauseSyntax?,
        genericWhereClause: GenericWhereClauseSyntax?
    ) -> String {
        var signature = "\(keyword) \(name)"

        if let generics = genericParameterClause {
            signature += generics.trimmedDescription
        }

        if let inheritance = inheritanceClause {
            signature += inheritance.trimmedDescription
        }

        if let whereClause = genericWhereClause {
            signature += " " + whereClause.trimmedDescription
        }

        return signature
    }

    /// Builds a signature for function declarations
    private func buildFunctionSignature(_ node: FunctionDeclSyntax) -> String {
        var signature = "func \(node.name.text)"

        if let generics = node.genericParameterClause {
            signature += generics.trimmedDescription
        }

        signature += node.signature.parameterClause.trimmedDescription

        if node.signature.effectSpecifiers?.asyncSpecifier != nil {
            signature += " async"
        }

        if node.signature.effectSpecifiers?.throwsSpecifier != nil {
            signature += " throws"
        }

        if let returnClause = node.signature.returnClause {
            signature += " " + returnClause.trimmedDescription
        }

        if let whereClause = node.genericWhereClause {
            signature += " " + whereClause.trimmedDescription
        }

        return signature
    }

    /// Builds a signature for initializer declarations
    private func buildInitializerSignature(_ node: InitializerDeclSyntax) -> String {
        var signature = "init"

        if node.optionalMark != nil {
            signature += "?"
        }

        if let generics = node.genericParameterClause {
            signature += generics.trimmedDescription
        }

        signature += node.signature.parameterClause.trimmedDescription

        if node.signature.effectSpecifiers?.asyncSpecifier != nil {
            signature += " async"
        }

        if node.signature.effectSpecifiers?.throwsSpecifier != nil {
            signature += " throws"
        }

        return signature
    }

    /// Builds a signature for property declarations
    private func buildPropertySignature(_ node: VariableDeclSyntax, binding: PatternBindingSyntax, name: String) -> String {
        let keyword = node.bindingSpecifier.text
        var signature = "\(keyword) \(name)"

        if let typeAnnotation = binding.typeAnnotation {
            signature += typeAnnotation.trimmedDescription
        }

        return signature
    }

    /// Builds a signature for enum case elements
    private func buildEnumCaseSignature(_ element: EnumCaseElementSyntax) -> String {
        var signature = "case \(element.name.text)"

        if let associatedValue = element.parameterClause {
            signature += associatedValue.trimmedDescription
        }

        if let rawValue = element.rawValue {
            signature += " " + rawValue.trimmedDescription
        }

        return signature
    }

    /// Builds a signature for subscript declarations
    private func buildSubscriptSignature(_ node: SubscriptDeclSyntax) -> String {
        var signature = "subscript"

        if let generics = node.genericParameterClause {
            signature += generics.trimmedDescription
        }

        signature += node.parameterClause.trimmedDescription
        signature += " " + node.returnClause.trimmedDescription

        if let whereClause = node.genericWhereClause {
            signature += " " + whereClause.trimmedDescription
        }

        return signature
    }
}

// MARK: - Public Parser Interface

/// Parses Swift source code to extract structural entities using SwiftSyntax.
///
/// This parser uses SwiftSyntax for accurate AST-based parsing, which provides:
/// - Correct handling of braces in strings and comments
/// - Proper parsing of multi-line declarations
/// - Accurate generic parameter parsing
/// - Full attribute support
/// - Graceful handling of malformed code
///
/// The parser maintains the same public interface as the previous regex-based implementation
/// for backward compatibility.
class SwiftStructureParser {

    /// Parses Swift source code and returns a list of top-level entities.
    ///
    /// - Parameter source: The Swift source code to parse
    /// - Returns: An array of top-level CodeEntity objects with their children
    func parse(_ source: String) -> [CodeEntity] {
        // Handle empty source
        guard !source.isEmpty else {
            return []
        }

        // Parse the source code into a syntax tree
        let sourceFile = Parser.parse(source: source)

        // Create a source location converter for accurate line numbers
        let converter = SourceLocationConverter(fileName: "", tree: sourceFile)

        // Create and run the visitor
        let visitor = SwiftSyntaxStructureVisitor(sourceLocationConverter: converter)
        visitor.walk(sourceFile)

        return visitor.rootEntities
    }
}

// MARK: - Structural Diff Computer

/// Computes structural differences between two versions of code
class StructuralDiffComputer {

    /// Computes structural changes between old and new code
    func computeDiff(oldSource: String, newSource: String) -> [StructuralChange] {
        let parser = SwiftStructureParser()
        let oldEntities = flattenEntities(parser.parse(oldSource))
        let newEntities = flattenEntities(parser.parse(newSource))

        var changes: [StructuralChange] = []

        // Build lookup maps
        let oldByName = Dictionary(grouping: oldEntities, by: { "\($0.kind.rawValue):\($0.name)" })
        let newByName = Dictionary(grouping: newEntities, by: { "\($0.kind.rawValue):\($0.name)" })

        // Find removed entities
        for (key, entities) in oldByName {
            if newByName[key] == nil {
                for entity in entities {
                    // Check if it was renamed (same signature, different name)
                    if let renamed = findRenamedEntity(entity: entity, in: newEntities, excluding: newByName.keys) {
                        changes.append(StructuralChange(
                            changeType: .renamed,
                            entity: renamed,
                            oldEntity: entity,
                            description: "\(entity.kind.rawValue) '\(entity.name)' renamed to '\(renamed.name)'"
                        ))
                    } else {
                        changes.append(StructuralChange(
                            changeType: .removed,
                            entity: entity,
                            oldEntity: nil,
                            description: "\(entity.kind.rawValue) '\(entity.name)' removed"
                        ))
                    }
                }
            }
        }

        // Find added entities
        for (key, entities) in newByName {
            if oldByName[key] == nil {
                for entity in entities {
                    // Skip if already handled as rename
                    let isRename = changes.contains { $0.changeType == .renamed && $0.entity.id == entity.id }
                    if !isRename {
                        changes.append(StructuralChange(
                            changeType: .added,
                            entity: entity,
                            oldEntity: nil,
                            description: "\(entity.kind.rawValue) '\(entity.name)' added"
                        ))
                    }
                }
            }
        }

        // Find modified entities (same name, different signature or visibility)
        for (key, newEntitiesList) in newByName {
            guard let oldEntitiesList = oldByName[key] else { continue }

            for newEntity in newEntitiesList {
                for oldEntity in oldEntitiesList {
                    if oldEntity.signature != newEntity.signature {
                        changes.append(StructuralChange(
                            changeType: .signatureChanged,
                            entity: newEntity,
                            oldEntity: oldEntity,
                            description: "Signature changed: '\(oldEntity.signature)' → '\(newEntity.signature)'"
                        ))
                    } else if oldEntity.visibility != newEntity.visibility {
                        changes.append(StructuralChange(
                            changeType: .visibilityChanged,
                            entity: newEntity,
                            oldEntity: oldEntity,
                            description: "Visibility changed: \(oldEntity.visibility.rawValue) → \(newEntity.visibility.rawValue)"
                        ))
                    }
                }
            }
        }

        return changes
    }

    /// Flattens nested entities into a single list
    private func flattenEntities(_ entities: [CodeEntity]) -> [CodeEntity] {
        var result: [CodeEntity] = []
        for entity in entities {
            result.append(entity)
            result.append(contentsOf: flattenEntities(entity.children))
        }
        return result
    }

    /// Attempts to find a renamed entity based on signature similarity
    private func findRenamedEntity(entity: CodeEntity, in newEntities: [CodeEntity], excluding existingKeys: Dictionary<String, [CodeEntity]>.Keys) -> CodeEntity? {
        // Look for entities of same kind with similar signature but different name
        for newEntity in newEntities {
            let newKey = "\(newEntity.kind.rawValue):\(newEntity.name)"
            guard !existingKeys.contains(newKey) else { continue }
            guard newEntity.kind == entity.kind else { continue }

            // Compare signatures without the name
            let oldSigNormalized = normalizeSignature(entity.signature, removingName: entity.name)
            let newSigNormalized = normalizeSignature(newEntity.signature, removingName: newEntity.name)

            if oldSigNormalized == newSigNormalized {
                return newEntity
            }
        }
        return nil
    }

    /// Normalizes a signature by removing the entity name
    private func normalizeSignature(_ signature: String, removingName name: String) -> String {
        signature.replacingOccurrences(of: name, with: "___")
    }
}
