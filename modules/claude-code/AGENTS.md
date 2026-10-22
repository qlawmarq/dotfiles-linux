# Claude Code Integration

This repository provides user-level Claude Code configuration shared across all projects.
The `claude-code` module targets **Claude Code only**. It mirrors the `claude` module of
dotfiles-macos; keep the two in step when changing either.

### Step-based application

`modules/claude-code/apply.sh` is a dispatcher. Every step is independent, so skills can be
updated without reinstalling the CLI:

```bash
bash modules/claude-code/apply.sh            # interactive step menu (all steps when non-TTY)
bash modules/claude-code/apply.sh skills     # one step
bash modules/claude-code/apply.sh skills mcp # several (always run in canonical order)
bash modules/claude-code/apply.sh all
CLAUDE_APPLY_STEPS=skills bash modules/claude-code/apply.sh
```

`modules/claude-code/backup.sh` mirrors this with `mcp` and `settings` steps.

A step whose prerequisites are missing (no `jq`, no `claude`, no resolvable `npx`)
logs a warning and skips, rather than failing the module.

### CLI install methods

The `cli` step lives in `modules/common/claude/install/` and is shared with the sibling
dotfiles repository; `steps/cli.sh` only sources it. It reports how Claude Code is
installed (`Installed via: <method>` plus every `claude` on PATH with its version), asks
which method to use (selecting none skips), installs or updates with it, and offers to remove installs made with
other methods, since the official troubleshooting guide says to keep only one. Without a
terminal it only reports; `CLAUDE_INSTALL_METHOD=<id>` picks a method without asking.

- Methods: `native` (official installer, recommended), `brew`, `npm`, `apt`, `dnf`. A
  method is offered when its command exists (`curl`, `brew`, `npm`, `apt`, `dnf`) or when
  it is already installed; there is no OS check. All of them use the latest channel.
- Detection: native is `~/.local/bin/claude`, brew is `brew list --cask` for
  `claude-code@latest` or `claude-code`, npm is `npm ls -g @anthropic-ai/claude-code`
  (all three from the official guide); apt (`dpkg-query`) and dnf (`rpm -q`) have no
  official detection command, so those checks are ours. `installMethod` in
  `~/.claude.json` is not used: it can keep a stale value (`global` was seen on a brew
  install).
- npm installs into the active Node.js version. Upgrading node with mise leaves the
  package behind in the old version, where it is neither detected nor on PATH; this is
  what broke `claude` after a node upgrade.
- apt and dnf need sudo, and dnf asks to confirm the signing key, so run them from a
  terminal.
- To add a method, write `methods/<id>.sh` with the `cim_<id>_*` functions listed in
  `install/lib.sh` and append `<id>` to `CLAUDE_INSTALL_METHODS`. The code relies on this
  repository's `lib/utils.sh` (`print_*`, `confirm`, `command_exists`) and `lib/menu.sh`
  (`smart_select_items --single`, the module menu in single-choice mode).

### Skills are symlinked

`~/.claude/skills/<name>` are symlinks into `modules/common`, which Claude Code follows.
Consequences:

- Submodule updates take effect immediately; no re-run needed to pick up edits.
- **Claude Code edits skills in place inside the submodule.** This is detectable and
  reversible: `bash modules/claude-code/apply.sh doctor` reports it, `git -C modules/common
  checkout -- skills claude/skills` discards it, `git -C modules/common commit` keeps it.
- Stale skills are pruned by deleting the link. Pruning only touches symlinks whose
  target is inside `modules/common`, so hand-written skills in `~/.claude/skills/` survive.
- On first run, pre-existing real directories are moved to
  `~/.claude/skills.pre-symlink.<timestamp>/` rather than deleted.
- A moved or renamed repository leaves dangling links: the skills disappear from `/skills`,
  `doctor` lists them, and re-running the `skills` step repairs them.
- `~/.agents/skills/` (Codex CLI / Gemini CLI) is symlinked the same way. Verified on
  2026-09-28 with Codex CLI 0.151.0 (`codex debug prompt-input` lists a symlinked
  `.agents/skills/<name>` in the model-visible prompt; its loader sets
  `DirectorySymlinkPolicy::Follow` for user and repo scopes) and Gemini CLI 0.28.0
  (`gemini skills list --all` resolves a symlinked entry; `gemini skills link` itself
  creates symlinks). Set `AGENTS_SKILLS_MODE=copy` to fall back to copies; the first
  symlink run deletes the copies recorded in `~/.agents/skills/.dotfiles-manifest`
  instead of migrating them, because they are exact copies of the submodule.
- The skills are also installable elsewhere with `npx skills add qlawmarq/dotfiles-common`
  (see `modules/common/README.md`). Never run that on a machine managed by this
  repository: the CLI replaces same-named entries in `~/.claude/skills` and
  `~/.agents/skills` without asking.

### settings.json merge semantics

`~/.claude/settings.json` is merged, not overwritten, so UI-written keys survive:

- `permissions` and `hooks` are **repository-owned** and replaced wholesale, so a key
  removed from the repository is also removed from the live file.
- Every other key is deep-merged, preserving local values such as `modelSettings`.
- The previous file is snapshotted to `~/.claude/.dotfiles-backups/` first.
- `backup.sh settings` writes back an allowlist (`$schema`, `permissions`, `model`,
  `tui`, `hooks`, `statusLine`, `env`, `cleanupPeriodDays`, and the notification keys)
  so machine-local UI state never enters the submodule.

`tui` is pinned to `fullscreen`. The default `classic` renderer draws inline into the
terminal scrollback without the alternate screen, so once a frame grows taller than the
pane, or the pane width changes and the terminal reflows, it can no longer erase what has
scrolled off and re-emits it: duplicated bands of lines and tables rendered half at the
old width and half at the new one. Measured on macOS under tmux at 120x20 with a width
change: `classic` left 7 distinct lines repeated up to 14 times in the scrollback,
`fullscreen` left none (`#{alternate_on}` 0 vs 1). The cost is that Claude Code owns the
screen, so tmux copy-mode no longer scrolls its output — the `alternate_on` branch of the
WheelUp binding in `tmux/.tmux.conf` forwards the wheel to Claude Code instead. Revert
per machine with `/tui default`.

Bash permission rules match with `*` wildcards. A trailing ` *` and a trailing `:*` are
equivalent, so `Bash(git status *)` and `Bash(git status:*)` both match `git status` and
`git status --short`; the permission dialog writes the space form. `:*` is recognized
only at the end of a pattern. Put the `*` after the subcommand: `Bash(git *)` allows
every git command.

### Notifications

Notifications use the built-in `preferredNotifChannel` setting, not hooks. It is pinned to
`terminal_bell` because the default `auto` sends a desktop notification only in iTerm2,
Ghostty and Kitty, and inside tmux it sends nothing at all. Measured with a permission
prompt left waiting (standalone BEL bytes in the pane output): `TERM_PROGRAM=tmux` gave
0 with `auto` and 1 with `terminal_bell`; `Apple_Terminal` gave 1 with either, and
`notifications_disabled` gave 0 (measured on macOS; the tmux case does not depend on the
host terminal). Under WSL, what the bell does is decided by the Windows Terminal profile
setting `bellStyle` (`audible` by default; `taskbar`, `window` or `all` add a visual cue),
which lives on the Windows side and is not managed here.

Mobile push (`inputNeededNotifEnabled`, `agentPushNotifEnabled`) is explicitly off.

### Subagent model

`CLAUDE_CODE_SUBAGENT_MODEL=opus` with `CLAUDE_CODE_SUBAGENT_MODEL_FORCE=1` keeps
subagents, teammates and workflow agents on Opus when the main session runs Fable. Forks
and skills that run in a subagent with `model: inherit` still use the main model.

**Customization:** user-level overrides go in `~/.claude/settings.json`; per-project
rules in `.claude/settings.local.json`.

### MCP servers

MCP is configured for the Claude Code **user scope** via `claude mcp add-json`, not by
editing `~/.claude.json` directly (that file is live client state the CLI writes
continuously).

`modules/claude-code/mcp-servers.json` uses `{{NPX}}`, `{{NODE_BIN}}` and `{{HOME}}`
placeholders, resolved at apply time by `resolve_npx` (`mise which npx`, falling back to
`command -v npx`). This keeps the template free of node versions and lets the macOS and
Windows dotfiles repositories share the same file by swapping the resolver.

`backup.sh mcp` reverses the substitution, normalizing version-pinned mise paths back to
placeholders. Servers present in the user scope but absent from the template are reported,
never deleted automatically — promote them with `bash modules/claude-code/backup.sh mcp`.
