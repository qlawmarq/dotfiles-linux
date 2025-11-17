#!/bin/bash

# ============================================================
# Claude Code PreToolUse Hook: Auto-approve safe commands
# ============================================================
#
# This hook automatically approves safe bash commands to reduce
# permission prompts while maintaining security.
#
# Exit codes:
#   0 = Auto-approve (no permission prompt)
#   1 = Ask user for permission (default behavior)
#
# Strategy:
#   - Only auto-approve commands that are DEFINITELY safe
#   - For shell operators (&&, ||, ;, |), ALL parts must be safe
#   - Unknown commands → ask user (fail-safe approach)
#   - Dangerous command blocking is handled by permissions.deny
#
# ============================================================

# Read JSON input from stdin
input=$(cat)

# Extract tool name and command
tool_name=$(echo "$input" | jq -r '.tool_name // empty')
command=$(echo "$input" | jq -r '.tool_input.command // empty')

# Only process Bash tool calls
if [ "$tool_name" != "Bash" ] || [ -z "$command" ]; then
  exit 1
fi

# ============================================================
# Safe command prefixes (whitelist approach)
# ============================================================
# These commands are read-only, idempotent, or have minimal side effects

SAFE_COMMANDS=(
  # Read-only file operations
  "cat" "head" "tail" "less" "more"
  "ls" "pwd" "file" "stat" "du" "df" "tree"

  # Search and text processing (read-only)
  "find" "grep" "awk" "sed -n" "jq" "diff" "wc"

  # Environment inspection
  "echo" "which" "type" "env" "printenv" "whoami" "hostname"
  "uname" "date" "uptime"

  # Version checks
  "node -v" "node --version" "npm -v" "npm --version"
  "pnpm --version" "yarn --version" "bun --version"
  "python --version" "python3 --version" "pip --version"
  "go version" "cargo --version" "rustc --version"

  # Git read operations
  "git status" "git diff" "git log" "git show" "git branch"
  "git remote" "git tag" "git describe" "git blame" "git reflog"
  "git config --get" "git config --list" "git rev-parse"
  "git check-ignore" "git ls-files" "git ls-tree" "git rev-list"
  "git count-objects" "git fsck" "git show-ref"

  # Git operations that modify local state but are generally safe
  "git fetch" "git add" "git commit"

  # Package manager safe operations
  "pnpm test" "pnpm run test" "pnpm lint" "pnpm dev"
  "pnpm build" "pnpm run build" "pnpm dev" "pnpm type-check"
  "pnpm check" "pnpm run check" "pnpm format" "pnpm list"
  "pnpm --filter" "pnpm vitest"
  "npm test" "npm run"
  "yarn test" "yarn lint" "yarn build" "yarn dev"
  "bun test" "bun run"

  # JavaScript/TypeScript tooling
  "eslint" "prettier" "tsc --noEmit" "vite"
  "npx playwright" "npx tsc --noEmit"

  # Python tooling
  "pytest" "python -m" "python3 -m pytest"
  "ruff check" "ruff format" "black --check" "mypy"
  "uv run"

  # Build tools
  "make build" "make test" "make clean"
  "cargo build" "cargo test" "cargo check" "cargo clippy"
  "go build" "go test" "go fmt" "go vet"

  # Runtime managers
  "mise current" "mise list" "mise ls" "mise where"
  "asdf current" "asdf list" "asdf where"

  # Utility wrappers
  "time" "timeout"

  # Path utilities
  "basename" "dirname" "realpath" "readlink"

  # Directory navigation (safe)
  "cd"
)

# ============================================================
# Check if a single command is safe
# ============================================================
is_safe_command() {
  local cmd="$1"

  # Trim leading/trailing whitespace
  cmd=$(echo "$cmd" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

  # Empty command is not safe
  [ -z "$cmd" ] && return 1

  # Check against whitelist
  for pattern in "${SAFE_COMMANDS[@]}"; do
    # Match if:
    # 1. Exact match (e.g., "ls" matches pattern "ls")
    # 2. Starts with pattern + space (e.g., "ls -la" matches pattern "ls")
    if [[ "$cmd" == "$pattern" ]] || [[ "$cmd" == "$pattern "* ]]; then
      return 0  # Safe
    fi
  done

  return 1  # Not in whitelist
}

# ============================================================
# Split command by shell operators and check all parts
# ============================================================
# For commands like "cd .. && pnpm build", we need to ensure
# ALL parts are safe before auto-approving

# Split by &&, ||, ;, and | (common shell operators)
# Note: This is a simple split, not a full shell parser
IFS_BACKUP="$IFS"
IFS=$'\n'

# Replace shell operators with newlines for splitting
parts=$(echo "$command" | sed 's/[;&|]\{1,2\}/\n/g')

all_safe=true
for part in $parts; do
  if ! is_safe_command "$part"; then
    all_safe=false
    break
  fi
done

IFS="$IFS_BACKUP"

# ============================================================
# Return result
# ============================================================

if [ "$all_safe" = true ]; then
  # Return JSON to bypass permission system
  jq -n '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "allow"
    }
  }'
  exit 0  # Auto-approve - all parts are safe
else
  # Don't make a decision - let normal permission check handle it
  exit 0  # Defer to normal permission check
fi
