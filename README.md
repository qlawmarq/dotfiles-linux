# Linux/WSL Dotfiles

Linux/WSL development environment setup scripts.

**For macOS version, see [dotfiles-macos](https://github.com/qlawmarq/dotfiles-macos)**

## 🎯 Supported Environments

- ✅ Ubuntu 20.04, 22.04, 24.04 (WSL2, Server, Desktop)
- ✅ Debian 10+
- ⚠️ Fedora, Arch Linux (experimental)

## 🚀 Quick Start

```bash
git clone https://github.com/qlawmarq/dotfiles-linux.git
cd dotfiles-linux
bash apply.sh
```

> ⚠️ **Important**: Always use `bash` to execute scripts, not `sh`. Using `sh` may invoke a POSIX shell (like `dash`) that doesn't support Bash-specific syntax.

## 📦 Package Management Strategy

**Two-layer architecture (No Homebrew):**

```
Layer 1: System Package Manager (apt/dnf/pacman/zypper)
└─ System libraries, CLI tools, development tools

Layer 2: mise (Runtime Version Management)
└─ node, python, go (installed via curl)
```

### Why No Homebrew on Linux?

- Disk space waste (~2GB+ in `/home/linuxbrew/`)
- System duplication (gcc, glibc)
- Non-standard approach
- mise doesn't require Homebrew

## 🔧 Modules

| Module          | Description                                   |
| --------------- | --------------------------------------------- |
| **packages**    | System package manager abstraction            |
| **mise**        | Runtime version management (node, python, go) |
| **dotfiles**    | Shell configurations (.zshrc, .tmux.conf)     |
| **git**         | Git configuration + SSH key setup             |
| **codex**       | Codex CLI                                     |
| **vscode**      | VS Code settings and extensions               |
| **claude-code** | Claude Code CLI configuration                 |

## 🔄 Backup

Backup your current configurations:

```bash
bash backup.sh
```
