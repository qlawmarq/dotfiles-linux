#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
. "$DOTFILES_DIR/lib/utils.sh"

check_linux

print_info "Backing up Claude Code configuration..."

CLAUDE_CODE_DIR="$HOME/.claude"

if [ ! -d "$CLAUDE_CODE_DIR" ]; then
    print_warning "Claude Code is not configured"
    exit 0
fi

BACKUP_DIR="$SCRIPT_DIR/backup.$(date +%Y%m%d%H%M%S)"
mkdir -p "$BACKUP_DIR"

# Backup settings.json
if [ -f "$CLAUDE_CODE_DIR/settings.json" ]; then
    cp "$CLAUDE_CODE_DIR/settings.json" "$BACKUP_DIR/"
    print_info "Backed up settings.json"
fi

# Backup resources
for resource_type in commands tools hooks skills agents; do
    if [ -d "$CLAUDE_CODE_DIR/$resource_type" ]; then
        cp -r "$CLAUDE_CODE_DIR/$resource_type" "$BACKUP_DIR/"
        print_info "Backed up $resource_type"
    fi
done

print_success "Claude Code configuration backed up to $BACKUP_DIR"
