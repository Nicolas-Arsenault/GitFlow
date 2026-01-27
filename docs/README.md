# GitFlow - macOS Git GUI

A free, professional-grade Git GUI for macOS built with Swift and SwiftUI, featuring excellent diff visualization.

## Features

### Core Features (P0 - Must Have)
- **Open Local Repository**: Browse and open any Git repository on your system
- **Working Tree Status**: View staged, unstaged, and untracked files with clear visual indicators
- **Stage/Unstage Files**: Easily move files between working tree and staging area
- **Unified Diff View**: View changes with syntax highlighting and line numbers
- **Create Commits**: Compose commit messages with subject line length guidance

### Extended Features (P1 - Should Have)
- **Commit History**: Browse commit history with author, date, and message
- **Branch Management**: View local and remote branches
- **Branch Switching**: Checkout existing branches
- **Split Diff View**: Side-by-side comparison of changes
- **Recent Repositories**: Quick access to previously opened repositories

### Additional Features (P2)
- **Stash Management**: Create, apply, pop, and drop stashes
- **Remote Operations**: Fetch, pull, and push to remotes with options for rebase and force push
- **Tag Management**: Create lightweight and annotated tags, push tags to remotes
- **Create/Delete Branches**: Full branch lifecycle management
- **Clone Repository**: Clone repositories from URLs (HTTPS, SSH, or local paths)
- **Settings/Preferences**: Customizable diff display, font sizes, and Git executable path
- **Hunk-Level Staging**: Stage or unstage individual hunks instead of entire files

### Planned Features
- [ ] Word-level diff highlighting
- [ ] Commit graph visualization

## Requirements

- macOS 13.0 (Ventura) or later
- Git installed on the system (default: `/usr/bin/git`)

## Installation

### Download DMG (Recommended)

1. Go to the [Releases page](https://github.com/Nicolas-Arsenault/GitFlow/releases)
2. Download the latest `GitFlow-x.x.x.dmg`
3. Open the DMG and drag GitFlow to Applications

**First Launch (Important):** macOS will show a warning because the app isn't notarized. To open it:

- **Option 1:** Right-click (or Control-click) GitFlow.app and select "Open", then click "Open" in the dialog
- **Option 2:** Run this command in Terminal:
  ```bash
  xattr -cr /Applications/GitFlow.app
  ```
  Then open the app normally

### Homebrew

```bash
brew tap nicolas-arsenault/tap
brew install --cask gitflow
```

To update:
```bash
brew upgrade --cask gitflow
```

### Building from Source

1. Clone the repository:
   ```bash
   git clone https://github.com/Nicolas-Arsenault/GitFlow.git
   cd GitFlow
   ```

2. **Option A**: Open in Xcode:
   ```bash
   open GitFlow.xcodeproj
   ```
   Then build and run (⌘R)

3. **Option B**: Build DMG from command line:
   ```bash
   ./scripts/build-dmg.sh
   ```
   This creates a universal binary (arm64 + x86_64) DMG file.

## Usage

### Opening a Repository

1. Launch GitFlow
2. Click "Open Repository" or use ⌘O
3. Select a folder containing a Git repository
4. The repository will load with its current status

### Cloning a Repository

1. Launch GitFlow
2. Click "Clone Repository" on the welcome screen
3. Enter the repository URL (HTTPS, SSH, or local path)
4. Choose a destination folder
5. Optionally specify a branch to clone
6. Click "Clone" to start the clone operation

### Staging Changes

- **Stage a file**: Click on a file in the "Changes" section, right-click and select "Stage"
- **Stage all**: Click "Stage All" in the section header
- **Unstage a file**: Right-click a staged file and select "Unstage"
- **Unstage all**: Click "Unstage All" in the section header
- **Hunk-level staging**: Hover over a hunk header in the diff view to see "Stage Hunk" or "Unstage Hunk" buttons

### Creating Commits

1. Stage the files you want to commit
2. Enter a commit message in the text area at the bottom
3. Click "Commit" or press ⌘↩

**Commit Message Guidelines**:
- Subject line ideally under 50 characters
- Hard limit at 72 characters
- Leave a blank line before the body (if any)

### Viewing Diffs

- **Select a file** to view its changes in the diff pane
- **Toggle view mode**: Use the Unified/Split toggle in the toolbar
- **Line numbers**: Enable/disable via the settings menu
- **Search in diff**: Press ⌘F or click the magnifying glass to search within the diff
  - Yellow highlighting shows all matches
  - Orange highlighting shows the current match
  - Use Enter or the arrow buttons to navigate between matches
  - Press Escape to close the search bar

### Browsing History

1. Click "History" in the sidebar
2. Select a commit to view its details and changes
3. The diff pane shows all files changed in that commit

### Managing Branches

1. Click "Branches" in the sidebar
2. **Checkout**: Double-click a branch or right-click and select "Checkout"
3. **Create**: Click the + button to create a new branch
4. **Delete**: Right-click a branch and select "Delete"

### Managing Stashes

1. Click "Stashes" in the sidebar
2. **Create Stash**: Click the + button, optionally add a message and include untracked files
3. **Apply Stash**: Right-click a stash and select "Apply" (keeps the stash)
4. **Pop Stash**: Right-click and select "Pop" (applies and removes the stash)
5. **Drop Stash**: Right-click and select "Drop" to delete a stash
6. **Clear All**: Click "Clear All" in the footer to remove all stashes

### Managing Tags

1. Click "Tags" in the sidebar
2. **Create Tag**: Click the + button, choose between lightweight or annotated tag
3. **Push Tag**: Right-click a tag and select "Push to Remote"
4. **Delete Tag**: Right-click a tag and select "Delete"

### Syncing with Remotes

1. Click "Sync" in the sidebar
2. **Fetch**: Click "Fetch" to download changes from all remotes
3. **Pull**: Click "Pull" to fetch and merge changes (right-click for rebase option)
4. **Push**: Click "Push" to upload commits (right-click for force push or set upstream options)

### Settings

Access settings via **GitFlow > Settings** (⌘,):

- **General**: Configure behavior preferences like showing remote branches
- **Diff**: Set default view mode (unified/split), line numbers, line wrapping, and font size
- **Git**: Specify a custom Git executable path

## Keyboard Shortcuts

| Action | Shortcut |
|--------|----------|
| Open Repository | ⌘O |
| Refresh | ⌘R |
| Commit | ⌘↩ |
| Search in Diff | ⌘F |

## User Experience Design

GitFlow follows a carefully crafted UX philosophy designed to reduce Git anxiety and create a calm, trustworthy interface.

### Design Principles

1. **Calm and Professional**: Muted color palette that supports meaning without alarming users
2. **Accessibility First**: Visual indicators never rely on color alone; icons and shapes provide redundant cues
3. **Descriptive Actions**: Button labels describe outcomes, not mechanisms ("Discard Changes" instead of "OK")
4. **Safety by Default**: All destructive actions require confirmation with clear consequences explained
5. **Progressive Disclosure**: Advanced options appear on hover or in context menus

### Design System

The app uses a centralized design system (`DesignSystem.swift`) with:

- **Color Palette**: Muted, accessible colors for Git semantics (green=safe, red=destructive, amber=warning, blue=info)
- **Typography Scale**: Consistent font hierarchy following macOS conventions
- **Spacing Scale**: 4pt grid-based spacing for visual consistency
- **Accessibility**: Colorblind-safe palette, icon+color indicators, screen reader support

### Error Handling

Errors are displayed with a helpful tone:
- Clear explanation of what went wrong
- Why it happened (when known)
- Actionable suggestions for recovery

### Empty States

When no content is available, the app explains:
- What's missing
- Why it might be missing
- A suggested next action (with optional action button)

## Architecture

GitFlow follows the MVVM (Model-View-ViewModel) architecture pattern:

- **Models**: Pure data structures representing Git entities
- **ViewModels**: Business logic and state management
- **Views**: SwiftUI views for the user interface
- **Services**: Git command execution and parsing

For detailed architecture information, see [architecture.md](./architecture.md).

## Technical Decisions

| Decision | Rationale |
|----------|-----------|
| System Git CLI | Full compatibility with user's Git config, hooks, and features |
| MVVM Architecture | Natural fit for SwiftUI, testable ViewModels |
| Async/await | UI stays responsive during Git operations |
| Value-type Models | Thread-safe, automatic memory management |

## Contributing

Contributions are welcome! Please read our contributing guidelines before submitting pull requests.

## License

MIT License - See LICENSE file for details
