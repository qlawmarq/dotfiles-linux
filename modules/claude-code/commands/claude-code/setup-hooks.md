---
description: Set up project-specific hooks for automated linting, formatting, and testing
category: automation
allowed-tools: Bash, Read, Write, Glob
argument-hint: [--type python|node|go|rust|auto]
---

# Claude Command: Setup Hooks

This command helps you set up project-specific hooks for automated code quality checks, formatting, and testing.

## Usage

Automatically detect project type and setup hooks:
```
/setup-hooks
```

Or specify the project type:
```
/setup-hooks --type node
/setup-hooks --type python
```

## What This Command Does

1. **Detects Project Type** by checking for:
   - `package.json` → Node.js/JavaScript/TypeScript
   - `pyproject.toml` or `setup.py` → Python
   - `go.mod` → Go
   - `Cargo.toml` → Rust
   - `Gemfile` → Ruby
   - `pom.xml` or `build.gradle` → Java

2. **Identifies Available Tools** in the project:
   - Linters: ESLint, Ruff, golangci-lint, clippy
   - Formatters: Prettier, Black, gofmt, rustfmt
   - Test runners: Jest, pytest, go test, cargo test

3. **Creates Hook Configuration** in `.claude/settings.json`:
   - `PostToolUse` hooks for auto-formatting after edits
   - `PreToolUse` hooks for validation before commits
   - `SessionEnd` hooks for final quality checks

4. **Generates Hook Scripts** in `.claude/hooks/`:
   - Language-specific formatting scripts
   - Test execution scripts
   - Security validation scripts

## Hook Types to Configure

### PostToolUse Hooks (Auto-run after file edits)
- **Auto-format**: Run formatter on edited files
- **Auto-lint**: Run linter with auto-fix
- **Incremental tests**: Run tests for changed files

### PreToolUse Hooks (Validate before actions)
- **Secret detection**: Block commits with hardcoded secrets
- **File protection**: Prevent editing of lock files, .env files
- **Lint validation**: Ensure code passes linting before commit

### SessionEnd Hooks (Cleanup and verification)
- **Full test suite**: Run complete test suite
- **Coverage report**: Generate test coverage report
- **Git status**: Show uncommitted changes

## Project-Specific Examples

### Node.js/TypeScript Project
```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/format-typescript.sh"
          }
        ]
      }
    ]
  }
}
```

Generated script will run:
- `prettier --write` for formatting
- `eslint --fix` for auto-fixable issues

### Python Project
```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/format-python.sh"
          }
        ]
      }
    ]
  }
}
```

Generated script will run:
- `ruff format` or `black` for formatting
- `ruff check --fix` for auto-fixable issues

## Configuration Location

The command will create:
- `.claude/settings.json` - Project-level hook configuration (shared with team)
- `.claude/hooks/` - Hook script files

These can be committed to version control for team sharing.

## Best Practices

- **Start minimal**: Begin with auto-formatting only, add more hooks as needed
- **Test hooks**: Verify hooks work correctly before committing to git
- **Document hooks**: Add comments in hook scripts explaining their purpose
- **Team alignment**: Discuss with team before adding hooks that affect workflow
- **Performance**: Keep hooks fast (<5 seconds) to avoid slowing down development

## Requirements

The command will check for required tools and warn if they're not installed:
- Node.js: `npm`, `npx`, `prettier`, `eslint`
- Python: `ruff`, `black`, `pytest`
- Go: `gofmt`, `golangci-lint`
- Rust: `rustfmt`, `clippy`

## Additional Guidance

$ARGUMENTS
