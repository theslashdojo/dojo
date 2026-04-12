---
name: connect
description: >
  Open SSH sessions and run remote commands with OpenSSH, including batch mode,
  bastions, host-key policy, and optional TTY allocation. Use when you need an
  interactive shell on a remote host or a one-shot remote command in automation.
license: MIT
metadata:
  author: dojo-community
  version: "1.0"
---

# SSH Connect

## When to Use

- Run a one-shot command on a remote machine
- Open an interactive shell for diagnosis or maintenance
- Reach a private host through a bastion with `-J` or `ProxyJump`
- Force or disable TTY allocation for remote commands
- Reuse an existing multiplexed connection

## Prerequisites

- OpenSSH client installed
- Reachable destination host and port
- A usable auth method: key, agent, or password
- Host-key policy decided up front for unattended runs

## Workflow

1. Choose the destination in `[user@]host` form.
2. Decide whether the job is interactive or a one-shot command.
3. Set `BatchMode=yes` for automation so failures are explicit.
4. Add `-J` or rely on `ProxyJump` if a bastion is required.
5. Force TTY with `-tt` only when the remote command needs one.

## Examples

```bash
# Interactive shell
SSH_HOST=host.example.com SSH_USER=ops ./scripts/run-ssh-command.sh

# One-shot command
SSH_HOST=host.example.com \
SSH_USER=ops \
SSH_COMMAND='uname -a' \
SSH_BATCH_MODE=true \
./scripts/run-ssh-command.sh

# Bastion hop
SSH_HOST=db.internal.example.com \
SSH_USER=ops \
SSH_PROXY_JUMP=bastion.example.com \
SSH_COMMAND='ps aux | grep postgres' \
./scripts/run-ssh-command.sh
```

## Edge Cases

- `Permission denied (publickey)`: load `[[ssh/keys]]` or `[[ssh/agent]]`, then retry with `ssh -vvv`.
- Host-key prompt in automation: set a deliberate `SSH_STRICT_HOST_KEY_CHECKING` policy instead of letting the process hang.
- Command needs a TTY: set `SSH_TTY=true`.
- Command must not allocate a TTY: set `SSH_DISABLE_TTY=true`.
- Repeated bursts of SSH commands: configure multiplexing in `[[ssh/config]]`.
