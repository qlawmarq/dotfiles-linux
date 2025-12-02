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

print_info "Shell Configuration Setup"
echo "========================="

# Backup and install .bashrc
if [ -f "$HOME/.bashrc" ]; then
    backup="$HOME/.bashrc.$(date +%Y%m%d%H%M%S).bak"
    mv "$HOME/.bashrc" "$backup"
    print_info "Existing .bashrc backed up to $backup"
fi
cp "$SCRIPT_DIR/.bashrc" "$HOME/.bashrc"
print_success ".bashrc applied"

# Backup and install .profile
if [ -f "$HOME/.profile" ]; then
    backup="$HOME/.profile.$(date +%Y%m%d%H%M%S).bak"
    mv "$HOME/.profile" "$backup"
    print_info "Existing .profile backed up to $backup"
fi
cp "$SCRIPT_DIR/.profile" "$HOME/.profile"
print_success ".profile applied"

print_success "Shell configuration completed"
print_info ""
print_info "Note: tmux configuration is now managed by the 'tmux' module"
print_info "Restart your shell or run: source ~/.bashrc"
