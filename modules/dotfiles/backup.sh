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

print_info "Backing up shell configuration..."

# Backup .bashrc
if [ -f "$HOME/.bashrc" ]; then
    cp "$HOME/.bashrc" "$SCRIPT_DIR/.bashrc"
    print_success ".bashrc backed up"
fi

# Backup .profile
if [ -f "$HOME/.profile" ]; then
    cp "$HOME/.profile" "$SCRIPT_DIR/.profile"
    print_success ".profile backed up"
fi

print_success "Shell configuration backup completed"
print_info ""
print_info "Note: tmux configuration is now managed by the 'tmux' module"
