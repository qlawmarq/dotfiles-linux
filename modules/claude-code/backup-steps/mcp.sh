# Backup: live user-scope MCP servers -> modules/claude/mcp-servers.json
#
# Runtime paths are reverse-substituted back to {{NPX}} / {{NODE_BIN}} /
# {{HOME}} so the template stays environment independent and can be
# shared with the Linux and Windows dotfiles repositories.

need_cmd jq "MCP backup" || return 0

LIVE_JSON="$HOME/.claude.json"
TEMPLATE="$SCRIPT_DIR/mcp-servers.json"

if [ ! -f "$LIVE_JSON" ]; then
    print_warning "$LIVE_JSON not found - skipping"
    return 0
fi

NPX=$(resolve_npx)
if [ -z "$NPX" ]; then
    print_warning "Could not resolve npx - skipping MCP backup"
    return 0
fi

COUNT=$(jq -r '(.mcpServers // {}) | length' "$LIVE_JSON")
if [ "$COUNT" = "0" ]; then
    print_warning "No user-scope MCP servers configured - leaving template unchanged"
    return 0
fi

# Warn before dropping credential-bearing fields (see the allowlist in
# unrender_mcp_json): this template is tracked and pushed.
SECRETS=$(jq -r '(.mcpServers // {}) | to_entries[]
                 | select((.value.env // {} | length) > 0 or (.value.headers // {} | length) > 0)
                 | .key' "$LIVE_JSON" 2>/dev/null)
if [ -n "$SECRETS" ]; then
    print_warning "Dropping env/headers (may hold credentials) from:"
    printf '  %s\n' $SECRETS
    print_info "  Re-add them by hand after apply, or keep them in the local scope."
fi

TMP=$(mktemp)
if unrender_mcp_json "$LIVE_JSON" "$NPX" > "$TMP" && [ -s "$TMP" ] && jq -e . "$TMP" >/dev/null; then
    mv "$TMP" "$TEMPLATE"
    chmod 644 "$TEMPLATE"   # mktemp creates 0600; this file is tracked
    print_success "$COUNT MCP server(s) backed up to mcp-servers.json"
    if jq -r '.mcpServers[].command' "$TEMPLATE" 2>/dev/null | grep -q '/node/[0-9]'; then
        print_warning "A version-pinned node path survived substitution - check mcp-servers.json"
    fi
else
    rm -f "$TMP"
    print_error "Failed to build the template (left unchanged)"
    return 1
fi
