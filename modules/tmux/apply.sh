#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
COMMON_DIR="$DOTFILES_DIR/modules/common"

. "$DOTFILES_DIR/lib/utils.sh"

check_linux

print_info "tmux Configuration Setup (from common)"
echo "========================================"

# Verify submodule is initialized
if [ ! -f "$COMMON_DIR/tmux/.tmux.conf" ]; then
    print_error "Common submodule not initialized."
    print_info "Run: git submodule update --init"
    exit 1
fi

# Backup existing config
if [ -f "$HOME/.tmux.conf" ]; then
    backup="$HOME/.tmux.conf.$(date +%Y%m%d%H%M%S).bak"
    mv "$HOME/.tmux.conf" "$backup"
    print_info "Existing .tmux.conf backed up to $backup"
fi

# Deploy from common
cp "$COMMON_DIR/tmux/.tmux.conf" "$HOME/.tmux.conf"
print_success "tmux configuration applied from common repository"

print_info ""
print_info "Note: Reload tmux with 'tmux source ~/.tmux.conf' if already running"
