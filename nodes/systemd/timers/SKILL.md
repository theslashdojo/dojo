---
name: timers
description: Create and enable systemd timer units for delayed or recurring work. Use when a task should run on a schedule, after boot, or relative to another unit, especially when you want a cron replacement that integrates with service units and journald.
license: MIT
metadata:
  author: dojo-community
  version: "1.0"
---

# timers

Use timers to schedule work through systemd instead of separate cron machinery.

## When to Use

- A service should run on a calendar schedule such as nightly or weekly
- A job should run after boot or after another unit last completed
- Missed runs should catch up after downtime with `Persistent=true`
- A fleet needs randomized delay to avoid a thundering herd
- You want logs and state for scheduled work in the same systemd toolchain

## Workflow

1. Create or identify the target service unit the timer activates.
2. Pick the trigger style: `OnCalendar=` for wall-clock schedules or `OnBootSec=` / `OnUnitActiveSec=` for monotonic schedules.
3. Validate calendar expressions with `systemd-analyze calendar`.
4. Install the timer, reload the manager, enable it, and usually start it once.
5. Confirm with `systemctl list-timers --all` and inspect the paired service's journal.

## Example

```bash
export SYSTEMD_SCOPE=system
export SYSTEMD_USE_SUDO=true
export SYSTEMD_TIMER_NAME=my-backup
export SYSTEMD_TIMER_UNIT=my-backup.service
export SYSTEMD_TIMER_ON_CALENDAR='*-*-* 03:00:00'
export SYSTEMD_TIMER_PERSISTENT=true
export SYSTEMD_TIMER_ENABLE=true
export SYSTEMD_TIMER_START=true

./scripts/install-timer.sh
```

## Scripts

- `scripts/install-timer.sh` writes a timer unit, verifies it, installs it, reloads the manager, and optionally enables or starts it

## Edge Cases

- A timer does not spawn a second instance if the activated unit is already active.
- `Persistent=true` only helps `OnCalendar=` timers catch up after missed elapsed times.
- Services with `RemainAfterExit=yes` are usually a poor match for repetitive timers because they remain active.
- `AccuracySec=` coalesces wakeups for efficiency; `RandomizedDelaySec=` spreads load to reduce simultaneous runs.
