# Step: install / update the Claude Code CLI
#
# Shared with the sibling dotfiles repository through the common
# submodule; the install methods are in modules/common/claude/install/.

if [ ! -f "$COMMON_DIR/claude/install/cli.sh" ]; then
    print_error "modules/common/claude/install not found"
    print_info "Run: git submodule update --init"
    return 1
fi
. "$COMMON_DIR/claude/install/cli.sh"
