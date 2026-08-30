# Step: report drift between the repository and the live configuration.
#
# Read-only. Exists because symlinked skills make the submodule
# writable from a Claude Code session: this surfaces that, plus broken
# links, unmanaged skills and MCP drift, with the repair command for each.

ISSUES=0

CLAUDE_SKILLS="$CLAUDE_DIR/skills"

# --- broken links (repository moved, renamed or a skill deleted upstream)
if [ -d "$CLAUDE_SKILLS" ]; then
    BROKEN=$(find "$CLAUDE_SKILLS" -maxdepth 1 -type l ! -exec test -e {} \; -print 2>/dev/null)
    if [ -n "$BROKEN" ]; then
        print_warning "Broken skill links:"
        printf %s "$BROKEN" | sed 's/^/  /'
        print_info "  Repair: sh modules/claude-code/apply.sh skills"
        ISSUES=$((ISSUES + 1))
    fi
fi

# --- skills edited in place through a symlink
if [ -d "$COMMON_DIR/.git" ] || [ -f "$COMMON_DIR/.git" ]; then
    DIRTY=$(git -C "$COMMON_DIR" status --porcelain -- skills claude/skills 2>/dev/null)
    if [ -n "$DIRTY" ]; then
        print_warning "Uncommitted skill changes inside the common submodule:"
        printf '%s\n' "$DIRTY" | sed 's/^/  /'
        print_info "  Keep them:    git -C modules/common add -A && git -C modules/common commit"
        print_info "  Discard them: git -C modules/common checkout -- skills claude/skills"
        ISSUES=$((ISSUES + 1))
    fi
fi

# --- real directories where a managed link is expected
if [ -d "$CLAUDE_SKILLS" ]; then
    for e in "$CLAUDE_SKILLS"/*; do
        [ -d "$e" ] || continue
        [ -L "$e" ] && continue
        n=$(basename "$e")
        if [ -d "$COMMON_DIR/skills/$n" ] || [ -d "$COMMON_DIR/claude/skills/$n" ]; then
            print_warning "Unmanaged copy shadowing a repository skill: $n"
            print_info "  Repair: sh modules/claude-code/apply.sh skills"
            ISSUES=$((ISSUES + 1))
        fi
    done
fi

# --- leftover migration backups
for d in "$CLAUDE_DIR"/skills.pre-symlink.*; do
    [ -d "$d" ] || continue
    print_info "Pre-symlink backup still present: $d"
    print_info "  Remove it once /skills lists every skill."
done

# --- MCP drift between the template and the user scope
if command_exists jq && [ -f "$SCRIPT_DIR/mcp-servers.json" ] && [ -f "$HOME/.claude.json" ]; then
    NPX=$(resolve_npx)
    if [ -n "$NPX" ]; then
        R=$(mktemp)
        if render_mcp_template "$SCRIPT_DIR/mcp-servers.json" "$NPX" > "$R" 2>/dev/null; then
            DRIFT=$(jq -r --slurpfile tpl "$R" '
                (.mcpServers // {}) as $live
                | (($tpl[0] | keys) - ($live | keys) | map("missing: " + .))
                + (($live | keys) - ($tpl[0] | keys) | map("extra:   " + .))
                + ([$tpl[0] | keys[] | select($live[.] != null and $live[.] != $tpl[0][.]) | "differs: " + .])
                | .[]' "$HOME/.claude.json" 2>/dev/null)
            if [ -n "$DRIFT" ]; then
                print_warning "MCP user scope differs from the template:"
                printf '%s\n' "$DRIFT" | sed 's/^/  /'
                print_info "  Apply template: sh modules/claude-code/apply.sh mcp"
                print_info "  Adopt live:     bash modules/claude-code/backup.sh mcp"
                ISSUES=$((ISSUES + 1))
            fi
        fi
        rm -f "$R"
    fi
fi

if [ "$ISSUES" -eq 0 ]; then
    print_success "No drift detected"
fi
