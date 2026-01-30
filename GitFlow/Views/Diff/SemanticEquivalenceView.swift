import SwiftUI

/// View displaying semantic equivalence analysis
struct SemanticEquivalenceView: View {
    let equivalences: [SemanticEquivalence]

    var body: some View {
        if equivalences.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    Image(systemName: "equal.circle")
                        .foregroundStyle(.blue)
                    Text("Semantic Analysis")
                        .font(.caption.bold())
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.05))

                Divider()

                // Equivalences
                ForEach(Array(equivalences.enumerated()), id: \.offset) { _, equiv in
                    SemanticEquivalenceRow(equivalence: equiv)
                }
            }
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }
}

/// Single row for a semantic equivalence
struct SemanticEquivalenceRow: View {
    let equivalence: SemanticEquivalence

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main row
            Button {
                if equivalence.oldCode != nil || equivalence.newCode != nil {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    // Icon
                    Image(systemName: equivalence.equivalenceType.icon)
                        .foregroundStyle(iconColor)
                        .frame(width: 16)

                    // Label
                    VStack(alignment: .leading, spacing: 2) {
                        Text(equivalence.label)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(equivalence.equivalenceType.preservesBehavior ? .green : .orange)

                        Text(equivalence.description)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    // Confidence badge
                    ConfidenceBadge(confidence: equivalence.confidence)

                    // Expand indicator
                    if equivalence.oldCode != nil || equivalence.newCode != nil {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Expanded code view
            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    if let oldCode = equivalence.oldCode {
                        HStack(alignment: .top, spacing: 4) {
                            Text("-")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.red)
                            Text(oldCode)
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    }

                    if let newCode = equivalence.newCode {
                        HStack(alignment: .top, spacing: 4) {
                            Text("+")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.green)
                            Text(newCode)
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }

            Divider()
        }
    }

    private var iconColor: Color {
        switch equivalence.equivalenceType.color {
        case "blue": return .blue
        case "purple": return .purple
        case "orange": return .orange
        case "gray": return .secondary
        case "teal": return .teal
        case "green": return .green
        default: return .secondary
        }
    }
}

/// Badge showing confidence level
struct ConfidenceBadge: View {
    let confidence: SemanticEquivalence.Confidence

    var body: some View {
        Text(confidence.rawValue)
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(badgeColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(badgeColor.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private var badgeColor: Color {
        switch confidence.color {
        case "green": return .green
        case "yellow": return .yellow
        case "orange": return .orange
        default: return .secondary
        }
    }
}

/// Compact inline badge for showing semantic equivalence
struct SemanticEquivalenceBadge: View {
    let equivalence: SemanticEquivalence

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: equivalence.equivalenceType.icon)
                .font(.system(size: 10))

            Text(equivalence.equivalenceType.rawValue)
                .font(.system(size: 10, weight: .medium))

            if equivalence.equivalenceType.preservesBehavior {
                Image(systemName: "checkmark")
                    .font(.system(size: 8, weight: .bold))
            }
        }
        .foregroundStyle(equivalence.equivalenceType.preservesBehavior ? .green : .orange)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            (equivalence.equivalenceType.preservesBehavior ? Color.green : Color.orange)
                .opacity(0.1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        SemanticEquivalenceView(equivalences: [
            SemanticEquivalence(
                equivalenceType: .formattingOnly,
                confidence: .high,
                description: "Only whitespace changes detected",
                oldCode: nil,
                newCode: nil
            ),
            SemanticEquivalence(
                equivalenceType: .variableRename,
                confidence: .medium,
                description: "'userName' renamed to 'username'",
                oldCode: "let userName = user.name",
                newCode: "let username = user.name"
            ),
            SemanticEquivalence(
                equivalenceType: .methodExtraction,
                confidence: .medium,
                description: "Code extracted to 'validateInput()'",
                oldCode: nil,
                newCode: nil
            )
        ])

        SemanticEquivalenceBadge(equivalence: SemanticEquivalence(
            equivalenceType: .formattingOnly,
            confidence: .high,
            description: "",
            oldCode: nil,
            newCode: nil
        ))
    }
    .padding()
    .frame(width: 400)
}
