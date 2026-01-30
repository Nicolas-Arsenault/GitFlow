import SwiftUI

/// View displaying structural changes in a file (classes, functions, etc.)
struct StructuralDiffView: View {
    let changes: [StructuralChange]
    let oldEntities: [CodeEntity]
    let newEntities: [CodeEntity]
    var onSelectChange: ((StructuralChange) -> Void)?

    @State private var selectedChange: StructuralChange?
    @State private var expandedEntities: Set<String> = []

    var body: some View {
        VStack(spacing: 0) {
            // Header
            structureHeader

            Divider()

            if changes.isEmpty && oldEntities.isEmpty && newEntities.isEmpty {
                emptyState
            } else if changes.isEmpty {
                noChangesState
            } else {
                // Changes list
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(groupedChanges, id: \.0) { group, groupChanges in
                            StructuralChangeGroup(
                                title: group,
                                changes: groupChanges,
                                selectedChange: $selectedChange,
                                onSelect: onSelectChange
                            )
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
    }

    // MARK: - Header

    private var structureHeader: some View {
        HStack {
            Image(systemName: "list.bullet.indent")
                .foregroundStyle(.secondary)
            Text("Structure")
                .font(.headline)

            Spacer()

            // Summary badges
            HStack(spacing: 8) {
                if addedCount > 0 {
                    Badge(count: addedCount, color: .green, icon: "plus")
                }
                if removedCount > 0 {
                    Badge(count: removedCount, color: .red, icon: "minus")
                }
                if modifiedCount > 0 {
                    Badge(count: modifiedCount, color: .orange, icon: "pencil")
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - States

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "doc.text")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)
            Text("No Structure")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Unable to parse code structure")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var noChangesState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "checkmark.circle")
                .font(.system(size: 32))
                .foregroundStyle(.green)
            Text("No Structural Changes")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Code structure is unchanged")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Computed Properties

    private var groupedChanges: [(String, [StructuralChange])] {
        let grouped = Dictionary(grouping: changes) { change -> String in
            switch change.changeType {
            case .added: return "Added"
            case .removed: return "Removed"
            case .renamed, .moved: return "Renamed/Moved"
            case .modified, .signatureChanged, .visibilityChanged: return "Modified"
            }
        }

        // Order: Added, Modified, Renamed, Removed
        let order = ["Added", "Modified", "Renamed/Moved", "Removed"]
        return order.compactMap { key in
            grouped[key].map { (key, $0) }
        }
    }

    private var addedCount: Int {
        changes.filter { $0.changeType == .added }.count
    }

    private var removedCount: Int {
        changes.filter { $0.changeType == .removed }.count
    }

    private var modifiedCount: Int {
        changes.filter {
            $0.changeType == .modified ||
            $0.changeType == .signatureChanged ||
            $0.changeType == .visibilityChanged ||
            $0.changeType == .renamed ||
            $0.changeType == .moved
        }.count
    }
}

// MARK: - Change Group

private struct StructuralChangeGroup: View {
    let title: String
    let changes: [StructuralChange]
    @Binding var selectedChange: StructuralChange?
    var onSelect: ((StructuralChange) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Group header
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.secondary.opacity(0.05))

            // Changes
            ForEach(changes) { change in
                StructuralChangeRow(
                    change: change,
                    isSelected: selectedChange?.id == change.id,
                    onSelect: {
                        selectedChange = change
                        onSelect?(change)
                    }
                )
            }
        }
    }
}

// MARK: - Change Row

private struct StructuralChangeRow: View {
    let change: StructuralChange
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                // Change type icon
                Image(systemName: change.icon)
                    .foregroundStyle(changeColor)
                    .frame(width: 16)

                // Entity icon
                Image(systemName: change.entity.kind.icon)
                    .foregroundStyle(entityColor)
                    .frame(width: 16)

                // Entity info
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(change.entity.name)
                            .font(.system(.body, design: .monospaced))
                            .fontWeight(.medium)

                        if change.entity.visibility != .internal {
                            Text(change.entity.visibility.rawValue)
                                .font(.caption2)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.secondary.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                        }
                    }

                    Text(change.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                // Line number
                Text("L\(change.entity.lineRange.lowerBound + 1)")
                    .font(.caption.monospaced())
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var changeColor: Color {
        switch change.color {
        case "green": return .green
        case "red": return .red
        case "orange": return .orange
        case "blue": return .blue
        case "purple": return .purple
        case "yellow": return .yellow
        default: return .secondary
        }
    }

    private var entityColor: Color {
        switch change.entity.kind.color {
        case "purple": return .purple
        case "orange": return .orange
        case "blue": return .blue
        case "green": return .green
        case "teal": return .teal
        case "yellow": return .yellow
        default: return .secondary
        }
    }
}

// MARK: - Badge

private struct Badge: View {
    let count: Int
    let color: Color
    let icon: String

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 8, weight: .bold))
            Text("\(count)")
                .font(.caption2.bold())
        }
        .foregroundStyle(color)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(color.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

// MARK: - Entity Tree View

/// View showing the code structure as a tree
struct EntityTreeView: View {
    let entities: [CodeEntity]
    var onSelectEntity: ((CodeEntity) -> Void)?

    @State private var expandedIds: Set<String> = []

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(entities) { entity in
                    EntityRow(
                        entity: entity,
                        depth: 0,
                        expandedIds: $expandedIds,
                        onSelect: onSelectEntity
                    )
                }
            }
        }
    }
}

private struct EntityRow: View {
    let entity: CodeEntity
    let depth: Int
    @Binding var expandedIds: Set<String>
    var onSelect: ((CodeEntity) -> Void)?

    private var isExpanded: Bool {
        expandedIds.contains(entity.id)
    }

    private var hasChildren: Bool {
        !entity.children.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                if hasChildren {
                    if isExpanded {
                        expandedIds.remove(entity.id)
                    } else {
                        expandedIds.insert(entity.id)
                    }
                }
                onSelect?(entity)
            } label: {
                HStack(spacing: 4) {
                    // Indentation
                    if depth > 0 {
                        Color.clear
                            .frame(width: CGFloat(depth) * 16)
                    }

                    // Expand/collapse indicator
                    if hasChildren {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .frame(width: 12)
                    } else {
                        Color.clear.frame(width: 12)
                    }

                    // Entity icon
                    Image(systemName: entity.kind.icon)
                        .foregroundStyle(entityColor)
                        .frame(width: 16)

                    // Name
                    Text(entity.name)
                        .font(.system(.caption, design: .monospaced))

                    // Visibility badge
                    if entity.visibility != .internal {
                        Text(entity.visibility.rawValue)
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .padding(.vertical, 3)
                .padding(.horizontal, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Children
            if isExpanded {
                ForEach(entity.children) { child in
                    EntityRow(
                        entity: child,
                        depth: depth + 1,
                        expandedIds: $expandedIds,
                        onSelect: onSelect
                    )
                }
            }
        }
    }

    private var entityColor: Color {
        switch entity.kind.color {
        case "purple": return .purple
        case "orange": return .orange
        case "blue": return .blue
        case "green": return .green
        case "teal": return .teal
        case "yellow": return .yellow
        default: return .secondary
        }
    }
}

// MARK: - Preview

#Preview {
    StructuralDiffView(
        changes: [
            StructuralChange(
                changeType: .added,
                entity: CodeEntity(
                    id: "1",
                    name: "validateCredentials",
                    kind: .function,
                    visibility: .public,
                    signature: "func validateCredentials(_ creds: Credentials) -> Bool",
                    lineRange: 45..<52,
                    children: []
                ),
                oldEntity: nil,
                description: "func 'validateCredentials' added"
            ),
            StructuralChange(
                changeType: .signatureChanged,
                entity: CodeEntity(
                    id: "2",
                    name: "authenticate",
                    kind: .function,
                    visibility: .public,
                    signature: "func authenticate(credentials: Credentials) async throws",
                    lineRange: 12..<30,
                    children: []
                ),
                oldEntity: CodeEntity(
                    id: "2",
                    name: "authenticate",
                    kind: .function,
                    visibility: .public,
                    signature: "func authenticate(user: String, password: String) throws",
                    lineRange: 12..<25,
                    children: []
                ),
                description: "Signature changed: parameters updated"
            ),
            StructuralChange(
                changeType: .removed,
                entity: CodeEntity(
                    id: "3",
                    name: "legacyLogin",
                    kind: .function,
                    visibility: .internal,
                    signature: "func legacyLogin()",
                    lineRange: 60..<65,
                    children: []
                ),
                oldEntity: nil,
                description: "func 'legacyLogin' removed"
            )
        ],
        oldEntities: [],
        newEntities: []
    )
    .frame(width: 350, height: 400)
}
