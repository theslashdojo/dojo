---
name: remote-forward
description: >
  Open a reverse SSH tunnel with `ssh -R` so a remote host exposes a listener
  that forwards back to a client-side service. Use when publishing a local dev
  server, receiving callbacks, or bridging into a private client network.
license: MIT
metadata:
  author: dojo-community
  version: "1.0"
---

# SSH Remote Forward

## When to Use

- Publish a local dev server through a reachable bastion
- Receive webhook callbacks into a machine without inbound access
- Create a temporary reverse tunnel for troubleshooting

## Example

```bash
SSH_HOST=bastion.example.com \
SSH_USER=ops \
SSH_REMOTE_PORT=8080 \
SSH_DEST_HOST=127.0.0.1 \
SSH_DEST_PORT=3000 \
./scripts/open-remote-forward.sh
```

## Notes

- Remote bind behavior may depend on server-side `GatewayPorts`.
- The destination host is resolved from the client side.
- Use the parent skill `[[ssh/tunnel]]` for backgrounding and keepalive guidance.
