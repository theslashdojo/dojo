---
name: bash
description: Execute Bash commands, use builtins, perform variable expansion and globbing. Use when running shell commands, checking command availability, parsing command output, or building command strings with expansion.
---

# Bash

Execute commands in the Bourne Again SHell — the default command interpreter on most Linux systems.

## When to Use

- Running any command-line tool (git, node, python, curl, etc.)
- Checking if a command exists on the system
- Expanding variables, performing arithmetic, or matching file patterns
- Testing conditions (file existence, string comparison, numeric comparison)
- Capturing and processing command output

## Workflow

1. Determine the command to run and its arguments
2. Choose execution mode: foreground (blocking), background (`&`), or subshell (`$(...)`)
3. Handle variable expansion and quoting properly — always double-quote `"$variables"`
4. Check the exit code (`$?`) or use `&&`/`||` for conditional chaining
5. Parse output as needed (line-by-line, field extraction, pattern matching)

## Quick Reference

### Run and capture output
```bash
output=$(command arg1 arg2 2>&1)
exit_code=$?
```

### Check command exists
```bash
if command -v jq &>/dev/null; then
  echo "jq is available"
else
  echo "jq is not installed" >&2
fi
```

### Variable expansion with defaults
```bash
port="${PORT:-8080}"              # Default if unset
dir="${WORKDIR:?WORKDIR required}" # Error if unset
name="${FULL_NAME%% *}"           # Remove after first space
ext="${filename##*.}"             # Extract extension
```

### Conditional execution
```bash
# Chain — stop on failure
mkdir -p build && cd build && cmake ..

# Test file existence
[[ -f config.json ]] && echo "Config found"

# Pattern match
[[ "$url" =~ ^https?:// ]] && echo "Valid URL"
```

### Globbing
```bash
# Standard globs
ls *.ts                       # All .ts files
ls src/**/*.test.ts           # Recursive (needs shopt -s globstar)

# Brace expansion
mkdir -p src/{components,utils,hooks}
cp file.{js,bak}             # Copy file.js to file.bak
```

## Edge Cases

- Always double-quote variable expansions: `"$var"`, `"$@"`, `"$(cmd)"`
- `[[ ]]` is Bash-specific; `[ ]` is POSIX but splits words and expands globs
- Backticks `` `cmd` `` are legacy — use `$(cmd)` which nests cleanly
- `set -e` makes scripts exit on any unhandled failure — sometimes too aggressive for interactive use
- Empty globs: by default `*.xyz` returns the literal string if no match; use `shopt -s nullglob` to get empty results
- Word splitting on unquoted `$(cmd)` can cause bugs with filenames containing spaces
- `eval` is dangerous — avoid unless absolutely necessary; prefer arrays for dynamic commands
