# .profile - login shell configuration
# This file is sourced by login shells (including SSH sessions)

# Load .bashrc for interactive shells
if [ -n "$BASH_VERSION" ]; then
    if [ -f "$HOME/.bashrc" ]; then
        . "$HOME/.bashrc"
    fi
fi
