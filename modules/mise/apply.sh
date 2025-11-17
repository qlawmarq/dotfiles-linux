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

print_info "mise Setup"
echo "==========="

# Install mise via curl
if ! command_exists mise; then
    print_info "Installing mise via curl..."
    curl https://mise.run | sh

    if [ $? -ne 0 ]; then
        print_error "Failed to install mise"
        exit 1
    fi
    print_success "mise installed to ~/.local/bin/mise"
else
    print_info "mise is already installed"
fi

# Verify mise installation
MISE_BIN="$HOME/.local/bin/mise"
if [ ! -x "$MISE_BIN" ]; then
    print_error "mise not found at $MISE_BIN"
    exit 1
fi

print_info "mise version: $($MISE_BIN --version)"

# Install Go
if confirm "Would you like to install Go?"; then
    print_info "Installing Go..."
    $MISE_BIN use -g go@latest
    print_success "Go installed"
fi

# Install Python
if confirm "Would you like to install Python? (necessary for Claude Code)"; then
    print_info "Installing Python..."
    $MISE_BIN use -g python@latest
    print_success "Python installed"
    if confirm "Would you like to install uv?"; then
        print_info "Installing uv..."
        $MISE_BIN use -g uv@latest
        print_success "uv installed"
    fi
fi

# Install Node.js
if confirm "Would you like to install Node.js? (necessary for Claude Code/Codex)"; then
    print_info "Installing Node.js..."
    $MISE_BIN use -g node@lts
    print_success "Node.js installed"
    if confirm "Would you like to install pnpm?"; then
        print_info "Installing pnpm..."
        $MISE_BIN use -g pnpm@latest
        print_success "pnpm installed"
    fi
fi

# Note about mise activation
print_info ""
print_info "To use mise-installed tools, you need to activate mise in your shell."
print_info "This will be automatically added to your shell config by the dotfiles module."
print_info ""

print_success "mise setup completed!"