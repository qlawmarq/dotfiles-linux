#!/bin/bash

# ====================
# Codex CLI initialization script
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
print_info "Codex CLI Setup"
echo "================"

# Check for required dependencies
print_info "Checking dependencies..."

# Check if Node.js is installed
if ! command_exists "node"; then
    print_error "Node.js is not installed. Please run the mise module first."
    exit 1
fi

# Check if npm is available
if ! command_exists "npm"; then
    print_error "npm is not available. Please ensure Node.js is properly installed."
    exit 1
fi

NODE_VERSION=$(node --version)
print_info "Node.js version: $NODE_VERSION"

# Install Codex CLI globally
print_info "Installing Codex CLI..."
if npm list -g @openai/codex >/dev/null 2>&1; then
    print_warning "Codex CLI is already installed"
    if confirm "Would you like to upgrade to the latest version?"; then
        npm install -g @openai/codex@latest
        print_success "Codex CLI upgraded to latest version"
    fi
else
    npm install -g @openai/codex@latest
    print_success "Codex CLI installed successfully"
fi

# Create Codex configuration directory
print_info "Setting up Codex configuration..."
CODEX_CONFIG_DIR="$HOME/.codex"
mkdir -p "$CODEX_CONFIG_DIR"

# Check if configuration template exists
CONFIG_TEMPLATE="$SCRIPT_DIR/config.toml"
if [ ! -f "$CONFIG_TEMPLATE" ]; then
    print_error "Codex configuration template not found at $CONFIG_TEMPLATE"
    exit 1
fi

# Process configuration file
print_info "Installing Codex configuration..."

# Get current Node.js version from mise for MCP server paths
if command_exists "mise"; then
    MISE_NODE_VERSION=$(mise current node | awk '{print $1}')
    if [ -n "$MISE_NODE_VERSION" ]; then
        NODE_VERSION="$MISE_NODE_VERSION"
    fi
fi

# Function to get user input with default value
get_user_input() {
    local prompt="$1"
    local default="$2"
    local input
    
    if [ -n "$default" ]; then
        read -p "$prompt [$default]: " input
        echo "${input:-$default}"
    else
        while true; do
            read -p "$prompt: " input
            if [ -n "$input" ]; then
                echo "$input"
                break
            fi
            echo "This field cannot be empty. Please try again."
        done
    fi
}

# Try to get existing values from current config file if it exists
EXISTING_CONFIG="$CODEX_CONFIG_DIR/config.toml"
CURRENT_API_KEY=""
CURRENT_BASE_URL=""

if [ -f "$EXISTING_CONFIG" ]; then
    # Extract existing Azure API key from environment or existing config
    CURRENT_API_KEY="${AZURE_OPENAI_API_KEY:-}"
    
    # Extract existing base URL
    CURRENT_BASE_URL=$(grep -o 'base_url = "https://[^"]*"' "$EXISTING_CONFIG" 2>/dev/null | cut -d'"' -f2)
    
    # If base_url contains placeholder, clear it for user input
    if [[ "$CURRENT_BASE_URL" == *"YOUR_PROJECT_NAME"* ]]; then
        CURRENT_BASE_URL=""
    fi
fi

# Get Azure OpenAI API Key
if [ -z "$CURRENT_API_KEY" ]; then
    CURRENT_API_KEY="${AZURE_OPENAI_API_KEY:-}"
fi

if [ -n "$CURRENT_API_KEY" ]; then
    echo "Azure OpenAI API Key found in environment."
    AZURE_API_KEY="$CURRENT_API_KEY"
else
    print_info "Azure OpenAI configuration needed"
    AZURE_API_KEY=$(get_user_input "Enter your Azure OpenAI API Key (or press Enter to skip)" "")
fi

# Get Azure base URL (project name)
if [ -n "$CURRENT_BASE_URL" ]; then
    PROJECT_NAME=$(echo "$CURRENT_BASE_URL" | sed 's|https://\([^.]*\)\.openai\.azure\.com.*|\1|')
else
    PROJECT_NAME=""
fi

AZURE_PROJECT_NAME=$(get_user_input "Enter your Azure OpenAI project name" "$PROJECT_NAME")

# Construct the full base URL
AZURE_BASE_URL="https://${AZURE_PROJECT_NAME}.openai.azure.com/openai"

# Create configuration file with current environment
TMP_CONFIG=$(mktemp)
echo "Creating configuration with Node.js version: $NODE_VERSION"
if [ -n "$AZURE_API_KEY" ]; then
    echo "Configuring Azure OpenAI with project: $AZURE_PROJECT_NAME"
fi

# Replace placeholder values in the template
sed -e "s|\$NODE_VERSION|$NODE_VERSION|g" \
    -e "s|\$HOME|$HOME|g" \
    -e "s|YOUR_PROJECT_NAME|$AZURE_PROJECT_NAME|g" \
    "$CONFIG_TEMPLATE" > "$TMP_CONFIG"

# Copy processed configuration to Codex directory
cp "$TMP_CONFIG" "$CODEX_CONFIG_DIR/config.toml"
rm -f "$TMP_CONFIG"

# Save API key to .env_secrets file for automatic loading
if [ -n "$AZURE_API_KEY" ]; then
    ENV_SECRETS_FILE="$HOME/.env_secrets"
    
    # Create or update .env_secrets file
    if [ -f "$ENV_SECRETS_FILE" ]; then
        # Remove existing AZURE_OPENAI_API_KEY line if it exists
        grep -v "^export AZURE_OPENAI_API_KEY=" "$ENV_SECRETS_FILE" > "${ENV_SECRETS_FILE}.tmp" 2>/dev/null || true
        mv "${ENV_SECRETS_FILE}.tmp" "$ENV_SECRETS_FILE"
    else
        # Create new file with proper permissions (readable only by user)
        touch "$ENV_SECRETS_FILE"
        chmod 600 "$ENV_SECRETS_FILE"
        
        # Add header comment
        cat > "$ENV_SECRETS_FILE" << 'EOF'
#!/bin/bash
# Environment Secrets File
# This file contains sensitive environment variables and is excluded from git
# Generated and managed by dotfiles modules

EOF
    fi
    
    # Add the Azure API key
    echo "export AZURE_OPENAI_API_KEY=\"$AZURE_API_KEY\"" >> "$ENV_SECRETS_FILE"
    
    print_success "Azure API key saved to ~/.env_secrets (automatically loaded in new shell sessions)"
fi

print_success "Codex configuration installed at ~/.codex/config.toml"

# Show next steps
print_info "Next Steps:"
if [ -n "$AZURE_API_KEY" ] && [ -n "$AZURE_PROJECT_NAME" ]; then
    echo "✓ Azure OpenAI configured with project: $AZURE_PROJECT_NAME"
    echo "✓ API key saved to ~/.env_secrets (auto-loaded in new shells)"
    echo "1. Start a new shell session or run: . ~/.env_secrets"
    echo "2. Test the configuration: codex --help"
    echo "3. Or run 'codex' to start using the CLI"
else
    echo "1. Run the script again to configure Azure OpenAI"
    echo "2. Or run 'codex' and sign in with your ChatGPT account"
    echo "3. Or manually edit ~/.codex/config.toml to add your Azure settings"
    echo "4. Or manually add: export AZURE_OPENAI_API_KEY='your-key' to ~/.env_secrets"
fi

print_success "Codex CLI setup completed!"