#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
COMMON_DIR="$DOTFILES_DIR/modules/common"

. "$DOTFILES_DIR/lib/utils.sh"

check_linux

print_info "Claude Code CLI Setup (from common)"
echo "===================================="

# Verify submodule is initialized
if [ ! -d "$COMMON_DIR/claude" ]; then
    print_error "Common submodule not initialized."
    print_info "Run: git submodule update --init"
    exit 1
fi

# Check dependencies
if ! command_exists node; then
    print_error "Node.js is not installed. Please run mise module first."
    exit 1
fi

# Install Claude Code CLI
if confirm "Would you like to install @anthropic-ai/claude-code?"; then
    print_info "Installing @anthropic-ai/claude-code..."
    npm install -g @anthropic-ai/claude-code@latest

    if [ $? -eq 0 ]; then
        print_success "@anthropic-ai/claude-code installed"
    else
        print_error "Failed to install @anthropic-ai/claude-code"
        exit 1
    fi

    CLAUDE_CODE_DIR="$HOME/.claude"
    mkdir -p "$CLAUDE_CODE_DIR"

    # Deploy settings.json from common
    if [ -f "$COMMON_DIR/claude/settings.json" ]; then
        if [ -f "$CLAUDE_CODE_DIR/settings.json" ]; then
            backup="$CLAUDE_CODE_DIR/settings.json.$(date +%Y%m%d%H%M%S).bak"
            cp "$CLAUDE_CODE_DIR/settings.json" "$backup"
            print_info "Existing settings backed up to $backup"
        fi

        cp "$COMMON_DIR/claude/settings.json" "$CLAUDE_CODE_DIR/settings.json"
        print_success "Claude Code settings applied from common"
    fi

    # Deploy resources from common
    print_info "Deploying Claude Code resources from common..."

    for resource_type in agents commands skills tools; do
        resource_dir="$COMMON_DIR/claude/$resource_type"

        if [ -d "$resource_dir" ]; then
            print_info "Deploying $resource_type..."
            mkdir -p "$CLAUDE_CODE_DIR/$resource_type"

            if cp -r "$resource_dir"/* "$CLAUDE_CODE_DIR/$resource_type/" 2>/dev/null; then
                # Set execute permissions for tools
                if [ "$resource_type" = "tools" ]; then
                    find "$CLAUDE_CODE_DIR/$resource_type" -type f \( -name "*.sh" -o -name "*.py" \) -exec chmod +x {} \; 2>/dev/null
                fi

                print_success "$resource_type deployed"
            else
                print_warning "No $resource_type files found"
            fi
        fi
    done

    # Deploy hooks from common
    print_info "Deploying hooks from common..."
    mkdir -p "$CLAUDE_CODE_DIR/hooks"

    # Copy common hook
    if [ -f "$COMMON_DIR/claude/hooks/auto-approve-safe-commands.sh" ]; then
        cp "$COMMON_DIR/claude/hooks/auto-approve-safe-commands.sh" "$CLAUDE_CODE_DIR/hooks/"
        chmod +x "$CLAUDE_CODE_DIR/hooks/auto-approve-safe-commands.sh"
        print_success "Hooks deployed"
    fi

    # Copy Linux-specific hooks if they exist
    if [ -d "$COMMON_DIR/claude/hooks/platform/linux" ]; then
        for hook in "$COMMON_DIR/claude/hooks/platform/linux"/*; do
            if [ -f "$hook" ] && [ "$(basename "$hook")" != ".gitkeep" ]; then
                cp "$hook" "$CLAUDE_CODE_DIR/hooks/"
                chmod +x "$CLAUDE_CODE_DIR/hooks/$(basename "$hook")"
            fi
        done
    fi

    print_success "Claude Code CLI setup completed"
    print_info ""
    print_info "You can now use: claude"
else
    print_info "Claude Code CLI installation skipped"
fi
