---
name: files
description: Create, read, copy, move, delete, find, and manage permissions of files and directories using shell commands. Use when performing any filesystem operation from the command line.
---

# Files

Manage files and directories through shell commands — the most common operation for any agent.

## When to Use

- Creating files or directory structures
- Reading file contents or metadata
- Copying, moving, or renaming files
- Deleting files or directories
- Searching for files by name, type, size, or modification time
- Changing permissions or ownership
- Checking disk usage
- Creating temporary files for intermediate work

## Workflow

1. Identify the file operation needed (create, read, find, copy, move, delete, etc.)
2. Verify the target exists or the destination is writable before modifying
3. Use appropriate flags for safety (`-i` for interactive, `-n` for no-clobber, `-p` for preserve)
4. For destructive operations, list targets first before deleting
5. Clean up temporary files using `trap ... EXIT`

## Quick Reference

### Create
```bash
touch file.txt                    # Empty file
mkdir -p path/to/dir              # Directory with parents
mktemp                            # Temp file in /tmp
cat > file.txt <<'EOF'            # Multi-line content
content here
EOF
```

### Read
```bash
cat file.txt                      # Entire file
head -n 20 file.txt               # First 20 lines
tail -n 20 file.txt               # Last 20 lines
tail -f log.txt                   # Follow live updates
wc -l file.txt                    # Count lines
```

### Copy / Move / Delete
```bash
cp -r src/ dest/                  # Recursive copy
cp -a src/ dest/                  # Archive (preserves everything)
mv old.txt new.txt                # Rename
mv file.txt dir/                  # Move
rm file.txt                       # Delete file
rm -rf dir/                       # Delete directory tree
```

### Find
```bash
find . -name '*.py' -type f                    # By name
find . -mtime -1 -type f                       # Modified today
find . -size +10M -type f                      # Over 10MB
find . -name '*.tmp' -delete                   # Find and delete
find . -path ./node_modules -prune -o -name '*.ts' -print  # Exclude dir
```

### Permissions
```bash
chmod +x script.sh                # Add execute
chmod 644 file.txt                # rw-r--r--
chmod 755 dir/                    # rwxr-xr-x
chown user:group file.txt         # Change owner
```

### Inspect
```bash
ls -lah                           # Detailed listing
stat file.txt                     # Full metadata
file document.pdf                 # Detect type
du -sh dir/                       # Directory size
df -h                             # Disk space
```

## Safety Patterns

```bash
# Always verify before destructive operations
[[ -f "$file" ]] && rm "$file"

# Backup before overwriting
cp important.conf important.conf.bak

# Atomic write via temp file
echo "$data" > output.tmp && mv output.tmp output.txt

# Temp file with cleanup
tmp=$(mktemp)
trap "rm -f '$tmp'" EXIT
```

## Edge Cases

- `rm -rf /` requires `--no-preserve-root` on modern systems (safety guard)
- `cp` without `-r` silently skips directories
- `mv` across filesystems does copy+delete (not atomic)
- `find` without `-maxdepth` descends into every subdirectory
- Hidden files (dotfiles) are not matched by `*` glob — use `.*` or `shopt -s dotglob`
- `ln -s` creates symlinks relative to the link location, not the current directory
- `stat` output format differs between GNU (Linux) and BSD (macOS) — use `stat -c` vs `stat -f`
- `mktemp` patterns must end with at least 3 `X` characters
