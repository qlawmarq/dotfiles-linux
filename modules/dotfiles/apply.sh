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

print_info "Setting up dotfiles..."
echo "======================"

# Setup .profile (loaded for login shells including SSH)
if [ -f "${SCRIPT_DIR}/.profile" ]; then
    cp "${SCRIPT_DIR}/.profile" ~/.profile
    print_success ".profile applied"
fi

# Setup .bashrc
if [ -f "${SCRIPT_DIR}/.bashrc" ]; then
    cp "${SCRIPT_DIR}/.bashrc" ~/.bashrc
    print_success ".bashrc applied"
fi

# Setup .tmux.conf
if [ -f "${SCRIPT_DIR}/.tmux.conf" ]; then
    cp "${SCRIPT_DIR}/.tmux.conf" ~/.tmux.conf
    print_success "tmux configuration applied"
fi

print_success "Dotfiles applied successfully"
print_info "Restart your shell or run: source ~/.bashrc"
