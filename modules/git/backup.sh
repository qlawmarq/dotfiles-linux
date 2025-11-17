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

# Directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# .gitconfig
if [ -f ~/.gitconfig ]; then
    # Create temporary file
    TMP_CONFIG=$(mktemp)
    
    # Copy current config
    cp ~/.gitconfig "$TMP_CONFIG"
    
    # Replace personal information with placeholders
    sed -i -e "s/^[[:space:]]*email[[:space:]]*=.*$/	email 	= \$GIT_EMAIL/" \
           -e "s/^[[:space:]]*name[[:space:]]*=.*$/	name 	= \$GIT_NAME/" \
           "$TMP_CONFIG"
    
    # Copy to dotfiles
    cp "$TMP_CONFIG" "${SCRIPT_DIR}/.gitconfig"
    rm -f "$TMP_CONFIG"
    echo "✓ .gitconfig synced (personal information replaced with placeholders)"
fi

# Global gitignore
if [ -f ~/.config/git/ignore ]; then
    mkdir -p "${SCRIPT_DIR}/.config/git"
    cp ~/.config/git/ignore "${SCRIPT_DIR}/.config/git/ignore"
    echo "✓ git ignore synced"
fi