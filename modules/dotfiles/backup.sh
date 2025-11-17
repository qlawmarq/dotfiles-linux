#!/bin/bash

# Load utils
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
if [ -f "$DOTFILES_DIR/lib/utils.sh" ]; then
    . "$DOTFILES_DIR/lib/utils.sh"
else
    echo "Error: utils.sh not found at $DOTFILES_DIR/lib/utils.sh"
    exit 1
fi

check_linux

print_info "Backing up dotfiles..."

# .profile
if [ -f ~/.profile ]; then
    cp ~/.profile "${SCRIPT_DIR}/.profile"
    echo "✓ .profile synced"
fi

# .bashrc
if [ -f ~/.bashrc ]; then
    cp ~/.bashrc "${SCRIPT_DIR}/.bashrc"
    echo "✓ .bashrc synced"
fi

# .tmux.conf
if [ -f ~/.tmux.conf ]; then
    cp ~/.tmux.conf "${SCRIPT_DIR}/.tmux.conf"
    echo "✓ .tmux.conf synced"
fi
