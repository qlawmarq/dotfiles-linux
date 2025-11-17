# CLAUDE.md

This file provides guidance to Claude Code when working with code in this repository.

## Repository Overview

This is a modular Linux/WSL dotfiles management system that automates development environment setup using a two-layer package management approach.

## Architecture

### Two-Layer Package Management

```
Layer 1: System Package Manager (apt/dnf/pacman/zypper)
├─ System libraries: build-essential, git, curl
├─ Development tools: tmux, zsh
├─ CLI utilities: ripgrep, fd, bat, jq, fzf
└─ Distribution integration

Layer 2: mise (Runtime Version Management)
├─ Installed via: curl https://mise.run | sh
├─ Programming languages: node, python, go
├─ Project-specific version management
└─ Backend installations: npm:, pipx:, cargo:
```

### Why Not Homebrew on Linux?

**Decision: Complete exclusion**

Reasons:

1. **Disk space waste**: ~2GB+ in `/home/linuxbrew/.linuxbrew`
2. **System duplication**: gcc, glibc installed separately
3. **Non-standard**: Diverges from Linux distribution philosophy
4. **Unnecessary**: mise doesn't require Homebrew

## Modules

The repository uses a modular architecture with 7 independent modules:

- **packages**: System package manager abstraction (replaces macOS `brew`)
- **mise**: Runtime version management (curl installation)
- **dotfiles**: Shell configurations with automatic mise activation
- **git**: Git configuration with clipboard utilities
- **codex**: Codex CLI
- **vscode**: VS Code with Linux paths (`~/.config/Code/User/`)
- **claude-code**: Claude Code CLI (Desktop features excluded)

Module dependencies are defined in `modules/dependencies.txt`.

## Key Commands

```bash
# Initial setup
bash apply.sh

# Backup configurations
bash backup.sh
```

**Important**: Always use `bash` to execute scripts, not `sh`. The `sh` command may use a POSIX-compatible shell (like `dash` on Ubuntu/WSL) which doesn't support Bash-specific syntax used in these scripts.

## Development Guidelines

### When modifying modules:

1. Each module has `apply.sh` (apply settings) and `backup.sh` (backup settings)
2. Dependencies must be declared in `modules/dependencies.txt`
3. Use shared utilities in `lib/`:
   - `lib/utils.sh`: OS detection, common utilities
   - `lib/package.sh`: Package manager abstraction
   - `lib/menu.sh`: Interactive selection menus
   - `lib/dependencies.sh`: Dependency resolution logic

### Shell script conventions:

- Use `#!/bin/bash` (not `#!/bin/sh` as macOS uses)
- Source common utilities using POSIX-compatible dot notation: `. "$DOTFILES_DIR/lib/utils.sh"`
  - Use `.` instead of `source` for maximum compatibility (POSIX-compliant)
- Use `check_linux` instead of `check_macos`
- Handle errors gracefully with user prompts
- Use colored output functions: `print_success()`, `print_error()`, `print_info()`

### Configuration files:

- `.packages`: System package list (replaces `.Brewfile`)
- `vscode/settings.json`: VS Code preferences
- Shell configs are copied from `dotfiles/` to home directory

## Linux-Specific Considerations

### Package Manager Abstraction

The `lib/package.sh` provides abstraction across:

- Ubuntu/Debian: apt
- Fedora/RHEL: dnf
- Arch Linux: pacman
- openSUSE: zypper

Package names are normalized (e.g., `build-essential` → `gcc gcc-c++ make` on Fedora).

### Clipboard Utilities

Git module uses `copy_to_clipboard()` function that supports:

- X11: xclip
- Wayland: wl-clipboard
- WSL: clip.exe

### XDG Base Directory

Partial compliance:

- ✅ VS Code: `~/.config/Code/User/settings.json`
- ✅ Git: `~/.config/git/ignore`
- ⚠️ Claude Code: `~/.claude/` (official spec, non-XDG)
- ⚠️ Dotfiles: `~/.zshrc`, `~/.tmux.conf` (common convention)

## Differences from macOS Version

| Feature         | macOS (dotfiles-macos) | Linux (dotfiles-linux) |
| --------------- | ---------------------- | ---------------------- |
| Package Manager | Homebrew               | apt/dnf/pacman         |
| Runtime Manager | mise (via Homebrew)    | mise (via curl)        |
| Claude          | Desktop + CLI          | CLI only               |
| Finder          | ✅                     | ❌ (N/A)               |
| Keyboard        | ✅ Karabiner           | ❌ (N/A)               |
| VS Code Path    | `~/Library/...`        | `~/.config/Code/User/` |
| Clipboard       | pbcopy                 | xclip/wl-copy/clip.exe |

## Testing Changes

When modifying setup scripts:

1. Test module application: `bash modules/<module_name>/apply.sh`
2. Test backup: `bash modules/<module_name>/backup.sh`
3. Test full flow: `bash apply.sh`
4. Verify on multiple distributions (Ubuntu, Fedora, Arch)

**Note**: Always use `bash` command, never `sh`, to ensure Bash-specific features work correctly.

## Related Repository

For macOS version, see [dotfiles-macos](https://github.com/qlawmarq/dotfiles-macos).
