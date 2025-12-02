#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
COMMON_DIR="$DOTFILES_DIR/modules/common"

. "$DOTFILES_DIR/lib/utils.sh"

check_linux

print_info "Backing up tmux configuration to common"
echo "========================================"

# Check if config exists
if [ ! -f "$HOME/.tmux.conf" ]; then
    print_warning "No .tmux.conf found in home directory"
    exit 0
fi

# Backup to common
cp "$HOME/.tmux.conf" "$COMMON_DIR/tmux/.tmux.conf"
print_success "tmux configuration backed up to common/tmux/"

print_warning "Remember to commit and push changes in common submodule:"
print_info "  cd $COMMON_DIR"
print_info "  git add tmux/.tmux.conf"
print_info "  git commit -m 'Update tmux configuration'"
print_info "  git push"
