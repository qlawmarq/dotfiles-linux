#!/bin/bash

# ============================================================
# Claude Code configuration backup - step dispatcher (Linux)
#
# Usage:
#   bash backup.sh              # interactive step menu (TTY) / all steps
#   bash backup.sh mcp          # single step
#   CLAUDE_BACKUP_STEPS="mcp" bash backup.sh
#
# Writes live configuration back into the repository:
#   mcp      -> modules/claude/mcp-servers.json
#   settings -> modules/common/claude/settings.json  (SUBMODULE)
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
fi

. "$SCRIPT_DIR/lib.sh"

CLAUDE_DIR="$HOME/.claude"

ALL_STEPS="mcp settings"

STEPS="$*"
[ -z "$STEPS" ] && STEPS="${CLAUDE_BACKUP_STEPS:-}"

if [ -z "$STEPS" ]; then
    if [ -t 0 ]; then
        smart_select_items "Select what to back up" $ALL_STEPS
        STEPS="$SELECTED_ITEMS"
    else
        STEPS="$ALL_STEPS"
    fi
fi

[ "$STEPS" = "all" ] && STEPS="$ALL_STEPS"

if [ -z "$STEPS" ]; then
    print_warning "Nothing selected"
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

RUN=""
for s in $ALL_STEPS; do
    case " $STEPS " in
        *" $s "*) RUN="$RUN $s" ;;
    esac
done

print_info "Backing up Claude Code configuration"
echo "====================================="
print_info "Steps:$RUN"
echo ""

COMMON_TOUCHED=false
FAILED=""
for s in $RUN; do
    print_info "--- step: $s ---"
    if ! ( . "$SCRIPT_DIR/backup-steps/$s.sh" ); then
        FAILED="$FAILED $s"
    fi
    [ "$s" = "settings" ] && COMMON_TOUCHED=true
    echo ""
done

if [ "$COMMON_TOUCHED" = true ]; then
    print_warning "modules/common (submodule) was modified. Commit it there first:"
    echo "  git -C modules/common add -A && git -C modules/common commit && git -C modules/common push"
    echo "  git add modules/common && git commit -m 'chore: bump common'"
fi

if [ -n "$FAILED" ]; then
    print_error "Failed steps:$FAILED"
    exit 1
fi

print_success "Backup completed"
exit 0
