---
name: dynamic-forward
description: >
  Open a SOCKS proxy over SSH with `ssh -D`. Use when a SOCKS-aware client such
  as a browser or debugger needs flexible access through an SSH host or bastion
  to multiple destinations.
license: MIT
metadata:
  author: dojo-community
  version: "1.0"
---

# SSH Dynamic Forward

## When to Use

- A browser or tool can already use a SOCKS proxy
- Multiple remote destinations need temporary access through one SSH path
- You do not want to declare a separate local forward for each target

## Example

```bash
SSH_HOST=bastion.example.com \
SSH_USER=ops \
SSH_LOCAL_PORT=1080 \
./scripts/open-dynamic-forward.sh
```

## Notes

- Dynamic forwarding requires a SOCKS-aware client.
- For a single known destination, `[[ssh/tunnel/local-forward]]` is usually simpler.
