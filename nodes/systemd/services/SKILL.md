---
name: services
description: Create and install systemd service units for long-running daemons or one-shot jobs. Use when an app, script, worker, or agent process must become a managed Linux service with restart policy, environment, and boot/login activation.
license: MIT
metadata:
  author: dojo-community
  version: "1.0"
---

# services

Turn a command into a managed `.service` unit.

## When to Use

- A web server, worker, agent, or sync process should survive terminal exit
- A shell script must run as a controlled one-shot unit
- A process needs restart policy, working directory, environment, or service user
- You need a user service in `~/.config/systemd/user`
- You need to install a service cleanly before pairing it with a timer

## Workflow

1. Decide whether this is a system service or a user service.
2. Pick the correct service type: usually `Type=exec`, sometimes `oneshot`, `notify`, or `dbus`.
3. Define `ExecStart`, restart policy, environment, user, and working directory.
4. Verify the unit with `systemd-analyze verify`.
5. Install the file, run `systemctl daemon-reload`, then `enable` and/or `start`.
6. Confirm behavior with `systemctl status` and `journalctl -u`.

## Example

```bash
export SYSTEMD_SCOPE=system
export SYSTEMD_USE_SUDO=true
export SYSTEMD_SERVICE_NAME=my-app
export SYSTEMD_SERVICE_EXEC_START='/usr/bin/node /srv/my-app/server.js'
export SYSTEMD_SERVICE_WORKING_DIRECTORY=/srv/my-app
export SYSTEMD_SERVICE_USER=deploy
export SYSTEMD_SERVICE_RESTART=on-failure
export SYSTEMD_SERVICE_ENABLE=true
export SYSTEMD_SERVICE_START=true

./scripts/install-service.sh
```

## Scripts

- `scripts/install-service.sh` writes a service unit, verifies it, installs it, reloads the manager, and optionally enables or starts it

## Edge Cases

- `Type=exec` is usually better than `Type=simple` because setup failures surface to `systemctl start`.
- `Type=oneshot` is for jobs that exit; combine with `RemainAfterExit=yes` only when that semantic is actually needed.
- If the service uses an environment file, make sure the file exists on the target host before starting.
- If you install a system unit without root privileges, use `SYSTEMD_USE_SUDO=true` or switch to a user service.
- If the unit file changes do not take effect, `daemon-reload` was probably skipped or an override is shadowing the main file.
