#!/bin/bash

# Load common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
if [ -f "$DOTFILES_DIR/lib/utils.sh" ]; then
    . "$DOTFILES_DIR/lib/utils.sh"
else
    echo "Error: utils.sh not found at $DOTFILES_DIR/lib/utils.sh"
    exit 1
fi

check_linux

print_info "Backing up VS Code configuration..."

VSCODE_CONFIG_DIR="$HOME/.config/Code/User"

if [ ! -d "$VSCODE_CONFIG_DIR" ]; then
    print_warning "VS Code is not installed or not configured"
    exit 0
fi

BACKUP_DIR="$SCRIPT_DIR/backup.$(date +%Y%m%d%H%M%S)"
mkdir -p "$BACKUP_DIR"

# Backup settings.json
if [ -f "$VSCODE_CONFIG_DIR/settings.json" ]; then
    # Get current Node.js version
    if command_exists mise; then
        NODE_VERSION=$(mise current node 2>/dev/null | awk '{print $1}')
    else
        NODE_VERSION="unknown"
    fi

    # Process configuration to replace dynamic values with placeholders
    TMP_CONFIG=$(mktemp)
    cat "$VSCODE_CONFIG_DIR/settings.json" | \
    sed -E "s|node/[0-9]+\.[0-9]+\.[0-9]+|node/\$NODE_VERSION|g; \
            s|${HOME}|\$HOME|g; \
            s|\"GITHUB_PERSONAL_ACCESS_TOKEN\": \"[^\"]*\"|\"GITHUB_PERSONAL_ACCESS_TOKEN\": \"\$GITHUB_TOKEN\"|g" \
    > "$TMP_CONFIG"

    if [ -s "$TMP_CONFIG" ]; then
        cp "$TMP_CONFIG" "$BACKUP_DIR/settings.json"
        print_info "Backed up settings.json"
    fi
    rm -f "$TMP_CONFIG"
fi

# Export installed extensions
if command_exists code; then
    code --list-extensions | sort > "$BACKUP_DIR/extensions.txt"
    print_info "Backed up extension list"
fi

print_success "VS Code configuration backed up to $BACKUP_DIR"
