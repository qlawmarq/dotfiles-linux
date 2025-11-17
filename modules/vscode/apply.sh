#!/bin/bash

# Read common utils
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
if [ -f "$DOTFILES_DIR/lib/utils.sh" ]; then
    . "$DOTFILES_DIR/lib/utils.sh"
else
    echo "Error: utils.sh not found at $DOTFILES_DIR/lib/utils.sh"
    exit 1
fi

check_linux

print_info "VS Code Setup"
echo "============="

# Check if VS Code is installed
if ! command_exists code; then
    print_error "VS Code is not installed."
    print_info "Install VS Code: https://code.visualstudio.com/docs/setup/linux"
    exit 1
fi

# Linux configuration directory
VSCODE_CONFIG_DIR="$HOME/.config/Code/User"
mkdir -p "$VSCODE_CONFIG_DIR"

# Get mise Node.js version
if command_exists mise; then
    NODE_VERSION=$(mise current node 2>/dev/null | awk '{print $1}')
else
    NODE_VERSION=""
fi

if [ -z "$NODE_VERSION" ]; then
    print_warning "Node.js is not installed via mise. Some features may not work."
    NODE_VERSION="unknown"
fi

# GitHub Token handling
CONFIG_FILE="$VSCODE_CONFIG_DIR/settings.json"
GITHUB_TOKEN=""

if [ -f "$CONFIG_FILE" ]; then
    GITHUB_TOKEN=$(grep -o '"GITHUB_PERSONAL_ACCESS_TOKEN": "[^"]*"' "$CONFIG_FILE" | cut -d'"' -f4)
fi

if [ -z "$GITHUB_TOKEN" ]; then
    echo "Please enter your GitHub Personal Access Token (or press Enter to skip):"
    read -r GITHUB_TOKEN
fi

# Generate configuration file
print_info "Updating configuration with Node.js $NODE_VERSION..."

TMP_CONFIG=$(mktemp)
sed -e "s|\$NODE_VERSION|$NODE_VERSION|g" \
    -e "s|\$HOME|$HOME|g" \
    -e "s|\$GITHUB_TOKEN|$GITHUB_TOKEN|g" \
    "${SCRIPT_DIR}/settings.json" > "$TMP_CONFIG"

cp "$TMP_CONFIG" "$CONFIG_FILE"
rm "$TMP_CONFIG"

print_success "VS Code settings applied"

# Install extensions
if [ -f "${SCRIPT_DIR}/vscode-extensions.txt" ]; then
    print_info "Installing VS Code extensions..."
    while IFS= read -r extension; do
        code --install-extension "$extension"
    done < "${SCRIPT_DIR}/vscode-extensions.txt"
    print_success "VS Code extensions installed"
fi

print_success "VS Code setup completed"
