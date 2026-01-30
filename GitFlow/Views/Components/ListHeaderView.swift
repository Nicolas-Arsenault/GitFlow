import SwiftUI

/// A reusable header view for list sections.
///
/// Provides a consistent header layout with:
/// - Title
/// - Optional badge count
/// - Optional add button
/// - Loading indicator
///
/// Usage:
/// ```swift
/// ListHeaderView(
///     title: "Branches",
///     count: viewModel.branches.count,
///     isLoading: viewModel.isLoading,
///     addAction: { showCreateSheet = true }
/// )
/// ```
struct ListHeaderView: View {
    let title: String
    var count: Int? = nil
    var isLoading: Bool = false
    var addAction: (() -> Void)? = nil
    var refreshAction: (() -> Void)? = nil

    var body: some View {
        HStack {
            Text(title)
                .font(.headline)

            if let count = count {
                Text("(\(count))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let refreshAction = refreshAction {
                Button(action: refreshAction) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .disabled(isLoading)
            }

            if let addAction = addAction {
                Button(action: addAction) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
            }

            if isLoading {
                ProgressView()
                    .scaleEffect(0.6)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

/// A view that displays loading, empty, or content states.
///
/// Usage:
/// ```swift
/// StateView(
///     isEmpty: items.isEmpty,
///     isLoading: viewModel.isLoading,
///     emptyTitle: "No Items",
///     emptyIcon: "tray",
///     emptyDescription: "Add items to get started"
/// ) {
///     List(items) { item in
///         ItemRow(item: item)
///     }
/// }
/// ```
struct StateView<Content: View>: View {
    let isEmpty: Bool
    let isLoading: Bool
    let emptyTitle: String
    let emptyIcon: String
    var emptyDescription: String? = nil
    @ViewBuilder let content: () -> Content

    var body: some View {
        if isLoading && isEmpty {
            loadingView
        } else if isEmpty {
            EmptyStateView(emptyTitle, systemImage: emptyIcon, description: emptyDescription ?? "")
        } else {
            content()
        }
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading...")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview("ListHeaderView") {
    VStack(spacing: 0) {
        ListHeaderView(
            title: "Branches",
            count: 5,
            isLoading: false,
            addAction: { print("Add") }
        )
        Divider()
        ListHeaderView(
            title: "Tags",
            count: 12,
            isLoading: true,
            addAction: { print("Add") },
            refreshAction: { print("Refresh") }
        )
        Divider()
        ListHeaderView(
            title: "Stashes",
            isLoading: false
        )
    }
    .frame(width: 300)
}

#Preview("StateView - Loading") {
    StateView(
        isEmpty: true,
        isLoading: true,
        emptyTitle: "No Items",
        emptyIcon: "tray"
    ) {
        Text("Content")
    }
    .frame(width: 300, height: 200)
}

#Preview("StateView - Empty") {
    StateView(
        isEmpty: true,
        isLoading: false,
        emptyTitle: "No Items",
        emptyIcon: "tray",
        emptyDescription: "Add items to get started"
    ) {
        Text("Content")
    }
    .frame(width: 300, height: 200)
}
