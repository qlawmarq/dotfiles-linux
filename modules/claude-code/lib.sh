#!/bin/bash
# ============================================================
# Shared helpers for the claude module (apply + backup steps)
#
# Sourced by apply.sh / backup.sh after lib/utils.sh.
# Keep POSIX-sh compatible: the top-level driver runs modules
# with `sh`, which is bash 3.2 in POSIX mode on macOS.
# ============================================================

# ------------------------------------------------------------
# Dependency guard
# Usage: need_cmd "jq" "settings merge" || return 0
# Prints a skip notice and returns 1 when the command is absent.
# Callers SKIP (return 0) rather than fail, so a missing optional
# dependency never marks the whole module as failed.
# ------------------------------------------------------------
need_cmd() {
    if command_exists "$1"; then
        return 0
    fi
    print_warning "'$1' not found - skipping $2"
    return 1
}

# ------------------------------------------------------------
# Resolve the npx executable for MCP server templates.
#
# Prefers mise so the path follows the active node install.
# NOTE: `mise which npx` returns the *alias* dir (e.g. .../node/lts/bin)
# only while node is pinned to an alias. If ~/.config/mise/config.toml
# pins an exact version (node = "24.12.0"), this starts returning a
# version-pinned path again. The backup-side reverse substitution
# normalizes those, but the applied config would be pinned.
# ------------------------------------------------------------
resolve_npx() {
    local _npx
    _npx=""
    if command_exists mise; then
        _npx=$(mise which npx 2>/dev/null)
    fi
    if [ -z "$_npx" ] || [ ! -x "$_npx" ]; then
        _npx=$(command -v npx 2>/dev/null)
    fi
    if [ -z "$_npx" ] || [ ! -x "$_npx" ]; then
        return 1
    fi
    printf '%s\n' "$_npx"
}

# ------------------------------------------------------------
# Template placeholders: {{NPX}} {{NODE_BIN}} {{HOME}}
#
# render_mcp_template TEMPLATE_FILE NPX
#   -> stdout: the .mcpServers object with placeholders resolved
# ------------------------------------------------------------
render_mcp_template() {
    local _tpl _npx _nodebin
    _tpl="$1"
    _npx="$2"
    _nodebin=$(dirname "$_npx")

    jq --arg npx "$_npx" --arg nodebin "$_nodebin" --arg home "$HOME" '
      def lrep($a; $b): if ($a | length) == 0 then . else (split($a) | join($b)) end;
      def walkstr:
          if   type == "string" then lrep("{{NPX}}"; $npx)
                                   | lrep("{{NODE_BIN}}"; $nodebin)
                                   | lrep("{{HOME}}"; $home)
          elif type == "array"  then map(walkstr)
          elif type == "object" then map_values(walkstr)
          else . end;
      (.mcpServers // {}) | walkstr
    ' "$_tpl"
}

# ------------------------------------------------------------
# unrender_mcp_json LIVE_JSON NPX
#   -> stdout: { "mcpServers": ... } with runtime paths replaced
#              by placeholders.
#
# Ordering matters. The live config may hold a version-pinned mise
# path (.../node/24.12.0/bin) while the resolver yields an alias path
# (.../node/lts/bin), so a literal reversal alone would miss it and
# commit a pinned path. Passes:
#   1. exact $npx match
#   2. regex over any pinned mise node bin dir
#   3. collapse the intermediate token
#   4. $HOME last - doing it earlier breaks the pass-2 regex
# ------------------------------------------------------------
unrender_mcp_json() {
    local _live _npx _nodebin
    _live="$1"
    _npx="$2"
    _nodebin=$(dirname "$_npx")

    jq --arg npx "$_npx" --arg nodebin "$_nodebin" --arg home "$HOME" '
      def lrep($a; $b): if ($a | length) == 0 then . else (split($a) | join($b)) end;
      def norm:
          lrep($npx; "{{NPX}}")
        | gsub("/\\.local/share/mise/installs/node/[^/]+/bin"; "{{NODE_BIN_REL}}")
        | lrep("{{NODE_BIN_REL}}/npx"; "{{NPX_REL}}")
        | lrep($home; "{{HOME}}")
        | lrep("{{HOME}}{{NPX_REL}}"; "{{NPX}}")
        | lrep("{{HOME}}{{NODE_BIN_REL}}"; "{{NODE_BIN}}")
        | lrep($nodebin; "{{NODE_BIN}}");
      def walkstr:
          if   type == "string" then norm
          elif type == "array"  then map(walkstr)
          elif type == "object" then map_values(walkstr)
          else . end;
      { mcpServers: ((.mcpServers // {})
          | map_values({command, args, type, url, transport}
                       | with_entries(select(.value != null)))
          | walkstr) }
    ' "$_live"
}

# ------------------------------------------------------------
# link_dir SRC DEST
#
# Idempotent directory symlink.
#   - existing correct link  -> no-op (no write, mtime preserved)
#   - existing wrong link    -> replaced
#   - existing real dir      -> moved to $MIGRATION_DIR, never deleted
#
# `ln -s SRC DEST` on an existing symlink-to-dir would create
# DEST/$(basename SRC), so the old link must be removed first.
# MIGRATION_DIR must be set by the caller and must live OUTSIDE the
# skills directory, or Claude Code scans the backup as duplicate skills.
# ------------------------------------------------------------
link_dir() {
    local _src _dest
    _src="$1"
    _dest="$2"

    if [ -L "$_dest" ]; then
        if [ "$(readlink "$_dest")" = "$_src" ]; then
            return 0
        fi
        rm -f "$_dest"
    elif [ -d "$_dest" ]; then
        mkdir -p "$MIGRATION_DIR"
        mv "$_dest" "$MIGRATION_DIR/"
        print_warning "Migrated real directory $(basename "$_dest") -> $MIGRATION_DIR/"
    elif [ -e "$_dest" ]; then
        rm -f "$_dest"
    fi

    ln -s "$_src" "$_dest"
}

# ------------------------------------------------------------
# deploy_skills SRC_DIR DEST_DIR [symlink|copy]
#
# A skill is any direct subdirectory containing SKILL.md.
# Appends the deployed names to DEPLOYED_NAMES so the caller can
# prune once at the end (two source dirs feed ~/.claude/skills).
# ------------------------------------------------------------
deploy_skills() {
    local _src _dest _mode _sd _n
    _src="$1"
    _dest="$2"
    _mode="${3:-symlink}"

    [ -d "$_src" ] || return 0
    mkdir -p "$_dest"

    for _sd in "$_src"/*; do
        [ -d "$_sd" ] || continue
        [ -f "$_sd/SKILL.md" ] || continue
        _n=$(basename "$_sd")
        DEPLOYED_NAMES="$DEPLOYED_NAMES $_n"
        if [ "$_mode" = "symlink" ]; then
            link_dir "$_sd" "$_dest/$_n"
        else
            rm -rf "${_dest:?}/$_n"
            cp -R "$_sd" "$_dest/"
        fi
    done
}

# ------------------------------------------------------------
# prune_links DEST_DIR OWNED_PREFIX "name1 name2 ..."
#
# Removes only entries that are (a) symlinks, (b) pointing inside
# OWNED_PREFIX, and (c) absent from the keep list. Hand-written skill
# directories and links pointing elsewhere are never touched, and
# `rm -f` on a symlink never recurses into the target.
# Also catches dangling links left behind by a moved repository.
# ------------------------------------------------------------
prune_links() {
    local _dest _own _keep _e _t _n
    _dest="$1"
    _own="$2"
    _keep=" $3 "

    [ -d "$_dest" ] || return 0

    for _e in "$_dest"/*; do
        [ -L "$_e" ] || continue
        _t=$(readlink "$_e")
        case "$_t" in
            "$_own"/*) ;;
            *) continue ;;
        esac
        _n=$(basename "$_e")
        case "$_keep" in
            *" $_n "*) continue ;;
        esac
        rm -f "$_e"
        print_info "Pruned stale skill link: $_n"
    done
}

# ------------------------------------------------------------
# prune_copies DEST_DIR "name1 name2 ..."
#
# Copy-mode counterpart of prune_links. readlink cannot establish
# ownership for plain directories, so ownership is tracked in a
# manifest. Only names recorded by a previous run are ever removed.
# The leading dot keeps the manifest from being scanned as a skill.
# ------------------------------------------------------------
prune_copies() {
    local _dest _keep _manifest _n
    _dest="$1"
    _keep=" $2 "
    _manifest="$_dest/.dotfiles-manifest"

    if [ -f "$_manifest" ]; then
        while IFS= read -r _n; do
            [ -n "$_n" ] || continue
            case "$_keep" in
                *" $_n "*) continue ;;
            esac
            if [ -d "$_dest/$_n" ]; then
                rm -rf "${_dest:?}/$_n"
                print_info "Pruned stale skill copy: $_n"
            fi
        done < "$_manifest"
    fi

    : > "$_manifest"
    for _n in $2; do
        printf '%s\n' "$_n" >> "$_manifest"
    done
}
