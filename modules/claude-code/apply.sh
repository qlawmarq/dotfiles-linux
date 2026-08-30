#!/bin/bash

# ============================================================
# Claude Code setup - step dispatcher (Linux)
#
# Usage:
#   sh apply.sh                 # interactive step menu (TTY) / all steps (non-TTY)
#   sh apply.sh skills          # run a single step
#   sh apply.sh skills mcp      # run several (always in canonical order)
#   sh apply.sh all             # run everything
#   CLAUDE_APPLY_STEPS="skills" sh apply.sh
#
# The top-level apply.sh invokes this with no arguments, so argument
# support is an extra affordance for direct invocation. Every step is
# independent: updating skills does not require reinstalling the CLI.
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
COMMON_DIR="$DOTFILES_DIR/modules/common"

if [ -f "$DOTFILES_DIR/lib/utils.sh" ]; then
    . "$DOTFILES_DIR/lib/utils.sh"
else
    echo "Error: utils.sh not found at $DOTFILES_DIR/lib/utils.sh" >&2
    exit 1
fi

check_linux

if [ -f "$DOTFILES_DIR/lib/menu.sh" ]; then
    . "$DOTFILES_DIR/lib/menu.sh"
else
    print_error "menu.sh not found at $DOTFILES_DIR/lib/menu.sh"
    exit 1
fi

. "$SCRIPT_DIR/lib.sh"

if [ ! -d "$COMMON_DIR/claude" ]; then
    print_error "Common submodule not initialized."
    print_info "Run: git submodule update --init"
    exit 1
fi

CLAUDE_DIR="$HOME/.claude"

ALL_STEPS="cli hooks settings skills mcp doctor"

# ------------------------------------------------------------
# Resolve which steps to run
# ------------------------------------------------------------
STEPS="$*"
[ -z "$STEPS" ] && STEPS="${CLAUDE_APPLY_STEPS:-}"

if [ -z "$STEPS" ]; then
    if [ -t 0 ]; then
        # smart_select_items clears the screen, so print the header after it
        smart_select_items "Select Claude Code setup steps" $ALL_STEPS
        STEPS="$SELECTED_ITEMS"
    else
        STEPS="$ALL_STEPS"
    fi
fi

[ "$STEPS" = "all" ] && STEPS="$ALL_STEPS"

if [ -z "$STEPS" ]; then
    print_warning "No steps selected"
    exit 0
fi

for s in $STEPS; do
    case " $ALL_STEPS " in
        *" $s "*) ;;
        *)
            print_error "Unknown step: $s"
            print_info "Valid steps: $ALL_STEPS"
            exit 1
            ;;
    esac
done

# Re-order into canonical order; menu selection order is not meaningful
RUN=""
for s in $ALL_STEPS; do
    case " $STEPS " in
        *" $s "*) RUN="$RUN $s" ;;
    esac
done

print_info "Claude Code Setup"
echo "======================"
print_info "Steps:$RUN"
echo ""

# ------------------------------------------------------------
# Run each step in a subshell so a step's `exit` cannot abort the
# module and no variables leak between steps.
# ------------------------------------------------------------
FAILED=""
for s in $RUN; do
    print_info "--- step: $s ---"
    if ! ( . "$SCRIPT_DIR/steps/$s.sh" ); then
        FAILED="$FAILED $s"
    fi
    echo ""
done

if [ -n "$FAILED" ]; then
    print_error "Failed steps:$FAILED"
    exit 1
fi

print_success "Claude Code setup completed"
exit 0
