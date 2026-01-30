# Changelog

All notable changes to GitFlow will be documented in this file.

## [Unreleased]

### Added
- **Stack-based navigation for diffs**: Replaced split view layouts with stack-based navigation
  - Changes view: Selecting a file navigates to a maximized diff view with back navigation
  - History view: Selecting a commit shows maximized commit details and diff
  - Back button and Escape key return to the list view
- **StackNavigationHeader component**: Reusable header with back button, title, and subtitle
- **CommitDiffContentView**: Combined view for commit detail, file tree, and diff in history section
- **Collapsible file list**: Files section in commit history can be collapsed/expanded by clicking the header
- **DiffFileTreeView**: Tree view for navigating files in multi-file commits
- **CommitSummaryView**: Displays commit analysis summary (type, risk, patterns)
- **Word-level diff highlighting**: WordDiffLineView for inline change visualization
- **Structural diff analysis**: StructuralDiffView, SemanticEquivalenceView, ChangeImpactView for Swift code
- **Noise suppression options**: Filter generated files, lockfiles, collapse renames
- **SwiftStructureParser**: Parse Swift code structure for semantic diff analysis

### Changed
- **DiffToolbar**: Simplified layout to prevent UI overlap
  - View mode picker changed from segmented to dropdown menu
  - Blame toggle moved into options menu
  - Controls wrapped in fixed-size container to prevent compression
- **DiffFileHeader**: Added max width constraint to prevent pushing toolbar controls off screen
- **DiffView**: Removed fullscreen toggle binding (now handled by stack navigation)

### Fixed
- Toolbar controls no longer overlap when window is narrow
- File tree always visible in commit history (not just for 2+ files)
