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

# Never wire a hook whose script is not on disk: the shared settings file
# is used by both platforms, and a command that does not exist fails on
# every matching tool call. The `hooks` step runs before this one, so what
# is on disk now is what this machine actually got.
MISSING_HOOKS="[]"
HOOK_CMDS=$(jq -r '(.hooks // {}) | to_entries[] | .value[]? | .hooks[]?
                   | select(.type == "command") | .command' "$REPO_SETTINGS" 2>/dev/null | sort -u)
OLDIFS=$IFS
IFS='
'
for cmd in $HOOK_CMDS; do
    resolved=$(printf '%s' "$cmd" | sed "s|\$HOME|$HOME|g")
    script=${resolved%% *}
    if [ ! -e "$script" ]; then
        MISSING_HOOKS=$(printf '%s' "$MISSING_HOOKS" | jq -c --arg c "$cmd" '. + [$c]')
        print_warning "Hook script not present, dropping its wiring: $script"
    fi
done
IFS=$OLDIFS

TMP=$(mktemp)
if jq -n --slurpfile live "$LIVE_SETTINGS" --slurpfile repo "$REPO_SETTINGS" \
        --argjson missing "$MISSING_HOOKS" '
      def prune_missing:
          map_values(
              map(.hooks |= map(select(.command as $c | ($missing | index($c)) | not)))
              | map(select((.hooks | length) > 0))
          )
          | with_entries(select((.value | length) > 0));
      ($live[0] // {}) * ($repo[0] // {})
      | .permissions = ($repo[0].permissions // {})
      | .hooks       = (($repo[0].hooks // {}) | prune_missing)
   ' > "$TMP" && [ -s "$TMP" ]; then
    mv "$TMP" "$LIVE_SETTINGS"
    print_success "settings.json merged (permissions/hooks from repo, local keys preserved)"
    print_warning "Restart running Claude Code sessions to pick up settings changes"
else
    rm -f "$TMP"
    print_error "Failed to merge settings.json (left unchanged)"
    return 1
fi
