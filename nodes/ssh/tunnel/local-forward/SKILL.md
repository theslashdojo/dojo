---
name: local-forward
description: >
  Open a local SSH port forward with `ssh -L` so a remote service is reachable
  from the local machine. Use when accessing private databases, dashboards, or
  APIs through an SSH host or bastion.
license: MIT
metadata:
  author: dojo-community
  version: "1.0"
---

# SSH Local Forward

## When to Use

- Reach a private Postgres instance from your laptop
- Open a local window into an internal HTTP admin interface
- Keep the remote service private while exposing a local port only

## Example

```bash
SSH_HOST=db-gateway.example.com \
SSH_USER=ops \
SSH_LOCAL_PORT=5433 \
SSH_DEST_HOST=127.0.0.1 \
SSH_DEST_PORT=5432 \
./scripts/open-local-forward.sh
```

## Notes

- The destination host is resolved from the remote side.
- Local bind addresses control whether the listening port is private to the client.
- Use the parent skill `[[ssh/tunnel]]` for shared forwarding behavior and keepalives.
