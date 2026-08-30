# Step: deploy hook scripts to ~/.claude/hooks/

HOOKS_DIR="$CLAUDE_DIR/hooks"
mkdir -p "$HOOKS_DIR"

# De-provision the retired auto-approve PreToolUse hook. The settings
# step drops its wiring; this removes the orphaned script. Idempotent -
# safe to delete this line once every machine has run it.
if [ -e "$HOOKS_DIR/auto-approve-safe-commands.sh" ]; then
    rm -f "$HOOKS_DIR/auto-approve-safe-commands.sh"
    print_info "Removed retired hook: auto-approve-safe-commands.sh"
fi

LINUX_HOOKS="$COMMON_DIR/claude/hooks/platform/linux"
if [ ! -d "$LINUX_HOOKS" ]; then
    print_warning "No Linux hooks in common - skipping"
    return 0
fi

DEPLOYED=false
for hook in "$LINUX_HOOKS"/*; do
    [ -f "$hook" ] || continue
    name=$(basename "$hook")
    [ "$name" = ".gitkeep" ] && continue
    if [ "$name" = "notify-config" ] && [ -f "$HOOKS_DIR/$name" ]; then
        print_info "Kept existing notify-config"
        continue
    fi
    cp "$hook" "$HOOKS_DIR/$name"
    DEPLOYED=true
done

if [ "$DEPLOYED" = true ]; then
    chmod +x "$HOOKS_DIR"/*.sh 2>/dev/null || true
    print_success "Hooks deployed to $HOOKS_DIR"
else
    print_info "No Linux hooks to deploy (platform/linux is empty)"
fi

if ! command_exists jq; then
    print_warning "'jq' not found - notify.sh needs it at runtime"
fi
