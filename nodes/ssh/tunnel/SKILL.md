---
name: tunnel
description: >
  Open SSH port forwards for local access, reverse access, or SOCKS proxying.
  Use when a service is reachable through an SSH host but not directly exposed on
  the network, such as private databases, admin UIs, or reverse callbacks.
license: MIT
metadata:
  author: dojo-community
  version: "1.0"
---

# SSH Tunnel

## When to Use

- Reach a private database through a bastion
- Expose a local service through a remote host with a reverse tunnel
- Create a temporary SOCKS proxy for ad hoc access
- Keep a forwarding-only SSH session open with `-N`
- Background a verified tunnel after it is established

## Workflow

1. Choose the forwarding mode: local, remote, or dynamic.
2. Identify the SSH host that will anchor the tunnel.
3. Define the listening port and the destination host/port when required.
4. Use `ExitOnForwardFailure=yes` so backgrounded tunnels fail loudly.
5. Add keepalives for long-lived sessions.

## Examples

```bash
# Local port forward to a private Postgres instance
SSH_TUNNEL_MODE=local \
SSH_HOST=db-gateway.example.com \
SSH_USER=ops \
SSH_LOCAL_PORT=5433 \
SSH_DEST_HOST=127.0.0.1 \
SSH_DEST_PORT=5432 \
./scripts/open-tunnel.sh

# Reverse tunnel for a local dev server
SSH_TUNNEL_MODE=remote \
SSH_HOST=bastion.example.com \
SSH_USER=ops \
SSH_REMOTE_PORT=8080 \
SSH_DEST_HOST=127.0.0.1 \
SSH_DEST_PORT=3000 \
./scripts/open-tunnel.sh

# SOCKS proxy
SSH_TUNNEL_MODE=dynamic \
SSH_HOST=bastion.example.com \
SSH_USER=ops \
SSH_LOCAL_PORT=1080 \
./scripts/open-tunnel.sh
```

## Edge Cases

- Background mode needs `-n` as well as `-f`; the wrapper handles that.
- If the tunnel exits immediately, run it in the foreground first and inspect stderr.
- Remote listening on non-loopback interfaces may require server-side `GatewayPorts`.
- Long-lived tunnels should use `ServerAliveInterval` and `ServerAliveCountMax`.
