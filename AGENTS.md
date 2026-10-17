# AGENTS.md

This file provides guidance to coding agents when working with code in this repository.

## Repository Overview

This is a modular Linux/WSL dotfiles management system that automates development environment setup. Each directory under `modules/` is an independent module, installed in dependency order resolved from `modules/dependencies.txt` (e.g., `claude-code: mise` means claude-code depends on mise). Every change must keep working under WSL.

Packages come from two layers: the distribution package manager (apt/dnf/pacman/zypper, abstracted by `lib/package.sh`) for system tools, and mise (installed with `curl https://mise.run | sh`) for language runtimes.

Homebrew is deliberately excluded on Linux: it duplicates gcc/glibc under `/home/linuxbrew/.linuxbrew` (2GB+), diverges from the distribution's packaging, and mise does not need it.

## Development Guidelines

### When modifying modules:

1. Each module has `apply.sh` (apply settings) and optionally `backup.sh` (backup settings)
2. Every module must have an entry in `modules/dependencies.txt`, even with no dependencies (`mynewmodule:`)
3. Use the shared utilities in `lib/` for consistency

### Shell scripts conventions:

- Use `#!/bin/bash` and run scripts with `bash`, never `sh`: on Ubuntu/WSL `sh` is `dash`, which lacks the arrays, `[[ ]]` and `read -p` used in this project
- Source common utilities with POSIX dot notation: `. "$DOTFILES_DIR/lib/utils.sh"`
- Use `check_linux` (not `check_macos`); `is_wsl` and `copy_to_clipboard` in `lib/utils.sh` cover WSL differences
- Handle errors gracefully with user prompts to continue/abort
- Use colored output functions: `print_success()`, `print_error()`, `print_info()`, `print_warning()`

## Claude Code Integration

The `claude-code` module's design notes (symlinked skills, settings.json merge semantics, notifications, MCP) live in `modules/claude-code/AGENTS.md`.

Never edit `~/.claude.json` directly to configure MCP — it is live client state the CLI writes continuously; use `claude mcp add-json`.

## Related Repository

The macOS counterpart is [dotfiles-macos](https://github.com/qlawmarq/dotfiles-macos); both share [dotfiles-common](https://github.com/qlawmarq/dotfiles-common) as `modules/common`.
