import SwiftUI

/// Sidebar sections for navigation.
enum SidebarSection: String, CaseIterable, Identifiable {
    case changes = "Changes"
    case history = "History"
    case branches = "Branches"
    case stashes = "Stashes"
    case tags = "Tags"
    case sync = "Sync"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .changes: return "pencil.circle"
        case .history: return "clock"
        case .branches: return "arrow.triangle.branch"
        case .stashes: return "tray.and.arrow.down"
        case .tags: return "tag"
        case .sync: return "arrow.triangle.2.circlepath"
        }
    }
}

/// Left sidebar navigation.
struct Sidebar: View {
    @Binding var selectedSection: SidebarSection
    @ObservedObject var viewModel: RepositoryViewModel

    var body: some View {
        List(selection: $selectedSection) {
            Section("Workspace") {
                sidebarItem(for: .changes, badge: changesCountBadge)
                sidebarItem(for: .stashes, badge: stashCountBadge)
            }

            Section("Repository") {
                sidebarItem(for: .history, badge: nil)
                sidebarItem(for: .branches, badge: branchCountBadge)
                sidebarItem(for: .tags, badge: tagCountBadge)
            }

            Section("Remote") {
                sidebarItem(for: .sync, badge: nil)
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 250)
    }

    @ViewBuilder
    private func sidebarItem(for section: SidebarSection, badge: AnyView?) -> some View {
        Label {
            HStack {
                Text(section.rawValue)
                Spacer()
                if let badge {
                    badge
                }
            }
        } icon: {
            Image(systemName: section.icon)
        }
        .tag(section)
    }

    private var changesCountBadge: AnyView? {
        let count = viewModel.statusViewModel.status.totalChangedFiles
        guard count > 0 else { return nil }
        return AnyView(
            Text("\(count)")
                .font(DSTypography.smallLabel())
                .fontWeight(.medium)
                .padding(.horizontal, DSSpacing.sm)
                .padding(.vertical, DSSpacing.xs)
                .background(DSColors.badgeBackground)
                .clipShape(Capsule())
        )
    }

    private var branchCountBadge: AnyView? {
        let count = viewModel.branchViewModel.localBranchCount
        guard count > 0 else { return nil }
        return AnyView(
            Text("\(count)")
                .font(DSTypography.smallLabel())
                .foregroundStyle(.secondary)
        )
    }

    private var stashCountBadge: AnyView? {
        let count = viewModel.stashViewModel.stashCount
        guard count > 0 else { return nil }
        return AnyView(
            Text("\(count)")
                .font(DSTypography.smallLabel())
                .fontWeight(.medium)
                .padding(.horizontal, DSSpacing.sm)
                .padding(.vertical, DSSpacing.xs)
                .background(DSColors.warningBadgeBackground)
                .clipShape(Capsule())
        )
    }

    private var tagCountBadge: AnyView? {
        let count = viewModel.tagViewModel.tagCount
        guard count > 0 else { return nil }
        return AnyView(
            Text("\(count)")
                .font(DSTypography.smallLabel())
                .foregroundStyle(.secondary)
        )
    }
}

#Preview {
    Sidebar(
        selectedSection: .constant(.changes),
        viewModel: RepositoryViewModel(
            repository: Repository(rootURL: URL(fileURLWithPath: "/tmp")),
            gitService: GitService()
        )
    )
    .frame(width: 200)
}
