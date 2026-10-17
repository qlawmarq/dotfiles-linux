# Backup: live settings.json -> modules/common/claude/settings.json
#
# Allowlisted, not a verbatim copy: the live file carries machine-local
# UI state (per-model effort levels, ...) that must not enter a submodule
# shared with the Linux dotfiles repository. The notification keys are
# listed so a choice made in /config can be promoted on purpose.

need_cmd jq "settings backup" || return 0

LIVE_SETTINGS="$CLAUDE_DIR/settings.json"
REPO_SETTINGS="$COMMON_DIR/claude/settings.json"

if [ ! -f "$LIVE_SETTINGS" ]; then
    print_warning "$LIVE_SETTINGS not found - skipping"
    return 0
fi

if ! confirm "Back up Claude Code settings into the common submodule?"; then
    print_info "Skipped"
    return 0
fi

TMP=$(mktemp)
if jq '{"$schema": .["$schema"], permissions, model, tui, hooks, statusLine, env,
        cleanupPeriodDays, preferredNotifChannel,
        inputNeededNotifEnabled, agentPushNotifEnabled}
       | with_entries(select(.value != null))' "$LIVE_SETTINGS" > "$TMP" \
   && [ -s "$TMP" ] && jq -e . "$TMP" >/dev/null; then
    mv "$TMP" "$REPO_SETTINGS"
    chmod 644 "$REPO_SETTINGS"   # mktemp creates 0600; this file is tracked
    print_success "settings.json backed up to $REPO_SETTINGS"
else
    rm -f "$TMP"
    print_error "Failed to filter settings.json (left unchanged)"
    return 1
fi
