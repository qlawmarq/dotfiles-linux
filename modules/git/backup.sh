#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
COMMON_DIR="$DOTFILES_DIR/modules/common"

. "$DOTFILES_DIR/lib/utils.sh"

check_linux

print_info "Backing up Git configuration to common"
echo "========================================"

# Backup .gitconfig
if [ -f ~/.gitconfig ]; then
    TMP_CONFIG=$(mktemp)
    cp ~/.gitconfig "$TMP_CONFIG"

    # Replace personal info with placeholders (GNU sed)
    sed -i -e "s/^[[:space:]]*email[[:space:]]*=.*$/	email 	= \$GIT_EMAIL/" \
           -e "s/^[[:space:]]*name[[:space:]]*=.*$/	name 	= \$GIT_NAME/" \
           "$TMP_CONFIG"

    cp "$TMP_CONFIG" "$COMMON_DIR/git/.gitconfig"
    rm -f "$TMP_CONFIG"
    print_success ".gitconfig backed up to common/git/"
fi

# Backup gitignore
if [ -f ~/.config/git/ignore ]; then
    mkdir -p "$COMMON_DIR/git/.config/git"
    cp ~/.config/git/ignore "$COMMON_DIR/git/.config/git/ignore"
    print_success "git ignore backed up to common/git/"
fi

print_warning "Remember to commit and push changes in common submodule:"
print_info "  cd $COMMON_DIR"
print_info "  git add git/"
print_info "  git commit -m 'Update git configuration'"
print_info "  git push"
