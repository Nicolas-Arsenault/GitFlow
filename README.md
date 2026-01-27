# GitFlow

A free, professional-grade Git GUI for macOS with best-in-class diff visualization.

[![Release](https://img.shields.io/github/v/release/Nicolas-Arsenault/GitFlow)](https://github.com/Nicolas-Arsenault/GitFlow/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![macOS](https://img.shields.io/badge/macOS-13%2B-blue)](https://github.com/Nicolas-Arsenault/GitFlow)

## Official website
https://nicolas-arsenault.github.io/gitflow-website/index.html

## Install

### Quick Install (Recommended)

Run this command in Terminal:

```bash
curl -fsSL https://raw.githubusercontent.com/Nicolas-Arsenault/GitFlow/main/scripts/install.sh | bash
```

This downloads, installs, and configures GitFlow automatically.

### Homebrew

```bash
brew tap nicolas-arsenault/tap
brew install --cask gitflow-gui
```

### Manual Download

1. Download the latest DMG from [Releases](https://github.com/Nicolas-Arsenault/GitFlow/releases)
2. Open the DMG and drag GitFlow to Applications
3. Run this command to avoid security warnings:
   ```bash
   xattr -cr /Applications/GitFlow.app
   ```

## Features

- **Safety First** — Confirmation for destructive actions, warnings for unpushed commits
- **Native macOS** — Built with SwiftUI, optimized for Apple Silicon
- **Best-in-class Diffs** — Unified and split views, syntax highlighting, hunk-level staging
- **Full Git Workflow** — Branches, stashes, tags, remotes, and more
- **Offline First** — Works fully without internet

## Screenshots

### Welcome Screen
![Welcome Screen](docs/images/screenshot-welcome.png)

### Changes View with Diff
![Changes View](docs/images/screenshot-changes.png)

### History View
![History View](docs/images/screenshot-history.png)

## Documentation

See the [full documentation](docs/README.md) for detailed usage instructions.

## Building from Source

```bash
git clone https://github.com/Nicolas-Arsenault/GitFlow.git
cd GitFlow
./scripts/build-dmg.sh
```

Requires Xcode 15+ and macOS 13+.

## Contributing

Contributions are welcome! Please open an issue first to discuss what you'd like to change.

## License

[MIT](LICENSE)
