---
description: Review a pull request and provide constructive feedback
category: version-control-git
allowed-tools: Bash, Read, Glob, WebFetch
argument-hint: [PR-number or PR-URL]
---

# Claude Command: Review Pull Request

This command helps you perform thorough code reviews and provide constructive feedback on pull requests.

## Usage

To review a pull request:

```
/pr-review 123
```

Or with a URL:

```
/pr-review https://github.com/owner/repo/pull/123
```

If no argument is provided, Claude will ask which PR you want to review.

## What This Command Does

1. Fetches the PR details using `gh pr view <number>`:
   - Title and description
   - Changed files
   - Commits included
   - Current status and checks
2. Reviews the diff using `gh pr diff <number>`
3. Analyzes the changes for:
   - Code quality and best practices
   - Potential bugs or issues
   - Performance considerations
   - Security concerns
   - Test coverage
   - Documentation completeness
4. Checks that the PR follows project conventions:
   - Coding style
   - Commit message format
   - PR description completeness
5. Prepares structured feedback with:
   - Overall assessment
   - Specific comments on code changes
   - Suggestions for improvements
   - Questions for clarification if needed
6. Optionally posts the review using `gh pr review <number>`

## Review Focus Areas

### Code Quality
- Readability and maintainability
- Adherence to project coding standards
- Proper error handling
- Appropriate abstractions

### Functionality
- Logic correctness
- Edge cases handled
- Backward compatibility
- Breaking changes documented

### Testing
- Test coverage adequate
- Test cases comprehensive
- Edge cases tested

### Documentation
- Code comments clear
- README updated if needed
- API changes documented

### Security
- No hardcoded secrets
- Input validation present
- SQL injection prevention
- XSS prevention

## Review Guidelines

- **Be constructive**: Focus on improving the code, not criticizing the author
- **Be specific**: Point to exact lines and explain your concerns
- **Suggest solutions**: Don't just point out problems, offer alternatives
- **Ask questions**: If something is unclear, ask for clarification
- **Acknowledge good work**: Highlight well-written code or clever solutions
- **Distinguish between**: Must-fix issues vs. suggestions for improvement

## Additional Guidance

$ARGUMENTS
