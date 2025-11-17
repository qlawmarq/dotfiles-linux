#!/bin/bash

# ====================
# Codex CLI backup script
# ====================

# Directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Load utils
if [ -f "$DOTFILES_DIR/lib/utils.sh" ]; then
    . "$DOTFILES_DIR/lib/utils.sh"
else
    echo "Error: utils.sh not found at $DOTFILES_DIR/lib/utils.sh"
    exit 1
fi

check_linux

# Print header
print_info "Backing up Codex CLI configuration..."
echo "====================================="

# Check if Codex is installed
if ! command_exists "codex"; then
    print_warning "Codex CLI is not installed. Nothing to backup."
    exit 0
fi

# Codex configuration directory
CODEX_CONFIG_DIR="$HOME/.codex"
CODEX_CONFIG_FILE="$CODEX_CONFIG_DIR/config.toml"

# Check if configuration file exists
if [ ! -f "$CODEX_CONFIG_FILE" ]; then
    print_warning "Codex configuration file not found at $CODEX_CONFIG_FILE"
    exit 0
fi

print_info "Found existing Codex configuration"

# Get current Node.js version from mise
NODE_VERSION=""
if command_exists "mise"; then
    NODE_VERSION=$(mise current node | awk '{print $1}')
fi

# If mise is not available or doesn't have node, try to get from node directly
if [ -z "$NODE_VERSION" ] && command_exists "node"; then
    NODE_VERSION=$(node --version | sed 's/^v//')
fi

if [ -z "$NODE_VERSION" ]; then
    print_warning "Could not determine Node.js version for placeholder replacement"
    NODE_VERSION="latest"
fi

print_info "Using Node.js version: $NODE_VERSION"

# Create temporary file for processing
TMP_CONFIG=$(mktemp)

# Process the configuration file to replace specific values with placeholders
cat "$CODEX_CONFIG_FILE" | \
sed -E "s|node/[0-9]+\.[0-9]+\.[0-9]+|node/\$NODE_VERSION|g; \
        s|${HOME}|\$HOME|g; \
        s|base_url = \"https://[^.]+\.openai\.azure\.com|base_url = \"https://YOUR_PROJECT_NAME.openai.azure.com|g" \
> "$TMP_CONFIG"

# Check if the processed file has content
if [ -s "$TMP_CONFIG" ]; then
    # Copy processed configuration to module directory
    cp "$TMP_CONFIG" "$SCRIPT_DIR/config.toml"
    print_success "Codex configuration backed up to config.toml"
    
    # Show what was backed up
    print_info "Configuration contains:"
    if grep -q "model_provider.*azure" "$TMP_CONFIG"; then
        echo "  ✓ Azure OpenAI provider configuration"
    fi
    if grep -q "\[mcp_servers\]" "$TMP_CONFIG"; then
        echo "  ✓ MCP servers configuration"
    fi
    if grep -q "model.*=" "$TMP_CONFIG"; then
        MODEL=$(grep "model.*=" "$TMP_CONFIG" | head -1 | cut -d'=' -f2 | tr -d ' "')
        echo "  ✓ Default model: $MODEL"
    fi
else
    print_error "Failed to process configuration file"
    rm -f "$TMP_CONFIG"
    exit 1
fi

# Clean up
rm -f "$TMP_CONFIG"

# Additional backup information
print_info "Backup completed. The configuration template is ready for deployment."
echo "To apply this configuration on another system, run: bash apply.sh"

print_success "Codex CLI configuration backup completed!"