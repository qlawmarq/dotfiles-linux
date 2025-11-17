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

print_info "Git Configuration Setup"
echo "======================="

# Get current git config if exists
if [ -f ~/.gitconfig ]; then
    CURRENT_EMAIL=$(git config --global user.email)
    CURRENT_NAME=$(git config --global user.name)
else
    CURRENT_EMAIL=""
    CURRENT_NAME=""
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

# Get git user information
GIT_EMAIL=$(get_user_input "Enter your Git email" "$CURRENT_EMAIL")
GIT_NAME=$(get_user_input "Enter your Git name" "$CURRENT_NAME")

# Setup SSH for GitHub if not exists
setup_github_ssh() {
    local email="$1"
    if [ ! -f ~/.ssh/id_ed25519 ]; then
        print_info "Setting up SSH key for GitHub..."
        ssh-keygen -t ed25519 -C "$email" -f ~/.ssh/id_ed25519 -N ""

        # Create or update SSH config
        if [ ! -f ~/.ssh/config ]; then
            mkdir -p ~/.ssh
            touch ~/.ssh/config
        fi

        # Only add GitHub config if it doesn't exist
        if ! grep -q "Host github.com" ~/.ssh/config; then
            cat << EOF >> ~/.ssh/config

Host github.com
    AddKeysToAgent yes
    IdentityFile ~/.ssh/id_ed25519
EOF
        fi

        # Start ssh-agent and add key
        eval "$(ssh-agent -s)"
        ssh-add ~/.ssh/id_ed25519

        # Copy public key to clipboard
        cat ~/.ssh/id_ed25519.pub | copy_to_clipboard

        if [ $? -eq 0 ]; then
            print_success "SSH public key has been copied to clipboard."
        else
            print_warning "Could not copy to clipboard. Here is your public key:"
            cat ~/.ssh/id_ed25519.pub
        fi

        echo ""
        print_info "Please add it to your GitHub account: https://github.com/settings/keys"
        echo "Press Enter when you have added the key to GitHub..."
        read -r
    else
        print_info "SSH key already exists, skipping GitHub SSH setup..."
    fi
}

# Create temporary config with user input
TMP_CONFIG=$(mktemp)
sed -e "s|\$GIT_EMAIL|$GIT_EMAIL|g" \
    -e "s|\$GIT_NAME|$GIT_NAME|g" \
    "${SCRIPT_DIR}/.gitconfig" > "$TMP_CONFIG"

# Setup git related files
cp "$TMP_CONFIG" ~/.gitconfig
mkdir -p ~/.config/git
cp "${SCRIPT_DIR}/.config/git/ignore" ~/.config/git/ignore

# Clean up
rm -f "$TMP_CONFIG"

print_success "Git configuration applied"

# Setup GitHub SSH
setup_github_ssh "$GIT_EMAIL"

print_success "Git setup completed"
