---
name: analyze
description: Verify unit files, validate timer expressions, inspect load paths, and debug manager behavior with systemd-analyze. Use when a unit should be checked before activation or when boot ordering, security posture, or schedule syntax needs investigation.
license: MIT
metadata:
  author: dojo-community
  version: "1.0"
---

# analyze

Use `systemd-analyze` before enabling risky unit changes and when the manager behaves in unexpected ways.

## When to Use

- A new or edited unit file should be validated with `verify`
- A timer calendar expression needs normalization or sanity checking
- You need the real unit load paths for system or user managers
- A service hardening review is needed with `security`
- Boot or dependency issues need `blame`, `critical-chain`, or `dot`

## Workflow

1. Run `systemd-analyze verify` on unit files before `daemon-reload`.
2. Use `calendar`, `timestamp`, or `timespan` to validate schedule and time syntax.
3. Use `unit-paths` to understand where units and overrides can load from.
4. Use `security` for a quick hardening review of an installed unit.
5. Use `blame` or `critical-chain` when startup ordering or boot latency is the problem.

## Examples

```bash
systemd-analyze verify /etc/systemd/system/my-app.service
systemd-analyze calendar 'Mon..Fri 03:00'
systemd-analyze unit-paths
systemd-analyze security my-app.service
systemd-analyze critical-chain my-app.service
```

## Scripts

- `scripts/analyze-systemd.sh` wraps the most useful `systemd-analyze` verbs for validation and debugging

## Edge Cases

- `blame` does not show meaningful startup time for `Type=simple` units because systemd treats them as started immediately.
- `unit-paths` prints compiled search paths; `systemctl show -p UnitPath --value` shows what the running manager actually uses.
- `verify` catches syntax and many dependency issues, but it does not replace runtime log inspection.
