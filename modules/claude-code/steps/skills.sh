# Step: deploy skills
#
# ~/.claude/skills/<name> entries are symlinks into the common submodule.
# Claude Code follows symlinks for personal skills, so submodule updates
# take effect immediately and stale skills can be pruned by removing the
# link alone - no rm -rf of the skills directory.
#
# ~/.agents/skills (Codex CLI / Gemini CLI) is symlinked too. Both CLIs
# follow symlinked skill directories (verified 2026-09-28: Codex CLI
# 0.151.0, Gemini CLI 0.28.0; see modules/claude-code/AGENTS.md). Set
# AGENTS_SKILLS_MODE=copy to fall back to the previous copy deployment.

# Surface accidental edits early. Because the skills below are symlinks
# into the submodule, anything that writes to ~/.claude/skills/<name>/
# (Claude Code itself, skill-creator, a stray editor) modifies
# modules/common directly. That is the intended editing path - it is how
# a skill change gets committed - but it must never happen unnoticed.
if command_exists git && [ -e "$COMMON_DIR/.git" ]; then
    COMMON_DIRTY=$(git -C "$COMMON_DIR" status --porcelain -- skills claude/skills 2>/dev/null)
    if [ -n "$COMMON_DIRTY" ]; then
        print_warning "modules/common has uncommitted skill changes:"
        printf '%s\n' "$COMMON_DIRTY" | while IFS= read -r line; do
            print_warning "   $line"
        done
        print_info "Commit them in the submodule, or discard with:"
        print_info "  git -C modules/common checkout -- skills claude/skills"
    fi
fi

CLAUDE_SKILLS="$CLAUDE_DIR/skills"
AGENTS_SKILLS="$HOME/.agents/skills"
AGENTS_SKILLS_MODE="${AGENTS_SKILLS_MODE:-symlink}"

# Migration target must sit OUTSIDE the skills directory, or Claude Code
# would scan the backup and register duplicate skills.
MIGRATION_DIR="$CLAUDE_DIR/skills.pre-symlink.$(date +%Y%m%d%H%M%S)"

CROSS_AGENT="$COMMON_DIR/skills"
CLAUDE_ONLY="$COMMON_DIR/claude/skills"

# --- ~/.claude/skills : both sources, prune once at the end ---
DEPLOYED_NAMES=""
deploy_skills "$CROSS_AGENT" "$CLAUDE_SKILLS" symlink
deploy_skills "$CLAUDE_ONLY" "$CLAUDE_SKILLS" symlink
prune_links "$CLAUDE_SKILLS" "$COMMON_DIR" "$DEPLOYED_NAMES"
print_success "Claude Code skills linked into $CLAUDE_SKILLS"

# --- ~/.agents/skills : cross-agent skills only ---
if [ -d "$CROSS_AGENT" ]; then
    # Switching from copy to symlink: the copies listed in the manifest were
    # written by this step from the submodule, so delete them instead of
    # migrating them like foreign directories. Copies of skills that were
    # since removed from the submodule are covered too, as the manifest
    # names every copy the last copy-mode run left behind.
    AGENTS_MANIFEST="$AGENTS_SKILLS/.dotfiles-manifest"
    if [ "$AGENTS_SKILLS_MODE" = "symlink" ] && [ -f "$AGENTS_MANIFEST" ]; then
        while IFS= read -r _n; do
            [ -n "$_n" ] || continue
            if [ -d "$AGENTS_SKILLS/$_n" ] && [ ! -L "$AGENTS_SKILLS/$_n" ]; then
                rm -rf "${AGENTS_SKILLS:?}/$_n"
                print_info "Removed skill copy (now symlinked): $_n"
            fi
        done < "$AGENTS_MANIFEST"
        rm -f "$AGENTS_MANIFEST"
    fi

    DEPLOYED_NAMES=""
    deploy_skills "$CROSS_AGENT" "$AGENTS_SKILLS" "$AGENTS_SKILLS_MODE"
    if [ "$AGENTS_SKILLS_MODE" = "symlink" ]; then
        prune_links "$AGENTS_SKILLS" "$COMMON_DIR" "$DEPLOYED_NAMES"
    else
        prune_copies "$AGENTS_SKILLS" "$DEPLOYED_NAMES"
        # Copies do not inherit the git index mode, unlike symlinks.
        find "$AGENTS_SKILLS" -type f \( -name "*.sh" -o -name "*.py" \) \
            -exec chmod +x {} \; 2>/dev/null || true
    fi
    print_success "Cross-agent skills deployed to $AGENTS_SKILLS ($AGENTS_SKILLS_MODE)"
fi

if [ -d "$MIGRATION_DIR" ]; then
    print_warning "Pre-symlink skill directories preserved at:"
    print_warning "  $MIGRATION_DIR"
    print_info "Verify skills load (/skills in a session), then delete it."
fi

print_info "Note: skills are now edited in place inside modules/common."
print_info "      Check 'git -C modules/common status' before committing."
