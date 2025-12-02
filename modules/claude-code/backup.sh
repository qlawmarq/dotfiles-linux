#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
COMMON_DIR="$DOTFILES_DIR/modules/common"

. "$DOTFILES_DIR/lib/utils.sh"

check_linux

print_info "Backing up Claude Code configuration to common"
echo "==============================================="

CLAUDE_CODE_DIR="$HOME/.claude"

# Check if Claude Code directory exists
if [ ! -d "$CLAUDE_CODE_DIR" ]; then
    print_warning "Claude Code directory not found at $CLAUDE_CODE_DIR"
    exit 0
fi

# Backup settings.json
if [ -f "$CLAUDE_CODE_DIR/settings.json" ]; then
    cp "$CLAUDE_CODE_DIR/settings.json" "$COMMON_DIR/claude/settings.json"
    print_success "settings.json backed up"
fi

# Backup resources
for resource_type in agents commands skills tools; do
    if [ -d "$CLAUDE_CODE_DIR/$resource_type" ]; then
        print_info "Backing up $resource_type..."
        mkdir -p "$COMMON_DIR/claude/$resource_type"
        cp -r "$CLAUDE_CODE_DIR/$resource_type"/* "$COMMON_DIR/claude/$resource_type/" 2>/dev/null
        print_success "$resource_type backed up"
    fi
done

# Backup common hooks only (not platform-specific)
if [ -f "$CLAUDE_CODE_DIR/hooks/auto-approve-safe-commands.sh" ]; then
    cp "$CLAUDE_CODE_DIR/hooks/auto-approve-safe-commands.sh" "$COMMON_DIR/claude/hooks/"
    print_success "Common hooks backed up"
fi

print_success "Backup completed"
print_warning "Remember to commit and push changes in common submodule:"
print_info "  cd $COMMON_DIR"
print_info "  git add claude/"
print_info "  git commit -m 'Update Claude Code configuration'"
print_info "  git push"
