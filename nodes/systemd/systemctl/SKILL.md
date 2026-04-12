---
name: systemctl
description: Manage systemd unit state and enablement with systemctl. Use when you need to inspect a unit, start or stop it, restart after a deploy, enable it at boot, reload manager state, or work with the user manager.
license: MIT
metadata:
  author: dojo-community
  version: "1.0"
---

# systemctl

Use `systemctl` for unit lifecycle work after a unit file already exists.

## When to Use

- A service exists but needs `start`, `stop`, `restart`, or `reload`
- A freshly edited unit file needs `daemon-reload`
- You need to enable or disable a unit at boot/login
- You need machine-readable unit properties instead of human `status` output
- A user service should be managed with `systemctl --user`

## Workflow

1. Inspect the unit with `systemctl status` for humans or `systemctl show` for parsable state.
2. If you edited a unit file on disk, run `systemctl daemon-reload` before starting it.
3. Apply the lifecycle action: `start`, `stop`, `restart`, or `reload`.
4. Persist activation state with `enable`, `disable`, `mask`, or `unmask`.
5. Confirm the result with `is-active`, `is-enabled`, `show`, and `journalctl -u`.

## Quick Reference

```bash
systemctl status my-app.service
systemctl show my-app.service -p ActiveState -p SubState -p FragmentPath --value
systemctl daemon-reload
systemctl restart my-app.service
systemctl enable --now my-app.service
systemctl --user status my-agent.service
```

## Scripts

- `scripts/inspect-unit.sh` emits JSON-like state from `systemctl show`
- `scripts/manage-unit.sh` performs lifecycle and enablement actions, then reports resulting state

## Edge Cases

- `reload` reloads the service's own config, not the unit file. Use `daemon-reload` after editing unit files.
- `status` is optimized for humans. Use `show` if another program needs stable fields.
- `disable` removes install symlinks; `mask` makes manual starts impossible by linking the unit to `/dev/null`.
- `systemctl --user` talks to the per-user manager, not PID 1.
- `restart` is not identical to a full stop plus start when the service keeps resources like file descriptor stores.
