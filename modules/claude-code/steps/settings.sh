# Step: merge repository settings into ~/.claude/settings.json
#
# A plain copy would wipe UI-written keys (inputNeededNotifEnabled,
# modelSettings, ...) on every run. A plain deep merge would never
# remove a key the repository dropped, so a retired hook would linger
# forever. Deep-merge for UI-owned keys, wholesale assignment for the
# two objects the repository owns.

need_cmd jq "settings merge" || return 0

REPO_SETTINGS="$COMMON_DIR/claude/settings.json"
LIVE_SETTINGS="$CLAUDE_DIR/settings.json"

if [ ! -f "$REPO_SETTINGS" ]; then
    print_warning "No settings.json in common - skipping"
    return 0
fi

mkdir -p "$CLAUDE_DIR"
[ -f "$LIVE_SETTINGS" ] || echo '{}' > "$LIVE_SETTINGS"

if ! jq -e . "$LIVE_SETTINGS" >/dev/null 2>&1; then
    print_error "$LIVE_SETTINGS is not valid JSON - refusing to merge"
    return 1
fi

# Snapshot into our own directory; ~/.claude/backups is Claude Code's.
BACKUP_DIR="$CLAUDE_DIR/.dotfiles-backups"
mkdir -p "$BACKUP_DIR"
cp "$LIVE_SETTINGS" "$BACKUP_DIR/settings-$(date +%Y%m%d%H%M%S).json"

TMP=$(mktemp)
if jq -n --slurpfile live "$LIVE_SETTINGS" --slurpfile repo "$REPO_SETTINGS" '
      ($live[0] // {}) * ($repo[0] // {})
      | .permissions = ($repo[0].permissions // {})
      | .hooks       = ($repo[0].hooks // {})
   ' > "$TMP" && [ -s "$TMP" ]; then
    mv "$TMP" "$LIVE_SETTINGS"
    print_success "settings.json merged (permissions/hooks from repo, local keys preserved)"
    print_warning "Restart running Claude Code sessions to pick up settings changes"
else
    rm -f "$TMP"
    print_error "Failed to merge settings.json (left unchanged)"
    return 1
fi

# De-provision the retired notify hook. Notifications now come from the
# built-in preferredNotifChannel setting, and the merge above has already
# dropped the hook wiring. Idempotent - safe to delete this block once
# every machine has run it.
for f in notify.sh notify-config auto-approve-safe-commands.sh; do
    if [ -e "$CLAUDE_DIR/hooks/$f" ]; then
        rm -f "$CLAUDE_DIR/hooks/$f"
        print_info "Removed retired hook file: $f"
    fi
done
rmdir "$CLAUDE_DIR/hooks" 2>/dev/null || true
