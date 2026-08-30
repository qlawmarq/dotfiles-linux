# Step: apply MCP servers to the Claude Code user scope
#
# Writes through `claude mcp add-json` rather than editing ~/.claude.json
# directly: that file is ~150KB of live client state (project history,
# onboarding flags, caches) that Claude Code writes continuously, so a
# shell read-modify-write risks losing updates.

need_cmd jq "MCP configuration" || return 0

if ! command_exists claude; then
    print_warning "'claude' not found - skipping MCP configuration"
    return 0
fi

TEMPLATE="$SCRIPT_DIR/mcp-servers.json"
if [ ! -f "$TEMPLATE" ]; then
    print_warning "No mcp-servers.json template - skipping"
    return 0
fi

NPX=$(resolve_npx)
if [ -z "$NPX" ]; then
    print_warning "Could not resolve npx (tried mise, PATH) - skipping MCP configuration"
    return 0
fi
print_info "Resolved npx: $NPX"

RENDERED=$(mktemp)
if ! render_mcp_template "$TEMPLATE" "$NPX" > "$RENDERED" || [ ! -s "$RENDERED" ]; then
    rm -f "$RENDERED"
    print_error "Failed to render $TEMPLATE"
    return 1
fi

AVAILABLE=$(jq -r 'keys[]' "$RENDERED")

if [ -t 0 ]; then
    smart_select_items "Select MCP servers to configure" $AVAILABLE
    SERVERS="$SELECTED_ITEMS"
    if [ -z "$SERVERS" ]; then
        # Deselecting everything means "skip", matching the step dispatcher.
        rm -f "$RENDERED"
        print_warning "No MCP servers selected - skipping"
        return 0
    fi
else
    SERVERS="$AVAILABLE"
fi

RC=0
for name in $SERVERS; do
    json=$(jq -c --arg n "$name" '.[$n]' "$RENDERED")
    if [ -z "$json" ] || [ "$json" = "null" ]; then
        print_warning "Not in template: $name"
        continue
    fi
    # Validate BEFORE removing, so a bad payload cannot leave a gap
    if ! printf '%s' "$json" | jq -e '.command or .url' >/dev/null 2>&1; then
        print_error "Invalid server definition: $name"
        RC=1
        continue
    fi
    # Capture the current definition so a failed add can be rolled back:
    # remove-then-add would otherwise leave the server simply gone.
    prev=$(jq -c --arg n "$name" '(.mcpServers // {})[$n] // empty' "$HOME/.claude.json" 2>/dev/null)
    claude mcp remove "$name" -s user >/dev/null 2>&1 || true
    if claude mcp add-json "$name" "$json" -s user >/dev/null 2>&1; then
        print_success "MCP: $name"
    else
        print_error "MCP: failed to add $name"
        if [ -n "$prev" ] && claude mcp add-json "$name" "$prev" -s user >/dev/null 2>&1; then
            print_warning "MCP: restored the previous definition of $name"
        fi
        RC=1
    fi
done

# Report servers that exist live but not in the template. Never remove
# them automatically - promote them with `bash backup.sh mcp` instead.
LIVE_JSON="$HOME/.claude.json"
if [ -f "$LIVE_JSON" ]; then
    EXTRA=$(jq -r --slurpfile tpl "$RENDERED" \
        '(.mcpServers // {}) | keys[] | select(. as $k | ($tpl[0] | has($k)) | not)' \
        "$LIVE_JSON" 2>/dev/null)
    for name in $EXTRA; do
        print_warning "User-scope server not in template: $name"
        if [ -t 0 ] && confirm "  Remove '$name' from the user scope?"; then
            claude mcp remove "$name" -s user >/dev/null 2>&1 \
                && print_success "Removed: $name"
        else
            print_info "  Kept. Run 'bash backup.sh mcp' to add it to the template."
        fi
    done
fi

rm -f "$RENDERED"
return $RC
