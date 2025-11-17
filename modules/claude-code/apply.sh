#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
. "$DOTFILES_DIR/lib/utils.sh"

check_linux

print_info "Claude Code CLI Setup"
echo "====================="

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

    # Claude Code configuration directory
    CLAUDE_CODE_DIR="$HOME/.claude"

    # Deploy settings.json
    if [ -f "$SCRIPT_DIR/settings.json" ]; then
        mkdir -p "$CLAUDE_CODE_DIR"

        if [ -f "$CLAUDE_CODE_DIR/settings.json" ]; then
            backup="$CLAUDE_CODE_DIR/settings.json.$(date +%Y%m%d%H%M%S).bak"
            cp "$CLAUDE_CODE_DIR/settings.json" "$backup"
            print_info "Existing settings backed up to $backup"
        fi

        cp "$SCRIPT_DIR/settings.json" "$CLAUDE_CODE_DIR/settings.json"
        print_success "Claude Code settings applied"
    fi

    # Deploy resources (commands, tools, hooks, skills, agents)
    print_info "Deploying Claude Code resources..."

    for resource_type in commands tools hooks skills agents; do
        resource_dir="$SCRIPT_DIR/$resource_type"

        if [ -d "$resource_dir" ]; then
            print_info "Deploying $resource_type..."
            mkdir -p "$CLAUDE_CODE_DIR/$resource_type"

            # Copy files
            if cp -r "$resource_dir"/* "$CLAUDE_CODE_DIR/$resource_type/" 2>/dev/null; then
                # Set execute permissions for tools and hooks
                if [ "$resource_type" = "tools" ] || [ "$resource_type" = "hooks" ]; then
                    find "$CLAUDE_CODE_DIR/$resource_type" -type f \( -name "*.sh" -o -name "*.py" \) -exec chmod +x {} \; 2>/dev/null
                fi

                print_success "$resource_type deployed"
            else
                print_warning "No $resource_type files found"
            fi
        fi
    done

    print_success "Claude Code CLI setup completed"
    print_info ""
    print_info "You can now use: claude"
else
    print_info "Claude Code CLI installation skipped"
fi
