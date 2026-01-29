import SwiftUI

/// View for reviewing and managing all branches.
struct BranchReviewView: View {
    @StateObject private var viewModel = BranchReviewViewModel()
    let repository: Repository

    var body: some View {
        VStack(spacing: 0) {
            // Header with stats
            statsHeader

            Divider()

            // Tab picker
            Picker("View", selection: $viewModel.selectedTab) {
                ForEach(BranchReviewViewModel.ReviewTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            Divider()

            // Content
            if viewModel.isLoading && viewModel.branches.isEmpty {
                loadingView
            } else {
                contentView
            }
        }
        .onAppear {
            viewModel.setRepository(repository)
        }
        .sheet(isPresented: $viewModel.showingArchiveSheet) {
            ArchiveBranchSheet(viewModel: viewModel)
        }
        .alert("Error", isPresented: .constant(viewModel.error != nil)) {
            Button("OK") {
                viewModel.error = nil
            }
        } message: {
            if let error = viewModel.error {
                Text(error)
            }
        }
    }

    // MARK: - Stats Header

    private var statsHeader: some View {
        HStack(spacing: 20) {
            StatBadge(title: "Total", count: viewModel.totalBranchCount, color: .blue)
            StatBadge(title: "Stale", count: viewModel.staleBranchCount, color: .orange)
            StatBadge(title: "Merged", count: viewModel.mergedBranchCount, color: .green)
            StatBadge(title: "Archived", count: viewModel.archivedBranchCount, color: .purple)

            Spacer()

            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(0.7)
            }

            Button {
                Task {
                    await viewModel.loadData()
                }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help("Refresh branch analysis")
        }
        .padding()
    }

    // MARK: - Content

    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView("Analyzing branches...")
            Spacer()
        }
    }

    @ViewBuilder
    private var contentView: some View {
        switch viewModel.selectedTab {
        case .all:
            allBranchesView
        case .stale:
            staleBranchesView
        case .merged:
            mergedBranchesView
        case .archived:
            archivedBranchesView
        }
    }

    // MARK: - All Branches View

    private var allBranchesView: some View {
        List(viewModel.filteredBranches) { branch in
            BranchReviewRow(branch: branch, stalenessInfo: viewModel.staleBranches.first { $0.branch.name == branch.name })
                .contextMenu {
                    if !branch.isHead {
                        Button("Archive...") {
                            viewModel.showArchiveSheet(for: branch)
                        }
                    }
                }
        }
        .listStyle(.inset)
    }

    // MARK: - Stale Branches View

    private var staleBranchesView: some View {
        VStack(spacing: 0) {
            // Filter
            HStack {
                Text("Filter:")
                    .foregroundColor(.secondary)

                Picker("Staleness", selection: $viewModel.stalenessFilter) {
                    Text("All").tag(nil as BranchStalenessInfo.StalenessLevel?)
                    ForEach(BranchStalenessInfo.StalenessLevel.allCases, id: \.self) { level in
                        Text(level.description).tag(level as BranchStalenessInfo.StalenessLevel?)
                    }
                }
                .frame(width: 200)

                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            List(viewModel.filteredStaleBranches) { info in
                StaleBranchRow(info: info)
                    .contextMenu {
                        Button("Archive...") {
                            viewModel.showArchiveSheet(for: info.branch)
                        }
                    }
            }
            .listStyle(.inset)
        }
    }

    // MARK: - Merged Branches View

    private var mergedBranchesView: some View {
        Group {
            if viewModel.mergedBranches.isEmpty {
                VStack {
                    Spacer()
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 48))
                        .foregroundColor(.green)
                    Text("No Merged Branches")
                        .font(.headline)
                    Text("All branches are either active or have been cleaned up.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                List(viewModel.mergedBranches) { branch in
                    BranchReviewRow(branch: branch, stalenessInfo: viewModel.staleBranches.first { $0.branch.name == branch.name })
                        .contextMenu {
                            Button("Archive...") {
                                viewModel.showArchiveSheet(for: branch)
                            }
                        }
                }
                .listStyle(.inset)
            }
        }
    }

    // MARK: - Archived Branches View

    private var archivedBranchesView: some View {
        Group {
            if viewModel.archivedBranches.isEmpty {
                VStack {
                    Spacer()
                    Image(systemName: "archivebox")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No Archived Branches")
                        .font(.headline)
                    Text("Archive branches to keep your repository clean while preserving their history.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .padding()
            } else {
                List(viewModel.archivedBranches) { archived in
                    ArchivedBranchRow(archived: archived)
                        .contextMenu {
                            Button("Unarchive") {
                                Task {
                                    await viewModel.unarchiveBranch(archived)
                                }
                            }
                            Divider()
                            Button("Delete Permanently", role: .destructive) {
                                viewModel.deleteArchivedBranch(archived)
                            }
                        }
                }
                .listStyle(.inset)
            }
        }
    }
}

// MARK: - Stat Badge

private struct StatBadge: View {
    let title: String
    let count: Int
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text("\(count)")
                .font(.title2)
                .fontWeight(.semibold)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Branch Review Row

private struct BranchReviewRow: View {
    let branch: Branch
    let stalenessInfo: BranchStalenessInfo?

    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(branch.name)
                        .fontWeight(.medium)

                    if branch.isHead {
                        Text("HEAD")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                    }

                    if branch.isMerged {
                        Text("Merged")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.2))
                            .foregroundColor(.green)
                            .cornerRadius(4)
                    }
                }

                if let info = stalenessInfo {
                    Text("Last commit: \(info.daysSinceLastCommit) days ago")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private var statusColor: Color {
        guard let info = stalenessInfo else { return .gray }
        switch info.stalenessLevel {
        case .active: return .green
        case .aging: return .yellow
        case .stale: return .orange
        case .veryStale: return .red
        }
    }
}

// MARK: - Stale Branch Row

private struct StaleBranchRow: View {
    let info: BranchStalenessInfo

    var body: some View {
        HStack(spacing: 12) {
            // Staleness indicator
            Circle()
                .fill(stalenessColor)
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(info.branch.name)
                        .fontWeight(.medium)

                    if info.isMerged {
                        Text("Merged")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.2))
                            .foregroundColor(.green)
                            .cornerRadius(4)
                    }
                }

                Text("\(info.daysSinceLastCommit) days since last commit")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(info.stalenessLevel.rawValue)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(stalenessColor.opacity(0.2))
                .foregroundColor(stalenessColor)
                .cornerRadius(4)
        }
        .padding(.vertical, 4)
    }

    private var stalenessColor: Color {
        switch info.stalenessLevel {
        case .active: return .green
        case .aging: return .yellow
        case .stale: return .orange
        case .veryStale: return .red
        }
    }
}

// MARK: - Archived Branch Row

private struct ArchivedBranchRow: View {
    let archived: ArchivedBranch

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "archivebox")
                .foregroundColor(.purple)

            VStack(alignment: .leading, spacing: 2) {
                Text(archived.name)
                    .fontWeight(.medium)

                HStack(spacing: 8) {
                    Text("Archived \(archived.timeSinceArchived)")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("·")
                        .foregroundColor(.secondary)

                    Text(archived.shortHash)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                }

                if let reason = archived.reason {
                    Text(reason)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Archive Branch Sheet

struct ArchiveBranchSheet: View {
    @ObservedObject var viewModel: BranchReviewViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Archive Branch")
                    .font(.headline)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // Content
            VStack(alignment: .leading, spacing: 16) {
                if let branch = viewModel.branchToArchive {
                    Text("Archive '\(branch.name)'?")
                        .font(.body)

                    Text("This will delete the branch but save its information so you can restore it later.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    TextField("Reason for archiving (optional)", text: $viewModel.archiveReason)
                        .textFieldStyle(.roundedBorder)
                }
            }
            .padding()

            Spacer()

            Divider()

            // Actions
            HStack {
                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Archive") {
                    Task {
                        await viewModel.archiveBranch()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(viewModel.isLoading)
            }
            .padding()
        }
        .frame(width: 400, height: 250)
    }
}

// MARK: - Preview

#Preview {
    BranchReviewView(repository: Repository(rootURL: URL(fileURLWithPath: "/tmp/test")))
        .frame(width: 600, height: 500)
}
