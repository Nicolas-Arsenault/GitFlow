import SwiftUI

/// Hierarchical tree view for navigating changed files in a diff.
///
/// Organizes files by directory and provides aggregate statistics,
/// making it easier to review large changesets.
struct DiffFileTreeView: View {
    let diffs: [FileDiff]
    @Binding var selectedDiff: FileDiff?
    var noiseOptions: NoiseSuppressionOptions = .default

    @State private var expandedDirectories: Set<String> = []
    @State private var isInitialized: Bool = false

    /// The tree structure built from the diffs.
    private var tree: DiffFileTree {
        DiffFileTree.build(from: noiseOptions.apply(to: diffs))
    }

    var body: some View {
        List {
            // Summary header
            TreeSummaryHeader(
                totalFiles: diffs.count,
                filteredFiles: tree.totalFiles,
                totalAdditions: tree.totalAdditions,
                totalDeletions: tree.totalDeletions,
                hiddenCount: diffs.count - tree.totalFiles
            )

            // Tree content
            ForEach(tree.root.children) { node in
                TreeNodeView(
                    node: node,
                    selectedDiff: $selectedDiff,
                    expandedDirectories: $expandedDirectories,
                    depth: 0
                )
            }
        }
        .listStyle(.sidebar)
        .onAppear {
            if !isInitialized {
                // Auto-expand directories with few children
                expandedDirectories = tree.directoriesWithFewChildren(threshold: 5)
                isInitialized = true
            }
        }
    }
}

// MARK: - Tree Summary Header

private struct TreeSummaryHeader: View {
    let totalFiles: Int
    let filteredFiles: Int
    let totalAdditions: Int
    let totalDeletions: Int
    let hiddenCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("\(filteredFiles) files changed")
                    .font(.subheadline.bold())

                Spacer()

                HStack(spacing: 8) {
                    Text("+\(totalAdditions)")
                        .foregroundStyle(.green)
                    Text("-\(totalDeletions)")
                        .foregroundStyle(.red)
                }
                .font(.caption)
                .fontDesign(.monospaced)
            }

            if hiddenCount > 0 {
                Text("\(hiddenCount) files hidden")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Tree Node View

private struct TreeNodeView: View {
    let node: DiffFileTree.Node
    @Binding var selectedDiff: FileDiff?
    @Binding var expandedDirectories: Set<String>
    let depth: Int

    private var isExpanded: Bool {
        expandedDirectories.contains(node.path)
    }

    var body: some View {
        if node.isDirectory {
            DirectoryRow(
                node: node,
                isExpanded: isExpanded,
                onToggle: {
                    if isExpanded {
                        expandedDirectories.remove(node.path)
                    } else {
                        expandedDirectories.insert(node.path)
                    }
                }
            )

            if isExpanded {
                ForEach(node.children) { child in
                    TreeNodeView(
                        node: child,
                        selectedDiff: $selectedDiff,
                        expandedDirectories: $expandedDirectories,
                        depth: depth + 1
                    )
                    .padding(.leading, 16)
                }
            }
        } else if let diff = node.fileDiff {
            DiffFileRow(
                diff: diff,
                isSelected: selectedDiff?.id == diff.id,
                onSelect: { selectedDiff = diff }
            )
        }
    }
}

// MARK: - Directory Row

private struct DirectoryRow: View {
    let node: DiffFileTree.Node
    let isExpanded: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 6) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 12)

                Image(systemName: isExpanded ? "folder.fill" : "folder")
                    .foregroundStyle(.secondary)

                Text(node.name)
                    .lineLimit(1)

                Spacer()

                // Aggregate stats
                HStack(spacing: 2) {
                    Text("\(node.fileCount)")
                        .foregroundStyle(.secondary)

                    if node.totalAdditions > 0 {
                        Text("+\(node.totalAdditions)")
                            .foregroundStyle(.green)
                    }
                    if node.totalDeletions > 0 {
                        Text("-\(node.totalDeletions)")
                            .foregroundStyle(.red)
                    }
                }
                .font(.caption2)
                .fontDesign(.monospaced)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Diff File Row

private struct DiffFileRow: View {
    let diff: FileDiff
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 6) {
                // Spacer for alignment with directories
                Color.clear.frame(width: 12)

                ChangeTypeIcon(changeType: diff.changeType)

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Text(diff.fileName)
                            .lineLimit(1)

                        if diff.isPureRename {
                            Text("= rename")
                                .font(.caption2)
                                .foregroundStyle(.green)
                        } else if let similarity = diff.similarityPercentage,
                                  diff.changeType == .renamed {
                            Text("\(similarity)%")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }

                        if diff.isGeneratedFile {
                            Image(systemName: "gearshape")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }

                        if diff.isBinary {
                            Text("binary")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Old path for renames
                    if let oldName = diff.originalFileName, oldName != diff.fileName {
                        Text("← \(oldName)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer()

                // Stats
                if diff.additions > 0 || diff.deletions > 0 {
                    HStack(spacing: 4) {
                        if diff.additions > 0 {
                            Text("+\(diff.additions)")
                                .foregroundStyle(.green)
                        }
                        if diff.deletions > 0 {
                            Text("-\(diff.deletions)")
                                .foregroundStyle(.red)
                        }
                    }
                    .font(.caption2)
                    .fontDesign(.monospaced)
                }
            }
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

// MARK: - Diff File Tree Model

/// Represents a hierarchical tree of changed files.
struct DiffFileTree {
    let root: Node

    /// A node in the file tree (either a directory or file).
    struct Node: Identifiable {
        let id: String
        let name: String
        let path: String
        var children: [Node]
        var fileDiff: FileDiff?

        var isDirectory: Bool { fileDiff == nil }

        /// Number of files in this node (recursive).
        var fileCount: Int {
            if fileDiff != nil { return 1 }
            return children.reduce(0) { $0 + $1.fileCount }
        }

        /// Total additions in this node (recursive).
        var totalAdditions: Int {
            if let diff = fileDiff { return diff.additions }
            return children.reduce(0) { $0 + $1.totalAdditions }
        }

        /// Total deletions in this node (recursive).
        var totalDeletions: Int {
            if let diff = fileDiff { return diff.deletions }
            return children.reduce(0) { $0 + $1.totalDeletions }
        }
    }

    /// Total number of files in the tree.
    var totalFiles: Int { root.fileCount }

    /// Total additions across all files.
    var totalAdditions: Int { root.totalAdditions }

    /// Total deletions across all files.
    var totalDeletions: Int { root.totalDeletions }

    /// Builds a tree from a flat list of diffs.
    static func build(from diffs: [FileDiff]) -> DiffFileTree {
        var rootChildren: [String: Node] = [:]

        for diff in diffs {
            let components = diff.path.split(separator: "/").map(String.init)

            if components.count == 1 {
                // File at root level
                let node = Node(
                    id: diff.path,
                    name: diff.fileName,
                    path: diff.path,
                    children: [],
                    fileDiff: diff
                )
                rootChildren[diff.path] = node
            } else {
                // File in subdirectory
                insertIntoTree(&rootChildren, diff: diff, components: components, index: 0)
            }
        }

        // Sort children
        let sortedChildren = rootChildren.values.sorted { a, b in
            // Directories first, then files
            if a.isDirectory != b.isDirectory {
                return a.isDirectory
            }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }

        let root = Node(
            id: "__root__",
            name: "",
            path: "",
            children: sortedChildren,
            fileDiff: nil
        )

        return DiffFileTree(root: root)
    }

    /// Recursively inserts a diff into the tree.
    private static func insertIntoTree(
        _ nodes: inout [String: Node],
        diff: FileDiff,
        components: [String],
        index: Int
    ) {
        guard index < components.count else { return }

        let component = components[index]
        let isLastComponent = index == components.count - 1
        let path = components[0...index].joined(separator: "/")

        if isLastComponent {
            // This is the file
            let node = Node(
                id: diff.path,
                name: component,
                path: path,
                children: [],
                fileDiff: diff
            )
            nodes[component] = node
        } else {
            // This is a directory
            if nodes[component] == nil {
                nodes[component] = Node(
                    id: path,
                    name: component,
                    path: path,
                    children: [],
                    fileDiff: nil
                )
            }

            if var existingNode = nodes[component], existingNode.isDirectory {
                var childNodes: [String: Node] = Dictionary(
                    uniqueKeysWithValues: existingNode.children.map { ($0.name, $0) }
                )
                insertIntoTree(&childNodes, diff: diff, components: components, index: index + 1)

                // Sort children
                let sortedChildren = childNodes.values.sorted { a, b in
                    if a.isDirectory != b.isDirectory {
                        return a.isDirectory
                    }
                    return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
                }

                existingNode.children = sortedChildren
                nodes[component] = existingNode
            }
        }
    }

    /// Returns paths of directories with few children (for auto-expansion).
    func directoriesWithFewChildren(threshold: Int) -> Set<String> {
        var result: Set<String> = []
        collectSmallDirectories(node: root, threshold: threshold, result: &result)
        return result
    }

    private func collectSmallDirectories(node: Node, threshold: Int, result: inout Set<String>) {
        guard node.isDirectory else { return }

        if node.fileCount <= threshold && node.path != "" {
            result.insert(node.path)
        }

        for child in node.children {
            collectSmallDirectories(node: child, threshold: threshold, result: &result)
        }
    }
}

// MARK: - Preview

#Preview {
    let diffs = [
        FileDiff(path: "src/models/User.swift", changeType: .modified, hunks: []),
        FileDiff(path: "src/models/Post.swift", changeType: .added, hunks: []),
        FileDiff(path: "src/views/HomeView.swift", changeType: .modified, hunks: []),
        FileDiff(path: "README.md", changeType: .modified, hunks: []),
        FileDiff(
            path: "src/utils/helpers.swift",
            oldPath: "src/helpers.swift",
            changeType: .renamed,
            hunks: [],
            similarityPercentage: 95
        ),
        FileDiff(path: "package-lock.json", changeType: .modified, hunks: [])
    ]

    DiffFileTreeView(
        diffs: diffs,
        selectedDiff: .constant(nil)
    )
    .frame(width: 300, height: 400)
}
