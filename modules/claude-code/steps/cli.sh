# Step: install / update the Claude Code CLI
#
# npm global install under mise-managed node. The native installer
# (curl https://claude.ai/install.sh) is Anthropic's recommended path,
# but npm is kept here for parity with the Windows dotfiles repo, which
# installs the same way. The npm package ships the same native binary.

need_cmd node "Claude Code CLI install" || return 0
need_cmd npm "Claude Code CLI install" || return 0

if command_exists claude; then
    print_info "Currently installed: $(claude --version 2>/dev/null)"
fi

if ! confirm "Install/update @anthropic-ai/claude-code?"; then
    print_info "Skipped"
    return 0
fi

if npm install -g @anthropic-ai/claude-code@latest; then
    print_success "@anthropic-ai/claude-code installed ($(claude --version 2>/dev/null))"
else
    print_error "npm install failed"
    return 1
fi
