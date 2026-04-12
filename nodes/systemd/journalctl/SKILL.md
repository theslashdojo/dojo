---
name: journalctl
description: Query and maintain logs stored in journald with journalctl. Use when you need to inspect unit logs, compare current and previous boots, filter by priority or regex, export structured log output, or rotate and vacuum the journal.
license: MIT
metadata:
  author: dojo-community
  version: "1.0"
---

# journalctl

Use `journalctl` when the next question is "what did the unit actually log?"

## When to Use

- A systemd service failed and you need the exact error output
- A restart succeeded but behavior still looks wrong
- You need logs from the previous boot with `-b -1`
- You need structured output with `-o json`
- Journal storage needs `--disk-usage`, `--rotate`, or `--vacuum-*`

## Workflow

1. Start with a unit filter: `journalctl -u my-app.service -n 100 --no-pager`.
2. Narrow by boot, time window, priority, identifier, or grep pattern.
3. Switch output modes when needed: `short-iso`, `with-unit`, `json`, or `export`.
4. Use `-f` only when you need a live tail.
5. If logs are missing, check whether you are querying the right manager scope and whether you have permission to read the journal.

## Examples

```bash
journalctl -u my-app.service -n 200 --no-pager
journalctl -u my-app.service -b -1 -p err..alert --no-pager
journalctl -u my-app.service --since '2026-04-11 12:00:00' -o json --no-pager
journalctl --disk-usage
journalctl --vacuum-time=14d
```

## Scripts

- `scripts/journal-ops.sh query` builds filtered journal queries
- `scripts/journal-ops.sh verify|rotate|flush|sync|vacuum-*` handles maintenance tasks

## Edge Cases

- By default, unprivileged users usually cannot read the full system journal.
- `journalctl -f` is streaming and will not exit on its own.
- `Persistent=true` on a timer does not create journal retention; journal retention is managed separately.
- `-x` adds catalog explanations, but that extra text should usually be omitted from bug report attachments.
