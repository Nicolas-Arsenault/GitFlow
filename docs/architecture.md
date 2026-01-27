# GitFlow Architecture

## Overview

GitFlow is a macOS Git GUI application built with Swift and SwiftUI, following the MVVM (Model-View-ViewModel) architecture pattern. The application uses the system's Git CLI for all Git operations, ensuring full compatibility with user configurations and hooks.

## Architecture Diagram

```
┌─────────────────────────────────────────┐
│            SwiftUI Views                │
│  (@StateObject/@Published bindings)     │
└─────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────┐
│            ViewModels                   │
│  (Business logic, async Git ops)        │
└─────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────┐
│            Services                     │
│  (Git CLI wrapper, parsers)             │
└─────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────┐
│            Models                       │
│  (Pure data structures)                 │
└─────────────────────────────────────────┘
```

## Layer Descriptions

### Models Layer

Pure value types representing Git entities. These are immutable, thread-safe, and contain no business logic.

**Key Models:**
- `Repository`: Represents a Git repository with its root URL
- `Branch`: Local or remote branch with tracking information
- `Commit`: Commit with full metadata (author, date, message, parents)
- `FileStatus`: File status in the working tree (staged/unstaged/untracked)
- `FileDiff`: Diff for a single file with hunks and lines
- `DiffHunk`: A contiguous block of changes
- `DiffLine`: A single line in a diff with type and line numbers
- `GitError`: Typed errors for Git operations

### Services Layer

Handles Git command execution and output parsing.

**Components:**

#### GitExecutor
- Async Process wrapper for executing Git commands
- Handles timeouts, environment setup, and output capture
- Thread-safe via Swift actor

#### GitService
- High-level facade for Git operations
- Composes commands and parsers
- Provides typed async methods for all Git operations

#### Commands
Protocol-based command pattern for Git operations:
- `StatusCommand`: Working tree status
- `DiffCommand`: File diffs (staged, unstaged, commit)
- `LogCommand`: Commit history
- `BranchCommand`: Branch listing and operations
- `CommitCommand`: Commit creation
- `StageCommand`: Staging/unstaging files
- `RemoteCommand`: Remote management (add, remove, rename, set-url)

#### Parsers
Parse Git CLI output into model objects:
- `StatusParser`: Parses `git status --porcelain` output
- `DiffParser`: Parses unified diff format
- `LogParser`: Parses custom log format with field separators
- `BranchParser`: Parses branch list with tracking info

### ViewModels Layer

ObservableObjects that manage state and coordinate between views and services.

**Key ViewModels:**

#### RepositoryViewModel
- Main coordinator for a repository
- Manages child ViewModels
- Handles cross-cutting concerns

#### StatusViewModel
- Working tree status management
- File selection and batch operations
- Stage/unstage operations

#### DiffViewModel
- Diff loading and display
- View mode switching (unified/split)
- Display settings

#### CommitViewModel
- Commit message composition
- Validation and guidelines
- Commit creation

#### HistoryViewModel
- Commit history loading
- Pagination support
- Filtering by branch/file

#### BranchViewModel
- Branch listing
- Checkout operations
- Create/delete branches

### Views Layer

SwiftUI views that render the UI and bind to ViewModels.

**Organization:**
- `Main/`: Primary window structure (MainWindow, Sidebar, ContentArea)
- `Repository/`: Repository-level views
- `Status/`: Working tree status views
- `Diff/`: Diff visualization (Unified, Split)
- `Commit/`: History and commit creation
- `Branch/`: Branch management
- `Shared/`: Reusable components (LoadingView, ErrorView, ConfirmationDialog, AvatarView)

**Shared Components:**
- `AvatarView`: Displays user avatars in commit history. Uses Gravatar service to fetch images based on email hash, with an initials-based fallback showing colored circles with user initials for users without Gravatar accounts.

## Data Flow

### Reading Repository State

```
1. User opens repository
2. AppState.openRepository() called
3. GitService.isGitRepository() validates path
4. RepositoryViewModel created with GitService
5. RepositoryViewModel.refresh() loads all data
6. Child ViewModels update their @Published state
7. SwiftUI views react to state changes
```

### Staging a File

```
1. User right-clicks file, selects "Stage"
2. StatusViewModel.stageFiles([path]) called
3. GitService.stage(files:in:) executes command
4. StatusViewModel.refresh() reloads status
5. Status published, views update
```

### Viewing a Diff

```
1. User selects file in list
2. StatusViewModel.selectedFile updated
3. Binding propagates to DiffViewModel.loadDiff()
4. GitService.getStagedDiff() or getUnstagedDiff() called
5. DiffParser.parse() converts output to FileDiff
6. DiffViewModel.currentDiff updated
7. DiffView renders hunks and lines
```

## Concurrency Model

- All Git operations are async using Swift concurrency
- GitExecutor is an actor for thread-safe command execution
- ViewModels are @MainActor for UI-safe state updates
- Long operations show loading indicators via @Published state

## Error Handling

Errors flow through the stack as typed GitError values:
1. GitExecutor throws on command failure
2. GitService methods propagate or wrap errors
3. ViewModels catch and expose via @Published error property
4. Views display errors via alerts or inline messages

## Persistence

- `RecentRepositoriesStore`: Stores recently opened repos in UserDefaults
- `SettingsStore`: Stores user preferences (diff mode, font size, etc.)

## Testing Strategy

### Unit Tests
- Parser tests with fixture files containing real Git output
- ViewModel tests with mock GitService
- Model tests for edge cases

### Integration Tests
- End-to-end tests with real Git repositories
- Command execution verification

### Manual Testing
- Edge cases: empty repo, merge conflicts, binary files
- Large repos with many files
- Various Git configurations

## Extension Points

The architecture supports extension via:
1. New GitCommand types for additional Git operations
2. New ViewModels for additional features
3. New parsers for different Git output formats
4. Settings for user customization

## Security Considerations

- No credentials are stored by the application
- Git operations use user's existing Git configuration
- Terminal prompts are disabled to prevent hangs
- File paths are validated before operations
